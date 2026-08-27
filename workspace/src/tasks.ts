import { Router, Request, Response } from 'express';

export type TaskStatus = 'pending' | 'in-progress' | 'completed';

export interface Task {
  id: string;
  title: string;
  description?: string;
  status: TaskStatus;
  createdAt: string;
  updatedAt: string;
}

interface CreateTaskBody {
  title?: unknown;
  description?: unknown;
  status?: unknown;
}

interface UpdateTaskBody {
  title?: unknown;
  description?: unknown;
  status?: unknown;
}

/**
 * In-memory task store. In production, this would be replaced by a database
 * (PostgreSQL, MongoDB, etc.) using a repository pattern.
 */
class TaskStore {
  private tasks: Map<string, Task> = new Map();

  getAll(): Task[] {
    return Array.from(this.tasks.values()).sort(
      (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
    );
  }

  getById(id: string): Task | undefined {
    return this.tasks.get(id);
  }

  create(input: Omit<Task, 'id' | 'createdAt' | 'updatedAt'>): Task {
    const id = this.generateId();
    const now = new Date().toISOString();
    const task: Task = { id, createdAt: now, updatedAt: now, ...input };
    this.tasks.set(id, task);
    return task;
  }

  update(id: string, updates: Partial<Omit<Task, 'id' | 'createdAt'>>): Task | undefined {
    const existing = this.tasks.get(id);
    if (!existing) return undefined;
    const updated: Task = {
      ...existing,
      ...updates,
      updatedAt: new Date().toISOString(),
    };
    this.tasks.set(id, updated);
    return updated;
  }

  delete(id: string): boolean {
    return this.tasks.delete(id);
  }

  clear(): void {
    this.tasks.clear();
  }

  private generateId(): string {
    return `task_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 10)}`;
  }
}

export const taskStore = new TaskStore();

const VALID_STATUSES: TaskStatus[] = ['pending', 'in-progress', 'completed'];

function isValidStatus(value: unknown): value is TaskStatus {
  return typeof value === 'string' && (VALID_STATUSES as string[]).includes(value);
}

function validateCreateBody(body: CreateTaskBody): { valid: boolean; error?: string; data?: Omit<Task, 'id' | 'createdAt' | 'updatedAt'> } {
  if (!body || typeof body !== 'object') {
    return { valid: false, error: 'Request body must be a JSON object.' };
  }
  if (typeof body.title !== 'string' || body.title.trim().length === 0) {
    return { valid: false, error: 'Field "title" is required and must be a non-empty string.' };
  }
  if (body.title.length > 200) {
    return { valid: false, error: 'Field "title" must not exceed 200 characters.' };
  }
  if (body.description !== undefined && typeof body.description !== 'string') {
    return { valid: false, error: 'Field "description" must be a string when provided.' };
  }
  let status: TaskStatus = 'pending';
  if (body.status !== undefined) {
    if (!isValidStatus(body.status)) {
      return { valid: false, error: `Field "status" must be one of: ${VALID_STATUSES.join(', ')}.` };
    }
    status = body.status;
  }
  return {
    valid: true,
    data: {
      title: body.title.trim(),
      description: body.description as string | undefined,
      status,
    },
  };
}

function validateUpdateBody(body: UpdateTaskBody): { valid: boolean; error?: string; data?: Partial<Omit<Task, 'id' | 'createdAt'>> } {
  if (!body || typeof body !== 'object') {
    return { valid: false, error: 'Request body must be a JSON object.' };
  }
  const updates: Partial<Omit<Task, 'id' | 'createdAt'>> = {};

  if (body.title !== undefined) {
    if (typeof body.title !== 'string' || body.title.trim().length === 0) {
      return { valid: false, error: 'Field "title" must be a non-empty string when provided.' };
    }
    if (body.title.length > 200) {
      return { valid: false, error: 'Field "title" must not exceed 200 characters.' };
    }
    updates.title = body.title.trim();
  }

  if (body.description !== undefined) {
    if (typeof body.description !== 'string') {
      return { valid: false, error: 'Field "description" must be a string when provided.' };
    }
    updates.description = body.description;
  }

  if (body.status !== undefined) {
    if (!isValidStatus(body.status)) {
      return { valid: false, error: `Field "status" must be one of: ${VALID_STATUSES.join(', ')}.` };
    }
    updates.status = body.status;
  }

  if (Object.keys(updates).length === 0) {
    return { valid: false, error: 'At least one field (title, description, status) must be provided.' };
  }

  return { valid: true, data: updates };
}

export const TasksRouter: Router = Router();

// GET /api/tasks - List all tasks (with optional status filter)
TasksRouter.get('/', (req: Request, res: Response) => {
  const statusFilter = req.query.status;
  if (statusFilter !== undefined) {
    if (!isValidStatus(statusFilter)) {
      return res.status(400).json({
        error: 'Bad Request',
        message: `Query parameter "status" must be one of: ${VALID_STATUSES.join(', ')}.`,
      });
    }
    const filtered = taskStore.getAll().filter((t) => t.status === statusFilter);
    return res.status(200).json({ data: filtered, count: filtered.length });
  }
  const all = taskStore.getAll();
  return res.status(200).json({ data: all, count: all.length });
});

// GET /api/tasks/:id - Get a single task
TasksRouter.get('/:id', (req: Request, res: Response) => {
  const { id } = req.params;
  const task = taskStore.getById(id);
  if (!task) {
    return res.status(404).json({ error: 'Not Found', message: `Task with id "${id}" was not found.` });
  }
  return res.status(200).json({ data: task });
});

// POST /api/tasks - Create a new task
TasksRouter.post('/', (req: Request, res: Response) => {
  const result = validateCreateBody(req.body as CreateTaskBody);
  if (!result.valid || !result.data) {
    return res.status(400).json({ error: 'Bad Request', message: result.error });
  }
  const task = taskStore.create(result.data);
  return res.status(201).json({ data: task });
});

// PUT /api/tasks/:id - Update an existing task
TasksRouter.put('/:id', (req: Request, res: Response) => {
  const { id } = req.params;
  const existing = taskStore.getById(id);
  if (!existing) {
    return res.status(404).json({ error: 'Not Found', message: `Task with id "${id}" was not found.` });
  }
  const result = validateUpdateBody(req.body as UpdateTaskBody);
  if (!result.valid || !result.data) {
    return res.status(400).json({ error: 'Bad Request', message: result.error });
  }
  const updated = taskStore.update(id, result.data);
  return res.status(200).json({ data: updated });
});

// DELETE /api/tasks/:id - Delete a task
TasksRouter.delete('/:id', (req: Request, res: Response) => {
  const { id } = req.params;
  const deleted = taskStore.delete(id);
  if (!deleted) {
    return res.status(404).json({ error: 'Not Found', message: `Task with id "${id}" was not found.` });
  }
  return res.status(204).send();
});
