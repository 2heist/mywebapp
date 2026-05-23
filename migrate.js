const mariadb = require('mariadb');
const minimist = require('minimist');

const args = minimist(process.argv.slice(2));
const dbConfig = {
    host: args.dbhost || '127.0.0.1',
    user: args.dbuser || 'app',
    password: args.dbpassword || 'password',
    database: args.dbname || 'mywebapp'
};

async function migrate() {
    let conn;
    try {
        conn = await mariadb.createConnection(dbConfig);
        console.log("Підключено до БД. Виконуємо міграцію...");

        await conn.query(`
            CREATE TABLE IF NOT EXISTS notes (
                id INT AUTO_INCREMENT PRIMARY KEY,
                title VARCHAR(255) NOT NULL,
                content TEXT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        `);
        console.log("Міграція успішно завершена.");
        process.exit(0);
    } catch (err) {
        console.error("Помилка міграції:", err);
        process.exit(1);
    } finally {
        if (conn) conn.end();
    }
}

migrate();
