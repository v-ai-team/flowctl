#!/usr/bin/env node
/**
 * mcp-workflow-state.js
 * Backward-compatible MCP server for workflow-state tools.
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { CallToolRequestSchema, ListToolsRequestSchema } from '@modelcontextprotocol/sdk/types.js';
import { execFileSync } from 'child_process';
import { existsSync, readFileSync } from 'fs';
import { dirname, join, resolve } from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const REPO_ROOT = resolve(dirname(__filename), '..');
const STATE_FILE = join(REPO_ROOT, 'workflow-state.json');
const WORKFLOW_SCRIPT = join(REPO_ROOT, 'scripts', 'workflow.sh');

function runWorkflowCommand(args) {
  const out = execFileSync('bash', [WORKFLOW_SCRIPT, ...args.map((arg) => String(arg))], {
    cwd: REPO_ROOT,
    stdio: ['ignore', 'pipe', 'pipe'],
    encoding: 'utf8',
  });
  return out.trim();
}

function readWorkflowState() {
  if (!existsSync(STATE_FILE)) {
    return { error: 'workflow-state.json not found. Run `bash scripts/workflow.sh init --project "Name"` first.' };
  }
  return JSON.parse(readFileSync(STATE_FILE, 'utf8'));
}

function toolGetState() {
  return readWorkflowState();
}

function toolAddBlocker(args = {}) {
  if (!args.description || !String(args.description).trim()) {
    throw new Error('description is required');
  }
  const output = runWorkflowCommand(['blocker', 'add', String(args.description)]);
  return { ok: true, output, state: readWorkflowState() };
}

function toolAddDecision(args = {}) {
  if (!args.description || !String(args.description).trim()) {
    throw new Error('description is required');
  }
  const output = runWorkflowCommand(['decision', String(args.description)]);
  return { ok: true, output, state: readWorkflowState() };
}

function toolAdvanceStep(args = {}) {
  const approver = args.by && String(args.by).trim() ? String(args.by) : 'Workflow MCP';
  const commandArgs = ['approve', '--by', approver];
  if (args.skip_gate === true) {
    commandArgs.push('--skip-gate');
  }
  if (args.notes && String(args.notes).trim()) {
    runWorkflowCommand(['decision', String(args.notes)]);
  }
  const output = runWorkflowCommand(commandArgs);
  return { ok: true, output, state: readWorkflowState() };
}

function toolRequestApproval(args = {}) {
  const note = args.note && String(args.note).trim()
    ? String(args.note)
    : 'Approval requested via workflow-state MCP.';
  const output = runWorkflowCommand(['decision', `[APPROVAL REQUEST] ${note}`]);
  return { ok: true, output, state: readWorkflowState() };
}

const tools = [
  {
    name: 'workflow_get_state',
    description: 'Read current workflow-state.json payload.',
    inputSchema: { type: 'object', properties: {} },
    handler: toolGetState,
  },
  {
    name: 'workflow_advance_step',
    description: 'Approve current step and move to the next step.',
    inputSchema: {
      type: 'object',
      properties: {
        by: { type: 'string' },
        notes: { type: 'string' },
        skip_gate: { type: 'boolean' },
      },
    },
    handler: toolAdvanceStep,
  },
  {
    name: 'workflow_request_approval',
    description: 'Record an approval request note in workflow decisions.',
    inputSchema: {
      type: 'object',
      properties: {
        note: { type: 'string' },
      },
    },
    handler: toolRequestApproval,
  },
  {
    name: 'workflow_add_blocker',
    description: 'Add blocker to current step.',
    inputSchema: {
      type: 'object',
      properties: {
        description: { type: 'string' },
      },
      required: ['description'],
    },
    handler: toolAddBlocker,
  },
  {
    name: 'workflow_add_decision',
    description: 'Add decision to current step.',
    inputSchema: {
      type: 'object',
      properties: {
        description: { type: 'string' },
      },
      required: ['description'],
    },
    handler: toolAddDecision,
  },
];

const server = new Server(
  { name: 'workflow-state', version: '1.0.0' },
  { capabilities: { tools: {} } },
);

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: tools.map((tool) => ({
    name: tool.name,
    description: tool.description,
    inputSchema: tool.inputSchema,
  })),
}));

server.setRequestHandler(CallToolRequestSchema, async (req) => {
  const tool = tools.find((item) => item.name === req.params.name);
  if (!tool) {
    return {
      isError: true,
      content: [{ type: 'text', text: JSON.stringify({ error: `Unknown tool: ${req.params.name}` }) }],
    };
  }

  try {
    const result = tool.handler(req.params.arguments ?? {});
    return { content: [{ type: 'text', text: JSON.stringify(result, null, 2) }] };
  } catch (error) {
    return {
      isError: true,
      content: [{ type: 'text', text: JSON.stringify({ error: String(error.message || error) }) }],
    };
  }
});

const transport = new StdioServerTransport();
await server.connect(transport);
