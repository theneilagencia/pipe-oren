/* Oren · o link que o cliente abre para enviar documentos.
   Roda no Vercel, fora do navegador. É quem guarda a chave secreta do Supabase
   e as do armazenamento; o cliente não recebe nenhuma das duas.

   Sem login, por decisão: o token no endereço é a credencial. Por isso ele tem
   validade, pode ser revogado, e dá acesso a UM negócio e a mais nada.
*/
const crypto = require("crypto");
const b2 = require("./_b2.js");
const CHECKLISTS = require("./_checklists.js");
const hoje = () => new Date().toISOString().slice(0, 10);

const VALIDADE_PADRAO_DIAS = 30;

function cfg() {
  const url = process.env.SUPABASE_URL, chave = process.env.SUPABASE_SERVICE_ROLE;
  if (!url || !chave) throw new Error("configuracao-incompleta");
  return { url: url.replace(/\/+$/, ""), chave };
}
const sb = (c, caminho, opcoes) => fetch(c.url + caminho, Object.assign({}, opcoes, {
  headers: Object.assign({ apikey: c.chave, Authorization: "Bearer " + c.chave,
    "content-type": "application/json" }, (opcoes || {}).headers || {})
}));

/* O banco guarda só o SHA-256 do token, nunca o token. Quem consegue ler a
   tabela — qualquer pessoa logada no painel, inclusive leitor — vê hashes, e
   com hash não se abre link nenhum. O token só existe no endereço do cliente. */
const impressao = t => crypto.createHash("sha256").update(t, "utf8").digest("hex");

/* Valida o token e devolve o registro. Um token inexistente, vencido ou
   revogado recebe a MESMA resposta: quem tenta adivinhar não aprende nada com
   a diferença entre "não existe" e "expirou". */
async function abrirToken(c, t) {
  if (typeof t !== "string" || !/^[A-Za-z0-9_-]{32,}$/.test(t)) return null;
  const r = await sb(c, "/rest/v1/envio?select=*&token_hash=eq." + impressao(t));
  if (!r.ok) return null;
  const linhas = await r.json();
  const e = linhas[0];
  if (!e || e.revogado_em) return null;
  if (new Date(e.expira_em) < new Date()) return null;
  return e;
}

async function lerPipeline(c) {
  const r = await sb(c, "/rest/v1/pipeline?select=dados,versao&id=eq.1");
  if (!r.ok) throw new Error("pipeline-indisponivel");
  const l = await r.json();
  if (!l[0]) throw new Error("pipeline-vazio");
  return l[0];
}

/* Grava com a versão em mãos, como o painel faz. Se alguém gravou no meio,
   relê e tenta de novo: o cliente não pode perder um envio porque o comercial
   mexeu no negócio no mesmo segundo. */
async function gravarDoc(c, negocioId, num, registro) {
  for (let tentativa = 0; tentativa < 4; tentativa++) {
    const { dados, versao } = await lerPipeline(c);
    const d = (dados.deals || []).find(x => x.id === negocioId);
    if (!d) throw new Error("negocio-nao-existe");
    d.docs = d.docs || {};
    d.docs[String(num)] = Object.assign({}, d.docs[String(num)] || {}, registro);
    d.atualizadoEm = new Date().toISOString().slice(0, 10);
    const r = await sb(c, "/rest/v1/pipeline?id=eq.1&versao=eq." + encodeURIComponent(versao),
      { method: "PATCH", body: JSON.stringify({ dados: dados }),
        headers: { Prefer: "return=representation" } });
    if (!r.ok) throw new Error("gravacao-falhou");
    const linhas = await r.json();
    if (linhas.length) return true;          /* gravou */
    await new Promise(s => setTimeout(s, 120 * (tentativa + 1)));   /* conflito: tenta de novo */
  }
  throw new Error("conflito-persistente");
}

/* O que o cliente vê: o nome do negócio e a lista do que falta. Nada de valor,
   etapa, responsável ou qualquer outro dado interno. */
function paraOCliente(d, checklists) {
  const grupos = checklists[d.frente] || null;
  const itens = [];
  if (grupos) grupos.forEach(([cat, lista]) => lista.forEach(([n, texto]) => {
    const reg = (d.docs || {})[String(n)] || {};
    const st = reg.status || "pendente";
    if (st === "na") return;                 /* não se aplica: não se pede */
    itens.push({ n: n, categoria: cat, texto: texto, status: st,
      arquivo: reg.arquivoNome || "", em: reg.em || "" });
  }));
  return { negocio: d.titulo || "", itens: itens };
}

module.exports = async (req, res) => {
  res.setHeader("cache-control", "no-store");
  if (req.method === "OPTIONS") return res.status(204).end();
  if (req.method !== "POST") return res.status(405).json({ erro: "metodo" });

  let c; try { c = cfg(); } catch (e) {
    return res.status(500).json({ erro: "Falta configurar as variáveis de ambiente." });
  }
  let corpo = req.body;
  if (typeof corpo === "string") { try { corpo = JSON.parse(corpo); } catch (e) { corpo = null; } }
  if (!corpo || typeof corpo !== "object") return res.status(400).json({ erro: "Pedido inválido." });

  const envio = await abrirToken(c, corpo.t);
  if (!envio) return res.status(403).json({ erro: "Este link não vale mais. Peça um novo a quem te enviou." });

  try {
    const { dados } = await lerPipeline(c);
    const d = (dados.deals || []).find(x => x.id === envio.negocio_id);
    if (!d) return res.status(404).json({ erro: "Negócio não encontrado." });

    if (corpo.acao === "abrir") {
      await sb(c, "/rest/v1/envio?token_hash=eq." + envio.token_hash, { method: "PATCH",
        body: JSON.stringify({ ultimo_acesso: new Date().toISOString(), acessos: (envio.acessos || 0) + 1 }) });
      return res.status(200).json({ ok: true, dados: paraOCliente(d, CHECKLISTS) });
    }

    if (corpo.acao === "subir") {
      const { n, nome, tamanho, tipo, hash } = corpo;
      if (!n) return res.status(400).json({ erro: "Documento não informado." });
      if (!/^[a-f0-9]{64}$/.test(String(hash || ""))) return res.status(400).json({ erro: "Arquivo inválido." });
      if (!(tamanho > 0)) return res.status(400).json({ erro: "Arquivo vazio." });
      if (tamanho > b2.LIMITE_BYTES)
        return res.status(400).json({ erro: "Arquivo acima de 15 MB. Envie uma versão menor ou divida em partes." });
      if (b2.TIPOS_OK.indexOf(String(tipo)) < 0)
        return res.status(400).json({ erro: "Formato não aceito. Envie PDF, JPG ou PNG." });
      const ext = tipo === "application/pdf" ? ".pdf" : tipo === "image/png" ? ".png" : ".jpg";
      /* Deduplicação: se este conteúdo exato já está guardado, não sobe de novo. */
      let ja = false;
      try { ja = await b2.existe(hash, ext); } catch (e) { ja = false; }
      if (ja) {
        await gravarDoc(c, envio.negocio_id, n, { status: "recebido", em: hoje(),
          por: "cliente", arquivoHash: hash, arquivoExt: ext, arquivoNome: String(nome || "").slice(0, 120) });
        return res.status(200).json({ ok: true, dados: { jaExistia: true } });
      }
      return res.status(200).json({ ok: true, dados: { url: b2.urlDeUpload(hash, ext, tipo), ext: ext } });
    }

    if (corpo.acao === "confirmar") {
      const { n, hash, ext, nome } = corpo;
      if (!/^[a-f0-9]{64}$/.test(String(hash || ""))) return res.status(400).json({ erro: "Arquivo inválido." });
      /* Confia no que o B2 diz, não no que o navegador diz: confere se o
         objeto existe mesmo antes de marcar como recebido. */
      if (!(await b2.existe(hash, ext))) return res.status(400).json({ erro: "O envio não chegou completo. Tente de novo." });
      await gravarDoc(c, envio.negocio_id, n, { status: "recebido", em: hoje(), por: "cliente",
        arquivoHash: hash, arquivoExt: ext, arquivoNome: String(nome || "").slice(0, 120) });
      await sb(c, "/rest/v1/envio?token_hash=eq." + envio.token_hash, { method: "PATCH",
        body: JSON.stringify({ enviados: (envio.enviados || 0) + 1 }) });
      return res.status(200).json({ ok: true, dados: { recebido: true } });
    }

    return res.status(400).json({ erro: "Ação desconhecida." });
  } catch (e) {
    return res.status(502).json({ erro: "Não consegui concluir: " + String(e.message || e) });
  }
};