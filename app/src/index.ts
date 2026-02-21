import express from "express";
import { MongoClient, Db } from "mongodb";
import {
  collectDefaultMetrics,
  Counter,
  Histogram,
  Registry,
} from "prom-client";

const app = express();
const port = Number(process.env.PORT ?? "3000");

const mongoUri = process.env.MONGO_URI;
if (!mongoUri) throw new Error("MONGO_URI not defined");

const client = new MongoClient(mongoUri, {
  serverSelectionTimeoutMS: 5000,
});

let db: Db;

const register = new Registry();
collectDefaultMetrics({ register });

const httpRequestsTotal = new Counter({
  name: "http_requests_total",
  help: "Total number of HTTP requests",
  labelNames: ["method", "route", "status_code"] as const,
  registers: [register],
});

const httpRequestDuration = new Histogram({
  name: "http_request_duration_seconds",
  help: "HTTP request duration in seconds",
  labelNames: ["method", "route", "status_code"] as const,
  buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5],
  registers: [register],
});

const mongoQueryDuration = new Histogram({
  name: "mongo_query_duration_seconds",
  help: "Duration of MongoDB ping query",
  registers: [register],
});

function getRouteLabel(req: express.Request): string {
  const routePath = req.route?.path;
  if (typeof routePath === "string") return routePath;
  return "unknown";
}

app.use((req, res, next) => {
  const start = process.hrtime.bigint();

  res.on("finish", () => {
    const route = getRouteLabel(req);
    const statusCode = String(res.statusCode);
    const durationSeconds =
      Number(process.hrtime.bigint() - start) / 1_000_000_000;

    httpRequestsTotal.inc({
      method: req.method,
      route,
      status_code: statusCode,
    });

    httpRequestDuration.observe(
      {
        method: req.method,
        route,
        status_code: statusCode,
      },
      durationSeconds
    );

    console.log(
      JSON.stringify({
        ts: new Date().toISOString(),
        level: "info",
        msg: "request",
        method: req.method,
        path: req.path,
        route,
        statusCode: res.statusCode,
        durationSeconds,
      })
    );
  });

  next();
});

async function connectMongo() {
  await client.connect();
  db = client.db("test");
  console.log(
    JSON.stringify({
      ts: new Date().toISOString(),
      level: "info",
      msg: "Connected to MongoDB",
    })
  );
}

app.get("/", (_req, res) => {
  res.send("hello world");
});

app.get("/health", async (_req, res) => {
  try {
    await db.command({ ping: 1 });
    res.json({ status: "ok" });
  } catch {
    res.status(500).json({ status: "error" });
  }
});

app.get("/data", async (_req, res) => {
  const end = mongoQueryDuration.startTimer();
  try {
    await db.command({ ping: 1 });
    res.json({ result: "pong" });
  } finally {
    end();
  }
});

app.get("/metrics", async (_req, res) => {
  res.setHeader("Content-Type", register.contentType);
  res.end(await register.metrics());
});

async function shutdown() {
  console.log(
    JSON.stringify({
      ts: new Date().toISOString(),
      level: "info",
      msg: "Shutting down",
    })
  );
  await client.close();
  process.exit(0);
}

process.on("SIGTERM", shutdown);
process.on("SIGINT", shutdown);

connectMongo()
  .then(() => {
    app.listen(port, () => {
      console.log(
        JSON.stringify({
          ts: new Date().toISOString(),
          level: "info",
          msg: "App listening",
          port,
        })
      );
    });
  })
  .catch((err) => {
    console.error(
      JSON.stringify({
        ts: new Date().toISOString(),
        level: "error",
        msg: "Mongo connection failed",
        err: String(err),
      })
    );
    process.exit(1);
  });