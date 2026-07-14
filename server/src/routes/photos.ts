import { Hono } from 'hono';
import type { App } from '../types';

const MAX_PHOTO_BYTES = 10 * 1024 * 1024; // 10 MB

/** Mounted at /api — handles both /items/:id/photos (upload) and /photos/:id (get/delete). */
export const photos = new Hono<App>()
  .post('/items/:id/photos', async (c) => {
    const itemId = Number(c.req.param('id'));
    const item = await c.env.DB.prepare('SELECT id FROM items WHERE id = ?').bind(itemId).first();
    if (!item) return c.json({ error: 'item not found' }, 404);

    const contentType = c.req.header('Content-Type') ?? '';
    if (!contentType.startsWith('image/')) {
      return c.json({ error: 'body must be a raw image with an image/* Content-Type' }, 415);
    }
    // Buffer the body: R2 requires a known length for streams.
    const data = await c.req.arrayBuffer();
    if (data.byteLength === 0) return c.json({ error: 'empty body' }, 400);
    if (data.byteLength > MAX_PHOTO_BYTES) return c.json({ error: 'photo exceeds 10 MB limit' }, 413);

    const key = `items/${itemId}/${crypto.randomUUID()}`;
    await c.env.PHOTOS.put(key, data, { httpMetadata: { contentType } });
    const row = await c.env.DB.prepare(
      'INSERT INTO photos (item_id, r2_key, content_type, size) VALUES (?, ?, ?, ?) RETURNING id, item_id, content_type, size, created_at'
    )
      .bind(itemId, key, contentType, data.byteLength)
      .first();
    return c.json(row, 201);
  })
  .put('/items/:id/photos/reorder', async (c) => {
    const itemId = Number(c.req.param('id'));
    const body = await c.req.json<{ photo_ids: number[] }>();
    if (!body.photo_ids || !Array.isArray(body.photo_ids)) {
      return c.json({ error: 'invalid body' }, 400);
    }
    const stmts = body.photo_ids.map((photoId, index) => {
      return c.env.DB.prepare('UPDATE photos SET sort_order = ? WHERE id = ? AND item_id = ?').bind(index, photoId, itemId);
    });
    await c.env.DB.batch(stmts);
    return c.json({ ok: true });
  })
  .get('/photos/:id', async (c) => {
    const row = await c.env.DB.prepare('SELECT r2_key, content_type FROM photos WHERE id = ?')
      .bind(Number(c.req.param('id')))
      .first<{ r2_key: string; content_type: string }>();
    if (!row) return c.json({ error: 'not found' }, 404);
    const object = await c.env.PHOTOS.get(row.r2_key);
    if (!object) return c.json({ error: 'object missing from storage' }, 404);
    return new Response(object.body, {
      headers: {
        'Content-Type': row.content_type,
        'Cache-Control': 'private, max-age=86400',
        etag: object.httpEtag,
      },
    });
  })
  .delete('/photos/:id', async (c) => {
    const id = Number(c.req.param('id'));
    const row = await c.env.DB.prepare('SELECT r2_key FROM photos WHERE id = ?').bind(id).first<{ r2_key: string }>();
    if (!row) return c.json({ error: 'not found' }, 404);
    await c.env.PHOTOS.delete(row.r2_key);
    await c.env.DB.prepare('DELETE FROM photos WHERE id = ?').bind(id).run();
    return c.json({ ok: true });
  });
