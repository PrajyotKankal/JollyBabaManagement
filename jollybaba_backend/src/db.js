// src/db.js
const { Pool } = require('pg');

const connectionString = process.env.DATABASE_URL;

if (!connectionString) {
  throw new Error('DATABASE_URL is required but was not provided.');
}

let parsedUrl;
try {
  parsedUrl = new URL(connectionString);
} catch (err) {
  console.error('❌ Failed to parse DATABASE_URL. Ensure it is a valid Postgres connection string.');
  throw err;
}

const dbHost = parsedUrl.hostname;
const pool = new Pool({
  connectionString,
  ssl: { rejectUnauthorized: false },
});

pool.on('error', (err) => {
  console.error('❌ Unexpected idle client error', err);
});

async function ping() {
  const client = await pool.connect();
  try {
    await client.query('SELECT 1');
  } finally {
    client.release();
  }
}

function describeError(err) {
  if (!err) return 'Unknown error';
  const code = err.code || err.errno;
  switch (code) {
    case 'ENOTFOUND':
      return 'Database host not found (DNS lookup failed).';
    case 'ECONNREFUSED':
      return 'Connection refused by database host.';
    case 'ENETUNREACH':
      return 'Network unreachable when attempting to reach database host.';
    case 'ETIMEDOUT':
      return 'Connection attempt to database timed out.';
    case '28P01':
      return 'Authentication failed (check username/password).';
    default:
      return err.message || String(err);
  }
}

async function verifyConnection({ maxRetries = 5, delayMs = 2000 } = {}) {
  console.log(`🔌 Preparing to connect to Postgres host: ${dbHost}`);
  let attempt = 0;
  while (attempt < maxRetries) {
    attempt += 1;
    console.log(`🔄 DB connection attempt ${attempt}/${maxRetries}...`);
    try {
      await ping();
      console.log('✅ Postgres connection successful.');
      return true;
    } catch (err) {
      const description = describeError(err);
      console.error(`⚠️ Attempt ${attempt} failed: ${description}`);
      if (err && err.stack) {
        console.error(err.stack);
      }
      if (attempt >= maxRetries) {
        console.error('❌ Exhausted all retries. Ensure DATABASE_URL includes ?sslmode=require and IPv4 is preferred.');
        return false;
      }
      console.log(`⏳ Retrying in ${delayMs}ms...`);
      await new Promise((resolve) => setTimeout(resolve, delayMs));
    }
  }
  return false;
}

module.exports = pool;
module.exports.pool = pool;
module.exports.dbHost = dbHost;
module.exports.verifyConnection = verifyConnection;
module.exports.ping = ping;
module.exports.describeError = describeError;
