import express, { Application, Request, Response, NextFunction } from 'express';
import { TasksRouter } from './tasks';

/**
 * Create and configure the Express application.
 * This factory pattern enables isolated testing without binding a port.
 */
export function createApp(): Application {
  const app: Application = express();

  // Core middleware
  app.use(express.json());
  app.use(express.urlencoded({ extended: true }));

  // Health check endpoint
  app.get('/health', (_req: Request, res: Response) => {
    res.status(200).json({ status: 'ok', uptime: process.uptime() });
  });

  // Mount task routes
  app.use('/api/tasks', TasksRouter);

  // 404 handler for unknown routes
  app.use((_req: Request, res: Response) => {
    res.status(404).json({ error: 'Not Found', message: 'The requested resource does not exist.' });
  });

  // Global error handler
  app.use((err: Error, _req: Request, res: Response, _next: NextFunction) => {
    console.error('[Error]', err.stack);
    res.status(500).json({
      error: 'Internal Server Error',
      message: process.env.NODE_ENV === 'production' ? 'An unexpected error occurred.' : err.message,
    });
  });

  return app;
}
