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
  is_archived: z.boolean().optional(),
  is_consumable: z.boolean().optional(),
  min_quantity: z.number().int().min(0).optional(),
  is_wishlist: z.boolean().optional(),
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
    cover_photo_id: (photos.results[0] as { id: number } | undefined)?.id ?? null,
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
    const locationIdRaw = c.req.query('location_id');
    const locationId = (locationIdRaw && locationIdRaw !== 'null' && locationIdRaw !== 'undefined' && !isNaN(Number(locationIdRaw))) ? Number(locationIdRaw) : null;
    const labelIdRaw = c.req.query('label_id');
    const labelId = (labelIdRaw && labelIdRaw !== 'null' && labelIdRaw !== 'undefined' && !isNaN(Number(labelIdRaw))) ? Number(labelIdRaw) : null;
    const isAdvanced = c.req.query('advanced') === 'true';
    const includeArchived = c.req.query('include_archived') === 'true';
    const isWishlistParam = c.req.query('is_wishlist');
    const isConsumableParam = c.req.query('is_consumable');
    const isLowStockParam = c.req.query('low_stock') === 'true';
    const page = Math.max(1, Number(c.req.query('page') ?? 1) || 1);
    const perPage = Math.min(100, Math.max(1, Number(c.req.query('per_page') ?? 50) || 50));

    const where: string[] = [];
    const params: unknown[] = [];
    let withClause = '';
    
    if (!includeArchived) {
      where.push('i.is_archived = 0');
    }

    if (isWishlistParam === 'true') {
      where.push('i.is_wishlist = 1');
    } else if (isWishlistParam === 'false' || isWishlistParam === undefined || isWishlistParam === null) {
      where.push('i.is_wishlist = 0');
    }
    // If isWishlistParam === 'all', we don't filter by is_wishlist

    if (isConsumableParam === 'true') {
      where.push('i.is_consumable = 1');
    } else if (isConsumableParam === 'false') {
      where.push('i.is_consumable = 0');
    }

    if (isLowStockParam) {
      where.push('i.is_consumable = 1 AND i.quantity <= i.min_quantity AND i.is_wishlist = 0');
    }

    if (q) {
      let decodedQ = q.trim();
      let itemQuery = decodedQ;
      let locationQuery: string | null = null;
      const tags: string[] = [];

      if (isAdvanced) {
        // Extract tags: #tagname or tag:tagname
        const tagRegex = /(?:#|tag:)([a-zA-Z0-9_-]+)/g;
        let match;
        while ((match = tagRegex.exec(decodedQ)) !== null) {
          tags.push(match[1].toLowerCase());
        }
        decodedQ = decodedQ.replace(tagRegex, '').replace(/\s+/g, ' ').trim();

        // Extract location (e.g. "drill in garage" or "in garage")
        const locRegex = /^(?:(.*?)\s+)?(?:in|at|inside)\s+(.*)$/i;
        const locMatch = decodedQ.match(locRegex);
        
        if (locMatch) {
          itemQuery = (locMatch[1] ?? '').trim();
          locationQuery = locMatch[2].trim();
        } else {
          itemQuery = decodedQ;
        }

        // Add tag filters
        for (const tag of tags) {
          where.push(`EXISTS (SELECT 1 FROM item_labels il JOIN labels l ON l.id = il.label_id WHERE il.item_id = i.id AND LOWER(l.name) = ?)`);
          params.push(tag);
        }

        // Add location filter with CTE
        if (locationQuery) {
          withClause = `WITH RECURSIVE LocationAncestors AS (
            SELECT id as location_id, id as ancestor_id, name as ancestor_name FROM locations
            UNION ALL
            SELECT la.location_id, p.id as ancestor_id, p.name as ancestor_name
            FROM LocationAncestors la
            JOIN locations c ON la.ancestor_id = c.id
            JOIN locations p ON c.parent_id = p.id
          )`;
          
          where.push(`EXISTS (
            SELECT 1 FROM LocationAncestors la 
            WHERE la.location_id = i.location_id 
            AND LOWER(la.ancestor_name) LIKE ?
          )`);
          params.push(`%${locationQuery.toLowerCase()}%`);
        }
      }

      if (itemQuery) {
        const words = itemQuery.split(/\s+/).filter(Boolean);
        for (const word of words) {
          where.push('(LOWER(i.name) LIKE ? OR LOWER(COALESCE(i.description, \'\')) LIKE ? OR LOWER(COALESCE(i.serial_number, \'\')) LIKE ?)');
          const like = `%${word.toLowerCase()}%`;
          params.push(like, like, like);
        }
      }
    }

    if (locationId !== null) {
      where.push('i.location_id = ?');
      params.push(locationId);
    }
    if (labelId !== null) {
      where.push('EXISTS (SELECT 1 FROM item_labels il WHERE il.item_id = i.id AND il.label_id = ?)');
      params.push(labelId);
    }
    const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : '';

    const [list, count] = await c.env.DB.batch([
      c.env.DB.prepare(
        `${withClause} SELECT i.*,
           (SELECT p.id FROM photos p WHERE p.item_id = i.id ORDER BY p.sort_order ASC, p.id ASC LIMIT 1) AS cover_photo_id,
           (SELECT GROUP_CONCAT(il.label_id) FROM item_labels il WHERE il.item_id = i.id) AS label_ids
         FROM items i ${whereSql}
         ORDER BY i.updated_at DESC
         LIMIT ? OFFSET ?`
      ).bind(...params, perPage, (page - 1) * perPage),
      c.env.DB.prepare(`${withClause} SELECT COUNT(*) AS n FROM items i ${whereSql}`).bind(...params),
    ]);

    const itemsOut = (list.results as Record<string, unknown>[]).map((r) => ({
      ...r,
      label_ids: typeof r.label_ids === 'string' && r.label_ids.length > 0
        ? r.label_ids.split(',').filter(Boolean).map(Number)
        : [],
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
                          purchase_date, purchased_from, warranty_until, notes, is_consumable, min_quantity, is_wishlist, is_archived)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) RETURNING id`
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
        b.notes ?? null,
        b.is_consumable ? 1 : 0,
        b.min_quantity ?? 0,
        b.is_wishlist ? 1 : 0,
        b.is_archived ? 1 : 0
      )
      .first<{ id: number }>();
    if (b.label_ids?.length) await replaceLabels(c.env.DB, row!.id, b.label_ids);
    return c.json(await getItemDetail(c.env.DB, row!.id), 201);
  })
  .put('/bulk-move', zValidator('json', z.object({ item_ids: z.array(z.number()), location_id: z.number().nullable() })), async (c) => {
    const { item_ids, location_id } = c.req.valid('json');
    if (item_ids.length === 0) return c.json({ ok: true });
    
    const placeholders = item_ids.map(() => '?').join(',');
    await c.env.DB.prepare(`UPDATE items SET location_id = ?, updated_at = datetime('now') WHERE id IN (${placeholders})`)
      .bind(location_id, ...item_ids)
      .run();
    return c.json({ ok: true });
  })
  .post('/:id/consume', zValidator('json', z.object({ amount: z.number().int().min(1).optional() })), async (c) => {
    const id = Number(c.req.param('id'));
    const amount = c.req.valid('json').amount ?? 1;
    const existing = await c.env.DB.prepare('SELECT quantity FROM items WHERE id = ?').bind(id).first<{ quantity: number }>();
    if (!existing) return c.json({ error: 'not found' }, 404);

    const newQty = Math.max(0, existing.quantity - amount);
    await c.env.DB.prepare('UPDATE items SET quantity = ?, updated_at = datetime(\'now\') WHERE id = ?')
      .bind(newQty, id)
      .run();
    return c.json(await getItemDetail(c.env.DB, id));
  })
  .post('/:id/restock', zValidator('json', z.object({ amount: z.number().int().min(1).optional() })), async (c) => {
    const id = Number(c.req.param('id'));
    const amount = c.req.valid('json').amount ?? 1;
    const existing = await c.env.DB.prepare('SELECT quantity FROM items WHERE id = ?').bind(id).first<{ quantity: number }>();
    if (!existing) return c.json({ error: 'not found' }, 404);

    const newQty = existing.quantity + amount;
    await c.env.DB.prepare('UPDATE items SET quantity = ?, updated_at = datetime(\'now\') WHERE id = ?')
      .bind(newQty, id)
      .run();
    return c.json(await getItemDetail(c.env.DB, id));
  })
  .post('/:id/mark-bought', zValidator('json', z.object({
    location_id: z.number().int().nullable().optional(),
    purchase_price: z.number().nullable().optional(),
    purchase_date: z.string().nullable().optional(),
    quantity: z.number().int().min(1).optional(),
  })), async (c) => {
    const id = Number(c.req.param('id'));
    const b = c.req.valid('json');
    const existing = await c.env.DB.prepare('SELECT * FROM items WHERE id = ?').bind(id).first<Record<string, unknown>>();
    if (!existing) return c.json({ error: 'not found' }, 404);

    const todayStr = new Date().toISOString().split('T')[0];
    const newLocationId = b.location_id !== undefined ? b.location_id : existing.location_id;
    const newPrice = b.purchase_price !== undefined ? b.purchase_price : existing.purchase_price;
    const newDate = b.purchase_date ?? existing.purchase_date ?? todayStr;
    const currentQty = Number(existing.quantity);
    const newQty = b.quantity ?? (currentQty > 0 ? currentQty : 1);

    await c.env.DB.prepare(
      `UPDATE items SET is_wishlist = 0, location_id = ?, purchase_price = ?, purchase_date = ?, quantity = ?, updated_at = datetime('now')
       WHERE id = ?`
    )
      .bind(newLocationId, newPrice, newDate, newQty, id)
      .run();
    return c.json(await getItemDetail(c.env.DB, id));
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
         is_archived = ?, is_consumable = ?, min_quantity = ?, is_wishlist = ?, updated_at = datetime('now')
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
        b.is_archived !== undefined ? (b.is_archived ? 1 : 0) : existing.is_archived,
        b.is_consumable !== undefined ? (b.is_consumable ? 1 : 0) : existing.is_consumable,
        val('min_quantity'),
        b.is_wishlist !== undefined ? (b.is_wishlist ? 1 : 0) : existing.is_wishlist,
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

