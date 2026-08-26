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

function resolveWorkspace(relativePath: string): string {
  const root = path.resolve(WORKSPACE_ROOT);
  const target = path.resolve(root, relativePath);

  if (target !== root && !target.startsWith(`${root}${path.sep}`)) {
    throw new Error('Path escapes workspace');
  }

  return target;
}

export const readFile = tool({
  description: 'Read a file inside the Traveler Dev workspace.',
  inputSchema: z.object({
    path: z.string().min(1)
  }),
  execute: async ({ path: relativePath }) => {
    const target = resolveWorkspace(relativePath);
    return await fs.readFile(target, 'utf8');
  }
});

export const writeFile = tool({
  description: 'Write a file inside the Traveler Dev workspace.',
  inputSchema: z.object({
    path: z.string().min(1),
    content: z.string()
  }),
  execute: async ({ path: relativePath, content }) => {
    const target = resolveWorkspace(relativePath);

    await fs.mkdir(pathModuleDir(target), {
      recursive: true
    });

    await fs.writeFile(target, content, 'utf8');

    return {
      path: relativePath,
      bytes: Buffer.byteLength(content, 'utf8'),
      status: 'written'
    };
  }
});

export const listFiles = tool({
  description: 'List files and directories inside the workspace.',
  inputSchema: z.object({
    path: z.string().default('.')
  }),
  execute: async ({ path: relativePath }) => {
    const target = resolveWorkspace(relativePath);
    const entries = await fs.readdir(target, {
      withFileTypes: true
    });

    return entries.map((entry) => ({
      name: entry.name,
      type: entry.isDirectory() ? 'directory' : 'file'
    }));
  }
});

export const runCommand = tool({
  description:
    'Run a controlled command in the Traveler Dev workspace. Commands are restricted to approved development commands.',
  inputSchema: z.object({
    command: z.enum([
      'npm',
      'npx',
      'pnpm',
      'node',
      'python',
      'python3',
      'pytest',
      'git'
    ]),
    args: z.array(z.string()).default([])
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
      'wget'
    ];

    if (args.some((arg) =>
      forbidden.some((item) => arg.includes(item))
    )) {
      throw new Error('Command contains a forbidden operation');
    }

    const result = await execFileAsync(
      command,
      args,
      {
        cwd: WORKSPACE_ROOT,
        timeout: 120000,
        maxBuffer: 4 * 1024 * 1024,
        shell: false
      }
    );

    return {
      command,
      args,
      stdout: result.stdout,
      stderr: result.stderr
    };
  }
});

function pathModuleDir(filePath: string): string {
  return path.dirname(filePath);
}
