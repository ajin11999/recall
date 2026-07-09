import { Hono } from 'hono';
import { z } from 'zod';
import { zValidator } from '@hono/zod-validator';
import type { App } from '../types';

const locationSchema = z.object({
  name: z.string().min(1),
  parent_id: z.number().int().nullable().optional(),
  description: z.string().nullable().optional(),
});

export const locations = new Hono<App>()
  .get('/', async (c) => {
    const { results } = await c.env.DB.prepare(
      `SELECT l.*, (SELECT COUNT(*) FROM items i WHERE i.location_id = l.id) AS item_count
       FROM locations l ORDER BY l.name`
    ).all();
    return c.json(results);
  })
  .post('/', zValidator('json', locationSchema), async (c) => {
    const body = c.req.valid('json');
    const row = await c.env.DB.prepare(
      'INSERT INTO locations (name, parent_id, description) VALUES (?, ?, ?) RETURNING *'
    )
      .bind(body.name, body.parent_id ?? null, body.description ?? null)
      .first();
    return c.json(row, 201);
  })
  .put('/:id', zValidator('json', locationSchema.partial()), async (c) => {
    const id = Number(c.req.param('id'));
    const body = c.req.valid('json');
    const existing = await c.env.DB.prepare('SELECT * FROM locations WHERE id = ?').bind(id).first<Record<string, unknown>>();
    if (!existing) return c.json({ error: 'not found' }, 404);
    if (body.parent_id === id) return c.json({ error: 'location cannot be its own parent' }, 400);
    const row = await c.env.DB.prepare(
      'UPDATE locations SET name = ?, parent_id = ?, description = ? WHERE id = ? RETURNING *'
    )
      .bind(
        body.name ?? existing.name,
        body.parent_id !== undefined ? body.parent_id : existing.parent_id,
        body.description !== undefined ? body.description : existing.description,
        id
      )
      .first();
    return c.json(row);
  })
  .delete('/:id', async (c) => {
    const id = Number(c.req.param('id'));
    const { meta } = await c.env.DB.prepare('DELETE FROM locations WHERE id = ?').bind(id).run();
    if (meta.changes === 0) return c.json({ error: 'not found' }, 404);
    return c.json({ ok: true });
  });
