import pg from "pg";

// Uma única piscina de conexões para todo o processo.
// No Render o DATABASE_URL já vem pronto; local, use o .env.
const url = process.env.DATABASE_URL;
if (!url) {
  console.error("Falta DATABASE_URL. Copie o .env.example para .env e preencha.");
  process.exit(1);
}

export const pool = new pg.Pool({
  connectionString: url,
  // O Postgres do Render exige TLS; o local, não.
  ssl: /render\.com|amazonaws\.com/.test(url) ? { rejectUnauthorized: false } : false,
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
