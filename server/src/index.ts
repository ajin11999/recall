import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { z } from 'zod';
import { zValidator } from '@hono/zod-validator';
import type { App } from './types';
import { authMiddleware, createToken, verifyPassword } from './auth';
import { items } from './routes/items';
import { locations } from './routes/locations';
import { labels } from './routes/labels';
import { photos } from './routes/photos';
import { maintenance } from './routes/maintenance';

const app = new Hono<App>();

// Bearer-token auth (no cookies), so a permissive CORS policy is safe; needed for the Flutter web build.
app.use('/api/*', cors());

app.get('/', (c) => c.json({ name: 'recall', status: 'ok' }));

app.post('/api/auth/login', zValidator('json', z.object({ password: z.string() })), async (c) => {
  const { password } = c.req.valid('json');
  if (!(await verifyPassword(password, c.env.PASSWORD_HASH))) {
    return c.json({ error: 'invalid password' }, 401);
  }
  return c.json({ token: await createToken(c.env.SESSION_SECRET) });
});

app.use('/api/*', authMiddleware);

app.route('/api/items', items);
app.route('/api/locations', locations);
app.route('/api/labels', labels);
app.route('/api', photos);
app.route('/api', maintenance);

app.notFound((c) => c.json({ error: 'not found' }, 404));
app.onError((err, c) => {
  console.error(err);
  return c.json({ error: 'internal error' }, 500);
});

export default app;
