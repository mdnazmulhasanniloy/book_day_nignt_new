import test from 'node:test';
import assert from 'node:assert/strict';
import mediaRoutes from './media.routes';
import { requireMediaAuthMiddleware } from './media.middlewares';

// Guard against the route being re-registered without auth (HF-005 / S-01).
test('POST and DELETE /media both start with the auth guard', () => {
  const layers = (mediaRoutes as any).stack.filter(
    (l: any) => l.route?.path === '/media'
  );
  const methods = new Set<string>();
  for (const l of layers) {
    for (const m of Object.keys(l.route.methods)) {
      methods.add(m);
      assert.equal(
        l.route.stack[0].handle,
        requireMediaAuthMiddleware,
        `${m} /media must run the auth guard first`
      );
    }
  }
  assert.deepEqual([...methods].sort(), ['delete', 'post']);
});
