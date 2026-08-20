// Cria ou atualiza uma pessoa. Uso:
//   node src/usuario.js paulo@empresa.com "Paulo" senhaSegura [editor|leitor]
import { pool, consulta } from "./db.js";
import { criarHash } from "./auth.js";

const [email, nome, senha, papel = "editor"] = process.argv.slice(2);
if (!email || !nome || !senha) {
  console.error('Uso: node src/usuario.js email "Nome" senha [editor|leitor]');
  process.exit(1);
}
if (senha.length < 8) {
  console.error("A senha precisa ter pelo menos 8 caracteres.");
  process.exit(1);
}
await consulta(
  `insert into usuario (email, nome, senha_hash, papel) values ($1, $2, $3, $4)
   on conflict (email) do update set nome = $2, senha_hash = $3, papel = $4, ativo = true`,
  [email.trim().toLowerCase(), nome, criarHash(senha), papel],
);
console.log(`Pronto: ${nome} <${email}> como ${papel}.`);
await pool.end();
