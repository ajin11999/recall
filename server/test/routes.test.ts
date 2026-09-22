import test from 'node:test';
import assert from 'node:assert/strict';

test('Advanced search location and tag parsing logic', () => {
  const parseQuery = (q: string) => {
    let decodedQ = q.trim();
    let itemQuery = decodedQ;
    let locationQuery: string | null = null;
    const tags: string[] = [];

    // Extract tags
    const tagRegex = /(?:#|tag:)([a-zA-Z0-9_-]+)/g;
    let match;
    while ((match = tagRegex.exec(decodedQ)) !== null) {
      tags.push(match[1].toLowerCase());
    }
    decodedQ = decodedQ.replace(tagRegex, '').replace(/\s+/g, ' ').trim();

    // Extract location
    const locRegex = /^(?:(.*?)\s+)?(?:in|at|inside)\s+(.*)$/i;
    const locMatch = decodedQ.match(locRegex);

    if (locMatch) {
      itemQuery = (locMatch[1] ?? '').trim();
      locationQuery = locMatch[2].trim();
    } else {
      itemQuery = decodedQ;
    }

    const words = itemQuery ? itemQuery.split(/\s+/).filter(Boolean) : [];

    return { itemQuery, words, locationQuery, tags };
  };

  // Case 1: Standard "item in location"
  const r1 = parseQuery('drill in garage');
  assert.equal(r1.itemQuery, 'drill');
  assert.deepEqual(r1.words, ['drill']);
  assert.equal(r1.locationQuery, 'garage');
  assert.deepEqual(r1.tags, []);

  // Case 2: Leading "in location" (previously broke!)
  const r2 = parseQuery('in garage');
  assert.equal(r2.itemQuery, '');
  assert.deepEqual(r2.words, []);
  assert.equal(r2.locationQuery, 'garage');

  // Case 3: Tag with location "#tools in garage" (previously broke!)
  const r3 = parseQuery('#tools in garage');
  assert.equal(r3.itemQuery, '');
  assert.deepEqual(r3.words, []);
  assert.equal(r3.locationQuery, 'garage');
  assert.deepEqual(r3.tags, ['tools']);

  // Case 4: Item + Tag + Location
  const r4 = parseQuery('cordless drill #tools at workshop');
  assert.equal(r4.itemQuery, 'cordless drill');
  assert.deepEqual(r4.words, ['cordless', 'drill']);
  assert.equal(r4.locationQuery, 'workshop');
  assert.deepEqual(r4.tags, ['tools']);

  // Case 5: Plus characters in search query are preserved
  const r5 = parseQuery('C++ book in office');
  assert.equal(r5.itemQuery, 'C++ book');
  assert.deepEqual(r5.words, ['C++', 'book']);
  assert.equal(r5.locationQuery, 'office');

  // Case 6: "inside" preposition
  const r6 = parseQuery('hammer inside shed');
  assert.equal(r6.itemQuery, 'hammer');
  assert.equal(r6.locationQuery, 'shed');
});

test('mark-bought quantity calculation handles out of stock items', () => {
  const calcNewQty = (bQty: number | undefined, existingQty: number) => {
    const currentQty = Number(existingQty);
    return bQty ?? (currentQty > 0 ? currentQty : 1);
  };

  // When an out-of-stock item (quantity 0) is marked bought, quantity defaults to 1
  assert.equal(calcNewQty(undefined, 0), 1);

  // When an existing item had quantity 5, it retains 5
  assert.equal(calcNewQty(undefined, 5), 5);

  // When explicit quantity is passed, it uses explicit quantity
  assert.equal(calcNewQty(3, 0), 3);
  assert.equal(calcNewQty(10, 5), 10);
});

test('label_ids parsing handles empty string safely', () => {
  const parseLabelIds = (raw: unknown): number[] => {
    return typeof raw === 'string' && raw.length > 0
      ? raw.split(',').filter(Boolean).map(Number)
      : [];
  };

  assert.deepEqual(parseLabelIds(null), []);
  assert.deepEqual(parseLabelIds(undefined), []);
  assert.deepEqual(parseLabelIds(''), []);
  assert.deepEqual(parseLabelIds('1,2,3'), [1, 2, 3]);
  assert.deepEqual(parseLabelIds('42'), [42]);
});
