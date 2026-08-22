#!/bin/sh
# Publica o painel Oren no Vercel a partir deste repositório.
#
# Existe para o que está no ar ser sempre o que está no repositório. Copiar
# arquivo à mão foi o que já produziu um deploy sem a página /admin.
#
#   ./publicar.sh                  usa ~/painel-oren como pasta de trabalho
#   ./publicar.sh /outro/caminho   usa outra pasta
set -e
REPO=$(cd "$(dirname "$0")" && pwd)
PASTA=${1:-$HOME/painel-oren}

mkdir -p "$PASTA/admin" "$PASTA/api"
cp "$REPO/painel-oren.html" "$PASTA/index.html"
cp "$REPO/admin-oren.html"  "$PASTA/admin/index.html"
cp "$REPO/api/admin.js"     "$PASTA/api/admin.js"

# Nada de .env no que sobe: a chave secreta vive nas variáveis do Vercel.
printf '.env*\n.gitignore\n' > "$PASTA/.vercelignore"

echo "Vai subir isto:"
find "$PASTA" -type f -not -path "*/.vercel/*" -not -name ".env*" \
  -not -name ".gitignore" -not -name ".vercelignore" | sed "s|$PASTA|.|"
echo

cd "$PASTA"

# Versao travada de proposito. Sem travar, o npx puxa a CLI mais nova a
# qualquer momento, e uma CLI recem-baixada nao encontra a sessao do login
# anterior: o deploy morre com "Error: Not authorized" sem nada ter mudado
# aqui. Para experimentar outra versao: VERCEL_CLI=vercel@latest ./publicar.sh
CLI=${VERCEL_CLI:-vercel@59.3.0}

# set -e mataria o script antes da mensagem de ajuda abaixo.
set +e
if [ -n "$VERCEL_TOKEN" ]; then
  # Caminho do CI: token no ambiente, nenhuma pergunta.
  npx --yes "$CLI" --prod --yes --token "$VERCEL_TOKEN"
else
  npx --yes "$CLI" --prod
fi
CODIGO=$?
set -e
if [ "$CODIGO" -ne 0 ]; then
  echo
  echo "O deploy nao saiu (codigo $CODIGO)."
  echo "Se a mensagem foi \"Not authorized\", a sessao da CLI expirou ou mudou de versao:"
  echo "  npx --yes $CLI login"
  echo "e rode ./publicar.sh de novo."
  exit "$CODIGO"
fi
