// Primeira carga: cria as pessoas e põe o pipeline atual no banco.
// Rodar de novo NÃO sobrescreve o pipeline — só completa o que falta.
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { randomBytes } from "node:crypto";
import { pool, consulta } from "./db.js";
import { criarHash } from "./auth.js";

const raiz = join(dirname(fileURLToPath(import.meta.url)), "..");

const PESSOAS = [
  { email: "paulo@oren.com.br", nome: "Paulo" },
  { email: "theo@oren.com.br", nome: "Theo" },
  { email: "adriano@oren.com.br", nome: "Adriano" },
  { email: "adolfo@oren.com.br", nome: "Adolfo" },
];

// Senha temporária sorteada: nada de senha fraca escrita no código.
function senhaTemporaria() {
  return randomBytes(9).toString("base64url");
}

const criadas = [];
for (const p of PESSOAS) {
  const existe = await consulta("select 1 from usuario where email = $1", [p.email]);
  if (existe.rowCount) {
    console.log(`já existe: ${p.nome} <${p.email}>`);
    continue;
  }
  const senha = senhaTemporaria();
  await consulta(
    "insert into usuario (email, nome, senha_hash, papel) values ($1, $2, $3, 'editor')",
    [p.email, p.nome, criarHash(senha)],
  );
  criadas.push({ ...p, senha });
}

const jaTem = await consulta("select versao from pipeline where id = 1");
if (jaTem.rowCount) {
  console.log(`pipeline já está no banco (versão ${jaTem.rows[0].versao}), não toquei.`);
} else {
  const dados = JSON.parse(readFileSync(join(raiz, "seed/oren-dados.json"), "utf8"));
  await consulta(
    "insert into pipeline (id, dados, versao, atualizado_por) values (1, $1, 1, 'carga inicial')",
    [dados],
  );
  console.log(
    `pipeline carregado: ${dados.partners.length} parceiros, ${dados.customers.length} clientes, ${dados.deals.length} negócios.`,
  );
}

if (criadas.length) {
  console.log("\n=== SENHAS TEMPORÁRIAS — anote agora, não aparecem de novo ===");
  for (const c of criadas) console.log(`${c.nome.padEnd(10)} ${c.email.padEnd(26)} ${c.senha}`);
  console.log("Troque com: node src/usuario.js email \"Nome\" novaSenha\n");
}
await pool.end();
