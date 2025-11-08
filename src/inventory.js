// src/inventory.js
const express = require('express');
const router = express.Router();

// Debug middleware to log all requests to inventory routes
router.use((req, res, next) => {
  console.log(`[inventory router] ${req.method} ${req.path}`);
  next();
});
const pool = require('./db');

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

router.get('/inventory', async (req, res) => {
  try {
    const { q, status, vendor, from, to, brand, sort = 'date', order = 'desc' } = req.query;
    const { where, params } = buildWhere({ q, status, vendor, from, to, brand });
    const sortCol = sort === 'price' ? 'purchase_amount' : 'date';
    const sortOrder = String(order).toLowerCase() === 'asc' ? 'ASC' : 'DESC';

    const { rows } = await pool.query(
      `SELECT sr_no, to_char(date,'YYYY-MM-DD') as date, brand, model, imei, variant_gb_color, vendor_purchase, 
              purchase_amount::float, to_char(sell_date,'YYYY-MM-DD') as sell_date, sell_amount::float,
              customer_name, mobile_number, remarks, status
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
      `INSERT INTO inventory_items (date, brand, model, imei, variant_gb_color, vendor_purchase, purchase_amount, remarks, status, created_at, updated_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,'AVAILABLE', now(), now())
       RETURNING sr_no`,
      [c.date, c.brand || null, c.model, c.imei, c.variantGbColor || null, c.vendorPurchase || null, c.purchaseAmount || 0, c.remarks || null]
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

router.post('/inventory/:srNo/sell', async (req, res) => {
  const srNo = parseInt(req.params.srNo, 10);
  const c = req.body || {};
  try {
    const { rowCount } = await pool.query(
      `UPDATE inventory_items
         SET sell_date = $1,
             sell_amount = $2,
             customer_name = $3,
             mobile_number = $4,
             remarks = $5,
             status = 'SOLD',
             updated_at = now()
       WHERE sr_no = $6 AND status = 'AVAILABLE'`,
      [c.sellDate, c.sellAmount || 0, c.customerName || null, c.mobileNumber || null, c.remarks || null, srNo]
    );
    if (rowCount === 0) return res.status(400).json({ error: 'NOT_AVAILABLE_OR_NOT_FOUND' });
    return res.json({ success: true });
  } catch (e) {
    console.error('POST /inventory/:srNo/sell error', e);
    return res.status(500).json({ error: 'SELL_FAILED' });
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
