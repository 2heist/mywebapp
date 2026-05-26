const express = require('express');
const mariadb = require('mariadb');
const minimist = require('minimist');

const args = minimist(process.argv.slice(2));
const PORT = args.port || 5200;
const dbConfig = {
    host: args.dbhost || '127.0.0.1',
    user: args.dbuser || 'app',
    password: args.dbpassword || 'password',
    database: args.dbname || 'mywebapp',
    connectionLimit: 5
};

const app = express();
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

let pool;
try {
    pool = mariadb.createPool(dbConfig);
} catch (err) {
    console.error('Помилка пулу БД:', err);
}

const generateHTMLTable = (data, columns) => {
    if (!data || data.length === 0) return '<p>Немає даних</p>';
    let html = '<table border="1"><tr>' + columns.map(c => `<th>${c}</th>`).join('') + '</tr>';
    data.forEach(row => {
        html += '<tr>' + columns.map(c => `<td>${row[c]}</td>`).join('') + '</tr>';
    });
    return html + '</table>';
};

app.get('/health/alive', (req, res) => res.status(200).send('OK'));
app.get('/health/ready', async (req, res) => {
    try {
        const conn = await pool.getConnection();
        conn.release();
        res.status(200).send('OK');
    } catch (err) {
        res.status(500).send(err.message);
    }
});

app.get('/', (req, res) => res.send(`
    <h1>Notes Service API</h1>
    <ul>
        <li>GET /notes</li>
        <li>POST /notes</li>
        <li>GET /notes/&lt;id&gt;</li>
        <li>GET /health/alive</li>
        <li>GET /health/ready</li>
    </ul>
`));

app.get('/notes', async (req, res) => {
    try {
        const conn = await pool.getConnection();
        const rows = await conn.query("SELECT id, title FROM notes");
        conn.release();
        res.format({
            'application/json': () => res.json(rows),
            'text/html': () => res.send(generateHTMLTable(rows, ['id', 'title'])),
            default: () => res.status(406).send('Not Acceptable')
        });
    } catch (err) { res.status(500).send(err.message); }
});

app.get('/notes/:id', async (req, res) => {
    try {
        const conn = await pool.getConnection();
        const rows = await conn.query("SELECT id, title, created_at, content FROM notes WHERE id = ?", [req.params.id]);
        conn.release();
        if (rows.length === 0) return res.status(404).send('Not Found');
        res.format({
            'application/json': () => res.json(rows[0]),
            'text/html': () => res.send(generateHTMLTable([rows[0]], ['id', 'title', 'created_at', 'content'])),
            default: () => res.status(406).send('Not Acceptable')
        });
    } catch (err) { res.status(500).send(err.message); }
});

app.post('/notes', async (req, res) => {
    const { title, content } = req.body;
    if (!title || !content) return res.status(400).send('Bad Request');
    try {
        const conn = await pool.getConnection();
        const result = await conn.query("INSERT INTO notes (title, content) VALUES (?, ?)", [title, content]);
        conn.release();
        res.format({
            'application/json': () => res.status(201).json({ id: Number(result.insertId), title, content }),
            'text/html': () => res.status(201).send(`<p>Нотатка створена. ID: ${result.insertId}</p>`),
            default: () => res.status(406).send('Not Acceptable')
        });
    } catch (err) { res.status(500).send(err.message); }
});

if (process.env.LISTEN_FDS > 0) {
    app.listen({ fd: 3 }, () => console.log('Server is running via Socket Activation (fd: 3)'));
} else {
    app.listen(PORT, '0.0.0.0', () => console.log(`Server is running on 127.0.0.1:${PORT}`));
}

module.exports = app;
