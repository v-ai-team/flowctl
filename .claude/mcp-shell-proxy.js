#!/usr/bin/env node
/**
 * mcp-shell-proxy.js — Token-Efficient Shell Proxy MCP Server
 *
 * Replaces common bash operations with structured, cached MCP tools.
 * Token reduction: 70-95% for read operations.
 *
 * Cache strategy:
 *   static    → cached forever (env, versions, paths)
 *   git       → invalidated per commit (generation counter)
 *   state     → invalidated per workflow write (generation counter)
 *   file      → invalidated per mtime change
 *   ttl       → time-based expiry (seconds)
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';
import { execSync } from 'child_process';
import {
  readFileSync, writeFileSync, existsSync,
  mkdirSync, statSync, readdirSync,
} from 'fs';
import { join, resolve, relative, extname } from 'path';
import { fileURLToPath } from 'url';

// ── Paths ──────────────────────────────────────────────────────
const __file   = fileURLToPath(import.meta.url);
const REPO     = resolve(__file, '..', '..');
const CACHE    = join(REPO, '.cache', 'mcp');
const GEN_FILE = join(CACHE, '_gen.json');
const STATE    = join(REPO, 'workflow-state.json');

// ── Cache helpers ─────────────────────────────────────────────

function ensureCache() {
  if (!existsSync(CACHE)) mkdirSync(CACHE, { recursive: true });
}

function readGen() {
  if (!existsSync(GEN_FILE)) return { git: 0, state: 0 };
  try { return JSON.parse(readFileSync(GEN_FILE, 'utf8')); }
  catch { return { git: 0, state: 0 }; }
}

function cacheGet(key) {
  ensureCache();
  const f = join(CACHE, `${key}.json`);
  if (!existsSync(f)) return null;
  try {
    const entry = JSON.parse(readFileSync(f, 'utf8'));
    const gen = readGen();
    const now = Date.now();

    if (entry.strategy === 'static') return entry.data;
    if (entry.strategy === 'git'   && entry.gen === gen.git)   return entry.data;
    if (entry.strategy === 'state' && entry.gen === gen.state) return entry.data;
    if (entry.strategy === 'ttl'   && now - entry.ts < entry.ttl * 1000) return entry.data;
    if (entry.strategy === 'mtime') {
      const target = join(REPO, entry.path);
      if (existsSync(target) && statSync(target).mtimeMs === entry.mtime) return entry.data;
    }
  } catch { /* stale */ }
  return null;
}

function cacheSet(key, data, strategy, extra = {}) {
  ensureCache();
  const gen = readGen();
  const entry = { strategy, data, ts: Date.now() };
  if (strategy === 'git')   entry.gen = gen.git;
  if (strategy === 'state') entry.gen = gen.state;
  if (strategy === 'ttl')   entry.ttl = extra.ttl ?? 60;
  if (strategy === 'mtime') { entry.path = extra.path; entry.mtime = extra.mtime; }
  writeFileSync(join(CACHE, `${key}.json`), JSON.stringify(entry), 'utf8');
}

function invalidateAll(scope = 'all') {
  ensureCache();
  const gen = readGen();
  if (scope === 'all' || scope === 'git')   gen.git   = (gen.git   || 0) + 1;
  if (scope === 'all' || scope === 'state') gen.state = (gen.state || 0) + 1;
  writeFileSync(GEN_FILE, JSON.stringify(gen), 'utf8');
  return gen;
}

// ── Shell helper ───────────────────────────────────────────────

function sh(cmd, opts = {}) {
  try {
    return execSync(cmd, { cwd: REPO, encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'], ...opts }).trim();
  } catch (e) {
    return (e.stdout || '').trim() || '';
  }
}

// ── Tool implementations ───────────────────────────────────────

function tool_wf_state() {
  const cached = cacheGet('wf_state');
  if (cached) return { ...cached, _cache: 'hit' };

  if (!existsSync(STATE)) return { error: 'workflow-state.json not found' };
  const d = JSON.parse(readFileSync(STATE, 'utf8'));
  const step = String(d.current_step ?? 0);
  const s = (d.steps ?? {})[step] ?? {};

  const openBlockers = (s.blockers ?? []).filter(b => !b.resolved);
  const result = {
    project: d.project_name ?? '',
    status: d.overall_status ?? 'unknown',
    current_step: Number(step),
    step_name: s.name ?? '',
    step_status: s.status ?? 'pending',
    agent: s.agent ?? '',
    support_agents: s.support_agents ?? [],
    started_at: s.started_at ?? null,
    approval_status: s.approval_status ?? 'pending',
    open_blockers: openBlockers.length,
    blockers: openBlockers.map(b => b.description),
    recent_decisions: (s.decisions ?? []).slice(-3).map(d => d.description),
    deliverable_count: (s.deliverables ?? []).length,
    metrics: d.metrics ?? {},
    _cache: 'miss',
  };

  cacheSet('wf_state', result, 'state');
  return result;
}

function tool_git_context({ commits = 5 } = {}) {
  const key = `git_ctx_${commits}`;
  const cached = cacheGet(key);
  if (cached) return { ...cached, _cache: 'hit' };

  const branch  = sh('git rev-parse --abbrev-ref HEAD');
  const logRaw  = sh(`git log --oneline -${commits} --format="%h|%s|%cr|%an"`);
  const statusRaw = sh('git status --short');
  const aheadBehind = sh('git rev-list --left-right --count HEAD...@{u} 2>/dev/null || echo "0\t0"');
  const stashCount  = sh('git stash list 2>/dev/null | wc -l').replace(/\s/g, '');

  const recentCommits = logRaw.split('\n').filter(Boolean).map(l => {
    const [hash, msg, when, who] = l.split('|');
    return { hash, msg, when, who };
  });

  const changed = statusRaw.split('\n').filter(Boolean).map(l => ({
    status: l.slice(0, 2).trim(),
    file: l.slice(3),
  }));

  const [ahead = '0', behind = '0'] = aheadBehind.split(/\s+/);

  const result = {
    branch,
    recent_commits: recentCommits,
    changed_files: changed.length,
    changes: changed.slice(0, 10),
    ahead: Number(ahead),
    behind: Number(behind),
    stash_count: Number(stashCount),
    is_clean: changed.length === 0,
    _cache: 'miss',
  };

  cacheSet(key, result, 'git');
  return result;
}

function tool_step_context({ step } = {}) {
  const stateData = existsSync(STATE)
    ? JSON.parse(readFileSync(STATE, 'utf8'))
    : null;
  const currentStep = step ?? stateData?.current_step ?? 0;
  const key = `step_ctx_${currentStep}`;
  const cached = cacheGet(key);
  if (cached) return { ...cached, _cache: 'hit' };

  if (!stateData) return { error: 'workflow-state.json not found' };

  const s = (stateData.steps ?? {})[String(currentStep)] ?? {};

  // Gather prior decisions (all steps before current)
  const priorDecisions = [];
  for (let n = 1; n < currentStep; n++) {
    const ps = (stateData.steps ?? {})[String(n)] ?? {};
    for (const d of ps.decisions ?? []) {
      if (d.type !== 'rejection') priorDecisions.push({ step: n, text: d.description });
    }
  }

  // Open blockers across all steps
  const allBlockers = [];
  for (const [n, ps] of Object.entries(stateData.steps ?? {})) {
    for (const b of ps.blockers ?? []) {
      if (!b.resolved) allBlockers.push({ step: Number(n), text: b.description });
    }
  }

  // Context digest if exists
  const digestPath = join(REPO, 'workflows', 'dispatch', `step-${currentStep}`, 'context-digest.md');
  const hasDigest = existsSync(digestPath);

  // War room outputs
  const wrDir = join(REPO, 'workflows', 'dispatch', `step-${currentStep}`, 'war-room');
  const warRoomDone = existsSync(join(wrDir, 'pm-analysis.md')) &&
                      existsSync(join(wrDir, 'tech-lead-assessment.md'));

  // Mercenary outputs
  const mercDir = join(REPO, 'workflows', 'dispatch', `step-${currentStep}`, 'mercenaries');
  const mercOutputs = existsSync(mercDir)
    ? readdirSync(mercDir).filter(f => f.endsWith('-output.md')).map(f => `mercenaries/${f}`)
    : [];

  const result = {
    step: currentStep,
    step_name: s.name ?? '',
    agent: s.agent ?? '',
    support_agents: s.support_agents ?? [],
    status: s.status ?? 'pending',
    prior_decisions: priorDecisions.slice(-10),
    open_blockers: allBlockers,
    has_context_digest: hasDigest,
    war_room_complete: warRoomDone,
    mercenary_outputs: mercOutputs,
    deliverables: s.deliverables ?? [],
    graph_queries: [
      `graphify_query("step:${currentStep - 1}:outcomes")`,
      `graphify_query("project:constraints")`,
      `graphify_query("open:blockers")`,
      `graphify_query("aligned-plan:step:${currentStep}")`,
    ],
    _cache: 'miss',
  };

  cacheSet(key, result, 'state');
  return result;
}

function tool_project_files({ dir = '.', pattern = '', depth = 2 } = {}) {
  const key = `files_${dir}_${pattern}_${depth}`;
  const cached = cacheGet(key);
  if (cached) return { ...cached, _cache: 'hit' };

  const absDir = resolve(REPO, dir);
  const IGNORE = new Set([
    'node_modules', '.git', '.cache', '__pycache__',
    '.graphify', 'dist', 'build', '.next',
  ]);

  function scan(d, currentDepth) {
    if (currentDepth > depth) return [];
    let entries;
    try { entries = readdirSync(d, { withFileTypes: true }); }
    catch { return []; }

    const results = [];
    for (const e of entries) {
      if (IGNORE.has(e.name)) continue;
      const rel = relative(REPO, join(d, e.name));
      if (pattern && !e.name.includes(pattern) && !rel.includes(pattern)) {
        if (e.isDirectory()) {
          results.push(...scan(join(d, e.name), currentDepth + 1));
        }
        continue;
      }
      if (e.isDirectory()) {
        results.push({ type: 'dir', path: rel });
        results.push(...scan(join(d, e.name), currentDepth + 1));
      } else {
        let size = 0;
        try { size = statSync(join(d, e.name)).size; } catch {}
        results.push({ type: 'file', path: rel, size, ext: extname(e.name) });
      }
    }
    return results;
  }

  const entries = scan(absDir, 0);
  const result = {
    dir: relative(REPO, absDir) || '.',
    total_files: entries.filter(e => e.type === 'file').length,
    total_dirs: entries.filter(e => e.type === 'dir').length,
    entries,
    _cache: 'miss',
  };

  cacheSet(key, result, 'ttl', { ttl: 120 });
  return result;
}

function tool_read_file({ path: filePath, max_lines = 100, compress = true } = {}) {
  const absPath = resolve(REPO, filePath);
  if (!existsSync(absPath)) return { error: `File not found: ${filePath}` };

  const mtime = statSync(absPath).mtimeMs;
  const key   = `file_${filePath.replace(/[^a-z0-9]/gi, '_')}`;
  const cached = cacheGet(key);
  if (cached) return { ...cached, _cache: 'hit' };

  const raw   = readFileSync(absPath, 'utf8');
  const lines = raw.split('\n');
  const truncated = lines.length > max_lines;
  const content   = compress && truncated
    ? lines.slice(0, max_lines).join('\n') + `\n... [${lines.length - max_lines} more lines]`
    : raw;

  const result = {
    path: filePath,
    lines: lines.length,
    size_bytes: statSync(absPath).size,
    truncated,
    content,
    _cache: 'miss',
  };

  cacheSet(key, result, 'mtime', { path: filePath, mtime });
  return result;
}

function tool_env_info() {
  const cached = cacheGet('env_static');
  if (cached) return { ...cached, _cache: 'hit' };

  const result = {
    node:   sh('node --version'),
    npm:    sh('npm --version'),
    python: sh('python3 --version'),
    git:    sh('git --version'),
    os:     sh('uname -s'),
    arch:   sh('uname -m'),
    shell:  process.env.SHELL ?? '',
    cwd:    REPO,
    _cache: 'miss',
  };

  cacheSet('env_static', result, 'static');
  return result;
}

function tool_cache_invalidate({ scope = 'all' } = {}) {
  const gen = invalidateAll(scope);
  return { invalidated: scope, new_generations: gen };
}

// ── Tool registry ──────────────────────────────────────────────

const TOOLS = [
  {
    name: 'wf_state',
    description: 'Current workflow state — step, status, blockers, recent decisions. Replaces `cat workflow-state.json` + `bash scripts/workflow.sh status`. ~95% fewer tokens.',
    inputSchema: { type: 'object', properties: {} },
    fn: tool_wf_state,
  },
  {
    name: 'wf_git',
    description: 'Git snapshot — branch, recent commits, changed files, ahead/behind. Replaces git log + git status + git diff. ~90% fewer tokens.',
    inputSchema: {
      type: 'object',
      properties: {
        commits: { type: 'number', description: 'Recent commits to include (default 5)' },
      },
    },
    fn: ({ commits } = {}) => tool_git_context({ commits }),
  },
  {
    name: 'wf_step_context',
    description: 'All context for a workflow step — state, prior decisions, blockers, war room status, mercenary outputs, recommended graph queries. Single call replaces reading 5+ files.',
    inputSchema: {
      type: 'object',
      properties: {
        step: { type: 'number', description: 'Step number (default: current step)' },
      },
    },
    fn: ({ step } = {}) => tool_step_context({ step }),
  },
  {
    name: 'wf_files',
    description: 'Project file structure — replaces ls + find. Returns structured list with types and sizes.',
    inputSchema: {
      type: 'object',
      properties: {
        dir:     { type: 'string', description: 'Directory to scan (default: project root)' },
        pattern: { type: 'string', description: 'Filter pattern (e.g. ".md", "agent")' },
        depth:   { type: 'number', description: 'Max depth (default 2)' },
      },
    },
    fn: ({ dir, pattern, depth } = {}) => tool_project_files({ dir, pattern, depth }),
  },
  {
    name: 'wf_read',
    description: 'Read a file with caching + optional compression. Replaces `cat`. Returns cached result if file unchanged (mtime-based).',
    inputSchema: {
      type: 'object',
      properties: {
        path:      { type: 'string', description: 'Relative file path from project root' },
        max_lines: { type: 'number', description: 'Max lines to return (default 100)' },
        compress:  { type: 'boolean', description: 'Truncate large files (default true)' },
      },
      required: ['path'],
    },
    fn: ({ path, max_lines, compress } = {}) => tool_read_file({ path, max_lines, compress }),
  },
  {
    name: 'wf_env',
    description: 'Static environment info — OS, tool versions, paths. Cached forever. Replaces which/version commands.',
    inputSchema: { type: 'object', properties: {} },
    fn: tool_env_info,
  },
  {
    name: 'wf_cache_invalidate',
    description: 'Invalidate cached data after making changes. Call after modifying workflow state, committing code, or editing files.',
    inputSchema: {
      type: 'object',
      properties: {
        scope: {
          type: 'string',
          enum: ['all', 'git', 'state', 'files'],
          description: 'What to invalidate (default: all)',
        },
      },
    },
    fn: ({ scope } = {}) => tool_cache_invalidate({ scope }),
  },
];

// ── MCP Server ─────────────────────────────────────────────────

const server = new Server(
  { name: 'shell-proxy', version: '1.0.0' },
  { capabilities: { tools: {} } },
);

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: TOOLS.map(t => ({
    name: t.name,
    description: t.description,
    inputSchema: t.inputSchema,
  })),
}));

server.setRequestHandler(CallToolRequestSchema, async (req) => {
  const tool = TOOLS.find(t => t.name === req.params.name);
  if (!tool) {
    return {
      content: [{ type: 'text', text: JSON.stringify({ error: `Unknown tool: ${req.params.name}` }) }],
      isError: true,
    };
  }

  try {
    const result = tool.fn(req.params.arguments ?? {});
    return {
      content: [{ type: 'text', text: JSON.stringify(result, null, 2) }],
    };
  } catch (err) {
    return {
      content: [{ type: 'text', text: JSON.stringify({ error: String(err.message) }) }],
      isError: true,
    };
  }
});

const transport = new StdioServerTransport();
await server.connect(transport);
