import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import fs from 'node:fs/promises';
import path from 'node:path';

const execFileAsync = promisify(execFile);

export const WORKSPACE_ROOT =
  process.env.TRAVELER_WORKSPACE_ROOT ||
  '/root/Agent-traveler-dev2/workspace';

export const KNOWLEDGE_ROOT =
  process.env.TRAVELER_KNOWLEDGE_ROOT ||
  '/root/Agent-traveler-dev2/knowledge';

function resolveInside(
  rootValue: string,
  relativePath: string,
): string {
  const root = path.resolve(rootValue);
  const target = path.resolve(root, relativePath);

  if (
    target !== root &&
    !target.startsWith(`${root}${path.sep}`)
  ) {
    throw new Error('Path escapes permitted root');
  }

  return target;
}

export function resolveWorkspace(relativePath: string): string {
  return resolveInside(WORKSPACE_ROOT, relativePath);
}

export function resolveKnowledge(relativePath: string): string {
  return resolveInside(KNOWLEDGE_ROOT, relativePath);
}

export const TOOL_DEFINITIONS = [
  {
    type: 'function',
    function: {
      name: 'read_file',
      description:
        'Read a real source file from the TRAVELER DEV workspace.',
      parameters: {
        type: 'object',
        properties: {
          path: {
            type: 'string',
            minLength: 1,
          },
        },
        required: ['path'],
        additionalProperties: false,
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'write_file',
      description:
        'Write a complete production file into the real TRAVELER DEV workspace.',
      parameters: {
        type: 'object',
        properties: {
          path: {
            type: 'string',
            minLength: 1,
          },
          content: {
            type: 'string',
          },
        },
        required: ['path', 'content'],
        additionalProperties: false,
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'list_files',
      description:
        'List real files and directories in the workspace.',
      parameters: {
        type: 'object',
        properties: {
          path: {
            type: 'string',
          },
        },
        required: [],
        additionalProperties: false,
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'search_knowledge',
      description:
        'Search the TRAVELER DEV Markdown technical knowledge base.',
      parameters: {
        type: 'object',
        properties: {
          query: {
            type: 'string',
            minLength: 2,
          },
        },
        required: ['query'],
        additionalProperties: false,
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'read_knowledge',
      description:
        'Read a complete Markdown knowledge document.',
      parameters: {
        type: 'object',
        properties: {
          name: {
            type: 'string',
            minLength: 1,
          },
        },
        required: ['name'],
        additionalProperties: false,
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'list_knowledge',
      description:
        'List available Markdown knowledge documents.',
      parameters: {
        type: 'object',
        properties: {},
        additionalProperties: false,
      },
    },
  },

  {
    type: 'function',
    function: {
      name: 'supervisor_start_app',
      description:
        'Start a real application process in the workspace and wait until its HTTP endpoint is reachable.',
      parameters: {
        type: 'object',
        properties: {
          command: { type: 'string', minLength: 1 },
          directory: { type: 'string', minLength: 1 },
          port: { type: 'integer', minimum: 1, maximum: 65535 },
        },
        required: ['command', 'directory', 'port'],
        additionalProperties: false,
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'supervisor_stop_app',
      description:
        'Stop the currently running real application process.',
      parameters: {
        type: 'object',
        properties: {},
        additionalProperties: false,
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'supervisor_logs',
      description:
        'Read logs captured from the currently supervised application process.',
      parameters: {
        type: 'object',
        properties: {},
        additionalProperties: false,
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'browser_navigate',
      description:
        'Navigate the real Playwright Chromium browser to a live application URL and collect runtime diagnostics.',
      parameters: {
        type: 'object',
        properties: {
          url: { type: 'string', minLength: 1 },
        },
        required: ['url'],
        additionalProperties: false,
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'browser_click',
      description:
        'Click a real element in the Playwright browser and collect resulting runtime diagnostics.',
      parameters: {
        type: 'object',
        properties: {
          selector: { type: 'string', minLength: 1 },
        },
        required: ['selector'],
        additionalProperties: false,
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'browser_state',
      description:
        'Inspect the real browser URL, page title, and runtime diagnostics.',
      parameters: {
        type: 'object',
        properties: {},
        additionalProperties: false,
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'browser_text',
      description:
        'Read rendered text from a real element in the Playwright browser.',
      parameters: {
        type: 'object',
        properties: {
          selector: { type: 'string', minLength: 1 },
        },
        required: ['selector'],
        additionalProperties: false,
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'browser_screenshot',
      description:
        'Capture a real screenshot of the currently loaded application for visual verification.',
      parameters: {
        type: 'object',
        properties: {
          path: { type: 'string', minLength: 1 },
        },
        required: [],
        additionalProperties: false,
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'browser_diagnostics',
      description:
        'Retrieve and clear real Playwright console, page, and network diagnostics.',
      parameters: {
        type: 'object',
        properties: {},
        additionalProperties: false,
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'run_command',
      description:
        'Execute an approved development, build, test, or inspection command.',
      parameters: {
        type: 'object',
        properties: {
          command: {
            type: 'string',
            enum: [
              'npm',
              'npx',
              'pnpm',
              'node',
              'python',
              'python3',
              'pytest',
              'git',
            ],
          },
          args: {
            type: 'array',
            items: {
              type: 'string',
            },
          },
        },
        required: ['command'],
        additionalProperties: false,
      },
    },
  },

  {
    type: 'function',
    function: {
      name: 'browser_navigate',
      description: 'Navigate the real Playwright browser to a URL. Returns title, status, diagnostics, console errors, network failures.',
      parameters: {
        type: 'object',
        properties: {
          url: { type: 'string', description: 'The URL to navigate to.' },
        },
        required: ['url'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'browser_click',
      description: 'Click a real DOM element in the Playwright browser.',
      parameters: {
        type: 'object',
        properties: {
          selector: { type: 'string', description: 'CSS selector of element to click.' },
        },
        required: ['selector'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'browser_fill',
      description: 'Fill a real input/textarea element in the browser.',
      parameters: {
        type: 'object',
        properties: {
          selector: { type: 'string' },
          value: { type: 'string' },
        },
        required: ['selector', 'value'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'browser_get_page_state',
      description: 'Get the current browser URL, title, visible text, and diagnostics.',
      parameters: { type: 'object', properties: {} },
    },
  },
  {
    type: 'function',
    function: {
      name: 'browser_get_console',
      description: 'Get accumulated browser console logs, page errors, and network failures.',
      parameters: { type: 'object', properties: {} },
    },
  },
  {
    type: 'function',
    function: {
      name: 'browser_screenshot',
      description: 'Capture a real screenshot of the current browser page.',
      parameters: {
        type: 'object',
        properties: {
          path: { type: 'string', description: 'Output path relative to workspace root.' },
        },
        required: [],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'browser_wait_for',
      description: 'Wait for a CSS selector to appear in the browser.',
      parameters: {
        type: 'object',
        properties: {
          selector: { type: 'string' },
          timeoutMs: { type: 'number' },
        },
        required: ['selector'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'browser_start_app',
      description: 'Start a real application process in the workspace and wait for its HTTP port.',
      parameters: {
        type: 'object',
        properties: {
          command: { type: 'string' },
          directory: { type: 'string' },
          port: { type: 'number' },
        },
        required: ['command', 'directory', 'port'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'browser_stop_app',
      description: 'Stop the currently supervised application process.',
      parameters: { type: 'object', properties: {} },
    },
  },


  {
    type: 'function',
    function: {
      name: 'publish_to_surge',
      description: 'Publish a built website directory to Surge.sh and return a live public URL. Requires SURGE_TOKEN env var.',
      parameters: {
        type: 'object',
        properties: {
          directory: { type: 'string', description: 'Workspace-relative path to the built site directory.' },
          domain: { type: 'string', description: 'Optional custom surge.sh subdomain e.g. my-app.surge.sh' },
        },
        required: ['directory'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'create_download_archive',
      description: 'Zip a workspace directory so the user can download it.',
      parameters: {
        type: 'object',
        properties: {
          directory: { type: 'string', description: 'Workspace-relative directory to archive.' },
          outputName: { type: 'string', description: 'Output zip filename (no path, stays in workspace).' },
        },
        required: ['directory', 'outputName'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_preview_url',
      description: 'Get the current preview URL of the supervised application.',
      parameters: { type: 'object', properties: {} },
    },
  },


  {
    type: 'function',
    function: {
      name: 'git_clone',
      description: 'Clone a GitHub repository into the workspace.',
      parameters: {
        type: 'object',
        properties: {
          url: { type: 'string', description: 'GitHub repo URL to clone.' },
          directory: { type: 'string', description: 'Workspace-relative target directory.' },
        },
        required: ['url', 'directory'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'git_pull',
      description: 'Pull latest changes in a workspace git repository.',
      parameters: {
        type: 'object',
        properties: {
          directory: { type: 'string', description: 'Workspace-relative repo directory.' },
        },
        required: ['directory'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'git_push',
      description: 'Stage all changes, commit, and push to origin.',
      parameters: {
        type: 'object',
        properties: {
          directory: { type: 'string', description: 'Workspace-relative repo directory.' },
          message: { type: 'string', description: 'Commit message.' },
          branch: { type: 'string', description: 'Branch to push to. Default: main.' },
        },
        required: ['directory', 'message'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'git_status',
      description: 'Get git status and recent log of a workspace repository.',
      parameters: {
        type: 'object',
        properties: {
          directory: { type: 'string', description: 'Workspace-relative repo directory.' },
        },
        required: ['directory'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'git_delete_and_reclone',
      description: 'Delete a workspace directory and re-clone the repository fresh.',
      parameters: {
        type: 'object',
        properties: {
          url: { type: 'string', description: 'GitHub repo URL.' },
          directory: { type: 'string', description: 'Workspace-relative directory to wipe and reclone.' },
        },
        required: ['url', 'directory'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'github_get_repo_url',
      description: 'Get the remote origin URL of a workspace git repository.',
      parameters: {
        type: 'object',
        properties: {
          directory: { type: 'string', description: 'Workspace-relative repo directory.' },
        },
        required: ['directory'],
      },
    },
  },


  {
    type: 'function',
    function: {
      name: 'git_clone',
      description: 'Clone a GitHub repository into the workspace.',
      parameters: {
        type: 'object',
        properties: {
          url: { type: 'string', description: 'GitHub repo URL to clone.' },
          directory: { type: 'string', description: 'Workspace-relative target directory.' },
        },
        required: ['url', 'directory'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'git_pull',
      description: 'Pull latest changes in a workspace git repository.',
      parameters: {
        type: 'object',
        properties: {
          directory: { type: 'string', description: 'Workspace-relative repo directory.' },
        },
        required: ['directory'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'git_push',
      description: 'Stage all changes, commit, and push to origin.',
      parameters: {
        type: 'object',
        properties: {
          directory: { type: 'string', description: 'Workspace-relative repo directory.' },
          message: { type: 'string', description: 'Commit message.' },
          branch: { type: 'string', description: 'Branch to push to. Default: main.' },
        },
        required: ['directory', 'message'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'git_status',
      description: 'Get git status and recent log of a workspace repository.',
      parameters: {
        type: 'object',
        properties: {
          directory: { type: 'string', description: 'Workspace-relative repo directory.' },
        },
        required: ['directory'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'git_delete_and_reclone',
      description: 'Delete a workspace directory and re-clone the repository fresh.',
      parameters: {
        type: 'object',
        properties: {
          url: { type: 'string', description: 'GitHub repo URL.' },
          directory: { type: 'string', description: 'Workspace-relative directory to wipe and reclone.' },
        },
        required: ['url', 'directory'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'github_get_repo_url',
      description: 'Get the remote origin URL of a workspace git repository.',
      parameters: {
        type: 'object',
        properties: {
          directory: { type: 'string', description: 'Workspace-relative repo directory.' },
        },
        required: ['directory'],
      },
    },
  },

];

export async function readFile(relativePath: string): Promise<string> {
  return await fs.readFile(resolveWorkspace(relativePath), 'utf8');
}

export async function writeFile(
  relativePath: string,
  content: string,
): Promise<{ status: string; path: string; bytes: number }> {
  const target = resolveWorkspace(relativePath);
  await fs.mkdir(path.dirname(target), { recursive: true });
  await fs.writeFile(target, content, 'utf8');
  return {
    status: 'written',
    path: relativePath,
    bytes: Buffer.byteLength(content, 'utf8'),
  };
}

export async function listFiles(
  relativePath = '.',
): Promise<Array<{ name: string; type: string }>> {
  const target = resolveWorkspace(relativePath);
  const entries = await fs.readdir(target, { withFileTypes: true });
  return entries.map((entry) => ({
    name: entry.name,
    type: entry.isDirectory() ? 'directory' : 'file',
  }));
}

export async function searchKnowledge(query: string): Promise<
  Array<{ name: string; score: number; excerpt: string }>
> {
  try {
    const entries = await fs.readdir(KNOWLEDGE_ROOT, { withFileTypes: true });
    const lowerQuery = query.toLowerCase();
    const terms = lowerQuery
      .split(/[^a-z0-9_./:@+-]+/)
      .filter((term) => term.length >= 2);

    const results: Array<{ name: string; score: number; excerpt: string }> = [];

    for (const entry of entries) {
      if (!entry.isFile() || !entry.name.toLowerCase().endsWith('.md')) {
        continue;
      }

      const text = await fs.readFile(
        resolveKnowledge(entry.name),
        'utf8',
      );
      const lower = text.toLowerCase();
      let score = 0;

      if (lower.includes(lowerQuery)) {
        score += 100;
      }

      for (const term of terms) {
        let index = 0;
        while (true) {
          index = lower.indexOf(term, index);
          if (index < 0) break;
          score += 1;
          index += term.length;
        }
      }

      if (score === 0) continue;

      const lines = text.split('\n');
      const matched: string[] = [];
      for (let i = 0; i < lines.length; i += 1) {
        const line = lines[i].toLowerCase();
        if (
          line.includes(lowerQuery) ||
          terms.some((term) => line.includes(term))
        ) {
          matched.push(
            lines
              .slice(Math.max(0, i - 5), Math.min(lines.length, i + 16))
              .join('\n'),
          );
        }
        if (matched.join('\n\n---\n\n').length > 12000) break;
      }

      results.push({
        name: entry.name,
        score,
        excerpt: matched.join('\n\n---\n\n').slice(0, 12000),
      });
    }

    results.sort(
      (a, b) => b.score - a.score || a.name.localeCompare(b.name),
    );
    return results.slice(0, 8);
  } catch {
    return [];
  }
}

export async function readKnowledge(nameInput: string): Promise<string> {
  const name = path.basename(nameInput);
  if (!name.toLowerCase().endsWith('.md')) {
    throw new Error('Only Markdown knowledge documents are permitted.');
  }
  return await fs.readFile(resolveKnowledge(name), 'utf8');
}

export async function listKnowledge(): Promise<
  Array<{ name: string; bytes: number }>
> {
  try {
    const entries = await fs.readdir(KNOWLEDGE_ROOT, { withFileTypes: true });
    const result: Array<{ name: string; bytes: number }> = [];

    for (const entry of entries) {
      if (entry.isFile() && entry.name.toLowerCase().endsWith('.md')) {
        const file = resolveKnowledge(entry.name);
        const stat = await fs.stat(file);
        result.push({
          name: entry.name,
          bytes: stat.size,
        });
      }
    }
    return result;
  } catch {
    return [];
  }
}

export async function runCommand(
  command: string,
  args: string[] = [],
): Promise<{ stdout: string; stderr: string }> {
  const allowed = new Set([
    'npm',
    'npx',
    'pnpm',
    'node',
    'python',
    'python3',
    'pytest',
    'git',
  ]);

  if (!allowed.has(command)) {
    throw new Error(`Execution of command '${command}' is prohibited.`);
  }

  const { stdout, stderr } = await execFileAsync(command, args, {
    cwd: WORKSPACE_ROOT,
    env: { ...process.env },
    maxBuffer: 10 * 1024 * 1024,
  });

  return { stdout, stderr };
}


// ── Browser bridge client ─────────────────────────────────────────────────────
const BROWSER_BRIDGE_URL =
  process.env.TRAVELER_BROWSER_BRIDGE_URL || 'http://127.0.0.1:8091';

const BROWSER_TOOLS = new Set([
  'browser_navigate',
  'browser_click',
  'browser_fill',
  'browser_get_page_state',
  'browser_get_console',
  'browser_screenshot',
  'browser_wait_for',
  'browser_start_app',
  'browser_stop_app',
]);

async function callBrowserBridge(
  name: string,
  args: Record<string, unknown>,
): Promise<unknown> {
  // Validate screenshot paths stay inside workspace
  if (name === 'browser_screenshot' && args.path) {
    args.path = resolveWorkspace(String(args.path));
  }
  // Validate app directory stays inside workspace
  if (name === 'browser_start_app' && args.directory) {
    args.directory = resolveWorkspace(String(args.directory));
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 60000);

  try {
    const res = await fetch(`${BROWSER_BRIDGE_URL}/tool`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ name, arguments: args }),
      signal: controller.signal,
    });

    const text = await res.text();
    let payload: unknown;
    try {
      payload = JSON.parse(text);
    } catch {
      throw new Error(`Browser bridge returned invalid JSON: ${text.slice(0, 200)}`);
    }

    if (!res.ok) {
      throw new Error(
        `Browser bridge error (HTTP ${res.status}): ${JSON.stringify(payload)}`,
      );
    }

    return (payload as { result: unknown }).result ?? payload;
  } finally {
    clearTimeout(timeout);
  }
}


// ── Surge publish ─────────────────────────────────────────────────────────────
let _previewPort: number | null = null;
let _previewUrl: string | null = null;

export function setPreviewUrl(url: string, port: number): void {
  _previewUrl = url;
  _previewPort = port;
}

export async function publishToSurge(
  directory: string,
  domain?: string,
): Promise<{ url: string; domain: string }> {
  const safeDir = resolveWorkspace(directory);
  const surgeToken = process.env.SURGE_TOKEN || '';
  if (!surgeToken) {
    throw new Error('SURGE_TOKEN environment variable is not set. Add it to .env');
  }
  const ts = Date.now();
  const targetDomain = domain || `traveler-dev-${ts}.surge.sh`;
  const result = await runCommand('npx', [
    'surge', '--project', safeDir,
    '--domain', targetDomain,
    '--token', surgeToken,
  ]);
  if ((result as any).exitCode !== 0) {
    throw new Error(`Surge publish failed: ${result.stderr.slice(0, 400)}`);
  }
  return { url: `https://${targetDomain}`, domain: targetDomain };
}

export async function createDownloadArchive(
  directory: string,
  outputName: string,
): Promise<{ path: string; size: number }> {
  const safeDir = resolveWorkspace(directory);
  const safeName = outputName.replace(/[^a-zA-Z0-9_.-]/g, '_');
  const outPath = resolveWorkspace(safeName.endsWith('.zip') ? safeName : safeName + '.zip');
  const result = await runCommand('python3', [
    '-c',
    `import shutil, os; shutil.make_archive(${JSON.stringify(outPath.replace(/\.zip$/, ''))}, 'zip', ${JSON.stringify(safeDir)})`,
  ]);
  if ((result as any).exitCode !== 0) {
    throw new Error(`Archive creation failed: ${result.stderr.slice(0, 400)}`);
  }
  const { size } = await import('fs').then(fs => fs.promises.stat(outPath));
  return { path: outPath, size };
}


// ── GitHub / Git tools ────────────────────────────────────────────────────────
async function gitRun(
  args: string[],
  cwd: string,
): Promise<{ out: string; err: string; ok: boolean }> {
  const r = await runCommand('git', args);
  return {
    out: r.stdout,
    err: r.stderr,
    ok: (r as any).exitCode === 0,
  };
}

export async function gitClone(
  url: string,
  directory: string,
): Promise<{ success: boolean; path: string; output: string }> {
  const safeDir = resolveWorkspace(directory);
  const r = await runCommand('git', ['clone', url, safeDir]);
  const ok = (r as any).exitCode === 0;
  return { success: ok, path: safeDir, output: (ok ? r.stdout : r.stderr).slice(0, 800) };
}

export async function gitPull(
  directory: string,
): Promise<{ success: boolean; output: string }> {
  const safeDir = resolveWorkspace(directory);
  const r = await runCommand('git', ['-C', safeDir, 'pull']);
  const ok = (r as any).exitCode === 0;
  return { success: ok, output: (ok ? r.stdout : r.stderr).slice(0, 800) };
}

export async function gitPush(
  directory: string,
  message: string,
  branch: string = 'main',
): Promise<{ success: boolean; output: string }> {
  const safeDir = resolveWorkspace(directory);
  const steps = [
    ['git', '-C', safeDir, 'add', '-A'],
    ['git', '-C', safeDir, 'commit', '-m', message],
    ['git', '-C', safeDir, 'push', 'origin', branch],
  ];
  let output = '';
  for (const [cmd, ...args] of steps) {
    const r = await runCommand(cmd, args);
    output += r.stdout + r.stderr;
    const ok = (r as any).exitCode === 0;
    if (!ok && !r.stderr.includes('nothing to commit')) {
      return { success: false, output: output.slice(0, 1000) };
    }
  }
  return { success: true, output: output.slice(0, 1000) };
}

export async function gitStatus(
  directory: string,
): Promise<{ status: string; log: string }> {
  const safeDir = resolveWorkspace(directory);
  const s = await runCommand('git', ['-C', safeDir, 'status']);
  const l = await runCommand('git', ['-C', safeDir, 'log', '--oneline', '-10']);
  return {
    status: s.stdout.slice(0, 800),
    log: l.stdout.slice(0, 800),
  };
}

export async function gitDeleteAndReclone(
  url: string,
  directory: string,
): Promise<{ success: boolean; path: string; output: string }> {
  const safeDir = resolveWorkspace(directory);
  const rm = await runCommand('python3', [
    '-c',
    `import shutil, os; shutil.rmtree(${JSON.stringify(safeDir)}, ignore_errors=True)`,
  ]);
  return await gitClone(url, directory);
}

export async function githubGetRepoUrl(
  directory: string,
): Promise<{ url: string }> {
  const safeDir = resolveWorkspace(directory);
  const r = await runCommand('git', ['-C', safeDir, 'remote', 'get-url', 'origin']);
  return { url: r.stdout.trim() };
}


// ── GitHub / Git tools ─────────────────────────────────────────────────────
export async function executeTool(
  name: string,
  input: unknown,
): Promise<unknown> {
  const value =
    typeof input === 'object' && input !== null
      ? (input as Record<string, unknown>)
      : {};

  switch (name) {
    case 'read_file':
      return await readFile(String(value.path || ''));
    case 'write_file':
      return await writeFile(
        String(value.path || ''),
        String(value.content ?? ''),
      );
    case 'list_files':
      return await listFiles(
        typeof value.path === 'string' ? value.path : '.',
      );
    case 'search_knowledge':
      return await searchKnowledge(String(value.query || ''));
    case 'read_knowledge':
      return await readKnowledge(String(value.name || ''));
    case 'list_knowledge':
      return await listKnowledge();
    case 'run_command': {
      const command = String(value.command || '');
      const rawArgs = value.args;
      const commandArgs = Array.isArray(rawArgs) ? rawArgs.map(String) : [];
      return await runCommand(command, commandArgs);
    }
    
case 'git_clone': {
      const v = input as Record<string, unknown>;
      return await gitClone(String(v.url), String(v.directory));
    }
    case 'git_pull': {
      const v = input as Record<string, unknown>;
      return await gitPull(String(v.directory));
    }
    case 'git_push': {
      const v = input as Record<string, unknown>;
      return await gitPush(String(v.directory), String(v.message), String(v.branch || 'main'));
    }
    case 'git_status': {
      const v = input as Record<string, unknown>;
      return await gitStatus(String(v.directory));
    }
    case 'git_delete_and_reclone': {
      const v = input as Record<string, unknown>;
      return await gitDeleteAndReclone(String(v.url), String(v.directory));
    }
    case 'github_get_repo_url': {
      const v = input as Record<string, unknown>;
      return await githubGetRepoUrl(String(v.directory));
    }
    case 'publish_to_surge': {
      const dir = String((input as Record<string,unknown>)?.directory || '.');
      const dom = (input as Record<string,unknown>)?.domain as string | undefined;
      return await publishToSurge(dir, dom);
    }

    case 'create_download_archive': {
      const v = input as Record<string,unknown>;
      return await createDownloadArchive(String(v.directory || '.'), String(v.outputName || 'download.zip'));
    }

    case 'get_preview_url': {
      return { url: _previewUrl, port: _previewPort, available: _previewUrl !== null };
    }

    case 'browser_navigate':
    case 'browser_click':
    case 'browser_fill':
    case 'browser_get_page_state':
    case 'browser_get_console':
    case 'browser_screenshot':
    case 'browser_wait_for':
    case 'browser_start_app':
    case 'browser_stop_app': {
      const bridgeArgs = (typeof input === 'object' && input !== null ? input : {}) as Record<string, unknown>;
      return await callBrowserBridge(name, bridgeArgs);
    }

  default:
      throw new Error(`Unknown agent tool: ${name}`);
  }
}
