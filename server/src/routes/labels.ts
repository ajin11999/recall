import { Hono } from 'hono';
import { z } from 'zod';
import { zValidator } from '@hono/zod-validator';
import type { App } from '../types';

const labelSchema = z.object({
  name: z.string().min(1),
  color: z.string().nullable().optional(),
});

export const labels = new Hono<App>()
  .get('/', async (c) => {
    const { results } = await c.env.DB.prepare(
      `SELECT l.*, (SELECT COUNT(*) FROM item_labels il WHERE il.label_id = l.id) AS item_count
       FROM labels l ORDER BY l.name`
    ).all();
    return c.json(results);
  })
  .post('/', zValidator('json', labelSchema), async (c) => {
    const body = c.req.valid('json');
    try {
      const row = await c.env.DB.prepare('INSERT INTO labels (name, color) VALUES (?, ?) RETURNING *')
        .bind(body.name, body.color ?? null)
        .first();
      return c.json(row, 201);
    } catch (e) {
      if (String(e).includes('UNIQUE')) return c.json({ error: 'label name already exists' }, 409);
      throw e;
    }
  })
  .put('/:id', zValidator('json', labelSchema.partial()), async (c) => {
    const id = Number(c.req.param('id'));
    const body = c.req.valid('json');
    const existing = await c.env.DB.prepare('SELECT * FROM labels WHERE id = ?').bind(id).first<Record<string, unknown>>();
    if (!existing) return c.json({ error: 'not found' }, 404);
    const row = await c.env.DB.prepare('UPDATE labels SET name = ?, color = ? WHERE id = ? RETURNING *')
      .bind(body.name ?? existing.name, body.color !== undefined ? body.color : existing.color, id)
      .first();
    return c.json(row);
  })
  .delete('/:id', async (c) => {
    const id = Number(c.req.param('id'));
    const { meta } = await c.env.DB.prepare('DELETE FROM labels WHERE id = ?').bind(id).run();
    if (meta.changes === 0) return c.json({ error: 'not found' }, 404);
    return c.json({ ok: true });
  });
