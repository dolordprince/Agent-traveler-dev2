import { createApp } from './app';

const PORT = Number(process.env.PORT) || 3000;
const HOST = process.env.HOST || '0.0.0.0';

const app = createApp();

const server = app.listen(PORT, HOST, () => {
  console.log(`[Server] Task Management API listening on http://${HOST}:${PORT}`);
  console.log(`[Server] Health check: http://${HOST}:${PORT}/health`);
  console.log(`[Server] Tasks endpoint: http://${HOST}:${PORT}/api/tasks`);
});

// Graceful shutdown
const shutdown = (signal: string) => {
  console.log(`\n[Server] Received ${signal}. Closing HTTP server...`);
  server.close((err) => {
    if (err) {
      console.error('[Server] Error during shutdown:', err);
      process.exit(1);
    }
    console.log('[Server] HTTP server closed. Exiting.');
    process.exit(0);
  });
  // Force exit after 10 seconds
  setTimeout(() => {
    console.error('[Server] Forced shutdown after timeout.');
    process.exit(1);
  }, 10000).unref();
};

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
