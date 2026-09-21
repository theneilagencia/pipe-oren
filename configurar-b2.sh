#!/bin/sh
# Configura o armazenamento dos documentos no Vercel, numa passada só.
#
# Existe porque são cinco variáveis e um erro de digitação em qualquer uma
# falha só na hora do primeiro upload, com mensagem que não aponta para a causa.
#
#   ./configurar-b2.sh              pergunta cada valor e grava em produção
#   ./configurar-b2.sh --conferir   só lista o que já está configurado
#
# O segredo é digitado por você e vai direto para o Vercel: não fica em arquivo,
# não aparece na tela, não entra no histórico do shell.
set -e
CLI=${VERCEL_CLI:-vercel@59.3.0}

# env add grava no projeto da PASTA em que a CLI roda, e um clone novo do
# repositorio nao esta vinculado a projeto nenhum: a CLI tenta perguntar, nao
# consegue (a entrada padrao esta sendo usada pelas respostas) e falha dizendo
# outra coisa. Entao rodamos na mesma pasta que o publicar.sh usa.
PASTA=${PASTA:-$HOME/painel-oren}
if [ ! -d "$PASTA/.vercel" ]; then
  echo "A pasta $PASTA nao esta vinculada a um projeto do Vercel."
  echo "Vincule uma vez, escolhendo o projeto crm-oren:"
  echo "  cd $PASTA && npx --yes $CLI link"
  echo "Ou aponte para outra pasta ja vinculada:  PASTA=/caminho ./configurar-b2.sh"
  exit 1
fi
cd "$PASTA"

if [ "$1" = "--conferir" ]; then
  echo "Variáveis no projeto:"
  npx --yes "$CLI" env ls 2>/dev/null | grep -E "B2_|NAME|name" || echo "  não consegui listar"
  exit 0
fi

echo "Cinco valores, do console do Backblaze."
echo "Deixe em branco para pular uma variável que já está certa."
echo

pergunta() {   # $1 nome  $2 explicação  $3 =segredo?
  VAL=""
  printf "%s\n  %s\n  > " "$1" "$2"
  if [ "$3" = "segredo" ]; then stty -echo 2>/dev/null || true; fi
  read VAL
  if [ "$3" = "segredo" ]; then stty echo 2>/dev/null || true; echo; fi
  echo
}

grava() {      # $1 nome  $2 valor
  [ -z "$2" ] && { echo "  $1: pulado"; return 0; }
  # Remove antes de gravar: env add numa variável existente é recusado.
  npx --yes "$CLI" env rm "$1" production --yes >/dev/null 2>&1 || true
  SAIDA=$(printf '%s' "$2" | npx --yes "$CLI" env add "$1" production 2>&1) && {
    echo "  $1: gravada"; return 0; }
  # Mostra o que a CLI disse. Engolir a mensagem foi o que ja fez perder tempo
  # com um palpite ("faca login") quando o problema era outro.
  echo "  $1: FALHOU"
  echo "$SAIDA" | sed 's/^/      /' | head -n 6
  case "$SAIDA" in
    *"not authorized"*|*"Not authorized"*|*"credentials"*|*"log in"*)
      echo "      -> a sessao da CLI expirou:  npx --yes $CLI login" ;;
    *"link"*|*"Project not found"*|*"scope"*)
      echo "      -> a pasta nao aponta para o projeto certo:  cd $PASTA && npx --yes $CLI link" ;;
  esac
  return 1
}

pergunta B2_ENDPOINT "o endereço S3 do balde, algo como https://s3.us-west-004.backblazeb2.com"
END="$VAL"
case "$END" in
  ""|https://*) : ;;
  *) echo "O endpoint precisa começar com https://. Recomece."; exit 1 ;;
esac

pergunta B2_REGION "a região dentro do endpoint, algo como us-west-004"
REG="$VAL"
pergunta B2_BUCKET "o nome exato do balde que você criou"
BUC="$VAL"
pergunta B2_KEY_ID "o keyID da chave de aplicação"
KID="$VAL"
pergunta B2_KEY "o segredo da chave — não vai aparecer enquanto você digita" segredo
KEY="$VAL"

echo "Gravando no Vercel:"
grava B2_ENDPOINT "$END"
grava B2_REGION   "$REG"
grava B2_BUCKET   "$BUC"
grava B2_KEY_ID   "$KID"
grava B2_KEY      "$KEY"
KEY=""; VAL=""

echo
echo "Variável nova só vale no deploy seguinte. Publicando..."
npx --yes "$CLI" --prod --yes >/dev/null 2>&1 \
  && echo "Publicado. Gere um link de envio num negócio e teste com um PDF pequeno." \
  || echo "Não consegui publicar daqui. Rode ./publicar.sh --forcar"
