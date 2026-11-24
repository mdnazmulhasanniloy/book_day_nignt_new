import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { parse } from 'yaml';

// Guards the contract files: a stray colon or quote in a description once made
// api-spec.yaml invalid without any test noticing. `yaml` also rejects duplicate keys.
const repoRoot = path.resolve(__dirname, '../../../../..');

const files = [
  'project-docs/04-architecture/api-spec.yaml',
  'backend/openapi.yaml',
];

describe('contract files are valid YAML', () => {
  for (const rel of files) {
    it(rel, () => {
      const full = path.join(repoRoot, rel);
      if (!fs.existsSync(full)) return; // not present in a partial checkout
      const doc = parse(fs.readFileSync(full, 'utf8')) as {
        paths?: Record<string, unknown>;
      };
      assert.ok(doc && typeof doc === 'object', 'document parsed to an object');
      assert.ok(doc.paths && Object.keys(doc.paths).length > 0, 'has paths');
    });
  }
});
