const express = require("express");
const ExcelJS = require("exceljs");
const router = express.Router();
const pool = require("./db");

router.use((req, res, next) => {
  console.log(`[khatabook router] ${req.method} ${req.path}`);
  next();
});

function mapEntry(row) {
  return {
    id: row.id,
    name: row.name || "",
    mobile: row.mobile || "",
    amount: row.amount !== null && row.amount !== undefined ? Number(row.amount) : 0,
    paid: row.paid !== null && row.paid !== undefined ? Number(row.paid) : 0,
    description: row.description || "",
    note: row.note || "",
    entryDate: row.entry_date ? row.entry_date.toISOString() : null,
    createdAt: row.created_at ? row.created_at.toISOString() : null,
    updatedAt: row.updated_at ? row.updated_at.toISOString() : null,
  };
}

function normalizeDate(value) {
  if (!value) return new Date();
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return new Date();
  }
  return date;
}

function sanitizeNumber(value, fallback = 0) {
  if (value === null || value === undefined) return fallback;
  const num = typeof value === "string" ? Number(value.replace(/,/g, "")) : Number(value);
  if (!Number.isFinite(num)) return fallback;
  return num;
}

router.get("/khatabook", async (req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT id, name, mobile, amount, paid, description, note, entry_date, created_at, updated_at
         FROM khatabook_entries
         ORDER BY entry_date DESC, id DESC`
    );
    return res.json({ entries: rows.map(mapEntry) });
  } catch (err) {
    console.error("GET /khatabook error", err);
    return res.status(500).json({ error: "LIST_FAILED" });
  }
});

router.post("/khatabook", async (req, res) => {
  try {
    const body = req.body || {};
    const name = (body.name || body.manual_name || "").trim();
    if (!name) {
      return res.status(400).json({ error: "NAME_REQUIRED" });
    }

    const amount = sanitizeNumber(body.amount ?? body.manual_amount, 0);
    if (amount < 0) {
      return res.status(400).json({ error: "AMOUNT_INVALID" });
    }

    const paid = sanitizeNumber(body.paid ?? body.manual_paid ?? 0, 0);
    if (paid < 0 || paid > amount) {
      return res.status(400).json({ error: "PAID_INVALID" });
    }

    const entryDate = normalizeDate(body.entryDate || body.manual_date || new Date());
    const { rows } = await pool.query(
      `INSERT INTO khatabook_entries (name, mobile, amount, paid, description, note, entry_date)
       VALUES ($1,$2,$3,$4,$5,$6,$7)
       RETURNING id, name, mobile, amount, paid, description, note, entry_date, created_at, updated_at`,
      [
        name,
        (body.mobile || body.manual_mobile || null) || null,
        amount,
        paid,
        body.description || body.manual_description || null,
        body.note || body.manual_note || null,
        entryDate.toISOString().slice(0, 10),
      ]
    );

    return res.status(201).json({ entry: mapEntry(rows[0]) });
  } catch (err) {
    console.error("POST /khatabook error", err);
    return res.status(500).json({ error: "CREATE_FAILED" });
  }
});

router.patch("/khatabook/:id", async (req, res) => {
  const id = Number.parseInt(req.params.id, 10);
  if (!Number.isFinite(id)) {
    return res.status(400).json({ error: "INVALID_ID" });
  }

  const body = req.body || {};

  try {
    const existingRes = await pool.query(
      `SELECT id, name, mobile, amount, paid, description, note, entry_date, created_at, updated_at
         FROM khatabook_entries
        WHERE id = $1`,
      [id]
    );

    if (existingRes.rowCount === 0) {
      return res.status(404).json({ error: "NOT_FOUND" });
    }

    const current = existingRes.rows[0];

    let nextName = current.name || "";
    let nextMobile = current.mobile || null;
    let nextAmount = sanitizeNumber(current.amount, 0);
    let nextPaid = sanitizeNumber(current.paid, 0);
    let nextDescription = current.description || null;
    let nextNote = current.note || null;
    let nextEntryDate = normalizeDate(current.entry_date || current.entryDate || new Date());

    let changed = false;

    if (body.name !== undefined || body.manual_name !== undefined) {
      const name = (body.name || body.manual_name || "").trim();
      if (!name) return res.status(400).json({ error: "NAME_REQUIRED" });
      nextName = name;
      changed = true;
    }

    if (body.mobile !== undefined || body.manual_mobile !== undefined) {
      const mobile = (body.mobile || body.manual_mobile || "").trim();
      nextMobile = mobile || null;
      changed = true;
    }

    if (body.amount !== undefined || body.manual_amount !== undefined) {
      const amount = sanitizeNumber(body.amount ?? body.manual_amount, 0);
      if (amount < 0) return res.status(400).json({ error: "AMOUNT_INVALID" });
      nextAmount = amount;
      changed = true;
    }

    if (body.paid !== undefined || body.manual_paid !== undefined) {
      const paid = sanitizeNumber(body.paid ?? body.manual_paid, 0);
      if (paid < 0) return res.status(400).json({ error: "PAID_INVALID" });
      nextPaid = paid;
      changed = true;
    }

    if (body.description !== undefined || body.manual_description !== undefined) {
      nextDescription = (body.description || body.manual_description || "").trim() || null;
      changed = true;
    }

    if (body.note !== undefined || body.manual_note !== undefined) {
      nextNote = (body.note || body.manual_note || "").trim() || null;
      changed = true;
    }

    if (body.entryDate !== undefined || body.manual_date !== undefined) {
      nextEntryDate = normalizeDate(body.entryDate || body.manual_date);
      changed = true;
    }

    if (nextPaid > nextAmount) {
      return res.status(400).json({ error: "PAID_TOO_HIGH" });
    }

    if (!changed) {
      return res.json({ entry: mapEntry(current) });
    }

    const { rows } = await pool.query(
      `UPDATE khatabook_entries
         SET name = $1,
             mobile = $2,
             amount = $3,
             paid = $4,
             description = $5,
             note = $6,
             entry_date = $7,
             updated_at = now()
       WHERE id = $8
       RETURNING id, name, mobile, amount, paid, description, note, entry_date, created_at, updated_at`,
      [
        nextName,
        nextMobile,
        nextAmount,
        nextPaid,
        nextDescription,
        nextNote,
        nextEntryDate.toISOString().slice(0, 10),
        id,
      ]
    );

    return res.json({ entry: mapEntry(rows[0]) });
  } catch (err) {
    console.error("PATCH /khatabook/:id error", err);
    return res.status(500).json({ error: "UPDATE_FAILED" });
  }
});

router.delete("/khatabook/:id", async (req, res) => {
  const id = Number.parseInt(req.params.id, 10);
  if (!Number.isFinite(id)) {
    return res.status(400).json({ error: "INVALID_ID" });
  }
  try {
    const { rowCount } = await pool.query("DELETE FROM khatabook_entries WHERE id = $1", [id]);
    if (rowCount === 0) return res.status(404).json({ error: "NOT_FOUND" });
    return res.json({ success: true });
  } catch (err) {
    console.error("DELETE /khatabook/:id error", err);
    return res.status(500).json({ error: "DELETE_FAILED" });
  }
});

module.exports = router;
