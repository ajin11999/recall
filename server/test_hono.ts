import { Hono } from 'hono';

const app = new Hono();
app.get('/', (c) => {
  return c.json({ q: c.req.query('q') });
});

export default app;
