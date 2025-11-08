// src/uploads.js
const express = require("express");
const multer = require("multer");
const path = require("path");
const fs = require("fs");
const cloudinary = require("cloudinary").v2;
const { authMiddleware } = require("./auth");

const router = express.Router();

// ----------------------------
// Uploads directory
// ----------------------------
const UPLOADS_DIR = path.resolve(__dirname, "..", "uploads");
try {
  fs.mkdirSync(UPLOADS_DIR, { recursive: true });
  console.log("📂 Uploads directory ready:", UPLOADS_DIR);
} catch (err) {
  console.error("❌ Failed to create uploads directory:", err.message);
}

// ----------------------------
// Cloudinary configuration
// ----------------------------
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
    "⚠️ Cloudinary env variables missing. Set CLOUDINARY_CLOUD_NAME, CLOUDINARY_API_KEY, CLOUDINARY_API_SECRET to enable signed uploads."
  );
}

// ----------------------------
// Helpers
// ----------------------------
function extFromName(name) {
  return path.extname(name || "").toLowerCase();
}

function isAllowedByExt(originalname) {
  const ext = extFromName(originalname);
  return [".jpg", ".jpeg", ".png", ".webp", ".heic", ".pdf", ".gif"].includes(ext);
}

// ----------------------------
// Multer storage & filename
// ----------------------------
const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, UPLOADS_DIR),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname) || "";
    const base = path.basename(file.originalname, ext).replace(/\s+/g, "_");
    const uniqueName = `${Date.now()}-${Math.round(Math.random() * 1e9)}-${base}${ext}`;
    cb(null, uniqueName);
  },
});

// ----------------------------
// Acceptable mimetypes & fileFilter
// ----------------------------
const ALLOWED_MIMES = new Set([
  "image/jpeg",
  "image/jpg",
  "image/png",
  "image/webp",
  "image/heic",
  "image/heif",
  "image/gif",
  "application/pdf",
]);

function fileFilter(req, file, cb) {
  const mime = (file.mimetype || "").toLowerCase();
  const original = file.originalname || "";

  // If mime is known and allowed, accept
  if (mime && ALLOWED_MIMES.has(mime)) {
    return cb(null, true);
  }

  // Fallback: check extension if mime isn't recognized or missing
  if (isAllowedByExt(original)) {
    console.warn("fileFilter: accepting by extension fallback for", original, "mime:", mime);
    return cb(null, true);
  }

  // Reject with a MulterError code (so our handler picks it up)
  const msg = `Invalid file type. Allowed: JPG, PNG, WEBP, HEIC, GIF, PDF. received mime: ${mime || "unknown"}, name: ${original}`;
  const err = new multer.MulterError("LIMIT_UNEXPECTED_FILE", msg);
  return cb(err);
}

const upload = multer({
  storage,
  fileFilter,
  limits: {
    fileSize: 10 * 1024 * 1024, // 10 MB
  },
});

// ----------------------------
// Allowed fields & multer config
// ----------------------------
const ALLOWED_FIELDS = [
  { name: "file", maxCount: 1 },
  { name: "device_photo", maxCount: 1 },
  { name: "photo", maxCount: 1 },
  { name: "images", maxCount: 8 },
  { name: "attachments", maxCount: 8 },
];

const ALLOWED_FIELD_NAMES = new Set(ALLOWED_FIELDS.map((f) => f.name));

// ----------------------------
// Cleanup helper
// ----------------------------
function cleanupUploadedFiles(files = []) {
  for (const f of files) {
    try {
      const filePath = f && f.path ? f.path : path.join(UPLOADS_DIR, f.filename || "");
      if (filePath && fs.existsSync(filePath)) fs.unlinkSync(filePath);
      else console.warn("cleanupUploadedFiles: file not found", filePath);
    } catch (e) {
      console.warn("⚠️ Cleanup failed for", f.filename || f.path, (e && e.message) || e);
    }
  }
}

// ----------------------------
// Upload route
// ----------------------------
const cpUpload = upload.fields(ALLOWED_FIELDS);

// ----------------------------
// Signed upload signature endpoint
// ----------------------------
router.get("/cloudinary/sign", authMiddleware, (req, res) => {
  if (!CLOUDINARY_CONFIGURED) {
    return res.status(500).json({
      error: "Cloudinary is not configured on the server",
      missing: {
        cloud_name: !process.env.CLOUDINARY_CLOUD_NAME,
        api_key: !process.env.CLOUDINARY_API_KEY,
        api_secret: !process.env.CLOUDINARY_API_SECRET,
      },
    });
  }

  try {
    const timestamp = Math.round(Date.now() / 1000);
    const requestedFolder = typeof req.query.folder === "string" ? req.query.folder.trim() : "";
    const defaultFolder = process.env.CLOUDINARY_UPLOAD_FOLDER || "Jollybaba_Repair";
    const folder = requestedFolder || defaultFolder;

    const requestedPublicId = typeof req.query.publicId === "string" ? req.query.publicId.trim() : "";

    const paramsToSign = { timestamp };
    if (folder) paramsToSign.folder = folder;
    if (requestedPublicId) paramsToSign.public_id = requestedPublicId;

    const signature = cloudinary.utils.api_sign_request(
      paramsToSign,
      process.env.CLOUDINARY_API_SECRET
    );

    return res.json({
      signature,
      timestamp,
      api_key: process.env.CLOUDINARY_API_KEY,
      cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
      folder,
      ...(requestedPublicId ? { public_id: requestedPublicId } : {}),
    });
  } catch (err) {
    console.error("❌ Failed to create Cloudinary signature:", err && err.stack ? err.stack : err);
    return res.status(500).json({ error: "Failed to create Cloudinary signature" });
  }
});

router.post("/upload", cpUpload, (req, res) => {
  try {
    // multer produces req.files as an object keyed by fieldname
    const filesObj = req.files || {};
    const flattened = Object.values(filesObj).flat();

    if (!flattened.length) {
      return res.status(400).json({ error: "No file uploaded" });
    }

    // Extra validation of fields (defensive)
    const unexpected = flattened.filter((f) => !ALLOWED_FIELD_NAMES.has(f.fieldname));
    if (unexpected.length) {
      cleanupUploadedFiles(flattened);
      return res.status(400).json({
        error: "Unexpected field(s) received",
        receivedFields: [...new Set(flattened.map((f) => f.fieldname))],
        allowedFields: Array.from(ALLOWED_FIELD_NAMES),
      });
    }

    const uploaded = flattened.map((f) => ({
      field: f.fieldname,
      filename: f.filename,
      mimetype: f.mimetype,
      size: f.size,
      url: `${req.protocol}://${req.get("host")}/uploads/${f.filename}`,
    }));

    if (process.env.NODE_ENV !== "production") {
      console.log(`📁 Files uploaded: ${uploaded.map((u) => u.filename).join(", ")}`);
    }

    return res.status(201).json({ success: true, files: uploaded });
  } catch (err) {
    console.error("❌ Upload handler error:", err && err.stack ? err.stack : err);
    return res.status(500).json({ error: "File upload failed", details: err && err.message ? err.message : "" });
  }
});

// ----------------------------
// Multer-specific error handling for this router
// ----------------------------
router.use((err, req, res, next) => {
  if (err instanceof multer.MulterError) {
    console.error("Multer error:", err.code, err.message);

    // Attempt to clean up any files on disk
    const files = req.files ? (Array.isArray(req.files) ? req.files : Object.values(req.files).flat()) : [];
    if (files.length) cleanupUploadedFiles(files);

    if (err.code === "LIMIT_FILE_SIZE") {
      return res.status(400).json({ error: "File too large", code: err.code, message: err.message });
    }
    if (err.code === "LIMIT_UNEXPECTED_FILE") {
      return res.status(400).json({ error: "Invalid file type or unexpected field", code: err.code, message: err.message });
    }
    return res.status(400).json({ error: err.message, code: err.code });
  }

  // Fallback: custom message containing "Invalid file type"
  if (err && err.message && err.message.toLowerCase().includes("invalid file type")) {
    const files = req.files ? (Array.isArray(req.files) ? req.files : Object.values(req.files).flat()) : [];
    if (files.length) cleanupUploadedFiles(files);
    return res.status(400).json({ error: err.message });
  }

  return next(err);
});

module.exports = router;
