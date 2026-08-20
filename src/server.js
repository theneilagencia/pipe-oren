import express from "express";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { rotasAuth, exigeLogin } from "./auth.js";
import { rotasPipeline } from "./pipeline.js";
import { consulta } from "./db.js";

const raiz = join(dirname(fileURLToPath(import.meta.url)), "..");
const app = express();
app.set("trust proxy", 1);
app.use(express.json({ limit: "8mb" })); // o documento inteiro cabe folgado

// Cabeçalhos de segurança básicos. O painel é um arquivo só, sem CDN, então a
// política pode ser fechada.
app.use((_req, res, next) => {
  res.setHeader("X-Content-Type-Options", "nosniff");
  res.setHeader("X-Frame-Options", "DENY");
  res.setHeader("Referrer-Policy", "same-origin");
  res.setHeader("X-Robots-Tag", "noindex, nofollow");
  res.setHeader(
    "Content-Security-Policy",
    "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self'; form-action 'self'; frame-ancestors 'none'",
  );
  next();
});

app.get("/health", async (_req, res) => {
  try {
    await consulta("select 1");
    res.json({ ok: true });
  } catch {
    res.status(503).json({ ok: false });
  }
});

app.use("/api", rotasAuth());          // login, logout e eu: públicas
app.use("/api", exigeLogin, rotasPipeline()); // o resto exige sessão

app.use(express.static(join(raiz, "public"), { extensions: ["html"], maxAge: 0 }));

app.use((err, _req, res, _next) => {
  console.error("erro:", err?.message || err);
  res.status(500).json({ erro: "erro_interno" });
});

const porta = process.env.PORT || 3000;
app.listen(porta, () => console.log(`Oren no ar em http://localhost:${porta}`));
