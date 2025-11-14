// migrate_add_assigned_fields.js
require("dotenv").config();
const pool = require("./src/db");

(async () => {
  try {
    console.log("Running migration...");
    await pool.query(`
      ALTER TABLE tickets
      ADD COLUMN IF NOT EXISTS assigned_technician_id integer REFERENCES technicians(id);
    `);
    await pool.query(`
      ALTER TABLE tickets
      ADD COLUMN IF NOT EXISTS assigned_technician_email text;
    `);
    console.log("✅ Migration complete!");
  } catch (err) {
    console.error("❌ Migration failed:", err.message || err);
  } finally {
    await pool.end();
  }
})();
