// src/auth.js
const express = require("express");
const bcrypt = require("bcrypt");
const jwt = require("jsonwebtoken");
const pool = require("./db");

const router = express.Router();

const JWT_SECRET = process.env.JWT_SECRET || "change_this_secret_in_prod";
const SALT_ROUNDS = parseInt(process.env.SALT_ROUNDS || "12", 10);

// ---------------- helpers ----------------
function signToken(payload) {
  return jwt.sign(payload, JWT_SECRET, { expiresIn: "4h" });
}

// Simple async handler to forward errors to Express error middleware
function asyncHandler(fn) {
  return function (req, res, next) {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
}

// Verify token; returns decoded payload or throws
function verifyToken(token) {
  if (!token) throw new Error("Missing token");
  try {
    return jwt.verify(token, JWT_SECRET);
  } catch (err) {
    // rethrow with clear message
    throw new Error("Invalid or expired token");
  }
}

// ---------------- middleware ----------------
async function authMiddleware(req, res, next) {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader) return res.status(401).json({ error: "Unauthorized", message: "No authorization header" });

    const parts = authHeader.split(" ");
    if (parts.length !== 2 || parts[0] !== "Bearer") {
      return res.status(401).json({ error: "Unauthorized", message: "Malformed authorization header" });
    }

    const token = parts[1];
    const payload = verifyToken(token); // throws on invalid
    req.user = payload; // attach { id, email, role, iat, exp }
    next();
  } catch (err) {
    // Always return a JSON 401 rather than allowing an uncaught exception
    return res.status(401).json({ error: "Unauthorized", message: err.message || "Invalid token" });
  }
}

function requireRole(role) {
  return (req, res, next) => {
    if (!req.user) return res.status(401).json({ error: "Unauthorized" });
    if (req.user.role !== role) return res.status(403).json({ error: "Forbidden" });
    next();
  };
}

// ---------------- routes ----------------

// POST /api/auth/login
router.post(
  "/auth/login",
  asyncHandler(async (req, res) => {
    // Debug: log incoming request source & body (hide password)
    try {
      const loggedBody = {};
      if (req.body && typeof req.body === "object") {
        for (const k of Object.keys(req.body)) {
          loggedBody[k] = k.toLowerCase().includes("password") ? "***" : req.body[k];
        }
      }
      console.log("📥 /api/auth/login called - ip:", req.ip || req.connection?.remoteAddress, "body:", loggedBody);
    } catch (logErr) {
      console.error("Logger error (nonfatal):", logErr && logErr.stack ? logErr.stack : logErr);
    }

    const { email, password } = req.body || {};
    if (!email || !password) {
      console.log("🔒 login failed - missing email/password");
      return res.status(400).json({ error: "Email and password required" });
    }

    // use a single query; rowCount check handles not found
    const result = await pool.query("SELECT * FROM technicians WHERE email = $1", [email]);
    if (result.rowCount === 0) {
      console.log("🔒 login failed - user not found for:", email);
      // respond 401 but avoid leaking whether email exists
      return res.status(401).json({ error: "Invalid credentials" });
    }

    const user = result.rows[0];

    // if password_hash missing, treat as invalid
    if (!user.password_hash) {
      console.log("🔒 login failed - no password_hash for:", email);
      return res.status(401).json({ error: "Invalid credentials" });
    }

    const match = await bcrypt.compare(password, user.password_hash);
    if (!match) {
      console.log("🔒 login failed - password mismatch for:", email);
      return res.status(401).json({ error: "Invalid credentials" });
    }

    const token = signToken({ id: user.id, email: user.email, role: user.role });
    const safeUser = { id: user.id, name: user.name, email: user.email, role: user.role };

    console.log("✅ login success for:", email, "id:", user.id, "role:", user.role);
    return res.json({ token, user: safeUser });
  })
);

// GET /api/me
router.get(
  "/me",
  authMiddleware,
  asyncHandler(async (req, res) => {
    // req.user guaranteed by middleware
    const { id } = req.user || {};
    if (!id) return res.status(400).json({ error: "Invalid token payload" });

    const result = await pool.query(
      "SELECT id, name, email, role, created_at, updated_at FROM technicians WHERE id = $1",
      [id]
    );
    if (result.rowCount === 0) {
      console.log("🔍 /api/me - user not found for id:", id);
      return res.status(404).json({ error: "User not found" });
    }
    res.json(result.rows[0]);
  })
);

// POST /api/technicians  (admin-only)
router.post(
  "/technicians",
  authMiddleware,
  requireRole("admin"),
  asyncHandler(async (req, res) => {
    const { name, email, password, phone, role } = req.body || {};
    if (!name || !email || !password) return res.status(400).json({ error: "Name, email and password are required" });

    const existing = await pool.query("SELECT id FROM technicians WHERE email = $1", [email]);
    if (existing.rowCount > 0) {
      console.log("🔁 create technician - email already in use:", email);
      return res.status(409).json({ error: "Email already in use" });
    }

    const password_hash = await bcrypt.hash(password, SALT_ROUNDS);

    const result = await pool.query(
      `INSERT INTO technicians (name, email, password_hash, phone, role) VALUES ($1,$2,$3,$4,$5) 
       RETURNING id, name, email, role, created_at`,
      [name, email, password_hash, phone || null, role || "technician"]
    );

    console.log("✅ technician created:", result.rows[0]);
    return res.status(201).json({ technician: result.rows[0] });
  })
);

// ----------------------------------------------------
// NEW: GET /api/technicians/public
// Authenticated endpoint that returns only safe, non-sensitive fields
// Useful for populating dropdowns on technician devices.
// ----------------------------------------------------
router.get(
  "/technicians/public",
  authMiddleware,
  asyncHandler(async (req, res) => {
    try {
      const result = await pool.query("SELECT id, name, email, role FROM technicians ORDER BY id DESC");
      // Return as { technicians: [...] } to match existing frontend expectations
      res.json({ technicians: result.rows });
    } catch (err) {
      console.error("❌ /api/technicians/public error:", err && err.stack ? err.stack : err);
      res.status(500).json({ error: "Failed to list technicians" });
    }
  })
);

// GET /api/technicians  (admin-only) - keep for admin management
router.get(
  "/technicians",
  authMiddleware,
  requireRole("admin"),
  asyncHandler(async (req, res) => {
    const result = await pool.query("SELECT id, name, email, phone, role, created_at FROM technicians ORDER BY id DESC");
    res.json({ technicians: result.rows });
  })
);

// DELETE /api/technicians/:id  (admin-only)
router.delete(
  "/technicians/:id",
  authMiddleware,
  requireRole("admin"),
  asyncHandler(async (req, res) => {
    const { id } = req.params;
    const result = await pool.query("DELETE FROM technicians WHERE id = $1 RETURNING id", [id]);
    if (result.rowCount === 0) return res.status(404).json({ error: "Technician not found" });
    console.log("🗑️ technician deleted id:", id);
    res.json({ success: true });
  })
);

// Export both router and middleware helpers (keeps backward compatibility)
module.exports = {
  router,
  authMiddleware,
  requireRole,
};
