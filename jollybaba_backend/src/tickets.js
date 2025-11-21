// src/tickets.js
const express = require("express");
const multer = require("multer");
const path = require("path");
const fs = require("fs");
const sharp = require("sharp");
const cloudinary = require("cloudinary").v2;
const pool = require("./db");
const { authMiddleware } = require("./auth");

const router = express.Router();

const fsp = fs.promises;

const CLOUDINARY_CONFIGURED =
  process.env.CLOUDINARY_CLOUD_NAME &&
  process.env.CLOUDINARY_API_KEY &&
  process.env.CLOUDINARY_API_SECRET;

if (CLOUDINARY_CONFIGURED) {
  cloudinary.config({
    cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
    api_key: process.env.CLOUDINARY_API_KEY,
    api_secret: process.env.CLOUDINARY_API_SECRET,
  });
} else {
  console.warn(
    "⚠️ Cloudinary env variables missing. Set CLOUDINARY_CLOUD_NAME, CLOUDINARY_API_KEY, CLOUDINARY_API_SECRET to enable repaired photo uploads."
  );
}

const REPAIRED_FOLDER = process.env.CLOUDINARY_REPAIRED_FOLDER || "Jollybaba_Repaired";
const REPAIRED_MAX_DIMENSION = parseInt(process.env.REPAIRED_MAX_DIMENSION || "1600", 10);
const REPAIRED_THUMB_DIMENSION = parseInt(process.env.REPAIRED_THUMB_DIMENSION || "480", 10);
const REPAIRED_QUALITY = parseInt(process.env.REPAIRED_QUALITY || "75", 10);
const REPAIRED_THUMB_QUALITY = parseInt(process.env.REPAIRED_THUMB_QUALITY || "70", 10);

function inferUploadedBy(user = {}) {
  if (!user) return null;
  if (user.email) return user.email;
  if (user.name) return user.name;
  if (user.id !== undefined && user.id !== null) return `id:${user.id}`;
  return null;
}

function extractWorkerIdentity(user = {}) {
  if (!user) return null;
  const email = user.email ? user.email.toString().toLowerCase() : null;
  const name = user.name ? user.name.toString() : null;
  let id = null;
  if (Number.isInteger(user.id)) {
    id = user.id;
  } else if (user.id !== undefined && user.id !== null) {
    const parsed = parseInt(user.id, 10);
    if (!Number.isNaN(parsed)) id = parsed;
  }
  if (!email && !name && (id === null || Number.isNaN(id))) {
    return null;
  }
  return { email, name, id };
}

function buildWorkLogEntry(identity, action, extras = {}) {
  if (!identity) return null;
  const timestamp = extras.timestamp || new Date().toISOString();
  const entry = {
    action,
    at: timestamp,
    user: {
      email: identity.email || null,
      name: identity.name || null,
      id: identity.id,
    },
  };
  if (extras.notes) entry.notes = extras.notes;
  return entry;
}

function identityFromBody(body = {}) {
  if (!body) return null;
  const email = body.worked_by_email ? body.worked_by_email.toString().toLowerCase().trim() : null;
  const name = body.worked_by_name ? body.worked_by_name.toString().trim() : null;
  let id = null;
  if (body.worked_by_id !== undefined && body.worked_by_id !== null && `${body.worked_by_id}`.trim().length > 0) {
    const parsed = parseInt(body.worked_by_id, 10);
    if (!Number.isNaN(parsed)) id = parsed;
  }
  if (!email && !name && id === null) return null;
  return { email, name, id };
}

function normalizeIsoTimestamp(value) {
  if (!value) return new Date().toISOString();
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) return new Date().toISOString();
  return parsed.toISOString();
}

function parseNotesPayload(raw) {
  if (typeof raw === "undefined") {
    return { provided: false, notes: null };
  }
  let notes = raw;
  if (typeof notes === "string") {
    try {
      notes = JSON.parse(notes);
    } catch (_) {
      notes = [];
    }
  }
  if (!Array.isArray(notes)) {
    notes = [];
  }
  return { provided: true, notes };
}

function normalizeBooleanQuery(value) {
  if (typeof value === "boolean") return value;
  if (value === undefined || value === null) return false;
  const normalized = value.toString().trim().toLowerCase();
  return ["1", "true", "yes", "y", "on", "enabled", "mine", "me", "assigned", "own"].includes(normalized);
}

async function updateTicketWithWorklog({
  id,
  status,
  notes,
  notesProvided = false,
  deliveryPhoto1,
  deliveryPhoto2,
  assignedTechnician,
  assignedTechnicianEmail,
  assignedTo,
  assignedToEmail,
  customerName,
  mobileNumber,
  deviceModel,
  imei,
  issueDescription,
  estimatedCost,
  lockCode,
  receiveDate,
  repairDate,
  actingIdentity,
  workAction,
  workNotes,
  workedAt,
}) {
  if (!id) throw new Error("Ticket id is required for update");
  await ensureWorkLogColumns();

  const notesJson = notesProvided ? JSON.stringify(Array.isArray(notes) ? notes : []) : null;
  const worker = actingIdentity || null;
  const effectiveAction = workAction || (status ? `status:${status}` : "update");
  const timestamp = worker ? normalizeIsoTimestamp(workedAt) : null;
  const workEntry = worker
    ? buildWorkLogEntry(worker, effectiveAction, { notes: workNotes, timestamp })
    : null;
  const workLogPayload = workEntry ? JSON.stringify([workEntry]) : null;

  const queryText = `
    UPDATE tickets
    SET receive_date = COALESCE($1, receive_date),
        repair_date = COALESCE($2, repair_date),
        customer_name = COALESCE($3, customer_name),
        mobile_number = COALESCE($4, mobile_number),
        device_model = COALESCE($5, device_model),
        imei = COALESCE($6, imei),
        issue_description = COALESCE($7, issue_description),
        estimated_cost = COALESCE($8, estimated_cost),
        lock_code = COALESCE($9, lock_code),
        status = COALESCE($10, status),
        notes = COALESCE($11::jsonb, notes),
        delivery_photo_1 = COALESCE($12, delivery_photo_1),
        delivery_photo_2 = COALESCE($13, delivery_photo_2),
        assigned_technician = COALESCE($14, assigned_technician),
        assigned_technician_email = COALESCE($15, assigned_technician_email),
        assigned_to = COALESCE($16, assigned_to),
        assigned_to_email = COALESCE($17, assigned_to_email),
        last_worked_by_email = COALESCE($18, last_worked_by_email),
        last_worked_by_name = COALESCE($19, last_worked_by_name),
        last_worked_by_id = COALESCE($20, last_worked_by_id),
        last_worked_at = COALESCE($21, last_worked_at),
        work_log = CASE WHEN $22::jsonb IS NULL THEN work_log ELSE COALESCE(work_log, '[]'::jsonb) || $22::jsonb END,
        updated_at = now()
    WHERE id = $23
    RETURNING *;
  `;

  const params = [
    receiveDate || null,
    repairDate || null,
    customerName || null,
    mobileNumber || null,
    deviceModel || null,
    imei || null,
    issueDescription || null,
    estimatedCost || null,
    lockCode || null,
    status || null,
    notesJson,
    deliveryPhoto1 || null,
    deliveryPhoto2 || null,
    assignedTechnician || null,
    assignedTechnicianEmail || null,
    assignedTo || null,
    assignedToEmail || null,
    worker?.email || null,
    worker?.name || null,
    typeof worker?.id === "number" ? worker.id : null,
    timestamp,
    workLogPayload,
    id,
  ];

  return runQueryWithAddTimestampsOnMissingColumn(queryText, params);
}

function uploadBufferToCloudinary(buffer, options) {
  if (!CLOUDINARY_CONFIGURED) {
    return Promise.reject(new Error("Cloudinary not configured"));
  }
  return new Promise((resolve, reject) => {
    const stream = cloudinary.uploader.upload_stream(
      {
        resource_type: "image",
        overwrite: true,
        ...options,
      },
      (err, result) => {
        if (err) return reject(err);
        return resolve(result);
      }
    );
    stream.on("error", reject);
    stream.end(buffer);
  });
}

async function prepareRepairedPhotoVariants(filePath, ticketId) {
  if (!CLOUDINARY_CONFIGURED) {
    throw new Error("Cloudinary not configured");
  }
  const baseName = `ticket_${ticketId}_${Date.now()}`;
  const mainBuffer = await sharp(filePath)
    .rotate()
    .resize({
      width: REPAIRED_MAX_DIMENSION,
      height: REPAIRED_MAX_DIMENSION,
      fit: "inside",
      withoutEnlargement: true,
    })
    .webp({ quality: REPAIRED_QUALITY, effort: 4 })
    .toBuffer();

  const thumbBuffer = await sharp(filePath)
    .rotate()
    .resize({
      width: REPAIRED_THUMB_DIMENSION,
      height: REPAIRED_THUMB_DIMENSION,
      fit: "inside",
      withoutEnlargement: true,
    })
    .webp({ quality: REPAIRED_THUMB_QUALITY, effort: 2 })
    .toBuffer();

  const [mainUpload, thumbUpload] = await Promise.all([
    uploadBufferToCloudinary(mainBuffer, {
      folder: REPAIRED_FOLDER,
      public_id: `${baseName}`,
      format: "webp",
    }),
    uploadBufferToCloudinary(thumbBuffer, {
      folder: REPAIRED_FOLDER,
      public_id: `${baseName}_thumb`,
      format: "webp",
      transformation: [{ quality: "auto", fetch_format: "auto" }],
    }),
  ]);

  return {
    main: mainUpload,
    thumb: thumbUpload,
  };
}

// ---------------------------
// Uploads directory & multer
// ---------------------------
const UPLOADS_DIR = path.resolve(__dirname, "..", "uploads");
try {
  fs.mkdirSync(UPLOADS_DIR, { recursive: true });
} catch (err) {
  console.error("❌ Failed to create uploads dir:", err && err.stack ? err.stack : err);
}

// Cache tickets table columns for a short time to avoid repeated metadata queries
let _ticketsColumnsCache = { cols: null, ts: 0 };
async function getTicketsColumns() {
  if (!pool || typeof pool.query !== 'function') return new Set();
  const now = Date.now();
  if (_ticketsColumnsCache.cols && now - _ticketsColumnsCache.ts < 60_000) {
    return _ticketsColumnsCache.cols;
  }
  try {
    const res = await pool.query(
      `SELECT column_name FROM information_schema.columns WHERE table_name = 'tickets'`
    );
    const set = new Set((res.rows || []).map(r => String(r.column_name)));
    _ticketsColumnsCache = { cols: set, ts: now };
    return set;
  } catch {
    return new Set();
  }
}

// Allow only common image mime types (adjust as needed)
const allowedMimes = new Set([
  "image/jpeg",
  "image/png",
  "image/webp",
  "image/heic",
  "image/jpg",
]);

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, UPLOADS_DIR),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase() || "";
    // ensure ext is safe; fallback to .bin if unknown
    const safeExt = ext.match(/^\.[a-z0-9]{1,6}$/) ? ext : ".bin";
    const uniqueName = `${Date.now()}-${Math.round(Math.random() * 1e9)}${safeExt}`;
    cb(null, uniqueName);
  },
});

const upload = multer({
  storage,
  fileFilter: (req, file, cb) => {
    if (!allowedMimes.has(file.mimetype)) {
      return cb(new Error("UNSUPPORTED_FILE_TYPE"));
    }
    cb(null, true);
  },
  limits: {
    fileSize: 6 * 1024 * 1024, // 6 MB per file
    files: 1,
  },
});

// -----------------------------
// Helper: run query with retry if 'updated_at' column missing
// -----------------------------
async function runQueryWithAddTimestampsOnMissingColumn(queryText, params = []) {
  if (!pool || typeof pool.query !== "function") {
    const err = new Error("Database pool is not configured");
    err.code = "NO_POOL";
    throw err;
  }

  try {
    return await pool.query(queryText, params);
  } catch (err) {
    const message = (err && err.message) ? err.message.toString().toLowerCase() : "";
    if (message.includes('column "updated_at"') || message.includes('column updated_at')) {
      console.warn("⚠️ Detected missing 'updated_at' column. Attempting to add timestamp columns and retry query...");
      try {
        await pool.query(`ALTER TABLE tickets ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT now();`);
        await pool.query(`ALTER TABLE tickets ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT now();`);
        console.log("✅ added missing created_at/updated_at columns (if they were missing). Retrying original query...");
        return await pool.query(queryText, params); // retry once
      } catch (mErr) {
        console.error("❌ Failed to add timestamp columns or retry query:", mErr && mErr.stack ? mErr.stack : mErr);
        throw err;
      }
    }
    throw err;
  }
}

// -----------------------------
// Ticket Endpoints
// -----------------------------

// Ensure creator columns for technician visibility
async function ensureCreatorColumns() {
  if (!pool || typeof pool.query !== "function") return;
  try {
    await pool.query(`ALTER TABLE tickets ADD COLUMN IF NOT EXISTS created_by_email TEXT;`);
    await pool.query(`ALTER TABLE tickets ADD COLUMN IF NOT EXISTS created_by_name TEXT;`);
    await pool.query(`ALTER TABLE tickets ADD COLUMN IF NOT EXISTS created_by_id INTEGER;`);
  } catch (err) {
    console.warn("⚠️ ensureCreatorColumns failed (continuing):", err && err.stack ? err.stack : err);
  }
}

// Some legacy DBs may miss these assignment columns referenced in filters
async function ensureAssignmentColumns() {
  if (!pool || typeof pool.query !== "function") return;
  try {
    await pool.query(`ALTER TABLE tickets ADD COLUMN IF NOT EXISTS assigned_technician_email TEXT;`);
    await pool.query(`ALTER TABLE tickets ADD COLUMN IF NOT EXISTS assigned_to TEXT;`);
    await pool.query(`ALTER TABLE tickets ADD COLUMN IF NOT EXISTS assigned_to_email TEXT;`);
  } catch (err) {
    console.warn("⚠️ ensureAssignmentColumns failed (continuing):", err && err.stack ? err.stack : err);
  }
}

async function ensureWorkLogColumns() {
  if (!pool || typeof pool.query !== "function") return;
  try {
    await pool.query(`ALTER TABLE tickets ADD COLUMN IF NOT EXISTS last_worked_by_email TEXT;`);
    await pool.query(`ALTER TABLE tickets ADD COLUMN IF NOT EXISTS last_worked_by_name TEXT;`);
    await pool.query(`ALTER TABLE tickets ADD COLUMN IF NOT EXISTS last_worked_by_id INTEGER;`);
    await pool.query(`ALTER TABLE tickets ADD COLUMN IF NOT EXISTS last_worked_at TIMESTAMP;`);
    await pool.query(`ALTER TABLE tickets ADD COLUMN IF NOT EXISTS work_log JSONB DEFAULT '[]'::jsonb;`);
  } catch (err) {
    console.warn("⚠️ ensureWorkLogColumns failed (continuing):", err && err.stack ? err.stack : err);
  }
}

// GET /api/tickets
// - Admins see all tickets
// - Technicians see only tickets assigned to them OR tickets they created (by email preferred, fallback to name)
// - Requires authMiddleware (sets req.user)
// Supports pagination: ?page=1&perPage=50 (optional)
router.get("/tickets", authMiddleware, async (req, res) => {
  if (!pool || typeof pool.query !== "function") {
    return res.status(500).json({ error: "Database not available" });
  }

  try {
    await ensureCreatorColumns();
    await ensureAssignmentColumns();
    await ensureWorkLogColumns();
    const user = req.user || {};
    const role = (user.role || "").toString().toLowerCase().trim();
    const email = (user.email || "").toString().toLowerCase().trim();
    const name = (user.name || "").toString().toLowerCase().trim();

    const page = Math.max(1, parseInt(req.query.page || "1", 10) || 1);
    const perPage = Math.min(200, Math.max(10, parseInt(req.query.perPage || "100", 10) || 100));
    const offset = (page - 1) * perPage;
    const mineOnly = normalizeBooleanQuery(
      req.query.mineOnly ?? req.query.onlyMine ?? req.query.assigned ?? req.query.mine ?? req.query.my
    );
    const pendingOnly = normalizeBooleanQuery(req.query.pendingOnly ?? req.query.onlyPending ?? req.query.pending);
    const rawStatusFilter = (req.query.status || "").toString().trim().toLowerCase();
    const statusFilter = pendingOnly ? "pending" : rawStatusFilter;

    // Admins see everything (paginated)
    if (role === "admin" || role === "administrator") {
      const q = `SELECT * FROM tickets ORDER BY id DESC LIMIT $1 OFFSET $2`;
      const result = await runQueryWithAddTimestampsOnMissingColumn(q, [perPage, offset]);
      return res.json({ success: true, data: result.rows, page, perPage });
    }

    // For technicians: allow optional mine-only filter, otherwise show shared queue
    {
      const userId = (user.id && Number.isInteger(user.id)) ? user.id : (parseInt(user.id, 10) || null);
      if (!mineOnly) {
        const clauses = [];
        const params = [];
        let idx = 1;
        if (statusFilter) {
          clauses.push(`lower(coalesce(status, '')) = $${idx}`);
          params.push(statusFilter);
          idx++;
        }

        const whereSql = clauses.length ? `WHERE ${clauses.join(' AND ')}` : '';
        const orderSql = `ORDER BY (CASE WHEN lower(coalesce(status, '')) = 'pending' THEN 0 ELSE 1 END), updated_at DESC NULLS LAST, id DESC`;
        const q = `SELECT * FROM tickets ${whereSql} ${orderSql} LIMIT $${idx} OFFSET $${idx + 1}`;
        params.push(perPage, offset);
        const result = await runQueryWithAddTimestampsOnMissingColumn(q, params);
        return res.json({ success: true, data: result.rows, page, perPage });
      }

      if (!email && !name && !userId) {
        return res.json({ success: true, data: [], page, perPage });
      }

      const needles = [];
      if (email && email.length > 0) {
        needles.push(`%${email}%`);
        const local = email.split('@')[0];
        if (local && local.length > 0) needles.push(`%${local}%`);
      }
      if (name && name.length > 0) {
        needles.push(`%${name}%`);
        const parts = name.split(/\s+/).filter(Boolean);
        for (const p of parts) needles.push(`%${p}%`);
      }

      const whereParts = [];
      const params = [];
      let idx = 1;

      const likeExprsFor = (column) => {
        const exprs = [];
        for (const n of needles) {
          exprs.push(`lower(trim(coalesce(${column}, ''))) LIKE $${idx}`);
          params.push(n.toLowerCase());
          idx++;
        }
        return exprs;
      };

      const available = await getTicketsColumns();

      ['assigned_technician', 'assigned_technician_email', 'assigned_to'].forEach(col => {
        if (!available.has(col)) return;
        const exprs = likeExprsFor(col);
        if (exprs.length) whereParts.push(`(${exprs.join(' OR ')})`);
      });

      ['created_by_email', 'created_by_name'].forEach(col => {
        if (!available.has(col)) return;
        const exprs = likeExprsFor(col);
        if (exprs.length) whereParts.push(`(${exprs.join(' OR ')})`);
      });

      if (userId && available.has('created_by_id')) {
        whereParts.push(`created_by_id = $${idx}`);
        params.push(userId);
        idx++;
      }

      if (whereParts.length === 0 && !userId) {
        return res.json({ success: true, data: [], page, perPage });
      }

      const q = `
        SELECT *
        FROM tickets
        WHERE ${whereParts.join(' OR ')}
        ORDER BY id DESC
        LIMIT $${idx} OFFSET $${idx + 1}
      `;
      params.push(perPage, offset);

      console.log('[tickets] GET /tickets filter (mineOnly)', {
        email,
        name,
        userId,
        where: whereParts.join(' OR '),
        paramsPreview: params.map((p) => (typeof p === 'string' ? p.slice(0, 64) : p)),
      });

      const result = await runQueryWithAddTimestampsOnMissingColumn(q, params);
      return res.json({ success: true, data: result.rows, page, perPage });
    }
  } catch (err) {
    console.error("❌ Error fetching tickets:", err && err.stack ? err.stack : err);
    return res.status(500).json({
      error: "Failed to fetch tickets",
      details: process.env.NODE_ENV === "development" ? (err.message || err) : undefined,
    });
  }
});

// POST /api/tickets  (create new ticket)
// Note: left open (no auth) — add authMiddleware if creation should require authentication.
router.post("/tickets", authMiddleware, upload.single("photo"), async (req, res) => {
  if (!pool || typeof pool.query !== "function") {
    return res.status(500).json({ error: "Database not available" });
  }

  try {
    await ensureCreatorColumns();
    await ensureAssignmentColumns();
    console.log("📥 Incoming Ticket Data (keys):", Object.keys(req.body), "file:", req.file ? req.file.filename : null);

    const host = req.get("host") || process.env.EXPOSED_HOST || "localhost:5000";
    const protocol = req.protocol || "http";
    const device_photo = req.file
      ? `${protocol}://${host}/uploads/${req.file.filename}`
      : (req.body.device_photo || null);

    let {
      receive_date,
      customer_name,
      mobile_number,
      device_model,
      imei,
      issue_description,
      assigned_technician,
      estimated_cost,
      lock_code,
      repair_date,
      delivery_date,
      status,
      notes,
    } = req.body || {};

    // Basic validation (you can expand this)
    if (!customer_name || customer_name.toString().trim().length === 0) {
      return res.status(400).json({ error: "customer_name is required" });
    }

    // Normalize notes
    if (typeof notes === "string") {
      try {
        notes = JSON.parse(notes);
      } catch {
        notes = [];
      }
    }
    if (!Array.isArray(notes)) notes = [];

    // If no explicit assignee provided, default-assign to creator (tech) for visibility
    try {
      const me = req.user || {};
      const meName = (me.name || '').toString();
      const meEmail = (me.email || '').toString();
      if (!assigned_technician || assigned_technician.toString().trim().length === 0) {
        assigned_technician = meName || assigned_technician;
        if (!req.body.assigned_technician_email && meEmail) {
          req.body.assigned_technician_email = meEmail;
        }
      }
    } catch {}

    const result = await pool.query(
      `
      INSERT INTO tickets (
        receive_date, customer_name, mobile_number, device_model, imei,
        issue_description, assigned_technician, assigned_technician_email, estimated_cost, device_photo,
        lock_code, repair_date, delivery_date, status, notes
      )
      VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15::jsonb)
      RETURNING *;
      `,
      [
        receive_date || null,
        customer_name || null,
        mobile_number || null,
        device_model || null,
        imei || null,
        issue_description || null,
        assigned_technician || null,
        (req.body.assigned_technician_email || null),
        estimated_cost || null,
        device_photo || null,
        lock_code || null,
        repair_date || null,
        delivery_date || null,
        status || null,
        JSON.stringify(notes),
      ]
    );

    console.log("✅ Ticket created:", result.rows[0].id);
    // Update creator columns using auth user if present
    try {
      const me = req.user || {};
      const creatorEmail = (me.email || null) && me.email.toString().toLowerCase();
      const creatorName = (me.name || null) && me.name.toString().toLowerCase();
      const creatorId = Number.isInteger(me.id) ? me.id : (parseInt(me.id, 10) || null);
      if (creatorEmail || creatorName || creatorId) {
        await pool.query(
          `UPDATE tickets SET created_by_email = COALESCE($1, created_by_email), created_by_name = COALESCE($2, created_by_name), created_by_id = COALESCE($3, created_by_id) WHERE id = $4`,
          [creatorEmail || null, creatorName || null, creatorId || null, result.rows[0].id]
        );
      }
    } catch (e) {
      console.warn("⚠️ Failed to set creator columns:", e && e.stack ? e.stack : e);
    }

    // Re-fetch updated row
    const refreshed = await pool.query(`SELECT * FROM tickets WHERE id = $1`, [result.rows[0].id]);
    return res.status(201).json({ success: true, ticket: refreshed.rows[0] });
  } catch (err) {
    // Multer errors will be handled by your global multer error handler in server.js
    console.error("❌ Error creating ticket:", err && err.stack ? err.stack : err);
    return res.status(500).json({ error: "Failed to create ticket", details: process.env.NODE_ENV === "development" ? (err.message || err) : undefined });
  }
});

// POST /api/tickets/:id/repaired-photo
// Requires auth and a multipart field `repaired_photo`.
// Compresses the image, uploads variants to Cloudinary, stamps metadata, flips status to "Repaired".
console.log("🛠️ Repaired photo endpoint registered (tickets.js)");
router.post(
  "/tickets/:id/repaired-photo",
  authMiddleware,
  upload.single("repaired_photo"),
  async (req, res) => {
    if (!pool || typeof pool.query !== "function") {
      return res.status(500).json({ error: "Database not available" });
    }

    const rawId = req.params.id;
    const ticketId = Number.parseInt(rawId, 10);
    if (!Number.isInteger(ticketId)) {
      return res.status(400).json({ error: "Invalid ticket id" });
    }

    if (!req.file) {
      return res.status(400).json({ error: "repaired_photo file is required" });
    }

    if (!CLOUDINARY_CONFIGURED) {
      await fsp.unlink(req.file.path).catch(() => {});
      return res.status(500).json({ error: "Repaired photo uploads are not configured" });
    }

    let notes = req.body?.notes;
    if (typeof notes === "string") {
      try {
        notes = JSON.parse(notes);
      } catch (_) {
        notes = [];
      }
    }
    if (!Array.isArray(notes)) notes = undefined;

    try {
      // Ensure ticket exists before processing heavy work
      const existing = await pool.query("SELECT id FROM tickets WHERE id = $1", [ticketId]);
      if (existing.rowCount === 0) {
        await fsp.unlink(req.file.path).catch(() => {});
        return res.status(404).json({ error: "Ticket not found" });
      }

      let variants;
      try {
        variants = await prepareRepairedPhotoVariants(req.file.path, ticketId);
      } finally {
        await fsp.unlink(req.file.path).catch(() => {});
      }

      const mainUrl = variants?.main?.secure_url || variants?.main?.url;
      const thumbUrl = variants?.thumb?.secure_url || variants?.thumb?.url;
      if (!mainUrl) {
        return res.status(500).json({ error: "Failed to upload repaired photo" });
      }

      const uploadedBy = inferUploadedBy(req.user);

      const updateResult = await pool.query(
        `
        UPDATE tickets
        SET status = 'Repaired',
            notes = COALESCE($1::jsonb, notes),
            repaired_photo = $2,
            repaired_photo_thumb = COALESCE($3, repaired_photo_thumb),
            repaired_photo_uploaded_at = now(),
            repaired_photo_uploaded_by = COALESCE($4, repaired_photo_uploaded_by),
            updated_at = now()
        WHERE id = $5
        RETURNING *;
        `,
        [notes ? JSON.stringify(notes) : null, mainUrl, thumbUrl, uploadedBy || null, ticketId]
      );

      if (updateResult.rowCount === 0) {
        return res.status(404).json({ error: "Ticket not found" });
      }

      const updated = updateResult.rows[0];
      return res.json({
        success: true,
        ticket: updated,
        repairedPhoto: {
          url: updated.repaired_photo,
          thumbUrl: updated.repaired_photo_thumb,
          uploadedAt: updated.repaired_photo_uploaded_at,
          uploadedBy: updated.repaired_photo_uploaded_by,
        },
      });
    } catch (err) {
      console.error("❌ Repaired photo upload failed:", err && err.stack ? err.stack : err);
      return res.status(500).json({
        error: "Failed to process repaired photo",
        details: process.env.NODE_ENV === "development" ? err?.message || err : undefined,
      });
    }
  }
);

// PATCH /api/tickets/:id  (update ticket)
router.patch("/tickets/:id", authMiddleware, async (req, res) => {
  if (!pool || typeof pool.query !== "function") {
    return res.status(500).json({ error: "Database not available" });
  }

  try {
    const { id } = req.params;
    const { provided: notesProvided, notes } = parseNotesPayload(req.body?.notes);
    const actingIdentity = identityFromBody(req.body) || extractWorkerIdentity(req.user);
    const workAction = req.body?.work_action || null;
    const workNotes = req.body?.work_notes || null;
    const workedAt = req.body?.worked_at || req.body?.last_worked_at || null;
    const status = req.body?.status;
    const deliveryPhoto1 = req.body?.delivery_photo_1;
    const deliveryPhoto2 = req.body?.delivery_photo_2;
    const assignedTechnician = req.body?.assigned_technician;
    const assignedTechnicianEmail = req.body?.assigned_technician_email;
    const assignedTo = req.body?.assigned_to;
    const assignedToEmail = req.body?.assigned_to_email;

    const result = await updateTicketWithWorklog({
      id,
      status,
      notes,
      notesProvided,
      deliveryPhoto1,
      deliveryPhoto2,
      assignedTechnician,
      assignedTechnicianEmail,
      assignedTo,
      assignedToEmail,
      actingIdentity,
      workAction,
      workNotes,
      workedAt,
    });

    if (result.rowCount === 0) return res.status(404).json({ error: "Ticket not found" });
    return res.json({ success: true, ticket: result.rows[0] });
  } catch (err) {
    console.error("❌ Error updating ticket:", err && err.stack ? err.stack : err);
    return res.status(500).json({ error: "Failed to update ticket", details: process.env.NODE_ENV === "development" ? (err.message || err) : undefined });
  }
});

// POST /api/tickets/:id/update (multipart) - used to upload delivery photo
router.post("/tickets/:id/update", authMiddleware, upload.single("delivery_photo_2"), async (req, res) => {
  if (!pool || typeof pool.query !== "function") {
    return res.status(500).json({ error: "Database not available" });
  }

  try {
    const { id } = req.params;
    const status = req.body?.status;
    const { provided: notesProvided, notes } = parseNotesPayload(req.body?.notes);
    let delivery_photo_2 = null;

    if (req.file) {
      const host = req.get("host") || process.env.EXPOSED_HOST || "localhost:5000";
      delivery_photo_2 = `${req.protocol}://${host}/uploads/${req.file.filename}`;
      console.log(`📸 Uploaded photo for ticket ${id}: ${delivery_photo_2}`);
    }

    const actingIdentity = identityFromBody(req.body) || extractWorkerIdentity(req.user);
    const workAction = req.body?.work_action || (delivery_photo_2 ? "delivery_photo" : null);
    const workNotes = req.body?.work_notes || null;
    const workedAt = req.body?.worked_at || req.body?.last_worked_at || null;

    const result = await updateTicketWithWorklog({
      id,
      status,
      notes,
      notesProvided,
      deliveryPhoto2: delivery_photo_2,
      actingIdentity,
      workAction,
      workNotes,
      workedAt,
    });

    if (result.rowCount === 0) return res.status(404).json({ error: "Ticket not found" });
    return res.json({ success: true, ticket: result.rows[0] });
  } catch (err) {
    console.error("❌ Multipart update error:", err && err.stack ? err.stack : err);
    return res.status(500).json({ error: "Failed to update ticket (multipart)", details: process.env.NODE_ENV === "development" ? (err.message || err) : undefined });
  }
});

module.exports = router;
