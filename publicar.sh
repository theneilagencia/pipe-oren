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
npx vercel --prod
