#!/bin/sh
# Monta a pasta que o Vercel vai servir, quando o deploy vem do Git.
#
# Existe porque o repositorio nao tem a forma de um site: o painel se chama
# painel-oren.html e nao index.html, e ao lado dele moram coisas que nao podem
# ficar publicas (SQL, carga inicial, README). Sem este passo o Vercel serviria
# a raiz do repositorio inteira, e "/" daria 404.
#
# api/admin.js fica onde esta, na raiz: e' de lá que o Vercel tira a funcao de
# servidor. Este script cuida so do estatico.
set -e

rm -rf site
mkdir -p site/admin
cp painel-oren.html site/index.html
cp admin-oren.html  site/admin/index.html

# Mesmo selo de versao do publicar.sh e do workflow, para a pergunta "isto ja
# esta no ar?" ter resposta na propria tela. Selo errado e' pior que nenhum,
# entao confere depois de gravar e derruba o build se nao entrou.
SHA=$(printf %.7s "${VERCEL_GIT_COMMIT_SHA:-}")
[ -n "$SHA" ] || SHA=$(git rev-parse --short HEAD 2>/dev/null || echo sem-git)
SELO="$SHA · $(date -u +%d/%m/%Y\ %H:%M) UTC"
for F in site/index.html site/admin/index.html; do
  sed "s|const VERSAO=\"local\"|const VERSAO=\"$SELO\"|" "$F" > "$F.novo"
  mv "$F.novo" "$F"
  grep -q "const VERSAO=\"$SELO\"" "$F" || { echo "Nao consegui gravar o selo em $F"; exit 1; }
done

# Conferencia minima: painel inteiro, e nada de sobra na pasta publicada.
grep -q 'id="oren-dataset"' site/index.html || { echo "site/index.html nao parece o painel"; exit 1; }
grep -q 'gravarResponsaveis' site/admin/index.html || { echo "site/admin nao parece a administracao"; exit 1; }

echo "Selo desta publicacao: $SELO"
echo "Vai ao ar:"
find site -type f | sed 's|^|  |'
