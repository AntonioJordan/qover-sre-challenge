import express from "express";
import { MongoClient, Db } from "mongodb";
import { collectDefaultMetrics, Histogram, Registry } from "prom-client";

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

const mongoQueryDuration = new Histogram({
  name: "mongo_query_duration_seconds",
  help: "Duration of MongoDB ping query",
  registers: [register],
});

async function connectMongo() {
  await client.connect();
  db = client.db("test");
  console.log("Connected to MongoDB");
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
  console.log("Shutting down...");
  await client.close();
  process.exit(0);
}

process.on("SIGTERM", shutdown);
process.on("SIGINT", shutdown);

connectMongo()
  .then(() => {
    app.listen(port, () => {
      console.log(`App listening on port ${port}`);
    });
  })
  .catch((err) => {
    console.error("Mongo connection failed", err);
    process.exit(1);
  });
