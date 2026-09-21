/* Camada de armazenamento. Fala o protocolo S3, então serve para Backblaze B2,
   Cloudflare R2, Wasabi ou MinIO sem mudar uma linha: troca-se o endpoint e as
   chaves nas variáveis de ambiente. Isolado de propósito — trocar de
   fornecedor não pode ser reescrever a funcionalidade.

   Assina à mão, sem SDK: o projeto não tem package.json e não vai ter por
   causa disto. São ~40 linhas de SigV4, verificadas contra o botocore.

   Variáveis:
     B2_ENDPOINT   https://s3.us-west-004.backblazeb2.com
     B2_REGION     us-west-004
     B2_BUCKET     oren-documentos
     B2_KEY_ID     id da chave de aplicação
     B2_KEY        o segredo da chave
*/
const crypto = require("crypto");

const LIMITE_BYTES = 15 * 1024 * 1024;   /* 15 MB por documento, combinado */
const TIPOS_OK = ["application/pdf", "image/jpeg", "image/png"];

function cfg() {
  const c = {
    endpoint: process.env.B2_ENDPOINT, region: process.env.B2_REGION,
    bucket: process.env.B2_BUCKET, keyId: process.env.B2_KEY_ID, key: process.env.B2_KEY
  };
  for (const k of Object.keys(c)) if (!c[k]) throw new Error("armazenamento-nao-configurado");
  c.host = new URL(c.endpoint).host;
  return c;
}

const sha256 = x => crypto.createHash("sha256").update(x).digest("hex");
const hmac = (k, x) => crypto.createHmac("sha256", k).update(x).digest();
/* encodeURIComponent não escapa !'()* , e o S3 exige que escape. */
const esc = s => encodeURIComponent(s).replace(/[!'()*]/g, c =>
  "%" + c.charCodeAt(0).toString(16).toUpperCase());
const escCaminho = s => s.split("/").map(esc).join("/");

/* URL assinada: vale por alguns minutos, para um caminho só e um verbo só.
   Quem a recebe não recebe a chave. */
function assinar(metodo, chave, segundos, extras) {
  const c = cfg();
  const agora = new Date();
  const data = agora.toISOString().replace(/[:-]|\.\d{3}/g, "");   /* 20260921T220000Z */
  const dia = data.slice(0, 8);
  const escopo = dia + "/" + c.region + "/s3/aws4_request";
  const q = Object.assign({
    "X-Amz-Algorithm": "AWS4-HMAC-SHA256",
    "X-Amz-Credential": c.keyId + "/" + escopo,
    "X-Amz-Date": data,
    "X-Amz-Expires": String(segundos),
    "X-Amz-SignedHeaders": "host"
  }, extras || {});
  const canonQ = Object.keys(q).sort().map(k => esc(k) + "=" + esc(q[k])).join("&");
  const caminho = "/" + c.bucket + "/" + escCaminho(chave);
  const canon = [metodo, caminho, canonQ, "host:" + c.host + "\n", "host", "UNSIGNED-PAYLOAD"].join("\n");
  const paraAssinar = ["AWS4-HMAC-SHA256", data, escopo, sha256(canon)].join("\n");
  const kData = hmac("AWS4" + c.key, dia), kReg = hmac(kData, c.region),
        kSrv = hmac(kReg, "s3"), kSig = hmac(kSrv, "aws4_request");
  const assinatura = crypto.createHmac("sha256", kSig).update(paraAssinar).digest("hex");
  return c.endpoint.replace(/\/+$/, "") + caminho + "?" + canonQ + "&X-Amz-Signature=" + assinatura;
}

/* O caminho é o hash do conteúdo: o mesmo documento enviado em três negócios do
   mesmo cliente ocupa espaço uma vez, e reenviar o mesmo arquivo não duplica. */
const caminhoDe = (hash, ext) => "doc/" + hash.slice(0, 2) + "/" + hash + (ext || "");

const urlDeUpload  = (hash, ext, tipo) => assinar("PUT", caminhoDe(hash, ext), 900);
const urlDeLeitura = (hash, ext, nome) => assinar("GET", caminhoDe(hash, ext), 300,
  nome ? {"response-content-disposition": 'inline; filename="' + nome.replace(/"/g, "") + '"'} : null);

async function existe(hash, ext) {
  const r = await fetch(assinar("HEAD", caminhoDe(hash, ext), 60), { method: "HEAD" });
  return r.status === 200;
}

module.exports = { LIMITE_BYTES, TIPOS_OK, caminhoDe, urlDeUpload, urlDeLeitura, existe, assinar, cfg };
