// src/inventory.js
const express = require('express');
const router = express.Router();

// Debug middleware to log all requests to inventory routes
router.use((req, res, next) => {
  console.log(`[inventory router] ${req.method} ${req.path}`);
  next();
});
const pool = require('./db');

function normalizeWhitespace(value) {
  return (value || '')
    .toString()
    .trim()
    .replace(/\s+/g, ' ');
}

async function ensureSalespersonColumn() {
  if (!pool || typeof pool.query !== 'function') return;
  try {
    await pool.query(`ALTER TABLE inventory_items ADD COLUMN IF NOT EXISTS salesperson_name TEXT;`);
  } catch (err) {
    console.warn('⚠️ ensureSalespersonColumn failed (continuing):', err && err.stack ? err.stack : err);
  }
}

function toNameKey(name) {
  return normalizeWhitespace(name).toLowerCase();
}

function toPhoneDigits(phone) {
  return (phone || '').toString().replace(/\D+/g, '');
}

async function upsertCustomerRecord({ name, phone, address, lastPurchaseAt }, client) {
  const trimmedName = normalizeWhitespace(name);
  if (!trimmedName) return;

  const nameKey = toNameKey(trimmedName);
  const digits = toPhoneDigits(phone);
  const safeDigits = digits || '';
  const purchaseDate = lastPurchaseAt || null;

  const executor = client || pool;
  await executor.query(
    `
      INSERT INTO customers (name, name_key, phone, phone_digits, address, last_purchase_at, created_at, updated_at)
      VALUES ($1, $2, $3, $4, NULLIF($5, ''), COALESCE($6::timestamp, now()), now(), now())
      ON CONFLICT (name_key, phone_digits)
      DO UPDATE SET
        name = EXCLUDED.name,
        phone = EXCLUDED.phone,
        address = COALESCE(NULLIF(EXCLUDED.address, ''), customers.address),
        last_purchase_at = COALESCE($6::timestamp, now()),
        updated_at = now();
    `,
    [
      trimmedName,
      nameKey,
      phone || null,
      safeDigits,
      normalizeWhitespace(address),
      purchaseDate,
    ]
  );
}

function toNumericAmount(value) {
  if (value === null || value === undefined) return 0;
  if (typeof value === 'number') return Number(value) || 0;
  const cleaned = value.toString().replace(/,/g, '').trim();
  const parsed = Number.parseFloat(cleaned);
  return Number.isFinite(parsed) ? parsed : 0;
}

function extractPaidAmountFromRemarks(remarks) {
  if (!remarks) return 0;
  const match = /Paid\s*:?.*?₹?\s*([0-9][0-9,]*(?:\.[0-9]+)?)/i.exec(remarks);
  if (!match) return 0;
  const cleaned = match[1].replace(/,/g, '');
  const parsed = Number.parseFloat(cleaned);
  return Number.isFinite(parsed) ? parsed : 0;
}

async function createKhatabookEntryForSale(client, { srNo, item, payload }) {
  const amount = toNumericAmount(payload.sellAmount);
  if (amount <= 0) return null;

  const name = normalizeWhitespace(payload.customerName) || 'Customer';
  const mobile = normalizeWhitespace(payload.mobileNumber) || null;
  const remarks = normalizeWhitespace(payload.remarks);
  const paid = extractPaidAmountFromRemarks(remarks);
  const remaining = Math.max(0, amount - paid);
  const entryDate = normalizeWhitespace(payload.sellDate) || new Date().toISOString().slice(0, 10);

  const descriptorParts = [];
  if (item.model) descriptorParts.push(normalizeWhitespace(item.model));
  if (item.variant_gb_color) descriptorParts.push(normalizeWhitespace(item.variant_gb_color));
  const description = descriptorParts.length ? `Sale • ${descriptorParts.join(' • ')}` : `Sale • SR ${srNo}`;

  const noteParts = [];
  if (item.imei) noteParts.push(`IMEI: ${item.imei}`);
  if (payload.customerAddress) noteParts.push(`Address: ${normalizeWhitespace(payload.customerAddress)}`);
  if (remarks) noteParts.push(remarks);
  if (remaining > 0.0001) noteParts.push(`Remaining: ₹${remaining.toFixed(2)}`);
  noteParts.push(`SR No: ${srNo}`);
  const note = noteParts.map((p) => normalizeWhitespace(p)).filter((p) => p && p.length).join(' | ');

  const { rows } = await client.query(
    `
      INSERT INTO khatabook_entries (name, mobile, amount, paid, description, note, entry_date)
      VALUES ($1, $2, $3, $4, $5, NULLIF($6, ''), $7)
      RETURNING id
    `,
    [name, mobile, amount, paid, description, note, entryDate]
  );

  return rows[0] ? rows[0].id : null;
}

function toCsv(rows) {
  if (!rows || rows.length === 0) return '';
  const headers = Object.keys(rows[0]);
  const escape = (v) => {
    if (v === null || v === undefined) return '';
    const s = String(v);
    if (/[",\n]/.test(s)) return '"' + s.replace(/"/g, '""') + '"';
    return s;
  };
  const lines = [];
  lines.push(headers.join(','));
  for (const r of rows) lines.push(headers.map((h) => escape(r[h])).join(','));
  return lines.join('\n');
}

function buildWhere({ q, status, vendor, from, to, brand }) {
  const where = [];
  const params = [];
  if (q && q.trim()) {
    params.push(`%${q.trim().toLowerCase()}%`);
    where.push('(LOWER(imei) LIKE $' + params.length + ' OR LOWER(model) LIKE $' + params.length + ')');
  }
  if (status && status.trim()) {
    params.push(status.trim());
    where.push('status = $' + params.length);
  }
  if (vendor && vendor.trim()) {
    params.push('%' + vendor.trim().toLowerCase() + '%');
    where.push('LOWER(vendor_purchase) LIKE $' + params.length);
  }
  if (brand && brand.trim()) {
    params.push(brand.trim());
    where.push('brand = $' + params.length);
  }
  if (from) {
    params.push(from);
    where.push('date >= $' + params.length);
  }
  if (to) {
    params.push(to);
    where.push('date <= $' + params.length);
  }
  return { where: where.length ? 'WHERE ' + where.join(' AND ') : '', params };
}

router.get('/customers/search', async (req, res) => {
  const raw = (req.query.q || '').toString();
  const query = raw.trim();
  if (query.length < 2) {
    return res.json({ customers: [] });
  }

  try {
    const lower = query.toLowerCase();
    const nameKeyLike = `%${toNameKey(query)}%`;
    const nameLike = `%${lower}%`;
    const phoneDigits = toPhoneDigits(query);

    const filters = ['LOWER(name) LIKE $1', 'name_key LIKE $2'];
    const params = [nameLike, nameKeyLike];
    if (phoneDigits) {
      filters.push('phone_digits LIKE $3');
      params.push(`%${phoneDigits}%`);
    }

    const sql = `
      SELECT id, name, phone, email, address, last_purchase_at
      FROM customers
      WHERE ${filters.join(' OR ')}
      ORDER BY last_purchase_at DESC NULLS LAST, updated_at DESC
      LIMIT 10
    `;

    const { rows } = await pool.query(sql, params);
    return res.json({ customers: rows });
  } catch (err) {
    console.error('GET /customers/search error', err);
    return res.status(500).json({ error: 'CUSTOMER_SEARCH_FAILED' });
  }
});

router.get('/vendors/search', async (req, res) => {
  const raw = (req.query.q || '').toString();
  const query = raw.trim();
  if (query.length < 2) {
    return res.json({ vendors: [] });
  }

  try {
    const like = `%${query}%`;
    const digits = toPhoneDigits(query);
    const conditions = ['vendor_purchase ILIKE $1', "COALESCE(vendor_phone, '') ILIKE $2"];
    const params = [like, like];
    if (digits) {
      params.push(`%${digits}%`);
      conditions.push("regexp_replace(COALESCE(vendor_phone,''), '\\\\D','','g') LIKE $" + params.length);
    }

    const sql = `
      SELECT vendor_purchase AS name,
             COALESCE(vendor_phone, '') AS phone,
             COUNT(*) AS total,
             MAX(updated_at) AS last_used
      FROM inventory_items
      WHERE vendor_purchase IS NOT NULL
        AND (${conditions.join(' OR ')})
      GROUP BY vendor_purchase, vendor_phone
      ORDER BY last_used DESC NULLS LAST, total DESC
      LIMIT 10
    `;

    const { rows } = await pool.query(sql, params);
    return res.json({ vendors: rows });
  } catch (err) {
    console.error('GET /vendors/search error', err);
    return res.status(500).json({ error: 'VENDOR_SEARCH_FAILED' });
  }
});

router.get('/inventory', async (req, res) => {
  try {
    const { q, status, vendor, from, to, brand, sort = 'date', order = 'desc' } = req.query;
    const { where, params } = buildWhere({ q, status, vendor, from, to, brand });
    const sortCol = sort === 'price' ? 'purchase_amount' : 'date';
    const sortOrder = String(order).toLowerCase() === 'asc' ? 'ASC' : 'DESC';

    const { rows } = await pool.query(
      `SELECT sr_no,
              to_char(date,'YYYY-MM-DD') as date,
              brand,
              model,
              imei,
              variant_gb_color,
              vendor_purchase,
              vendor_phone,
              purchase_amount::float,
              to_char(sell_date,'YYYY-MM-DD') as sell_date,
              sell_amount::float,
              customer_name,
              mobile_number,
              remarks,
              status,
              khatabook_entry_id
         FROM inventory_items ${where}
         ORDER BY ${sortCol} ${sortOrder}, sr_no DESC`,
      params
    );

    // counts
    const countsRes = await pool.query(
      `SELECT 
          COUNT(*) FILTER (WHERE status='AVAILABLE') as available,
          COUNT(*) FILTER (WHERE status='SOLD') as sold,
          COUNT(*) as total
       FROM inventory_items ${where}`,
      params
    );

    // visible index for AVAILABLE only in current filter order
    const visibleIndex = {};
    let idx = 1;
    for (const r of rows) {
      if (r.status === 'AVAILABLE') visibleIndex[String(r.sr_no)] = idx++;
    }

    return res.json({ items: rows, counts: countsRes.rows, visibleIndex });
  } catch (e) {
    console.error('GET /inventory error', e);
    return res.status(500).json({ error: 'LIST_FAILED' });
  }
});

// Update inventory item fields (allowed whitelist)
console.log('[inventory.js] Registering PATCH /inventory/:srNo route');
router.patch('/inventory/:srNo', async (req, res) => {
  const srNo = parseInt(req.params.srNo, 10);
  const body = req.body || {};
  const allowed = {
    date: 'date',
    brand: 'brand',
    model: 'model',
    imei: 'imei',
    variantGbColor: 'variant_gb_color',
    vendorPurchase: 'vendor_purchase',
    vendorPhone: 'vendor_phone',
    purchaseAmount: 'purchase_amount',
    remarks: 'remarks',
    customerName: 'customer_name',
    mobileNumber: 'mobile_number',
    sellDate: 'sell_date',
    sellAmount: 'sell_amount',
  };
  const sets = [];
  const params = [];
  for (const k of Object.keys(allowed)) {
    if (Object.prototype.hasOwnProperty.call(body, k)) {
      sets.push(`${allowed[k]} = $${sets.length + 1}`);
      params.push(body[k]);
    }
  }
  if (sets.length === 0) return res.status(400).json({ error: 'NO_FIELDS' });
  params.push(srNo);
  try {
    const { rowCount } = await pool.query(
      `UPDATE inventory_items SET ${sets.join(', ')}, updated_at=now() WHERE sr_no=$${params.length}`,
      params
    );
    if (rowCount === 0) return res.status(404).json({ error: 'NOT_FOUND' });
    return res.json({ success: true });
  } catch (e) {
    console.error('PATCH /inventory/:srNo error', e);
    return res.status(500).json({ error: 'UPDATE_FAILED' });
  }
});

// Alias for environments that block PATCH
router.put('/inventory/:srNo', async (req, res) => {
  const srNo = parseInt(req.params.srNo, 10);
  const body = req.body || {};
  const allowed = {
    date: 'date',
    brand: 'brand',
    model: 'model',
    imei: 'imei',
    variantGbColor: 'variant_gb_color',
    vendorPurchase: 'vendor_purchase',
    purchaseAmount: 'purchase_amount',
    remarks: 'remarks',
    customerName: 'customer_name',
    mobileNumber: 'mobile_number',
    sellDate: 'sell_date',
    sellAmount: 'sell_amount',
  };
  const sets = [];
  const params = [];
  for (const k of Object.keys(allowed)) {
    if (Object.prototype.hasOwnProperty.call(body, k)) {
      sets.push(`${allowed[k]} = $${sets.length + 1}`);
      params.push(body[k]);
    }
  }
  if (sets.length === 0) return res.status(400).json({ error: 'NO_FIELDS' });
  params.push(srNo);
  try {
    const { rowCount } = await pool.query(
      `UPDATE inventory_items SET ${sets.join(', ')}, updated_at=now() WHERE sr_no=$${params.length}`,
      params
    );
    if (rowCount === 0) return res.status(404).json({ error: 'NOT_FOUND' });
    return res.json({ success: true });
  } catch (e) {
    console.error('PUT /inventory/:srNo error', e);
    return res.status(500).json({ error: 'UPDATE_FAILED' });
  }
});

// Explicit POST alias .../update
router.post('/inventory/:srNo/update', async (req, res) => {
  const srNo = parseInt(req.params.srNo, 10);
  const body = req.body || {};
  const allowed = {
    date: 'date',
    brand: 'brand',
    model: 'model',
    imei: 'imei',
    variantGbColor: 'variant_gb_color',
    vendorPurchase: 'vendor_purchase',
    purchaseAmount: 'purchase_amount',
    remarks: 'remarks',
    customerName: 'customer_name',
    mobileNumber: 'mobile_number',
    sellDate: 'sell_date',
    sellAmount: 'sell_amount',
  };
  const sets = [];
  const params = [];
  for (const k of Object.keys(allowed)) {
    if (Object.prototype.hasOwnProperty.call(body, k)) {
      sets.push(`${allowed[k]} = $${sets.length + 1}`);
      params.push(body[k]);
    }
  }
  if (sets.length === 0) return res.status(400).json({ error: 'NO_FIELDS' });
  params.push(srNo);
  try {
    const { rowCount } = await pool.query(
      `UPDATE inventory_items SET ${sets.join(', ')}, updated_at=now() WHERE sr_no=$${params.length}`,
      params
    );
    if (rowCount === 0) return res.status(404).json({ error: 'NOT_FOUND' });
    return res.json({ success: true });
  } catch (e) {
    console.error('POST /inventory/:srNo/update error', e);
    return res.status(500).json({ error: 'UPDATE_FAILED' });
  }
});

router.post('/inventory', async (req, res) => {
  const c = req.body || {};
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const { rows } = await client.query(
      `INSERT INTO inventory_items (date, brand, model, imei, variant_gb_color, vendor_purchase, vendor_phone, purchase_amount, remarks, status, created_at, updated_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,'AVAILABLE', now(), now())
       RETURNING sr_no`,
      [
        c.date,
        c.brand || null,
        c.model,
        c.imei,
        c.variantGbColor || null,
        c.vendorPurchase || null,
        c.vendorPhone || null,
        c.purchaseAmount || 0,
        c.remarks || null,
      ]
    );
    await client.query('COMMIT');
    return res.json({ success: true, sr_no: rows[0].sr_no });
  } catch (e) {
    await client.query('ROLLBACK');
    if (String(e.message || '').toLowerCase().includes('unique')) {
      return res.status(409).json({ error: 'DUP_IMEI' });
    }
    console.error('POST /inventory error', e);
    return res.status(500).json({ error: 'CREATE_FAILED' });
  } finally {
    client.release();
  }
});

// Multi-add endpoint: create many AVAILABLE items in a single transaction
router.post('/inventory/add-multiple', async (req, res) => {
  const c = req.body || {};
  const items = Array.isArray(c.items) ? c.items : [];

  if (!items.length) {
    return res.status(400).json({ error: 'NO_ITEMS_PROVIDED' });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const srNos = [];
    for (const row of items) {
      const r = row || {};
      const date = r.date || c.date || new Date().toISOString().slice(0, 10);
      const brand = r.brand || null;
      const model = r.model;
      const imei = r.imei;
      const variantGbColor = r.variantGbColor || null;
      const vendorPurchase = r.vendorPurchase || c.vendorPurchase || null;
      const vendorPhone = r.vendorPhone || c.vendorPhone || null;
      const purchaseAmount = r.purchaseAmount || c.purchaseAmount || 0;
      const remarks = r.remarks || c.remarks || null;

      if (!model || !imei) {
        await client.query('ROLLBACK');
        return res.status(400).json({ error: 'INVALID_ITEM', item: r });
      }

      try {
        const { rows } = await client.query(
          `INSERT INTO inventory_items (date, brand, model, imei, variant_gb_color, vendor_purchase, vendor_phone, purchase_amount, remarks, status, created_at, updated_at)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,'AVAILABLE', now(), now())
           RETURNING sr_no`,
          [
            date,
            brand,
            model,
            imei,
            variantGbColor,
            vendorPurchase,
            vendorPhone,
            purchaseAmount,
            remarks,
          ]
        );
        if (rows[0] && rows[0].sr_no !== undefined) {
          srNos.push(rows[0].sr_no);
        }
      } catch (e) {
        if (String(e.message || '').toLowerCase().includes('unique')) {
          await client.query('ROLLBACK');
          return res.status(409).json({ error: 'DUP_IMEI_IN_BATCH' });
        }
        throw e;
      }
    }

    await client.query('COMMIT');
    return res.json({ success: true, created: srNos.length, sr_nos: srNos });
  } catch (e) {
    await client.query('ROLLBACK');
    console.error('POST /inventory/add-multiple error', e);
    return res.status(500).json({ error: 'CREATE_MULTI_FAILED' });
  } finally {
    client.release();
  }
});

// Multi-sell endpoint: mark many AVAILABLE items as SOLD in a single sale
router.post('/inventory/sell-multiple', async (req, res) => {
  const c = req.body || {};
  const srNos = Array.isArray(c.srNos) ? c.srNos.map((n) => parseInt(n, 10)).filter((n) => Number.isInteger(n)) : [];

  if (!srNos.length) {
    return res.status(400).json({ error: 'NO_SR_NOS_PROVIDED' });
  }

  await ensureSalespersonColumn();
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const totalAmount = toNumericAmount(c.sellAmount);
    const perItemAmount = srNos.length > 0 ? totalAmount / srNos.length : 0;

    const updateRes = await client.query(
      `UPDATE inventory_items
         SET sell_date = $1,
             sell_amount = $2,
             customer_name = $3,
             mobile_number = $4,
             remarks = $5,
             salesperson_name = $6,
             status = 'SOLD',
             updated_at = now()
       WHERE sr_no = ANY($7::int[]) AND status = 'AVAILABLE'
       RETURNING sr_no, model, variant_gb_color, imei` ,
      [c.sellDate, perItemAmount, c.customerName || null, c.mobileNumber || null, c.remarks || null, c.salespersonName || null, srNos]
    );

    if (updateRes.rowCount === 0) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'NOT_AVAILABLE_OR_NOT_FOUND' });
    }

    const firstItem = updateRes.rows[0];
    const firstSrNo = firstItem.sr_no;
    let khatabookEntryId = null;

    try {
      // Use original payload so khatabook entry amount reflects total sale amount
      khatabookEntryId = await createKhatabookEntryForSale(client, {
        srNo: firstSrNo,
        item: firstItem,
        payload: c,
      });
      if (khatabookEntryId) {
        await client.query(
          'UPDATE inventory_items SET khatabook_entry_id = $1 WHERE sr_no = ANY($2::int[])',
          [khatabookEntryId, srNos]
        );
      }
    } catch (entryErr) {
      console.warn('POST /inventory/sell-multiple khatabook create failed', entryErr);
    }

    try {
      await upsertCustomerRecord(
        {
          name: c.customerName,
          phone: c.mobileNumber,
          address: c.customerAddress,
          lastPurchaseAt: c.sellDate,
        },
        client
      );
    } catch (customerErr) {
      console.warn('POST /inventory/sell-multiple customer upsert failed', customerErr);
    }

    await client.query('COMMIT');

    return res.json({ success: true, updated: updateRes.rowCount, khatabookEntryId: khatabookEntryId || null });
  } catch (e) {
    await client.query('ROLLBACK');
    console.error('POST /inventory/sell-multiple error', e);
    return res.status(500).json({ error: 'MULTI_SELL_FAILED' });
  } finally {
    client.release();
  }
});

router.post('/inventory/:srNo/sell', async (req, res) => {
  const srNo = parseInt(req.params.srNo, 10);
  const c = req.body || {};
  await ensureSalespersonColumn();
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const updateRes = await client.query(
      `UPDATE inventory_items
         SET sell_date = $1,
             sell_amount = $2,
             customer_name = $3,
             mobile_number = $4,
             remarks = $5,
             salesperson_name = $6,
             status = 'SOLD',
             updated_at = now()
       WHERE sr_no = $7 AND status = 'AVAILABLE'
       RETURNING sr_no, model, variant_gb_color, imei` ,
      [c.sellDate, c.sellAmount || 0, c.customerName || null, c.mobileNumber || null, c.remarks || null, c.salespersonName || null, srNo]
    );

    if (updateRes.rowCount === 0) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'NOT_AVAILABLE_OR_NOT_FOUND' });
    }

    const itemRow = updateRes.rows[0];
    let khatabookEntryId = null;

    try {
      khatabookEntryId = await createKhatabookEntryForSale(client, { srNo, item: itemRow, payload: c });
      if (khatabookEntryId) {
        await client.query('UPDATE inventory_items SET khatabook_entry_id = $1 WHERE sr_no = $2', [khatabookEntryId, srNo]);
      }
    } catch (entryErr) {
      console.warn('POST /inventory/:srNo/sell khatabook create failed', entryErr);
    }

    try {
      await upsertCustomerRecord(
        {
          name: c.customerName,
          phone: c.mobileNumber,
          address: c.customerAddress,
          lastPurchaseAt: c.sellDate,
        },
        client
      );
    } catch (customerErr) {
      console.warn('POST /inventory/:srNo/sell customer upsert failed', customerErr);
    }

    await client.query('COMMIT');

    return res.json({ success: true, khatabookEntryId: khatabookEntryId || null });
  } catch (e) {
    await client.query('ROLLBACK');
    console.error('POST /inventory/:srNo/sell error', e);
    return res.status(500).json({ error: 'SELL_FAILED' });
  } finally {
    client.release();
  }
});

router.post('/inventory/:srNo/make-available', async (req, res) => {
  const srNo = parseInt(req.params.srNo, 10);
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const currentRes = await client.query(
      `SELECT sr_no, status, remarks, khatabook_entry_id
         FROM inventory_items
        WHERE sr_no = $1
        FOR UPDATE`,
      [srNo]
    );

    if (currentRes.rowCount === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'NOT_FOUND' });
    }

    const current = currentRes.rows[0];
    if (current.status !== 'SOLD') {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'NOT_SOLD' });
    }

    let khatabookEntryDeleted = false;
    if (current.khatabook_entry_id) {
      try {
        const delRes = await client.query('DELETE FROM khatabook_entries WHERE id = $1', [current.khatabook_entry_id]);
        khatabookEntryDeleted = delRes.rowCount > 0;
      } catch (delErr) {
        console.warn('POST /inventory/:srNo/make-available khatabook delete failed', delErr);
      }
    }

    const cancellationNote = `Sale cancelled on ${new Date().toISOString().slice(0, 10)}`;
    const existingRemarks = normalizeWhitespace(current.remarks);
    const combinedRemarks = existingRemarks ? `${existingRemarks} | ${cancellationNote}` : cancellationNote;
    const nextRemarks = normalizeWhitespace(combinedRemarks) || null;

    const updateRes = await client.query(
      `UPDATE inventory_items
          SET sell_date = NULL,
              sell_amount = NULL,
              customer_name = NULL,
              mobile_number = NULL,
              remarks = $2,
              salesperson_name = NULL,
              status = 'AVAILABLE',
              khatabook_entry_id = NULL,
              updated_at = now()
        WHERE sr_no = $1
        RETURNING sr_no, status, remarks, sell_date, sell_amount, customer_name, mobile_number`,
      [srNo, nextRemarks]
    );

    await client.query('COMMIT');

    return res.json({ success: true, item: updateRes.rows[0], khatabookEntryDeleted });
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('POST /inventory/:srNo/make-available error', err);
    return res.status(500).json({ error: 'MAKE_AVAILABLE_FAILED' });
  } finally {
    client.release();
  }
});

router.patch('/inventory/:srNo/remarks', async (req, res) => {
  const srNo = parseInt(req.params.srNo, 10);
  const { remarks } = req.body || {};
  try {
    const { rowCount } = await pool.query(
      `UPDATE inventory_items SET remarks=$1, updated_at=now() WHERE sr_no=$2`,
      [remarks || null, srNo]
    );
    if (rowCount === 0) return res.status(404).json({ error: 'NOT_FOUND' });
    return res.json({ success: true });
  } catch (e) {
    console.error('PATCH /inventory/:srNo/remarks error', e);
    return res.status(500).json({ error: 'REMARKS_FAILED' });
  }
});

router.get('/inventory/export.csv', async (req, res) => {
  try {
    const { q, status, vendor, from, to, sort = 'date', order = 'desc' } = req.query;
    const { where, params } = buildWhere({ q, status, vendor, from, to });
    const sortCol = sort === 'price' ? 'purchase_amount' : 'date';
    const sortOrder = String(order).toLowerCase() === 'asc' ? 'ASC' : 'DESC';
    const { rows } = await pool.query(
      `SELECT * FROM inventory_items ${where} ORDER BY ${sortCol} ${sortOrder}, sr_no DESC`,
      params
    );
    const csv = toCsv(rows);
    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', 'attachment; filename="inventory_export.csv"');
    return res.send(csv);
  } catch (e) {
    console.error('GET /inventory/export.csv error', e);
    return res.status(500).json({ error: 'EXPORT_FAILED' });
  }
});

module.exports = router;
