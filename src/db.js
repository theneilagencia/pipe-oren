import pg from "pg";

// Uma única piscina de conexões para todo o processo.
// No Render o DATABASE_URL já vem pronto; local, use o .env.
const url = process.env.DATABASE_URL;
if (!url) {
  console.error("Falta DATABASE_URL. Copie o .env.example para .env e preencha.");
  process.exit(1);
}

// Banco na nuvem exige TLS; banco local, não. Em vez de listar provedores um a
// um (e esquecer o próximo), a regra é: se não é a sua máquina, é com TLS.
export function precisaTls(u) {
  if (/sslmode=(require|verify-ca|verify-full)/.test(u)) return true;
  if (/sslmode=disable/.test(u)) return false;
  const host = (u.match(/@([^/:?]+)/) || [])[1] || "";
  if (!host || u.includes("host=/")) return false; // socket unix
  return !/^(localhost|127\.0\.0\.1|\[::1\]|host\.docker\.internal|postgres|db)$/.test(host);
}

export const pool = new pg.Pool({
  connectionString: url,
  ssl: precisaTls(url) ? { rejectUnauthorized: false } : false,
  max: 5,
  idleTimeoutMillis: 30000,
});

export function consulta(sql, params) {
  return pool.query(sql, params);
}

// Roda tudo dentro de uma transação e desfaz se algo falhar no meio.
export async function transacao(fn) {
  const cliente = await pool.connect();
  try {
    await cliente.query("begin");
    const r = await fn(cliente);
    await cliente.query("commit");
    return r;
  } catch (e) {
    await cliente.query("rollback");
    throw e;
  } finally {
    cliente.release();
  }
}
