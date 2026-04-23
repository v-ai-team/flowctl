#!/usr/bin/env node
// setup-git-hooks.mjs — Install git hooks for cache invalidation
// Run once: node scripts/setup-git-hooks.mjs

import { writeFileSync, chmodSync, existsSync, mkdirSync } from 'fs';
import { join, resolve } from 'path';
import { fileURLToPath } from 'url';

const REPO = resolve(fileURLToPath(import.meta.url), '..', '..');
const GIT_HOOKS = join(REPO, '.git', 'hooks');

if (!existsSync(GIT_HOOKS)) {
  console.error('Not a git repo or .git/hooks missing');
  process.exit(1);
}

// post-commit: invalidate git cache after every commit
const postCommit = `#!/usr/bin/env bash
# Auto-invalidate MCP shell proxy git cache
bash "$(git rev-parse --show-toplevel)/scripts/hooks/invalidate-cache.sh" git 2>/dev/null || true
`;

// post-merge: invalidate after pull/merge
const postMerge = `#!/usr/bin/env bash
bash "$(git rev-parse --show-toplevel)/scripts/hooks/invalidate-cache.sh" git 2>/dev/null || true
`;

// post-checkout: invalidate after branch switch
const postCheckout = `#!/usr/bin/env bash
bash "$(git rev-parse --show-toplevel)/scripts/hooks/invalidate-cache.sh" git 2>/dev/null || true
`;

const hooks = {
  'post-commit':   postCommit,
  'post-merge':    postMerge,
  'post-checkout': postCheckout,
};

for (const [name, content] of Object.entries(hooks)) {
  const path = join(GIT_HOOKS, name);
  writeFileSync(path, content, 'utf8');
  chmodSync(path, 0o755);
  console.log(`✓ Installed: .git/hooks/${name}`);
}

console.log('\nGit hooks installed. MCP cache will auto-invalidate on git operations.');
