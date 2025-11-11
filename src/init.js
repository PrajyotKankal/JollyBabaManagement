// src/init.js
/**
 * Responsible for ensuring DB schema (tables) exist and optionally seeding a dev admin.
 *
 * Usage:
 *   const init = require('./src/init');
 *   init().catch(err => console.error('Init failed', err));
 *
 * Behavior:
 *  - Always ensures 'technicians' and 'tickets' tables exist.
 *  - Seeds/updates a dev admin only in non-production or when SEED_ADMIN_ALWAYS=true.
 *
 * NOTE: In production you should avoid seeding predictable accounts and never log secrets.
 */

const pool = require("./db");
const bcrypt = require("bcrypt");

const SALT_ROUNDS_RAW = parseInt(process.env.SALT_ROUNDS || "12", 10);
const SALT_ROUNDS = Number.isFinite(SALT_ROUNDS_RAW) ? Math.max(4, SALT_ROUNDS_RAW) : 12;

async function ensureTables() {
  // technicians table
  await pool.query(`
    CREATE TABLE IF NOT EXISTS technicians (
      id SERIAL PRIMARY KEY,
      name TEXT NOT NULL,
      email TEXT UNIQUE NOT NULL,
      password_hash TEXT NOT NULL,
      phone TEXT,
      role TEXT DEFAULT 'technician',
      created_at TIMESTAMP DEFAULT now(),
      updated_at TIMESTAMP DEFAULT now()
    );
  `);

  // tickets table
  await pool.query(`
    CREATE TABLE IF NOT EXISTS tickets (
      id SERIAL PRIMARY KEY,
      receive_date TIMESTAMP,
      customer_name TEXT,
      mobile_number TEXT,
      device_model TEXT,
      imei TEXT,
      issue_description TEXT,
      assigned_technician TEXT,
      estimated_cost TEXT,
      device_photo TEXT,
      lock_code TEXT,
      repair_date TIMESTAMP,
      delivery_date TIMESTAMP,
      status TEXT,
      notes JSONB DEFAULT '[]'::jsonb,
      delivery_photo_1 TEXT,
      delivery_photo_2 TEXT,
      created_at TIMESTAMP DEFAULT now(),
      updated_at TIMESTAMP DEFAULT now()
    );
  `);

  await pool.query(`
    ALTER TABLE tickets
    ADD COLUMN IF NOT EXISTS repaired_photo TEXT;
  `);

  await pool.query(`
    ALTER TABLE tickets
    ADD COLUMN IF NOT EXISTS repaired_photo_thumb TEXT;
  `);

  await pool.query(`
    ALTER TABLE tickets
    ADD COLUMN IF NOT EXISTS repaired_photo_uploaded_at TIMESTAMP;
  `);

  await pool.query(`
    ALTER TABLE tickets
    ADD COLUMN IF NOT EXISTS repaired_photo_uploaded_by TEXT;
  `);
  // inventory_items table
  await pool.query(`
    CREATE TABLE IF NOT EXISTS inventory_items (
      sr_no SERIAL PRIMARY KEY,
      created_at TIMESTAMP NOT NULL DEFAULT now(),
      updated_at TIMESTAMP NOT NULL DEFAULT now(),
      date DATE NOT NULL,
      model TEXT NOT NULL,
      imei TEXT NOT NULL UNIQUE,
      variant_gb_color TEXT,
      vendor_purchase TEXT,
      brand TEXT,
      purchase_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
      sell_date DATE,
      sell_amount NUMERIC(12,2),
      customer_name TEXT,
      mobile_number TEXT,
      remarks TEXT,
      vendor_phone TEXT,
      status TEXT NOT NULL DEFAULT 'AVAILABLE',
      CONSTRAINT inventory_items_status_chk CHECK (status IN ('AVAILABLE','SOLD','RESERVED'))
    );
  `);

  await pool.query(`
    ALTER TABLE inventory_items
    ADD COLUMN IF NOT EXISTS vendor_phone TEXT;
  `);

  await pool.query(`
    ALTER TABLE inventory_items
    ADD COLUMN IF NOT EXISTS brand TEXT;
  `);

  await pool.query(`
    ALTER TABLE inventory_items
    ADD COLUMN IF NOT EXISTS khatabook_entry_id INTEGER;
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS customers (
      id SERIAL PRIMARY KEY,
      name TEXT NOT NULL,
      name_key TEXT NOT NULL,
      phone TEXT,
      phone_digits TEXT NOT NULL DEFAULT '',
      email TEXT,
      address TEXT,
      notes TEXT,
      created_at TIMESTAMP NOT NULL DEFAULT now(),
      updated_at TIMESTAMP NOT NULL DEFAULT now(),
      last_purchase_at TIMESTAMP
    );
  `);

  await pool.query(`
    CREATE UNIQUE INDEX IF NOT EXISTS customers_name_phone_key
      ON customers (name_key, phone_digits);
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS khatabook_entries (
      id SERIAL PRIMARY KEY,
      name TEXT NOT NULL,
      mobile TEXT,
      amount NUMERIC(12,2) NOT NULL DEFAULT 0,
      paid NUMERIC(12,2) NOT NULL DEFAULT 0,
      description TEXT,
      note TEXT,
      entry_date DATE NOT NULL DEFAULT CURRENT_DATE,
      created_at TIMESTAMP NOT NULL DEFAULT now(),
      updated_at TIMESTAMP NOT NULL DEFAULT now(),
      CONSTRAINT khatabook_paid_nonnegative CHECK (paid >= 0),
      CONSTRAINT khatabook_amount_nonnegative CHECK (amount >= 0)
    );
  `);

  await pool.query(`
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'inventory_items_khatabook_entry_id_fkey'
      ) THEN
        ALTER TABLE inventory_items
        ADD CONSTRAINT inventory_items_khatabook_entry_id_fkey
        FOREIGN KEY (khatabook_entry_id)
        REFERENCES khatabook_entries(id)
        ON DELETE SET NULL;
      END IF;
    END
    $$;
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS khatabook_messages (
      id SERIAL PRIMARY KEY,
      entry_id INTEGER NOT NULL REFERENCES khatabook_entries(id) ON DELETE CASCADE,
      recipient_name TEXT NOT NULL,
      recipient_phone TEXT NOT NULL,
      template_key TEXT NOT NULL,
      text_snapshot TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'queued',
      provider_id TEXT,
      channel TEXT NOT NULL DEFAULT 'whatsapp',
      sandbox BOOLEAN NOT NULL DEFAULT false,
      error TEXT,
      metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
      created_at TIMESTAMP NOT NULL DEFAULT now(),
      updated_at TIMESTAMP NOT NULL DEFAULT now(),
      sent_at TIMESTAMP
    );
  `);

  await pool.query(`
    CREATE INDEX IF NOT EXISTS khatabook_messages_entry_phone_idx
      ON khatabook_messages (entry_id, recipient_phone, created_at DESC);
  `);

  console.log("🧱 Tables ensured: technicians, tickets, inventory_items, khatabook_entries, khatabook_messages");
}

/**
 * Seed or update a dev admin.
 * - Skips in production unless SEED_ADMIN_ALWAYS=true.
 * - Uses env vars: DEV_ADMIN_EMAIL/DEV_ADMIN_PASSWORD or ADMIN_EMAIL/ADMIN_PASSWORD.
 * - Does NOT log plaintext password.
 */
async function seedDevAdmin() {
  const nodeEnv = process.env.NODE_ENV || "development";
  const seedAlways = process.env.SEED_ADMIN_ALWAYS === "true";

  if (nodeEnv === "production" && !seedAlways) {
    console.log("🔒 Production environment detected — skipping dev admin seed (set SEED_ADMIN_ALWAYS=true to override)");
    return;
  }

  const adminEmail = process.env.DEV_ADMIN_EMAIL || process.env.ADMIN_EMAIL || "admin@jollybaba.local";
  const adminPassword = process.env.DEV_ADMIN_PASSWORD || process.env.ADMIN_PASSWORD || "admin1234";

  if (!adminEmail || !adminPassword) {
    console.warn("⚠️ Admin email or password is empty — skipping admin seeding.");
    return;
  }

  // Use a transaction to keep operation atomic
  const client = await pool.connect();
  try {
    await client.query("BEGIN");

    // Check existing admin
    const res = await client.query("SELECT id, password_hash FROM technicians WHERE email = $1 FOR UPDATE", [adminEmail]);

    if (res.rowCount === 0) {
      const hash = await bcrypt.hash(adminPassword, SALT_ROUNDS);
      await client.query(
        `INSERT INTO technicians (name, email, password_hash, role, created_at, updated_at)
         VALUES ($1, $2, $3, $4, now(), now())`,
        ["Administrator", adminEmail, hash, "admin"]
      );
      console.log(`🔐 Dev admin created: ${adminEmail} (password not logged)`);
    } else {
      const existing = res.rows[0];
      const match = await bcrypt.compare(adminPassword, existing.password_hash);
      if (!match) {
        // Upsert using ON CONFLICT would work too — here we update the password_hash and updated_at
        const newHash = await bcrypt.hash(adminPassword, SALT_ROUNDS);
        await client.query(
          "UPDATE technicians SET password_hash = $1, updated_at = now() WHERE id = $2",
          [newHash, existing.id]
        );
        console.log(`🔁 Dev admin password updated for ${adminEmail}`);
      } else {
        // optionally ensure role is 'admin' (idempotent)
        await client.query(
          `UPDATE technicians SET role = $1, updated_at = now() WHERE id = $2 AND role IS DISTINCT FROM $1`,
          ["admin", existing.id]
        );
        console.log("🔐 Dev admin already exists and password matches .env");
      }
    }

    await client.query("COMMIT");
  } catch (err) {
    await client.query("ROLLBACK");
    throw err;
  } finally {
    client.release();
  }
}

async function init() {
  try {
    await ensureTables();
    await seedDevAdmin();
    // place for future migrations / seeders
  } catch (err) {
    console.error("❌ Error in DB init:", err.message || err);
    throw err;
  }
}

module.exports = init;
