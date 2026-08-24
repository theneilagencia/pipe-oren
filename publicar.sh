#!/bin/sh
# Publica o painel Oren no Vercel a partir deste repositório.
#
# Existe para o que está no ar ser sempre o que está no repositório. Copiar
# arquivo à mão foi o que já produziu um deploy sem a página /admin.
#
#   ./publicar.sh                  usa ~/painel-oren como pasta de trabalho
#   ./publicar.sh /outro/caminho   usa outra pasta
#   ./publicar.sh --conferir       nao publica: so diz o que esta no ar agora
set -e
REPO=$(cd "$(dirname "$0")" && pwd)
ENDERECO=${ENDERECO:-https://crm-oren.vercel.app}

# Le o selo de versao da pagina que esta no ar. Existe porque "publiquei e nao
# mudou nada" precisa de uma resposta que nao seja opiniao: ou o selo do ar e' o
# do commit, ou nao e'.
selo_no_ar() {
  curl -fsS -H "Cache-Control: no-cache" "$ENDERECO/?c=$$$(date +%s)" 2>/dev/null \
    | grep -o 'const VERSAO="[^"]*"' | head -1 | sed -e 's/^const VERSAO="//' -e 's/"$//'
}

if [ "$1" = "--conferir" ]; then
  echo "No ar em $ENDERECO:"
  AR=$(selo_no_ar || true)
  if [ -z "$AR" ]; then
    echo "  nao consegui ler o selo. Sem rede, ou a pagina nao respondeu."
    exit 1
  fi
  echo "  $AR"
  AQUI=$(cd "$REPO" && git rev-parse --short HEAD 2>/dev/null || echo sem-git)
  echo "Neste clone: $AQUI"
  case "$AR" in
    "$AQUI"*) echo "Iguais: o que esta no ar e' o que esta aqui." ;;
    *) echo "Diferentes: o ar esta atrasado em relacao a este clone. Rode ./publicar.sh" ;;
  esac
  exit 0
fi

PASTA=${1:-$HOME/painel-oren}

# Antes de qualquer copia, trazer o repositorio para o dia. A causa mais comum
# de "publiquei e nao mudou nada" e' deploy de um clone atrasado: o arquivo que
# sobe e' o que esta nesta pasta, nao o que esta no GitHub. Para pular: SEM_PULL=1
if [ -z "$SEM_PULL" ] && [ -d "$REPO/.git" ] && git -C "$REPO" remote get-url origin >/dev/null 2>&1; then
  ANTES=$(git -C "$REPO" rev-parse --short HEAD)
  # --untracked-files=no de proposito: arquivo solto na pasta nao corre risco
  # num pull fast-forward, e e travar por causa dele so atrasaria a publicacao.
  if [ -n "$(git -C "$REPO" status --porcelain --untracked-files=no)" ]; then
    echo "Atencao: ha alteracao nao commitada neste clone. Nao vou puxar do GitHub."
    echo "Vai subir o que esta aqui, em $ANTES."
  else
    RAMO=$(git -C "$REPO" rev-parse --abbrev-ref HEAD)
    echo "Trazendo o repositorio para o dia ($RAMO)..."
    set +e
    git -C "$REPO" pull --ff-only origin "$RAMO"
    PULLOK=$?
    set -e
    DEPOIS=$(git -C "$REPO" rev-parse --short HEAD)
    if [ "$PULLOK" -ne 0 ]; then
      echo "Nao consegui puxar do GitHub. Vai subir o que ja esta aqui, em $DEPOIS."
    elif [ "$ANTES" = "$DEPOIS" ]; then
      echo "Ja estava no dia, em $DEPOIS."
    else
      echo "Atualizado de $ANTES para $DEPOIS."
    fi
  fi
fi

mkdir -p "$PASTA/admin" "$PASTA/api"
cp "$REPO/painel-oren.html" "$PASTA/index.html"
cp "$REPO/admin-oren.html"  "$PASTA/admin/index.html"
cp "$REPO/api/admin.js"     "$PASTA/api/admin.js"

# Selo de versão no que sobe: commit curto e data. Existe para a pergunta
# "isto já está no ar?" ter resposta na propria tela, no pé da lateral.
# sed -i não é portátil entre GNU e BSD, então escreve em arquivo novo e troca.
SELO="$(cd "$REPO" && git rev-parse --short HEAD 2>/dev/null || echo sem-git)"
SELO="$SELO · $(date +%d/%m/%Y\ %H:%M)"
for F in "$PASTA/index.html" "$PASTA/admin/index.html"; do
  sed "s|const VERSAO=\"local\"|const VERSAO=\"$SELO\"|" "$F" > "$F.novo" && mv "$F.novo" "$F"
  grep -q "const VERSAO=\"$SELO\"" "$F" || { echo "Nao consegui gravar o selo de versao em $F"; exit 1; }
done
echo "Selo desta publicacao: $SELO"

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

# Deploy que devolve codigo 0 nao prova nada sobre o que o endereco serve: ja
# subiu arquivo velho com "Ready" na tela. Entao confere no proprio endereco.
echo
echo "Conferindo o que $ENDERECO esta servindo..."
TENTATIVA=1
while [ "$TENTATIVA" -le 6 ]; do
  AR=$(selo_no_ar || true)
  if [ "$AR" = "$SELO" ]; then
    echo "Confirmado: no ar em $SELO"
    echo "  $ENDERECO/  e  $ENDERECO/admin"
    exit 0
  fi
  if [ -n "$AR" ]; then
    echo "  tentativa $TENTATIVA de 6: o ar ainda diz \"$AR\""
  else
    echo "  tentativa $TENTATIVA de 6: nao consegui ler o selo do ar"
  fi
  TENTATIVA=$((TENTATIVA + 1))
  [ "$TENTATIVA" -le 6 ] && sleep 5
done
echo
echo "O deploy saiu, mas o endereco continua servindo outra versao."
echo "  aqui:  $SELO"
echo "  no ar: ${AR:-nao consegui ler}"
echo "Duas causas possiveis, nesta ordem:"
echo "  1. Este projeto do Vercel nao e' o que responde por $ENDERECO."
echo "     Confira em vercel.com qual projeto tem esse dominio."
echo "  2. O deploy foi para preview, nao para producao."
echo "Rode ./publicar.sh --conferir depois de um minuto para ver de novo."
exit 1
