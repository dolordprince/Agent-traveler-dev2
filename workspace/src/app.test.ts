import request from 'supertest';
import { createApp } from './app';
import { taskStore } from './tasks';
import { Application } from 'express';

describe('Task Management API', () => {
  let app: Application;

  beforeEach(() => {
    taskStore.clear();
    app = createApp();
  });

  describe('GET /health', () => {
    it('should return a 200 status with health info', async () => {
      const res = await request(app).get('/health');
      expect(res.status).toBe(200);
      expect(res.body).toHaveProperty('status', 'ok');
      expect(res.body).toHaveProperty('uptime');
    });
  });

  describe('POST /api/tasks', () => {
    it('should create a new task with valid data', async () => {
      const res = await request(app)
        .post('/api/tasks')
        .send({ title: 'Write tests', description: 'Cover all endpoints' })
        .set('Content-Type', 'application/json');

      expect(res.status).toBe(201);
      expect(res.body.data).toMatchObject({
        title: 'Write tests',
        description: 'Cover all endpoints',
        status: 'pending',
      });
      expect(res.body.data.id).toBeDefined();
      expect(res.body.data.createdAt).toBeDefined();
      expect(res.body.data.updatedAt).toBeDefined();
    });

    it('should accept a valid status', async () => {
      const res = await request(app)
        .post('/api/tasks')
        .send({ title: 'In progress task', status: 'in-progress' })
        .set('Content-Type', 'application/json');

      expect(res.status).toBe(201);
      expect(res.body.data.status).toBe('in-progress');
    });

    it('should reject missing title with 400', async () => {
      const res = await request(app)
        .post('/api/tasks')
        .send({ description: 'no title here' })
        .set('Content-Type', 'application/json');

      expect(res.status).toBe(400);
      expect(res.body).toHaveProperty('error', 'Bad Request');
    });

    it('should reject empty title with 400', async () => {
      const res = await request(app)
        .post('/api/tasks')
        .send({ title: '   ' })
        .set('Content-Type', 'application/json');

      expect(res.status).toBe(400);
    });

    it('should reject invalid status with 400', async () => {
      const res = await request(app)
        .post('/api/tasks')
        .send({ title: 'Bad status', status: 'unknown' })
        .set('Content-Type', 'application/json');

      expect(res.status).toBe(400);
      expect(res.body.message).toMatch(/status/);
    });
  });

  describe('GET /api/tasks', () => {
    beforeEach(async () => {
      await request(app).post('/api/tasks').send({ title: 'Task A' });
      await request(app).post('/api/tasks').send({ title: 'Task B', status: 'completed' });
    });

    it('should list all tasks', async () => {
      const res = await request(app).get('/api/tasks');
      expect(res.status).toBe(200);
      expect(res.body.count).toBe(2);
      expect(res.body.data).toHaveLength(2);
    });

    it('should filter by status', async () => {
      const res = await request(app).get('/api/tasks?status=completed');
      expect(res.status).toBe(200);
      expect(res.body.count).toBe(1);
      expect(res.body.data[0].title).toBe('Task B');
    });

    it('should reject invalid status query with 400', async () => {
      const res = await request(app).get('/api/tasks?status=bogus');
      expect(res.status).toBe(400);
    });
  });

  describe('GET /api/tasks/:id', () => {
    it('should return a single task', async () => {
      const created = await request(app).post('/api/tasks').send({ title: 'Find me' });
      const id = created.body.data.id;

      const res = await request(app).get(`/api/tasks/${id}`);
      expect(res.status).toBe(200);
      expect(res.body.data.title).toBe('Find me');
    });

    it('should return 404 for a missing task', async () => {
      const res = await request(app).get('/api/tasks/does_not_exist');
      expect(res.status).toBe(404);
    });
  });

  describe('PUT /api/tasks/:id', () => {
    it('should update a task', async () => {
      const created = await request(app).post('/api/tasks').send({ title: 'Original' });
      const id = created.body.data.id;

      const res = await request(app)
        .put(`/api/tasks/${id}`)
        .send({ title: 'Updated', status: 'completed' })
        .set('Content-Type', 'application/json');

      expect(res.status).toBe(200);
      expect(res.body.data.title).toBe('Updated');
      expect(res.body.data.status).toBe('completed');
      expect(res.body.data.updatedAt).not.toBe(created.body.data.updatedAt);
    });

    it('should return 404 when updating a missing task', async () => {
      const res = await request(app)
        .put('/api/tasks/missing')
        .send({ title: 'New' })
        .set('Content-Type', 'application/json');
      expect(res.status).toBe(404);
    });

    it('should reject an empty body with 400', async () => {
      const created = await request(app).post('/api/tasks').send({ title: 'Original' });
      const id = created.body.data.id;

      const res = await request(app)
        .put(`/api/tasks/${id}`)
        .send({})
        .set('Content-Type', 'application/json');
      expect(res.status).toBe(400);
    });
  });

  describe('DELETE /api/tasks/:id', () => {
    it('should delete a task and return 204', async () => {
      const created = await request(app).post('/api/tasks').send({ title: 'Delete me' });
      const id = created.body.data.id;

      const res = await request(app).delete(`/api/tasks/${id}`);
      expect(res.status).toBe(204);

      const fetch = await request(app).get(`/api/tasks/${id}`);
      expect(fetch.status).toBe(404);
    });

    it('should return 404 when deleting a missing task', async () => {
      const res = await request(app).delete('/api/tasks/missing');
      expect(res.status).toBe(404);
    });
  });

  describe('Unknown routes', () => {
    it('should return 404 for unknown endpoints', async () => {
      const res = await request(app).get('/api/unknown');
      expect(res.status).toBe(404);
      expect(res.body.error).toBe('Not Found');
    });
  });
});
