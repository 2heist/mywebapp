const request = require('supertest');
const mariadb = require('mariadb');

jest.mock('mariadb', () => {
  const mConnection = {
    query: jest.fn(),
    release: jest.fn()
  };
  const mPool = {
    getConnection: jest.fn(() => Promise.resolve(mConnection))
  };
  return {
    createPool: jest.fn(() => mPool)
  };
});

const app = require('./app');

describe('Тестування Notes API', () => {
  let mockConnection;

  beforeEach(async () => {
    const pool = mariadb.createPool();
    mockConnection = await pool.getConnection();
    jest.clearAllMocks();
  });

  test('GET /health/alive повертає 200', async () => {
    const res = await request(app).get('/health/alive');
    expect(res.statusCode).toBe(200);
  });

  test('GET /health/ready повертає 200, коли БД доступна', async () => {
    const res = await request(app).get('/health/ready');
    expect(res.statusCode).toBe(200);
    expect(mockConnection.release).toHaveBeenCalled();
  });

  test('GET / повертає HTML з переліком маршрутів', async () => {
    const res = await request(app).get('/');
    expect(res.statusCode).toBe(200);
    expect(res.text).toContain('Notes Service API');
  });

  test('GET /notes повертає список нотаток у JSON', async () => {
    mockConnection.query.mockResolvedValue([{ id: 1, title: 'Тестова нотатка' }]);

    const res = await request(app).get('/notes').set('Accept', 'application/json');
    expect(res.statusCode).toBe(200);
    expect(res.body).toEqual([{ id: 1, title: 'Тестова нотатка' }]);
  });

  test('GET /notes/:id повертає конкретну нотатку', async () => {
    mockConnection.query.mockResolvedValue([
      { id: 1, title: 'Тест', content: 'Контент', created_at: '2026-01-01' }
    ]);

    const res = await request(app).get('/notes/1').set('Accept', 'application/json');
    expect(res.statusCode).toBe(200);
    expect(res.body.title).toBe('Тест');
  });

  test('GET /notes/:id повертає 404, якщо нотатки немає', async () => {
    mockConnection.query.mockResolvedValue([]);

    const res = await request(app).get('/notes/999');
    expect(res.statusCode).toBe(404);
  });

  test('POST /notes без даних повертає помилку 400', async () => {
    const res = await request(app).post('/notes').send({});
    expect(res.statusCode).toBe(400);
  });

  test('POST /notes успішно створює нотатку', async () => {
    mockConnection.query.mockResolvedValue({ insertId: 42 });

    const res = await request(app)
      .post('/notes')
      .send({ title: 'Нова', content: 'Нотатка' })
      .set('Accept', 'application/json');

    expect(res.statusCode).toBe(201);
    expect(res.body.id).toBe(42);
  });
});
