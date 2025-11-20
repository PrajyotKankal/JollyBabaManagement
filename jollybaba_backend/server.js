// server.js
const dns = require("node:dns");

dns.setDefaultResultOrder("ipv4first");

if (process.env.NODE_ENV !== "production") {
  require("dotenv").config();
}
const express = require("express");
const path = require("path");
const cors = require("cors");

// ---------- Config ----------
const app = express();
const port = process.env.PORT || 5000;
const DEBUG_EXIT = process.env.DEBUG_EXIT === "true";

// Deployment information
const deploymentInfo = {
  timestamp: new Date().toISOString(),
  nodeEnv: process.env.NODE_ENV || 'development',
  commitHash: process.env.COMMIT_HASH || 'local',
  version: process.env.APP_VERSION || '1.0.0'
};

console.log('\n' + '='.repeat(60));
console.log('🚀 JollyBaba Backend Service');
console.log('='.repeat(60));
console.log(`🕒 Deployment Time: ${deploymentInfo.timestamp}`);
console.log(`🌐 Environment: ${deploymentInfo.nodeEnv}`);
console.log(`🔖 Version: ${deploymentInfo.version}`);
console.log(`🔄 Commit: ${deploymentInfo.commitHash}`);
console.log('='.repeat(60) + '\n');

// ---------- Process lifecycle / crash instrumentation ----------
const originalExit = process.exit.bind(process);

process.on("beforeExit", (code) => {
  console.warn("process.beforeExit event, code:", code);
});

process.on("exit", (code) => {
  console.warn("process.exit event, code:", code);
});

process.on("uncaughtException", (err) => {
  console.error("UNCAUGHT EXCEPTION:", err && err.stack ? err.stack : err);
  // If you want to terminate on uncaught exceptions in production, uncomment:
  // originalExit(1);
});

process.on("unhandledRejection", (reason, promise) => {
  console.error(
    "UNHANDLED REJECTION at:",
    promise,
    "\nreason:",
    reason && reason.stack ? reason.stack : reason
  );
  // In production you might want to exit here.
});

if (DEBUG_EXIT) {
  // Override process.exit to capture who called it. Only enable intentionally.
  process.exit = function (code = 0) {
    console.error("=== process.exit called ===");
    console.error("exit code:", code);
    console.error(new Error("Stack trace for process.exit").stack);
    // For debugging we keep the process alive. To restore normal behavior, set DEBUG_EXIT=false.
    // If you want original behavior uncomment next line:
    // originalExit(code);
  };
}

// ---------- Middleware ----------
app.use(cors()); // consider tightening origin in production
app.use(express.json({ limit: "5mb" }));
app.use(express.urlencoded({ extended: true }));
app.use("/uploads", express.static(path.join(__dirname, "uploads")));

// ---------- DB & Init ----------
let poolModule;
try {
  poolModule = require("./src/db");
} catch (err) {
  console.error("Could not require ./src/db:", err && err.stack ? err.stack : err);
}

const pool = poolModule && (poolModule.pool || poolModule);
const verifyConnection = poolModule && poolModule.verifyConnection ? poolModule.verifyConnection.bind(poolModule) : async () => true;
const dbHost = poolModule && poolModule.dbHost ? poolModule.dbHost : "(unknown)";
const pingDb = poolModule && poolModule.ping ? poolModule.ping.bind(poolModule) : async () => {};
const describeDbError = poolModule && poolModule.describeError ? poolModule.describeError : (err) => err && err.message;

const initDb = (() => {
  try {
    return require("./src/init");
  } catch (err) {
    console.error("Could not require ./src/init:", err && err.stack ? err.stack : err);
    return async () => {};
  }
})();

const DB_MAX_RETRIES = Math.max(1, parseInt(process.env.DB_CONNECT_RETRIES || "5", 10));
const DB_RETRY_DELAY_MS = Math.max(500, parseInt(process.env.DB_CONNECT_RETRY_DELAY_MS || "2000", 10));

async function startDatabase() {
  if (!pool) {
    console.error("❌ Database pool is not initialized. Check ./src/db export.");
    return;
  }

  const connected = await verifyConnection({
    maxRetries: DB_MAX_RETRIES,
    delayMs: DB_RETRY_DELAY_MS,
  });

  if (!connected) {
    console.error("🚫 Database connection could not be established. The API will start, but database-dependent features will fail.");
    return;
  }

  initDb()
    .then(() => {
      console.log("DB init complete (initDb resolved).");
    })
    .catch((err) => {
      const description = describeDbError(err);
      console.error("❌ DB init error (continuing):", description);
      if (err && err.stack) {
        console.error(err.stack);
      }
    });
}

startDatabase();

// ---------- Require routers (defensive) ----------
let authModule, ticketsModule, uploadsModule, inventoryModule, khatabookModule;
try {
  authModule = require("./src/auth");
} catch (err) {
  console.error("Failed to require ./src/auth:", err && err.stack ? err.stack : err);
}
try {
  ticketsModule = require("./src/tickets");
} catch (err) {
  console.error("Failed to require ./src/tickets:", err && err.stack ? err.stack : err);
}
try {
  uploadsModule = require("./src/uploads");
} catch (err) {
  console.error("Failed to require ./src/uploads:", err && err.stack ? err.stack : err);
}
try {
  inventoryModule = require("./src/inventory");
} catch (err) {
  console.error("Failed to require ./src/inventory:", err && err.stack ? err.stack : err);
}
try {
  khatabookModule = require("./src/khatabook");
} catch (err) {
  console.error("Failed to require ./src/khatabook:", err && err.stack ? err.stack : err);
}

function mountedRouterFor(mod, name) {
  if (!mod) {
    console.error(`🚨 Module "${name}" is undefined (require returned falsy).`);
    return null;
  }

  // If the module itself is an Express Router instance or function
  if (typeof mod === "function" || (mod && typeof mod.use === "function")) {
    console.log(`✅ ${name}: module is a Router/function (mounted directly).`);
    return mod;
  }

  // If module exports { router }
  if (mod.router && typeof mod.router === "function") {
    console.log(`✅ ${name}: found .router and it's a Router function.`);
    return mod.router;
  }

  // If module exports default express() app
  if (mod.default && typeof mod.default === "function") {
    console.log(`✅ ${name}: found default export and it's a function — mounting default.`);
    return mod.default;
  }

  // Unexpected shape
  console.error(`🚨 ${name}: unexpected module shape. typeof mod =`, typeof mod);
  console.error("Exported object preview:", mod);
  return null;
}

const maybeAuthRouter = mountedRouterFor(authModule, "auth");
const maybeTicketsRouter = mountedRouterFor(ticketsModule, "tickets");
const maybeUploadsRouter = mountedRouterFor(uploadsModule, "uploads");
const maybeInventoryRouter = mountedRouterFor(inventoryModule, "inventory");
const maybeKhatabookRouter = mountedRouterFor(khatabookModule, "khatabook");

// Global request logger (before routers)
app.use((req, res, next) => {
  console.log(`[GLOBAL] ${req.method} ${req.url}`);
  next();
});

// Mount routers safely under /api prefix
if (maybeAuthRouter) app.use("/api", maybeAuthRouter);
if (maybeTicketsRouter) app.use("/api", maybeTicketsRouter);
if (maybeUploadsRouter) app.use("/api", maybeUploadsRouter);
if (maybeInventoryRouter) app.use("/api", maybeInventoryRouter);
if (maybeKhatabookRouter) app.use("/api", maybeKhatabookRouter);

// ---------- Health check ----------
app.get("/", (req, res) => {
  res.json({
    status: "ok",
    service: "jollybaba_backend",
    env: process.env.NODE_ENV || "development",
    dbHost,
  });
});

app.get("/health", async (req, res) => {
  try {
    await pingDb();
    res.json({ status: "ok", db: "up", host: dbHost });
  } catch (err) {
    const description = describeDbError(err);
    res.status(503).json({ status: "error", db: "down", host: dbHost, message: description });
  }
});

// ---------- Route dumper (useful for debugging /dev) ----------
app.get("/routes", (req, res) => {
  try {
    const routes = [];
    if (!app._router) return res.json(routes);

    const layerPath = (layer) => {
      // derive mount path from regexp when using app.use('/base', router)
      if (!layer || !layer.regexp) return '';
      if (layer.regexp.fast_slash) return '';
      let match = layer.regexp.toString();
      // Normalize typical express layer regex to a base path string
      match = match
        .replace(/^\/.\^\\\/?/, '/')
        .replace(/\\\/?\(\?=\\\/\|\$\)\/i\$/, '')
        .replace(/\$\/$/, '')
        .replace(/\\\//g, '/');
      // Fallback cleanup
      match = match.replace(/^\/\^/, '/').replace(/\(\?:\)\?$/, '').replace(/\/$/, '');
      return match.startsWith('/') ? match : ('/' + match);
    };

    app._router.stack.forEach((middleware) => {
      if (middleware.route) {
        const methods = Object.keys(middleware.route.methods).map((m) => m.toUpperCase()).join(',');
        routes.push({ path: middleware.route.path, methods });
      } else if (middleware.name === 'router' && middleware.handle && middleware.handle.stack) {
        const base = layerPath(middleware) || '';
        middleware.handle.stack.forEach((handler) => {
          if (handler.route) {
            const methods = Object.keys(handler.route.methods).map((m) => m.toUpperCase()).join(',');
            const p = handler.route.path.startsWith('/') ? handler.route.path : '/' + handler.route.path;
            routes.push({ path: `${base}${p}`, methods });
          }
        });
      }
    });
    return res.json(routes);
  } catch (err) {
    console.error("Failed to list routes:", err && err.stack ? err.stack : err);
    return res.status(500).json({ error: "Failed to list routes" });
  }
});

// ---------- Multer-specific error handler (explicit) ----------
const multer = (() => {
  try {
    return require("multer");
  } catch {
    return null;
  }
})();

if (multer) {
  // Catch Multer errors thrown by multer middleware and return 400 with code
  app.use((err, req, res, next) => {
    if (err && err instanceof multer.MulterError) {
      console.warn("Multer error:", err.code, err.message);
      return res.status(400).json({ error: err.code || "MULTER_ERROR", message: err.message });
    }
    return next(err);
  });
}

// ---------- Global Express error handler ----------
app.use((err, req, res, next) => {
  try {
    console.error("Express error handler:", err && err.stack ? err.stack : err);

    if (res.headersSent) return next(err);

    const status = err && err.status && Number.isInteger(err.status) ? err.status : 500;
    res.status(status).json({
      error: err.message || "Internal server error",
      ...(process.env.NODE_ENV !== "production" ? { stack: err.stack } : {}),
    });
  } catch (handlerErr) {
    console.error("Error inside global error handler:", handlerErr && handlerErr.stack ? handlerErr.stack : handlerErr);
    try {
      if (!res.headersSent) res.status(500).json({ error: "Fatal server error" });
    } catch (finalErr) {
      console.error("Could not send error response:", finalErr && finalErr.stack ? finalErr.stack : finalErr);
    }
  }
});

// ---------- Start server ----------
const server = app.listen(port, "0.0.0.0", () => {
  console.log(`🚀 Server listening at http://0.0.0.0:${port}`);
  console.log("PID:", process.pid);
  console.log("Node version:", process.version);
  console.log("cwd:", process.cwd());
  console.log("ENV NODE_ENV:", process.env.NODE_ENV || "(not set)");
  console.log("If the process exits after this log, something else is calling process.exit(...) or terminating Node.");

  // Print registered routes to logs for quick debugging
  try {
    const routes = [];
    if (app._router) {
      app._router.stack.forEach((middleware) => {
        if (middleware.name === "router" && middleware.handle && middleware.handle.stack) {
          middleware.handle.stack.forEach((handler) => {
            if (handler.route) {
              const methods = Object.keys(handler.route.methods).map(m => m.toUpperCase()).join(',');
              routes.push(`${methods} ${handler.route.path}`);
            }
          });
        } else if (middleware.route) {
          const methods = Object.keys(middleware.route.methods).map(m => m.toUpperCase()).join(',');
          routes.push(`${methods} ${middleware.route.path}`);
        }
      });
    }
    console.log("=== Registered routes ===");
    routes.forEach(r => console.log(r));
    console.log("=========================");
  } catch (err) {
    console.warn("Failed to print routes on startup:", err && err.stack ? err.stack : err);
  }
});

// Optional heartbeat logging (set HEARTBEAT_MS to enable in non-production debugging)
let heartbeat;
const heartbeatIntervalMs = parseInt(process.env.HEARTBEAT_MS ?? "NaN", 10);
if (Number.isFinite(heartbeatIntervalMs) && heartbeatIntervalMs > 0) {
  heartbeat = setInterval(() => {
    console.log("⏱️ heartbeat - still alive", new Date().toISOString());
  }, heartbeatIntervalMs);
}

// Handle graceful shutdown
function shutdown(reason) {
  console.warn("Shutting down server. Reason:", reason || "unknown");
  if (heartbeat) clearInterval(heartbeat);
  server.close((err) => {
    if (err) {
      console.error("Error during server.close:", err && err.stack ? err.stack : err);
      // Force exit if needed:
      originalExit(1);
    } else {
      originalExit(0);
    }
  });
}

// Example bindings for graceful shutdown on signals (helpful during dev)
process.on("SIGTERM", () => shutdown("SIGTERM"));
process.on("SIGINT", () => shutdown("SIGINT"));
