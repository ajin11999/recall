import { Hono } from 'hono';
import { z } from 'zod';
import { zValidator } from '@hono/zod-validator';
import type { App, Bindings } from '../types';

const itemSchema = z.object({
  name: z.string().min(1),
  description: z.string().nullable().optional(),
  quantity: z.number().int().min(0).optional(),
  location_id: z.number().int().nullable().optional(),
  serial_number: z.string().nullable().optional(),
  purchase_price: z.number().nullable().optional(),
  purchase_date: z.string().nullable().optional(),
  purchased_from: z.string().nullable().optional(),
  warranty_until: z.string().nullable().optional(),
  notes: z.string().nullable().optional(),
  label_ids: z.array(z.number().int()).optional(),
});

async function getItemDetail(db: Bindings['DB'], id: number) {
  const [item, labels, photos, schedules] = await db.batch([
    db.prepare('SELECT * FROM items WHERE id = ?').bind(id),
    db.prepare(
      'SELECT l.* FROM labels l JOIN item_labels il ON il.label_id = l.id WHERE il.item_id = ? ORDER BY l.name'
    ).bind(id),
    db.prepare('SELECT id, item_id, content_type, size, created_at FROM photos WHERE item_id = ? ORDER BY sort_order ASC, id ASC').bind(id),
    db.prepare('SELECT * FROM maintenance_schedules WHERE item_id = ? ORDER BY next_due_date').bind(id),
  ]);
  const row = item.results[0];
  if (!row) return null;
  return {
    ...row,
    labels: labels.results,
    photos: photos.results,
    maintenance_schedules: schedules.results,
  };
}

async function replaceLabels(db: Bindings['DB'], itemId: number, labelIds: number[]) {
  const stmts = [db.prepare('DELETE FROM item_labels WHERE item_id = ?').bind(itemId)];
  for (const labelId of labelIds) {
    stmts.push(db.prepare('INSERT OR IGNORE INTO item_labels (item_id, label_id) VALUES (?, ?)').bind(itemId, labelId));
  }
  await db.batch(stmts);
}

export const items = new Hono<App>()
  .get('/', async (c) => {
    const q = c.req.query('q') ?? null;
    const locationId = c.req.query('location_id') ?? null;
    const labelId = c.req.query('label_id') ?? null;
    const page = Math.max(1, Number(c.req.query('page') ?? 1) || 1);
    const perPage = Math.min(100, Math.max(1, Number(c.req.query('per_page') ?? 50) || 50));

    const where: string[] = [];
    const params: unknown[] = [];
    if (q) {
      const words = q.trim().split(/\s+/);
      for (const word of words) {
        where.push('(i.name LIKE ? OR i.description LIKE ? OR i.serial_number LIKE ?)');
        const like = `%${word}%`;
        params.push(like, like, like);
      }
    }
    if (locationId) {
      where.push('i.location_id = ?');
      params.push(Number(locationId));
    }
    if (labelId) {
      where.push('EXISTS (SELECT 1 FROM item_labels il WHERE il.item_id = i.id AND il.label_id = ?)');
      params.push(Number(labelId));
    }
    const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : '';

    const [list, count] = await c.env.DB.batch([
      c.env.DB.prepare(
        `SELECT i.*,
           (SELECT p.id FROM photos p WHERE p.item_id = i.id ORDER BY p.sort_order ASC, p.id ASC LIMIT 1) AS cover_photo_id,
           (SELECT GROUP_CONCAT(il.label_id) FROM item_labels il WHERE il.item_id = i.id) AS label_ids
         FROM items i ${whereSql}
         ORDER BY i.updated_at DESC
         LIMIT ? OFFSET ?`
      ).bind(...params, perPage, (page - 1) * perPage),
      c.env.DB.prepare(`SELECT COUNT(*) AS n FROM items i ${whereSql}`).bind(...params),
    ]);

    const itemsOut = (list.results as Record<string, unknown>[]).map((r) => ({
      ...r,
      label_ids: typeof r.label_ids === 'string' ? r.label_ids.split(',').map(Number) : [],
    }));
    return c.json({
      items: itemsOut,
      page,
      per_page: perPage,
      total: (count.results[0] as { n: number }).n,
    });
  })
  .get('/:id', async (c) => {
    const detail = await getItemDetail(c.env.DB, Number(c.req.param('id')));
    if (!detail) return c.json({ error: 'not found' }, 404);
    return c.json(detail);
  })
  .post('/', zValidator('json', itemSchema), async (c) => {
    const b = c.req.valid('json');
    const row = await c.env.DB.prepare(
      `INSERT INTO items (name, description, quantity, location_id, serial_number, purchase_price,
                          purchase_date, purchased_from, warranty_until, notes)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?) RETURNING id`
    )
      .bind(
        b.name,
        b.description ?? null,
        b.quantity ?? 1,
        b.location_id ?? null,
        b.serial_number ?? null,
        b.purchase_price ?? null,
        b.purchase_date ?? null,
        b.purchased_from ?? null,
        b.warranty_until ?? null,
        b.notes ?? null
      )
      .first<{ id: number }>();
    if (b.label_ids?.length) await replaceLabels(c.env.DB, row!.id, b.label_ids);
    return c.json(await getItemDetail(c.env.DB, row!.id), 201);
  })
  .put('/:id', zValidator('json', itemSchema.partial()), async (c) => {
    const id = Number(c.req.param('id'));
    const b = c.req.valid('json');
    const existing = await c.env.DB.prepare('SELECT * FROM items WHERE id = ?').bind(id).first<Record<string, unknown>>();
    if (!existing) return c.json({ error: 'not found' }, 404);

    const val = (key: keyof typeof b) => (b[key] !== undefined ? b[key] : (existing[key as string] as unknown));
    await c.env.DB.prepare(
      `UPDATE items SET name = ?, description = ?, quantity = ?, location_id = ?, serial_number = ?,
         purchase_price = ?, purchase_date = ?, purchased_from = ?, warranty_until = ?, notes = ?,
         updated_at = datetime('now')
       WHERE id = ?`
    )
      .bind(
        val('name'),
        val('description'),
        val('quantity'),
        val('location_id'),
        val('serial_number'),
        val('purchase_price'),
        val('purchase_date'),
        val('purchased_from'),
        val('warranty_until'),
        val('notes'),
        id
      )
      .run();
    if (b.label_ids !== undefined) await replaceLabels(c.env.DB, id, b.label_ids);
    return c.json(await getItemDetail(c.env.DB, id));
  })
  .delete('/:id', async (c) => {
    const id = Number(c.req.param('id'));
    const { results } = await c.env.DB.prepare('SELECT r2_key FROM photos WHERE item_id = ?').bind(id).all<{ r2_key: string }>();
    const { meta } = await c.env.DB.prepare('DELETE FROM items WHERE id = ?').bind(id).run();
    if (meta.changes === 0) return c.json({ error: 'not found' }, 404);
    if (results.length) await c.env.PHOTOS.delete(results.map((r) => r.r2_key));
    return c.json({ ok: true });
  });
