// show_columns.js
const pool = require('./src/db');

(async () => {
  try {
    const { rows } = await pool.query(
      `SELECT column_name, data_type
       FROM information_schema.columns
       WHERE table_name = 'tickets'
       ORDER BY ordinal_position;`
    );
    console.log('tickets columns:\n', rows);
    process.exit(0);
  } catch (err) {
    console.error(err);
    process.exit(1);
  }
})();
