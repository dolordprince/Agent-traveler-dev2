import * as fs from 'fs/promises';
import * as path from 'path';
import { execFile } from 'child_process';
import { promisify } from 'util';

const execFileAsync = promisify(execFile);

const WORKSPACE_ROOT = process.env.TRAVELER_WORKSPACE_ROOT || '/root/Agent-traveler-dev2/workspace';
const KNOWLEDGE_ROOT = process.env.TRAVELER_KNOWLEDGE_ROOT || '/root/Agent-traveler-dev2/knowledge';

const ALLOWED_COMMANDS = new Set([
  'npm',
  'npx',
  'pnpm',
  'node',
  'python',
  'python3',
  'pytest',
  'git',
]);

function securePath(root: string, targetPath: string): string {
  const resolvedRoot = path.resolve(root);
  const resolvedTarget = path.resolve(resolvedRoot, targetPath || '.');
  if (!resolvedTarget.startsWith(resolvedRoot)) {
    throw new Error(`Path traversal violation detected: ${targetPath}`);
  }
  return resolvedTarget;
}

export async function readFile(filePath: string): Promise<string> {
  const safePath = securePath(WORKSPACE_ROOT, filePath);
  return await fs.readFile(safePath, 'utf8');
}

export async function writeFile(filePath: string, content: string): Promise<void> {
  const safePath = securePath(WORKSPACE_ROOT, filePath);
  await fs.mkdir(path.dirname(safePath), { recursive: true });
  await fs.writeFile(safePath, content, 'utf8');
}

export async function listFiles(dirPath: string = '.'): Promise<string[]> {
  const safePath = securePath(WORKSPACE_ROOT, dirPath);
  try {
    const entries = await fs.readdir(safePath, { withFileTypes: true });
    const results: string[] = [];
    for (const entry of entries) {
      if (entry.name === 'node_modules' || entry.name === '.git') continue;
      const rel = path.relative(WORKSPACE_ROOT, path.join(safePath, entry.name));
      if (entry.isDirectory()) {
        results.push(rel + '/');
        const sub = await listFiles(rel);
        results.push(...sub);
      } else {
        results.push(rel);
      }
    }
    return results;
  } catch (err: any) {
    if (err.code === 'ENOENT') return [];
    throw err;
  }
}

export async function listKnowledge(): Promise<string[]> {
  try {
    const entries = await fs.readdir(KNOWLEDGE_ROOT, { withFileTypes: true });
    return entries.filter(e => e.isFile() && e.name.endsWith('.md')).map(e => e.name);
  } catch (err: any) {
    if (err.code === 'ENOENT') return [];
    throw err;
  }
}

export async function readKnowledge(name: string): Promise<string> {
  const safePath = securePath(KNOWLEDGE_ROOT, name);
  return await fs.readFile(safePath, 'utf8');
}

export async function searchKnowledge(query: string): Promise<Array<{ name: string; snippet: string }>> {
  const files = await listKnowledge();
  const results: Array<{ name: string; snippet: string }> = [];
  const lowerQuery = query.toLowerCase();

  for (const file of files) {
    try {
      const content = await readKnowledge(file);
      const lowerContent = content.toLowerCase();
      if (lowerContent.includes(lowerQuery)) {
        const idx = lowerContent.indexOf(lowerQuery);
        const start = Math.max(0, idx - 100);
        const end = Math.min(content.length, idx + 200);
        results.push({
          name: file,
          snippet: content.slice(start, end).replace(/\n/g, ' '),
        });
      }
    } catch {
      // ignore
    }
  }
  return results;
}

export async function runCommand(command: string, args: string[]): Promise<{ stdout: string; stderr: string; exitCode: number }> {
  if (!ALLOWED_COMMANDS.has(command)) {
    throw new Error(`Command not allowed: ${command}. Allowed: ${Array.from(ALLOWED_COMMANDS).join(', ')}`);
  }

  try {
    const { stdout, stderr } = await execFileAsync(command, args, {
      cwd: WORKSPACE_ROOT,
      timeout: 120000,
      maxBuffer: 1024 * 1024 * 10,
    });
    return { stdout, stderr, exitCode: 0 };
  } catch (err: any) {
    return {
      stdout: err.stdout || '',
      stderr: err.stderr || err.message || String(err),
      exitCode: typeof err.code === 'number' ? err.code : 1,
    };
  }
}

export const toolsSchema = [
  {
    type: 'function',
    function: {
      name: 'read_file',
      description: 'Read the contents of a file in the workspace.',
      parameters: {
        type: 'object',
        properties: {
          path: { type: 'string', description: 'Relative path of the file to read.' },
        },
        required: ['path'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'write_file',
      description: 'Write content to a file in the workspace (creates parent directories if needed).',
      parameters: {
        type: 'object',
        properties: {
          path: { type: 'string', description: 'Relative path of the file to write.' },
          content: { type: 'string', description: 'Content to write to the file.' },
        },
        required: ['path', 'content'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'list_files',
      description: 'List all files recursively in the workspace.',
      parameters: {
        type: 'object',
        properties: {
          path: { type: 'string', description: 'Optional directory path relative to workspace root.' },
        },
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'search_knowledge',
      description: 'Search the internal knowledge base Markdown files for a query string.',
      parameters: {
        type: 'object',
        properties: {
          query: { type: 'string', description: 'Query string to search for in knowledge base.' },
        },
        required: ['query'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'read_knowledge',
      description: 'Read a specific knowledge base Markdown file by name.',
      parameters: {
        type: 'object',
        properties: {
          name: { type: 'string', description: 'Name of the knowledge file.' },
        },
        required: ['name'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'list_knowledge',
      description: 'List all available knowledge base Markdown files.',
      parameters: {
        type: 'object',
        properties: {},
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'run_command',
      description: 'Execute an allowed command (npm, npx, pnpm, node, python, python3, pytest, git) in the workspace.',
      parameters: {
        type: 'object',
        properties: {
          command: { type: 'string', description: 'The executable command.' },
          args: { type: 'array', items: { type: 'string' }, description: 'Array of command-line arguments.' },
        },
        required: ['command', 'args'],
      },
    },
  },
];

export async function executeToolCall(name: string, args: Record<string, any>): Promise<any> {
  switch (name) {
    case 'read_file':
      return await readFile(args.path);
    case 'write_file':
      await writeFile(args.path, args.content);
      return { success: true, message: `Successfully wrote to ${args.path}` };
    case 'list_files':
      return await listFiles(args.path || '.');
    case 'search_knowledge':
      return await searchKnowledge(args.query);
    case 'read_knowledge':
      return await readKnowledge(args.name);
    case 'list_knowledge':
      return await listKnowledge();
    case 'run_command':
      return await runCommand(args.command, args.args || []);
    default:
      throw new Error(`Unknown tool call: ${name}`);
  }
}
