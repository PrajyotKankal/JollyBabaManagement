const express = require("express");
const ExcelJS = require("exceljs");
const router = express.Router();
const pool = require("./db");

console.log("[khatabook router] module loaded – export handler active");

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

function trimText(value) {
  return (value ?? "").toString().trim();
}

function digitsOnly(value) {
  return (value ?? "").toString().replace(/\D+/g, "");
}

function parsePaidFromRemarks(remarks) {
  if (!remarks) return 0;
  const match = /Paid\s*:?.*?₹?\s*([0-9][0-9,]*(?:\.[0-9]+)?)/i.exec(remarks);
  if (!match) return 0;
  const cleaned = match[1].replace(/,/g, "");
  const parsed = Number.parseFloat(cleaned);
  return Number.isFinite(parsed) ? parsed : 0;
}

function resolveDate(...values) {
  for (const value of values) {
    if (!value) continue;
    const date = value instanceof Date ? value : new Date(value);
    if (!Number.isNaN(date.getTime())) {
      return date;
    }
  }
  return new Date();
}

function clampAmount(total, paid) {
  let safeTotal = Number.isFinite(total) ? total : 0;
  let safePaid = Number.isFinite(paid) ? paid : 0;
  if (safePaid < 0) safePaid = 0;
  if (safePaid > safeTotal) safePaid = safeTotal;
  return safePaid;
}

function toEntryStatus(remaining) {
  return remaining <= 0.0001 ? "Settled" : "Pending";
}

function buildManualEntry(row) {
  const name = trimText(row.name) || "Unknown";
  const mobile = trimText(row.mobile);
  const total = sanitizeNumber(row.amount, 0);
  const paidRaw = sanitizeNumber(row.paid, 0);
  const paid = clampAmount(total, paidRaw);
  const remaining = Math.max(0, total - paid);
  const entryDate = resolveDate(row.entry_date, row.updated_at, row.created_at);
  const item = trimText(row.description) || "Manual entry";
  const notes = trimText(row.note);

  return {
    type: "Manual",
    name,
    mobile,
    entryDate,
    total,
    paid,
    remaining,
    status: toEntryStatus(remaining),
    item,
    srNo: "",
    imei: "",
    notes,
  };
}

function buildSaleEntry(row) {
  const name = trimText(row.customer_name) || "Customer";
  const mobile = trimText(row.mobile_number);
  const total = sanitizeNumber(row.sell_amount, 0);
  const paidRaw = parsePaidFromRemarks(row.remarks);
  const paid = clampAmount(total, paidRaw);
  const remaining = Math.max(0, total - paid);
  const entryDate = resolveDate(row.sell_date, row.updated_at, row.created_at, row.date);
  const model = trimText(row.model);
  const variant = trimText(row.variant_gb_color);
  const itemParts = [];
  if (model) itemParts.push(model);
  if (variant) itemParts.push(variant);
  const item = itemParts.length ? `Sale • ${itemParts.join(" • ")}` : `Sale • SR ${row.sr_no}`;
  const notes = trimText(row.remarks);
  const srNo = row.sr_no !== null && row.sr_no !== undefined ? String(row.sr_no) : "";
  const imei = trimText(row.imei);

  return {
    type: "Sale",
    name,
    mobile,
    entryDate,
    total,
    paid,
    remaining,
    status: toEntryStatus(remaining),
    item,
    srNo,
    imei,
    notes,
  };
}

function combineEntries(manualRows, soldRows) {
  const manualEntries = manualRows.map(buildManualEntry);
  const saleEntries = soldRows.map(buildSaleEntry);
  const combined = [...manualEntries, ...saleEntries];
  combined.sort((a, b) => b.entryDate - a.entryDate);
  return combined;
}

function groupEntriesForCustomers(entries) {
  const groups = new Map();
  let orphanCounter = 0;

  for (const entry of entries) {
    const digits = digitsOnly(entry.mobile);
    const nameKey = trimText(entry.name).toLowerCase();
    let key = digits || nameKey;
    if (!key) {
      key = `orphan-${orphanCounter++}`;
    }

    if (!groups.has(key)) {
      groups.set(key, {
        entries: [],
        displayMobile: digits ? entry.mobile : "",
        nameCounts: new Map(),
        totalAmount: 0,
        totalPaid: 0,
        totalRemaining: 0,
        latestDate: null,
      });
    }

    const group = groups.get(key);
    group.entries.push(entry);
    const trimmedName = trimText(entry.name);
    if (trimmedName) {
      group.nameCounts.set(trimmedName, (group.nameCounts.get(trimmedName) || 0) + 1);
    }
    if (digits && !group.displayMobile) {
      group.displayMobile = entry.mobile;
    }
    group.totalAmount += entry.total;
    group.totalPaid += entry.paid;
    group.totalRemaining += entry.remaining;
    if (!group.latestDate || (entry.entryDate && entry.entryDate > group.latestDate)) {
      group.latestDate = entry.entryDate;
    }
  }

  return Array.from(groups.values()).map((group) => {
    let chosenName = "Unknown";
    if (group.nameCounts.size > 0) {
      const sorted = Array.from(group.nameCounts.entries()).sort((a, b) => {
        if (b[1] !== a[1]) return b[1] - a[1];
        return a[0].localeCompare(b[0]);
      });
      chosenName = sorted[0][0];
    } else if (group.entries.length > 0) {
      chosenName = trimText(group.entries[0].name) || "Unknown";
    }

    const allSettled = group.entries.every((entry) => entry.status === "Settled");

    return {
      name: chosenName,
      displayMobile: group.displayMobile,
      entries: group.entries,
      totalAmount: group.totalAmount,
      totalPaid: group.totalPaid,
      totalRemaining: group.totalRemaining,
      status: allSettled ? "Settled" : "Pending",
      latestDate: group.latestDate,
      count: group.entries.length,
    };
  });
}

function summarizeByStatus(entries) {
  const base = {
    Pending: { count: 0, total: 0, paid: 0, outstanding: 0 },
    Settled: { count: 0, total: 0, paid: 0, outstanding: 0 },
  };

  for (const entry of entries) {
    const bucket = base[entry.status] || base.Pending;
    bucket.count += 1;
    bucket.total += entry.total;
    bucket.paid += entry.paid;
    bucket.outstanding += entry.remaining;
  }

  return base;
}

function toFixedNumber(value) {
  return Number.isFinite(value) ? Number(value.toFixed(2)) : 0;
}

function formatDate(value) {
  if (!value) return "";
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) return "";
  return date.toISOString().slice(0, 10);
}

function buildWorkbook(entries) {
  const workbook = new ExcelJS.Workbook();
  const now = new Date();
  workbook.created = now;
  workbook.modified = now;

  const summarySheet = workbook.addWorksheet("Summary");
  summarySheet.columns = [
    { header: "Status", key: "status", width: 14 },
    { header: "Entries", key: "entries", width: 12 },
    { header: "Total Amount", key: "totalAmount", width: 18, style: { numFmt: "#,##0.00" } },
    { header: "Amount Paid", key: "amountPaid", width: 18, style: { numFmt: "#,##0.00" } },
    { header: "Outstanding", key: "outstanding", width: 18, style: { numFmt: "#,##0.00" } },
  ];

  const summaries = summarizeByStatus(entries);
  for (const status of ["Pending", "Settled"]) {
    const bucket = summaries[status] || { count: 0, total: 0, paid: 0, outstanding: 0 };
    summarySheet.addRow({
      status,
      entries: bucket.count,
      totalAmount: toFixedNumber(bucket.total),
      amountPaid: toFixedNumber(bucket.paid),
      outstanding: toFixedNumber(bucket.outstanding),
    });
  }

  const customersSheet = workbook.addWorksheet("Customers");
  customersSheet.columns = [
    { header: "Customer Name", key: "name", width: 28 },
    { header: "Mobile", key: "mobile", width: 18 },
    { header: "Entries", key: "entries", width: 10 },
    { header: "Total Amount", key: "totalAmount", width: 16, style: { numFmt: "#,##0.00" } },
    { header: "Amount Paid", key: "amountPaid", width: 16, style: { numFmt: "#,##0.00" } },
    { header: "Outstanding", key: "outstanding", width: 16, style: { numFmt: "#,##0.00" } },
    { header: "Status", key: "status", width: 12 },
    { header: "Last Entry Date", key: "lastDate", width: 16 },
  ];

  const customerGroups = groupEntriesForCustomers(entries);
  for (const group of customerGroups) {
    customersSheet.addRow({
      name: group.name,
      mobile: group.displayMobile,
      entries: group.count,
      totalAmount: toFixedNumber(group.totalAmount),
      amountPaid: toFixedNumber(group.totalPaid),
      outstanding: toFixedNumber(group.totalRemaining),
      status: group.status,
      lastDate: formatDate(group.latestDate),
    });
  }

  const entriesSheet = workbook.addWorksheet("Entries");
  entriesSheet.columns = [
    { header: "Date", key: "date", width: 14 },
    { header: "Customer Name", key: "name", width: 26 },
    { header: "Mobile", key: "mobile", width: 18 },
    { header: "Pending/Settled", key: "status", width: 16 },
    { header: "Entry Type", key: "type", width: 12 },
    { header: "Item / Model", key: "item", width: 30 },
    { header: "SR No", key: "srNo", width: 12 },
    { header: "IMEI", key: "imei", width: 20 },
    { header: "Total Amount", key: "totalAmount", width: 16, style: { numFmt: "#,##0.00" } },
    { header: "Amount Paid", key: "amountPaid", width: 16, style: { numFmt: "#,##0.00" } },
    { header: "Outstanding", key: "outstanding", width: 16, style: { numFmt: "#,##0.00" } },
    { header: "Notes", key: "notes", width: 40 },
  ];

  for (const entry of entries) {
    entriesSheet.addRow({
      date: formatDate(entry.entryDate),
      name: trimText(entry.name) || "Unknown",
      mobile: trimText(entry.mobile),
      status: entry.status,
      type: entry.type,
      item: entry.item || "-",
      srNo: entry.srNo || "",
      imei: entry.imei || "",
      totalAmount: toFixedNumber(entry.total),
      amountPaid: toFixedNumber(entry.paid),
      outstanding: toFixedNumber(entry.remaining),
      notes: entry.notes || "",
    });
  }

  return workbook;
}

async function fetchManualEntriesForExport() {
  const { rows } = await pool.query(
    `SELECT id, name, mobile, amount, paid, description, note, entry_date, created_at, updated_at
       FROM khatabook_entries
       ORDER BY entry_date DESC NULLS LAST, id DESC`
  );
  return rows;
}

async function fetchSoldEntriesForExport() {
  const { rows } = await pool.query(
    `SELECT sr_no, customer_name, mobile_number, sell_amount::float AS sell_amount, remarks,
            model, variant_gb_color, imei, sell_date, date, created_at, updated_at
       FROM inventory_items
      WHERE status = 'SOLD'`
  );
  return rows;
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

router.get("/khatabook/export", async (req, res) => {
  try {
    const [manualRows, soldRows] = await Promise.all([
      fetchManualEntriesForExport(),
      fetchSoldEntriesForExport(),
    ]);

    console.log(
      `[khatabook export] fetched ${manualRows.length} manual entries and ${soldRows.length} sold entries`
    );

    const entries = combineEntries(manualRows, soldRows);
    const workbook = buildWorkbook(entries);
    const timestamp = new Date().toISOString().replace(/[-:T]/g, "").slice(0, 14);

    console.log(`[khatabook export] building workbook with ${entries.length} combined rows`);

    res.setHeader(
      "Content-Type",
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    );
    res.setHeader(
      "Content-Disposition",
      `attachment; filename="khatabook-${timestamp}.xlsx"`
    );

    await workbook.xlsx.write(res);
    console.log("[khatabook export] workbook stream complete");
    res.end();
  } catch (err) {
    console.error("GET /khatabook/export error", err);
    if (!res.headersSent) {
      res.status(500).json({ error: "EXPORT_FAILED" });
    } else {
      res.end();
    }
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
