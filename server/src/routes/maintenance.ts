import { Hono } from 'hono';
import { z } from 'zod';
import { zValidator } from '@hono/zod-validator';
import type { App } from '../types';

const isoDate = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'expected YYYY-MM-DD');

const scheduleSchema = z.object({
  name: z.string().min(1),
  notes: z.string().nullable().optional(),
  interval_days: z.number().int().min(1),
  next_due_date: isoDate.optional(),
});

const completeSchema = z.object({
  completed_at: isoDate.optional(),
  notes: z.string().nullable().optional(),
  cost: z.number().nullable().optional(),
});

/** Mounted at /api — handles /items/:id/maintenance and /maintenance/*. */
export const maintenance = new Hono<App>()
  .get('/items/:id/maintenance', async (c) => {
    const { results } = await c.env.DB.prepare(
      'SELECT * FROM maintenance_schedules WHERE item_id = ? ORDER BY next_due_date'
    )
      .bind(Number(c.req.param('id')))
      .all();
    return c.json(results);
  })
  .post('/items/:id/maintenance', zValidator('json', scheduleSchema), async (c) => {
    const itemId = Number(c.req.param('id'));
    const item = await c.env.DB.prepare('SELECT id FROM items WHERE id = ?').bind(itemId).first();
    if (!item) return c.json({ error: 'item not found' }, 404);
    const b = c.req.valid('json');
    const row = await c.env.DB.prepare(
      `INSERT INTO maintenance_schedules (item_id, name, notes, interval_days, next_due_date)
       VALUES (?, ?, ?, ?, COALESCE(?, date('now', '+' || ? || ' days'))) RETURNING *`
    )
      .bind(itemId, b.name, b.notes ?? null, b.interval_days, b.next_due_date ?? null, b.interval_days)
      .first();
    return c.json(row, 201);
  })
  .put('/maintenance/:id', zValidator('json', scheduleSchema.partial()), async (c) => {
    const id = Number(c.req.param('id'));
    const b = c.req.valid('json');
    const existing = await c.env.DB.prepare('SELECT * FROM maintenance_schedules WHERE id = ?')
      .bind(id)
      .first<Record<string, unknown>>();
    if (!existing) return c.json({ error: 'not found' }, 404);
    const row = await c.env.DB.prepare(
      'UPDATE maintenance_schedules SET name = ?, notes = ?, interval_days = ?, next_due_date = ? WHERE id = ? RETURNING *'
    )
      .bind(
        b.name ?? existing.name,
        b.notes !== undefined ? b.notes : existing.notes,
        b.interval_days ?? existing.interval_days,
        b.next_due_date ?? existing.next_due_date,
        id
      )
      .first();
    return c.json(row);
  })
  .delete('/maintenance/:id', async (c) => {
    const { meta } = await c.env.DB.prepare('DELETE FROM maintenance_schedules WHERE id = ?')
      .bind(Number(c.req.param('id')))
      .run();
    if (meta.changes === 0) return c.json({ error: 'not found' }, 404);
    return c.json({ ok: true });
  })
  .post('/maintenance/:id/complete', zValidator('json', completeSchema), async (c) => {
    const id = Number(c.req.param('id'));
    const schedule = await c.env.DB.prepare('SELECT * FROM maintenance_schedules WHERE id = ?')
      .bind(id)
      .first<{ interval_days: number }>();
    if (!schedule) return c.json({ error: 'not found' }, 404);
    const b = c.req.valid('json');
    const completedAt = b.completed_at ?? new Date().toISOString().slice(0, 10);
    await c.env.DB.batch([
      c.env.DB.prepare('INSERT INTO maintenance_logs (schedule_id, completed_at, notes, cost) VALUES (?, ?, ?, ?)').bind(
        id,
        completedAt,
        b.notes ?? null,
        b.cost ?? null
      ),
      c.env.DB.prepare(
        "UPDATE maintenance_schedules SET next_due_date = date(?, '+' || interval_days || ' days') WHERE id = ?"
      ).bind(completedAt, id),
    ]);
    const row = await c.env.DB.prepare('SELECT * FROM maintenance_schedules WHERE id = ?').bind(id).first();
    return c.json(row);
  })
  .get('/maintenance/:id/logs', async (c) => {
    const { results } = await c.env.DB.prepare(
      'SELECT * FROM maintenance_logs WHERE schedule_id = ? ORDER BY completed_at DESC'
    )
      .bind(Number(c.req.param('id')))
      .all();
    return c.json(results);
  })
  .get('/maintenance-upcoming', async (c) => {
    const days = Math.min(365, Math.max(1, Number(c.req.query('days') ?? 60) || 60));
    const { results } = await c.env.DB.prepare(
      `SELECT ms.*, i.name AS item_name
       FROM maintenance_schedules ms
       JOIN items i ON i.id = ms.item_id
       WHERE ms.next_due_date <= date('now', '+' || ? || ' days')
         AND i.is_archived = 0
       ORDER BY ms.next_due_date`
    )
      .bind(days)
      .all();
    return c.json(results);
  });
