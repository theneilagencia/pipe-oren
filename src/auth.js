import { randomBytes, scryptSync, timingSafeEqual } from "node:crypto";
import { Router } from "express";
import { consulta } from "./db.js";

const COOKIE = "oren_sessao";
const DIAS = 30;

/* ---------- senha ---------- */
// scrypt do próprio Node: sem dependência nativa para compilar no Render.
export function criarHash(senha) {
  const sal = randomBytes(16).toString("hex");
  const hash = scryptSync(senha, sal, 64).toString("hex");
  return `scrypt$${sal}$${hash}`;
}

export function senhaConfere(senha, guardado) {
  const [algo, sal, hash] = String(guardado || "").split("$");
  if (algo !== "scrypt" || !sal || !hash) return false;
  const tentativa = scryptSync(senha, sal, 64);
  const esperado = Buffer.from(hash, "hex");
  if (tentativa.length !== esperado.length) return false;
  return timingSafeEqual(tentativa, esperado);
}

/* ---------- sessão ---------- */
function leCookie(req, nome) {
  const cru = req.headers.cookie || "";
  for (const parte of cru.split(";")) {
    const [k, ...v] = parte.trim().split("=");
    if (k === nome) return decodeURIComponent(v.join("="));
  }
  return null;
}

function ehHttps(req) {
  return req.headers["x-forwarded-proto"] === "https" || process.env.NODE_ENV === "production";
}

function poeCookie(res, req, token) {
  const partes = [
    `${COOKIE}=${encodeURIComponent(token)}`,
    "Path=/",
    "HttpOnly",
    "SameSite=Lax",
    `Max-Age=${DIAS * 24 * 60 * 60}`,
  ];
  if (ehHttps(req)) partes.push("Secure");
  res.setHeader("Set-Cookie", partes.join("; "));
}

function limpaCookie(res, req) {
  const partes = [`${COOKIE}=`, "Path=/", "HttpOnly", "SameSite=Lax", "Max-Age=0"];
  if (ehHttps(req)) partes.push("Secure");
  res.setHeader("Set-Cookie", partes.join("; "));
}

export async function usuarioDaSessao(req) {
  const token = leCookie(req, COOKIE);
  if (!token) return null;
  const { rows } = await consulta(
    `select u.id, u.email, u.nome, u.papel
       from sessao s join usuario u on u.id = s.usuario_id
      where s.token = $1 and s.expira_em > now() and u.ativo = true`,
    [token],
  );
  return rows[0] || null;
}

// Barra qualquer rota que não seja de login. Devolve 401 em JSON — o painel
// entende e mostra a tela de entrada.
export function exigeLogin(req, res, next) {
  usuarioDaSessao(req)
    .then((u) => {
      if (!u) {
        res.status(401).json({ erro: "nao_autenticado" });
        return;
      }
      req.usuario = u;
      next();
    })
    .catch(next);
}

export function exigeEditor(req, res, next) {
  if (req.usuario?.papel !== "editor") {
    res.status(403).json({ erro: "somente_leitura" });
    return;
  }
  next();
}

/* ---------- rotas ---------- */
export function rotasAuth() {
  const r = Router();

  r.post("/login", async (req, res, next) => {
    try {
      const email = String(req.body?.email || "").trim().toLowerCase();
      const senha = String(req.body?.senha || "");
      if (!email || !senha) {
        res.status(400).json({ erro: "informe_email_e_senha" });
        return;
      }
      const { rows } = await consulta(
        "select id, email, nome, papel, senha_hash from usuario where email = $1 and ativo = true",
        [email],
      );
      const u = rows[0];
      // Mesma resposta para e-mail inexistente e senha errada: não conta a quem
      // está tentando qual dos dois falhou.
      if (!u || !senhaConfere(senha, u.senha_hash)) {
        res.status(401).json({ erro: "email_ou_senha_invalidos" });
        return;
      }
      const token = randomBytes(32).toString("base64url");
      await consulta(
        `insert into sessao (token, usuario_id, expira_em)
         values ($1, $2, now() + interval '${DIAS} days')`,
        [token, u.id],
      );
      poeCookie(res, req, token);
      res.json({ email: u.email, nome: u.nome, papel: u.papel });
    } catch (e) {
      next(e);
    }
  });

  r.post("/logout", async (req, res, next) => {
    try {
      const token = leCookie(req, COOKIE);
      if (token) await consulta("delete from sessao where token = $1", [token]);
      limpaCookie(res, req);
      res.json({ ok: true });
    } catch (e) {
      next(e);
    }
  });

  // Cada pessoa troca a própria senha. Não existe rota para trocar a de outro:
  // no plano sem terminal, isto é o único caminho — e o mais seguro.
  r.post("/senha", async (req, res, next) => {
    try {
      const u = await usuarioDaSessao(req);
      if (!u) {
        res.status(401).json({ erro: "nao_autenticado" });
        return;
      }
      const atual = String(req.body?.atual || "");
      const nova = String(req.body?.nova || "");
      if (nova.length < 8) {
        res.status(400).json({ erro: "senha_curta" });
        return;
      }
      const { rows } = await consulta("select senha_hash from usuario where id = $1", [u.id]);
      if (!senhaConfere(atual, rows[0].senha_hash)) {
        res.status(401).json({ erro: "senha_atual_invalida" });
        return;
      }
      await consulta("update usuario set senha_hash = $1 where id = $2", [criarHash(nova), u.id]);
      // Derruba as outras sessões da pessoa, mantendo a atual.
      const token = leCookie(req, COOKIE);
      await consulta("delete from sessao where usuario_id = $1 and token <> $2", [u.id, token]);
      res.json({ ok: true });
    } catch (e) {
      next(e);
    }
  });

  r.get("/eu", async (req, res, next) => {
    try {
      const u = await usuarioDaSessao(req);
      if (!u) {
        res.status(401).json({ erro: "nao_autenticado" });
        return;
      }
      res.json({ email: u.email, nome: u.nome, papel: u.papel });
    } catch (e) {
      next(e);
    }
  });

  return r;
}
