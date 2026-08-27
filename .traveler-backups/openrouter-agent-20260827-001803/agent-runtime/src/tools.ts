import { tool } from 'ai';
import { z } from 'zod';
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

function resolveInside(rootValue: string, relativePath: string): string {
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

export const readFile = tool({
  description:
    'Read a real source file from the current TRAVELER DEV workspace.',
  inputSchema: z.object({
    path: z.string().min(1),
  }),
  execute: async ({ path: relativePath }) => {
    return await fs.readFile(
      resolveWorkspace(relativePath),
      'utf8',
    );
  },
});

export const writeFile = tool({
  description:
    'Write a complete production file into the real TRAVELER DEV workspace.',
  inputSchema: z.object({
    path: z.string().min(1),
    content: z.string(),
  }),
  execute: async ({ path: relativePath, content }) => {
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
  },
});

export const listFiles = tool({
  description:
    'Inspect real files and directories in the current workspace.',
  inputSchema: z.object({
    path: z.string().default('.'),
  }),
  execute: async ({ path: relativePath }) => {
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
  },
});

export const searchKnowledge = tool({
  description:
    'Search the TRAVELER DEV Markdown knowledge base for technical implementation guidance. Use this before implementing technologies covered by the knowledge documents.',
  inputSchema: z.object({
    query: z.string().min(2),
  }),
  execute: async ({ query }) => {
    const entries = await fs.readdir(
      KNOWLEDGE_ROOT,
      { withFileTypes: true },
    );

    const terms = query
      .toLowerCase()
      .split(/[^a-z0-9_./:@+-]+/)
      .filter((value) => value.length >= 2);

    const results: Array<{
      name: string;
      score: number;
      excerpt: string;
    }> = [];

    for (const entry of entries) {
      if (
        !entry.isFile() ||
        !entry.name.toLowerCase().endsWith('.md')
      ) {
        continue;
      }

      const filePath = resolveKnowledge(entry.name);
      const text = await fs.readFile(
        filePath,
        'utf8',
      );

      const lower = text.toLowerCase();

      let score = 0;

      if (lower.includes(query.toLowerCase())) {
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
          line.includes(query.toLowerCase()) ||
          terms.some((term) => line.includes(term))
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

        if (matched.join('\n\n---\n\n').length > 12000) {
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
  },
});

export const readKnowledge = tool({
  description:
    'Read a complete Markdown knowledge document from the TRAVELER DEV knowledge base.',
  inputSchema: z.object({
    name: z.string().min(1),
  }),
  execute: async ({ name }) => {
    const safeName = path.basename(name);

    if (!safeName.toLowerCase().endsWith('.md')) {
      throw new Error(
        'Only Markdown knowledge documents are permitted.',
      );
    }

    return await fs.readFile(
      resolveKnowledge(safeName),
      'utf8',
    );
  },
});

export const listKnowledge = tool({
  description:
    'List all available TRAVELER DEV Markdown knowledge documents.',
  inputSchema: z.object({}),
  execute: async () => {
    const entries = await fs.readdir(
      KNOWLEDGE_ROOT,
      { withFileTypes: true },
    );

    const result = [];

    for (const entry of entries) {
      if (
        entry.isFile() &&
        entry.name.toLowerCase().endsWith('.md')
      ) {
        const file = resolveKnowledge(entry.name);
        const stat = await fs.stat(file);

        result.push({
          name: entry.name,
          bytes: stat.size,
        });
      }
    }

    return result;
  },
});

export const runCommand = tool({
  description:
    'Execute a real development/build/test command in the TRAVELER DEV workspace.',
  inputSchema: z.object({
    command: z.enum([
      'npm',
      'npx',
      'pnpm',
      'node',
      'python',
      'python3',
      'pytest',
      'git',
    ]),
    args: z.array(z.string()).default([]),
  }),
  execute: async ({ command, args }) => {
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
  },
});
