/* Oren · função de administração
   Roda no Vercel, fora do navegador. É o único lugar onde a chave service_role
   existe, lida de variável de ambiente. Nunca é devolvida ao cliente.

   Variáveis de ambiente exigidas no projeto Vercel:
     SUPABASE_URL           https://<ref>.supabase.co
     SUPABASE_ANON_KEY      a mesma chave publicável que está no painel
     SUPABASE_SERVICE_ROLE  a chave secreta, só aqui
     ADMIN_EMAIL            (opcional) quem pode administrar
*/
const ADMIN_PADRAO = "vinicius.debian@btsglobalcorp.com";
const PAPEIS = ["editor", "leitor"];

function cfg() {
  const url = process.env.SUPABASE_URL;
  const anon = process.env.SUPABASE_ANON_KEY;
  const chave = process.env.SUPABASE_SERVICE_ROLE;
  if (!url || !anon || !chave) throw new Error("configuracao-incompleta");
  return { url: url.replace(/\/+$/, ""), anon, chave,
    admin: (process.env.ADMIN_EMAIL || ADMIN_PADRAO).trim().toLowerCase() };
}

/* Quem está chamando? A resposta vem do próprio Supabase, com o token que o
   navegador mandou. Não confiamos em nada que o cliente diga sobre si. */
async function quemChama(c, autorizacao) {
  if (!autorizacao || !/^Bearer\s+\S+/i.test(autorizacao)) return null;
  const r = await fetch(c.url + "/auth/v1/user", {
    headers: { apikey: c.anon, Authorization: autorizacao }
  });
  if (!r.ok) return null;
  const u = await r.json();
  return u && u.email ? { id: u.id, email: String(u.email).trim().toLowerCase() } : null;
}

const adm = (c, caminho, opcoes) => fetch(c.url + caminho, Object.assign({}, opcoes, {
  headers: Object.assign({
    apikey: c.chave, Authorization: "Bearer " + c.chave, "content-type": "application/json"
  }, (opcoes || {}).headers || {})
}));

const emailValido = e => typeof e === "string" && /^[^@\s]+@[^@\s.]+\.[^@\s]+$/.test(e.trim());
const senhaValida = s => typeof s === "string" && s.length >= 8;

async function perfis(c) {
  const r = await adm(c, "/rest/v1/perfil?select=id,nome,papel,email,senha_provisoria");
  return r.ok ? await r.json() : [];
}

async function listar(c) {
  const r = await adm(c, "/auth/v1/admin/users?per_page=200");
  if (!r.ok) throw new Error("listar-falhou");
  const corpo = await r.json();
  const usuarios = Array.isArray(corpo) ? corpo : corpo.users || [];
  const porId = {};
  (await perfis(c)).forEach(p => { porId[p.id] = p; });
  return usuarios.map(u => {
    const p = porId[u.id] || {};
    return {
      id: u.id, email: u.email,
      nome: p.nome || "", papel: p.papel || "",
      senhaProvisoria: !!p.senha_provisoria,
      semPerfil: !porId[u.id],
      ultimoAcesso: u.last_sign_in_at || null,
      criadoEm: u.created_at || null,
      confirmado: !!(u.email_confirmed_at || u.confirmed_at)
    };
  }).sort((a, b) => (a.nome || a.email).localeCompare(b.nome || b.email, "pt-BR"));
}

async function marcarProvisoria(c, id, valor) {
  await adm(c, "/rest/v1/perfil?id=eq." + encodeURIComponent(id),
    { method: "PATCH", body: JSON.stringify({ senha_provisoria: !!valor }) });
}

async function criar(c, d) {
  if (!emailValido(d.email)) throw new Error("email-invalido");
  if (!senhaValida(d.senha)) throw new Error("senha-curta");
  const papel = PAPEIS.indexOf(d.papel) >= 0 ? d.papel : "editor";
  const nome = String(d.nome || "").trim();
  const r = await adm(c, "/auth/v1/admin/users", {
    method: "POST",
    body: JSON.stringify({
      email: d.email.trim(), password: d.senha, email_confirm: true,
      user_metadata: { nome: nome, papel: papel }
    })
  });
  const corpo = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error(corpo.msg || corpo.error_description || "criar-falhou");
  /* O gatilho do banco cria o perfil. Se o projeto tiver recusado o gatilho,
     o perfil é inserido aqui, senão a pessoa entra e não vê nada. */
  const jaTem = (await perfis(c)).some(p => p.id === corpo.id);
  if (!jaTem) {
    await adm(c, "/rest/v1/perfil", {
      method: "POST",
      body: JSON.stringify({ id: corpo.id, nome: nome || corpo.email.split("@")[0],
        papel: papel, email: corpo.email, senha_provisoria: true })
    });
  } else await marcarProvisoria(c, corpo.id, true);
  return { id: corpo.id, email: corpo.email };
}

async function trocarSenha(c, d) {
  if (!d.id) throw new Error("sem-id");
  if (!senhaValida(d.senha)) throw new Error("senha-curta");
  const r = await adm(c, "/auth/v1/admin/users/" + encodeURIComponent(d.id),
    { method: "PUT", body: JSON.stringify({ password: d.senha }) });
  if (!r.ok) throw new Error("senha-falhou");
  await marcarProvisoria(c, d.id, true);
  return { ok: true };
}

async function salvarPerfil(c, d) {
  if (!d.id) throw new Error("sem-id");
  const campos = {};
  if (typeof d.nome === "string" && d.nome.trim()) campos.nome = d.nome.trim();
  if (PAPEIS.indexOf(d.papel) >= 0) campos.papel = d.papel;
  if (!Object.keys(campos).length) throw new Error("nada-para-salvar");
  const r = await adm(c, "/rest/v1/perfil?id=eq." + encodeURIComponent(d.id),
    { method: "PATCH", body: JSON.stringify(campos) });
  if (!r.ok) throw new Error("perfil-falhou");
  return { ok: true };
}

async function recuperar(c, d) {
  if (!emailValido(d.email)) throw new Error("email-invalido");
  const r = await fetch(c.url + "/auth/v1/recover", {
    method: "POST",
    headers: { apikey: c.anon, "content-type": "application/json" },
    body: JSON.stringify({ email: d.email.trim() })
  });
  if (!r.ok) throw new Error("recuperar-falhou");
  return { ok: true };
}

async function remover(c, d, quem) {
  if (!d.id) throw new Error("sem-id");
  if (d.id === quem.id) throw new Error("nao-remove-a-si");
  const r = await adm(c, "/auth/v1/admin/users/" + encodeURIComponent(d.id), { method: "DELETE" });
  if (!r.ok) throw new Error("remover-falhou");
  return { ok: true };
}

module.exports = async (req, res) => {
  res.setHeader("cache-control", "no-store");
  if (req.method === "OPTIONS") return res.status(204).end();
  if (req.method !== "POST") return res.status(405).json({ erro: "metodo" });

  let c;
  try { c = cfg(); } catch (e) {
    return res.status(500).json({ erro: "Falta configurar as variáveis de ambiente no Vercel." });
  }

  const quem = await quemChama(c, req.headers.authorization);
  if (!quem) return res.status(401).json({ erro: "Entre no painel antes." });
  /* A restrição de verdade é esta linha, no servidor. Checagem por e-mail no
     navegador seria decorativa. */
  if (quem.email !== c.admin) return res.status(403).json({ erro: "Sem permissão." });

  let corpo = req.body;
  if (typeof corpo === "string") { try { corpo = JSON.parse(corpo); } catch (e) { corpo = null; } }
  if (!corpo || typeof corpo !== "object") return res.status(400).json({ erro: "Pedido inválido." });

  const acoes = { listar, criar, senha: trocarSenha, perfil: salvarPerfil, recuperar, remover };
  const fn = acoes[corpo.acao];
  if (!fn) return res.status(400).json({ erro: "Ação desconhecida." });
  try {
    return res.status(200).json({ ok: true, dados: await fn(c, corpo, quem) });
  } catch (e) {
    const m = String(e.message || "");
    const legivel = {
      "email-invalido": "E-mail inválido.",
      "senha-curta": "A senha precisa de pelo menos 8 caracteres.",
      "sem-id": "Escolha uma pessoa.",
      "nada-para-salvar": "Nada mudou.",
      "nao-remove-a-si": "Você não pode remover a própria conta."
    }[m];
    return res.status(legivel ? 400 : 502).json({ erro: legivel || "Não consegui concluir: " + m });
  }
};
