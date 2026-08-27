import { spawn, ChildProcess } from 'child_process';
import { chromium, Browser, Page, ConsoleMessage, Response } from 'playwright';
import path from 'path';
import fs from 'fs';

export interface CapturedError {
  type: 'console_error' | 'page_error' | 'network_error';
  message: string;
  url?: string;
  status?: number;
  timestamp: string;
}

export class BrowserQAEngine {
  private serverProcess: ChildProcess | null = null;
  private browser: Browser | null = null;
  private page: Page | null = null;
  private capturedErrors: CapturedError[] = [];

  // Step 1: Start Dev Server & Wait for Port Readiness
  async startDevServer(
    command: string,
    cwd: string,
    targetPort: number,
    timeoutMs = 30000
  ): Promise<{ success: boolean; port: number; log: string }> {
    return new Promise((resolve) => {
      const parts = command.split(' ');
      let logs = '';

      this.serverProcess = spawn(parts[0], parts.slice(1), {
        cwd,
        shell: true,
        env: { ...process.env, PORT: String(targetPort) }
      });

      const timer = setTimeout(() => {
        resolve({
          success: false,
          port: targetPort,
          log: `Timeout waiting for server on port ${targetPort}.\n${logs}`
        });
      }, timeoutMs);

      const checkOutput = (data: Buffer) => {
        const str = data.toString();
        logs += str;
        if (str.includes(`:${targetPort}`) || str.toLowerCase().includes('ready') || str.includes('Local:')) {
          clearTimeout(timer);
          resolve({ success: true, port: targetPort, log: logs });
        }
      };

      this.serverProcess.stdout?.on('data', checkOutput);
      this.serverProcess.stderr?.on('data', (data) => {
        logs += data.toString();
      });
    });
  }

  // Step 2: Launch Headless Chromium & Attach Interceptors
  async initBrowser(): Promise<void> {
    this.browser = await chromium.launch({ headless: true });
    const context = await this.browser.newContext();
    this.page = await context.newPage();
    this.capturedErrors = [];

    // Capture Console Errors
    this.page.on('console', (msg: ConsoleMessage) => {
      if (msg.type() === 'error') {
        this.capturedErrors.push({
          type: 'console_error',
          message: msg.text(),
          timestamp: new Date().toISOString()
        });
      }
    });

    // Capture Unhandled Page Errors
    this.page.on('pageerror', (err: Error) => {
      this.capturedErrors.push({
        type: 'page_error',
        message: err.message,
        timestamp: new Date().toISOString()
      });
    });

    // Capture HTTP 4xx/5xx Responses
    this.page.on('response', (res: Response) => {
      if (res.status() >= 400) {
        this.capturedErrors.push({
          type: 'network_error',
          message: `HTTP ${res.status()} ${res.statusText()}`,
          url: res.url(),
          status: res.status(),
          timestamp: new Date().toISOString()
        });
      }
    });
  }

  // Step 3: Multi-Viewport Screenshots & Error Collection
  async captureViewports(
    url: string,
    outputDir: string
  ): Promise<{ screenshots: string[]; errors: CapturedError[] }> {
    if (!this.page) throw new Error('Browser not initialized');

    const viewports = [
      { name: 'desktop-1440', width: 1440, height: 900 },
      { name: 'mobile-390', width: 390, height: 844 }
    ];

    const savedPaths: string[] = [];
    fs.mkdirSync(outputDir, { recursive: true });

    for (const vp of viewports) {
      await this.page.setViewportSize({ width: vp.width, height: vp.height });
      await this.page.goto(url, { waitUntil: 'networkidle' });

      const filePath = path.join(outputDir, `${vp.name}.png`);
      await this.page.screenshot({ path: filePath, fullPage: true });
      savedPaths.push(filePath);
    }

    return {
      screenshots: savedPaths,
      errors: this.capturedErrors
    };
  }

  // Step 4: Cleanup Server and Browser Processes
  async stopAll(): Promise<void> {
    if (this.browser) await this.browser.close();
    if (this.serverProcess) this.serverProcess.kill('SIGTERM');
  }
}
