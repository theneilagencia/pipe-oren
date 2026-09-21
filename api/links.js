/* Oren · criar e revogar o link de envio de um negócio.
   Diferente de /api/envio, aqui quem chama é gente da casa: exige a sessão do
   painel e papel de editor. Leitor não cria link, pelo mesmo motivo que não
   grava no pipeline. */
const crypto = require("crypto");

function cfg() {
  const url = process.env.SUPABASE_URL, anon = process.env.SUPABASE_ANON_KEY,
        chave = process.env.SUPABASE_SERVICE_ROLE;
  if (!url || !anon || !chave) throw new Error("configuracao-incompleta");
  return { url: url.replace(/\/+$/, ""), anon, chave };
}
const sb = (c, caminho, opcoes) => fetch(c.url + caminho, Object.assign({}, opcoes, {
  headers: Object.assign({ apikey: c.chave, Authorization: "Bearer " + c.chave,
    "content-type": "application/json" }, (opcoes || {}).headers || {})
}));

/* Quem está chamando, segundo o Supabase — não segundo o navegador. */
async function quem(c, autorizacao) {
  if (!autorizacao || !/^Bearer\s+\S+/i.test(autorizacao)) return null;
  const r = await fetch(c.url + "/auth/v1/user", { headers: { apikey: c.anon, Authorization: autorizacao } });
  if (!r.ok) return null;
  const u = await r.json();
  if (!u || !u.id) return null;
  const p = await sb(c, "/rest/v1/perfil?select=nome,papel&id=eq." + encodeURIComponent(u.id));
  const perfil = p.ok ? (await p.json())[0] : null;
  if (!perfil || perfil.papel !== "editor") return null;
  return { id: u.id, nome: perfil.nome || u.email };
}

/* 32 bytes de aleatório de verdade. Em base64url dá 43 caracteres: adivinhar
   está fora de questão, e é isso que sustenta o link sem senha. */
const novoToken = () => crypto.randomBytes(32).toString("base64url");

/* No banco vai só a impressão do token. Se alguém com acesso de leitura à
   tabela quiser usar um link, não consegue: hash não volta para token. */
const impressao = t => crypto.createHash("sha256").update(t, "utf8").digest("hex");

module.exports = async (req, res) => {
  res.setHeader("cache-control", "no-store");
  if (req.method !== "POST") return res.status(405).json({ erro: "metodo" });
  let c; try { c = cfg(); } catch (e) {
    return res.status(500).json({ erro: "Falta configurar as variáveis de ambiente." });
  }
  const eu = await quem(c, req.headers.authorization);
  if (!eu) return res.status(403).json({ erro: "Só quem entra como editor cria link." });

  let corpo = req.body;
  if (typeof corpo === "string") { try { corpo = JSON.parse(corpo); } catch (e) { corpo = null; } }
  if (!corpo) return res.status(400).json({ erro: "Pedido inválido." });
  const base = (process.env.ENDERECO_PUBLICO || "https://crm-oren.vercel.app").replace(/\/+$/, "");

  try {
    if (corpo.acao === "criar") {
      if (!corpo.negocioId) return res.status(400).json({ erro: "Negócio não informado." });
      const dias = Math.min(180, Math.max(1, Number(corpo.dias) || 30));
      const token = novoToken();
      const expira = new Date(Date.now() + dias * 864e5).toISOString();
      /* Um link ativo por negócio: criar outro revoga o anterior. Dois links
         vivos para o mesmo cliente é convite a confusão sobre qual vale. */
      await sb(c, "/rest/v1/envio?negocio_id=eq." + encodeURIComponent(corpo.negocioId) + "&revogado_em=is.null",
        { method: "PATCH", body: JSON.stringify({ revogado_em: new Date().toISOString() }) });
      const r = await sb(c, "/rest/v1/envio", { method: "POST",
        headers: { Prefer: "return=representation" },
        body: JSON.stringify({ token_hash: impressao(token), negocio_id: corpo.negocioId,
          criado_por: eu.nome, expira_em: expira }) });
      if (!r.ok) throw new Error("criar-falhou");
      /* O token vai depois do "#": fragmento não é enviado ao servidor, então
         não entra no log de acesso da Vercel nem em cabeçalho Referer. Só o
         navegador do cliente o enxerga. */
      return res.status(200).json({ ok: true, dados: { url: base + "/envio/#t=" + token, expira_em: expira } });
    }
    if (corpo.acao === "revogar") {
      if (!corpo.negocioId) return res.status(400).json({ erro: "Negócio não informado." });
      /* Devolve quantos caíram: "revoguei" e "não havia nada para revogar" são
         notícias diferentes para quem acabou de vazar um link sem querer. */
      const r = await sb(c, "/rest/v1/envio?negocio_id=eq." + encodeURIComponent(corpo.negocioId) + "&revogado_em=is.null",
        { method: "PATCH", headers: { Prefer: "return=representation" },
          body: JSON.stringify({ revogado_em: new Date().toISOString() }) });
      if (!r.ok) throw new Error("revogar-falhou");
      const linhas = await r.json();
      return res.status(200).json({ ok: true, dados: { revogados: linhas.length } });
    }
    return res.status(400).json({ erro: "Ação desconhecida." });
  } catch (e) {
    return res.status(502).json({ erro: "Não consegui concluir: " + String(e.message || e) });
  }
};
