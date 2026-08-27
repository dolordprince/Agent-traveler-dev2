import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import fs from 'node:fs/promises';
import path from 'node:path';

const execFileAsync = promisify(execFile);

const WORKSPACE_ROOT =
  process.env.TRAVELER_WORKSPACE_ROOT ||
  '/root/Agent-traveler-dev2/workspace';

const KNOWLEDGE_ROOT =
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

function resolveWorkspace(relativePath: string): string {
  return resolveInside(WORKSPACE_ROOT, relativePath);
}

function resolveKnowledge(relativePath: string): string {
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
] as const;

export async function executeTool(
  name: string,
  input: unknown,
): Promise<unknown> {
  const value =
    typeof input === 'object' &&
    input !== null
      ? input as Record<string, unknown>
      : {};

  switch (name) {
    case 'read_file': {
      const relativePath = String(value.path || '');
      return await fs.readFile(
        resolveWorkspace(relativePath),
        'utf8',
      );
    }

    case 'write_file': {
      const relativePath = String(value.path || '');
      const content = String(value.content ?? '');

      const target = resolveWorkspace(relativePath);

      await fs.mkdir(path.dirname(target), {
        recursive: true,
      });

      await fs.writeFile(
        target,
        content,
        'utf8',
      );

      return {
        status: 'written',
        path: relativePath,
        bytes: Buffer.byteLength(content, 'utf8'),
      };
    }

    case 'list_files': {
      const relativePath =
        typeof value.path === 'string'
          ? value.path
          : '.';

      const target = resolveWorkspace(relativePath);

      const entries = await fs.readdir(
        target,
        { withFileTypes: true },
      );

      return entries.map((entry) => ({
        name: entry.name,
        type: entry.isDirectory()
          ? 'directory'
          : 'file',
      }));
    }

    case 'search_knowledge': {
      const query = String(value.query || '');

      const entries = await fs.readdir(
        KNOWLEDGE_ROOT,
        { withFileTypes: true },
      );

      const lowerQuery = query.toLowerCase();

      const terms = query
        .toLowerCase()
        .split(/[^a-z0-9_./:@+-]+/)
        .filter((term) => term.length >= 2);

      const results: Array<{
        name: string;
        score: number;
        excerpt: string;
      }> = [];

      for (const entry of entries) {
        if (
          !entry.isFile() ||
          !entry.name
            .toLowerCase()
            .endsWith('.md')
        ) {
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

            if (index < 0) {
              break;
            }

            score += 1;
            index += term.length;
          }
        }

        if (score === 0) {
          continue;
        }

        const lines = text.split('\n');
        const matched: string[] = [];

        for (let i = 0; i < lines.length; i += 1) {
          const line = lines[i].toLowerCase();

          if (
            line.includes(lowerQuery) ||
            terms.some((term) =>
              line.includes(term),
            )
          ) {
            matched.push(
              lines
                .slice(
                  Math.max(0, i - 5),
                  Math.min(lines.length, i + 16),
                )
                .join('\n'),
            );
          }

          if (
            matched.join('\n\n---\n\n').length >
            12000
          ) {
            break;
          }
        }

        results.push({
          name: entry.name,
          score,
          excerpt: matched
            .join('\n\n---\n\n')
            .slice(0, 12000),
        });
      }

      results.sort(
        (a, b) =>
          b.score - a.score ||
          a.name.localeCompare(b.name),
      );

      return results.slice(0, 8);
    }

    case 'read_knowledge': {
      const name = path.basename(
        String(value.name || ''),
      );

      if (!name.toLowerCase().endsWith('.md')) {
        throw new Error(
          'Only Markdown knowledge documents are permitted.',
        );
      }

      return await fs.readFile(
        resolveKnowledge(name),
        'utf8',
      );
    }

    case 'list_knowledge': {
      const entries = await fs.readdir(
        KNOWLEDGE_ROOT,
        { withFileTypes: true },
      );

      const result: Array<{
        name: string;
        bytes: number;
      }> = [];

      for (const entry of entries) {
        if (
          entry.isFile() &&
          entry.name
            .toLowerCase()
            .endsWith('.md')
        ) {
          const file = resolveKnowledge(
            entry.name,
          );

          const stat = await fs.stat(file);

          result.push({
            name: entry.name,
            bytes: stat.size,
          });
        }
      }

      return result;
    }

    case 'run_command': {
      const command = String(
        value.command || '',
      );

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
        throw new Error(
          `Command is not permitted: ${command}`,
        );
      }

      const args = Array.isArray(value.args)
        ? value.args.map(String)
        : [];

      const forbidden = [
        'rm',
        'rmdir',
        'shutdown',
        'reboot',
        'mkfs',
        'dd',
        'mount',
        'umount',
        'curl',
        'wget',
      ];

      if (
        args.some((arg) =>
          forbidden.some((item) =>
            arg.includes(item),
          ),
        )
      ) {
        throw new Error(
          'Command contains a forbidden operation.',
        );
      }

      const result = await execFileAsync(
        command,
        args,
        {
          cwd: WORKSPACE_ROOT,
          timeout: 120000,
          maxBuffer: 4 * 1024 * 1024,
          shell: false,
        },
      );

      return {
        command,
        args,
        stdout: result.stdout,
        stderr: result.stderr,
      };
    }

    default:
      throw new Error(
        `Unknown coding-agent tool: ${name}`,
      );
  }
}
