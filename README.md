# Oren · Painel comercial

Painel de pipeline comercial com os dados no Supabase e entrada por e-mail e senha.

Não existe servidor. São três peças:

| Peça | O que é |
|---|---|
| `painel-oren.html` | o painel inteiro, um arquivo só, sem framework |
| `supabase/schema.sql` | as tabelas e as regras de acesso, para colar no Supabase |
| `carga-inicial.json` | os dados de partida: 43 parceiros, 4 clientes, 47 negócios |

O painel fala direto com o Supabase. Quem protege o dado são as regras de acesso
do banco: **sem login, o banco recusa tudo** — não existe caminho para ler nem
gravar. Quem é `leitor` consegue ver e não consegue gravar, e isso é decidido no
banco, não na tela.

## Montar, na primeira vez

**1. As tabelas.** No Supabase, em **SQL Editor**, cole `supabase/schema.sql`
inteiro e execute. Cria três tabelas, o histórico automático e as permissões.

**2. As pessoas.** Em **Authentication → Users → Add user**, crie cada uma com
e-mail e uma senha provisória. Marque *Auto Confirm User*, senão a pessoa precisa
confirmar por e-mail antes de entrar. O perfil nasce junto, com o nome tirado do
e-mail. Para acertar o nome ou tornar alguém somente leitura:

```sql
update public.perfil set nome = 'Paulo' where nome = 'Paulo.silva';
update public.perfil set papel = 'leitor' where nome = 'Ana';
```

Se o script avisou que não pôde criar o gatilho, insira o perfil na mão depois de
criar a pessoa:

```sql
insert into public.perfil (id, nome, papel)
select id, 'Paulo', 'editor' from auth.users where email = 'paulo@empresa.com';
```

**3. O endereço do seu projeto.** No topo do `painel-oren.html` existem duas
linhas com a URL e a chave publicável. Já vêm preenchidas com o projeto atual; se
trocar de projeto, pegue as novas em **Project Settings → API**. Essas duas
linhas são públicas por natureza: a chave publicável é feita para ficar no
navegador, e sozinha ela não abre nada — sem login, as regras do banco recusam.

**4. Abrir o painel.** Duas formas:

- **Arquivo no computador**: abra `painel-oren.html` com dois cliques. Funciona
  igual, e conversa com o Supabase pela internet.
- **Link para o time**: em **Storage**, crie um bucket público, suba o arquivo e
  use o link público. Se o navegador baixar em vez de abrir, fique com a primeira
  forma.

**5. Os dados.** Entre com uma conta editora e use **Importar** no menu, escolhendo
`carga-inicial.json`. Isso grava os 47 negócios no banco, e todo mundo passa a
ver. Faça uma vez só.

O negócio da ata de 21/08/2026 (cliente `C-05` e negócio `N-048`) não precisa de
passo nenhum: o painel grava na primeira entrada de um editor, não duplica na
segunda, e um perfil leitor não grava nada. `supabase/ata-2026-08-21.sql` continua
no repositório para quem preferir o SQL Editor — rodar os dois é seguro.

As **22 atividades da ata de 02/09/2026** (ids `AT-ATA-01` a `AT-ATA-22`) entram
pelo mesmo caminho, na primeira entrada de um editor. São as 20 linhas do plano
de ação do item 27, com a linha "revisar todas as pendências" desdobrada nas três
pessoas que o item 25 nomeia. Três regras valem para toda a carga:

- **Responsável** é o primeiro nome da linha do plano; os demais ficam escritos na
  descrição. Onde o plano não nomeia pessoa — "Operação", "responsáveis jurídicos
  / societários" — o campo fica **vazio**, e a descrição diz isso. O item 3 da ata
  trata atividade sem responsável e sem data como atividade não definida: deixar
  vazio registra a lacuna em vez de apagá-la.
- **Data de fim** só onde a ata dá uma data. "Imediato", "Prioritário",
  "Pendente", "Próxima rodada" e "Definir no CRM" não são datas; a palavra do
  plano fica na descrição e o campo vazio aparece na pastilha "sem data de fim" —
  que é exatamente a primeira ação P0 do plano.
- **Data de início** é 02/09/2026 em todas: é a data da reunião que atribuiu o
  trabalho. **Demandante** é Vinícius onde ele não é o responsável, porque a ata
  lhe dá a cobrança dos responsáveis (itens 2, 3 e 28).

A carga usa nomes que podem não estar na lista de responsáveis do painel —
**Vinícius** e **André**, entre outros. Enquanto não estiverem, o painel mostra
"(fora da lista)" no campo, eles não aparecem no filtro de responsável e a
`auditoria()` acusa. O caminho é `/admin` → Responsáveis: os nomes em uso e fora
da lista aparecem lá, com a contagem, e entram com um clique.

## Área administrativa

Em `/admin`, só para `vinicius.debian@btsglobalcorp.com`. De lá se cria pessoa,
define senha provisória, envia link de redefinição, troca nome e papel, e remove
conta.

Criar usuário e definir a senha de outra pessoa são operações da API de
administração do Supabase, e exigem a chave `service_role`. Essa chave ignora
todas as políticas de acesso: quem a tem lê e escreve tudo, sem login. Por isso
ela **não pode** ficar na página, que roda inteira no navegador de quem abre.
Quem fala com ela é `api/admin.js`, uma função no Vercel, fora do navegador. A
restrição por e-mail também mora lá, não no JavaScript da página, onde seria
decorativa.

**1. O banco.** SQL Editor, cole `supabase/admin.sql`, Run. Acrescenta `email` e
`senha_provisoria` no perfil, ensina o gatilho a preencher os dois, e cria a
função que desliga a marca de senha provisória depois que a pessoa troca a
própria senha.

**2. As variáveis no Vercel.** Project Settings, Environment Variables, quatro
entradas, em Production e Preview:

| Nome | Valor |
|---|---|
| `SUPABASE_URL` | `https://<ref>.supabase.co` |
| `SUPABASE_ANON_KEY` | a chave publicável, a mesma que está no painel |
| `SUPABASE_SERVICE_ROLE` | a chave secreta, em Project Settings, API, no Supabase |
| `ADMIN_EMAIL` | quem administra |

A `service_role` só existe aqui. Não vai para o repositório, nem para o painel,
nem para o navegador. Trocando as variáveis, republique para valer.

**3. A publicação.** A pasta que sobe passa a ter três coisas:

```
mkdir -p ~/painel-oren/admin ~/painel-oren/api
cp painel-oren.html  ~/painel-oren/index.html
cp admin-oren.html   ~/painel-oren/admin/index.html
cp api/admin.js      ~/painel-oren/api/admin.js
cd ~/painel-oren && npx vercel --prod
```

O `api/` é o que o Vercel transforma em função. Sem ele no ar, a página de
administração abre e nenhuma ação funciona.

## Primeiro acesso e senha esquecida

Pessoa criada pela área administrativa nasce com senha provisória. No primeiro
login o painel exige a troca antes de mostrar qualquer dado, e o botão de
cancelar não aparece. Depois de trocar, a marca é desligada por uma função do
banco, não por um update no perfil: política de update aberta ali deixaria um
leitor se promover a editor.

**Esqueci minha senha** manda um e-mail cujo link volta para o painel com o
token depois do `#`. Para isso funcionar, o **Site URL** em Authentication, URL
Configuration precisa ser o endereço publicado.

## Publicar

**Os endereços oficiais são o Vercel:**

| | |
|---|---|
| aplicação | https://crm-oren.vercel.app/ |
| administração | https://crm-oren.vercel.app/admin |

**Sozinho, a cada push no `main`.** `.github/workflows/publicar.yml` monta a pasta
com o painel em `index.html` e a administração em `admin/index.html`, e joga o
resultado na branch **`gh-pages`** — isso acontece sempre, sem segredo nenhum.

| Destino | Como recebe o que está no repositório | O que fica no ar |
|---|---|---|
| Vercel (oficial) | ligando o projeto ao repositório em *vercel.com → crm-oren → Settings → Git*, **ou** com `VERCEL_TOKEN`, `VERCEL_ORG_ID` e `VERCEL_PROJECT_ID` nos segredos do repositório, **ou** `./publicar.sh` na mão | painel, `/admin` e `api/admin.js` |
| GitHub Pages | já ligado em *Settings → Pages → Source: GitHub Actions* | painel e `/admin`, sem a função de servidor |

Enquanto o Vercel não estiver ligado ao repositório, ele fica na versão do último
`./publicar.sh` que alguém rodou — e foi assim que ele ficou semanas atrás do
repositório. O Pages serve de conferência: ele sempre tem o `main`.

### Ligar o Vercel ao repositório

*vercel.com → projeto **crm-oren** → Settings → Git → Connect Git Repository →
`theneilagencia/pipe-oren`, branch `main`.* Depois disso todo push publica sozinho
e ninguém precisa de terminal.

O repositório já está preparado para esse modo, e a preparação não é opcional: a
raiz **não tem a forma de um site**. O painel se chama `painel-oren.html`, não
`index.html`, e ao lado dele moram arquivos que não podem ficar públicos. Três
arquivos resolvem isso:

| Arquivo | Para que serve |
|---|---|
| `vercel.json` | manda o Vercel rodar `vercel-build.sh` e servir a pasta `site/` |
| `vercel-build.sh` | monta `site/index.html` e `site/admin/index.html`, grava o selo de versão (do `VERCEL_GIT_COMMIT_SHA`) e derruba o build se o selo não entrou |
| `.vercelignore` | mantém `supabase/`, `carga-inicial.json` e o `README` fora do que sobe |

`api/admin.js` continua na raiz, sem passar pelo build: é de lá que o Vercel tira
a função de servidor. As quatro variáveis de ambiente do projeto continuam como
estão — ligar o Git não mexe nelas.

Depois de ligar, confira duas coisas no primeiro deploy: o selo no pé da lateral
do painel tem de ser o commit do `main`, e em `/admin` a criação de pessoa tem de
funcionar (é ela que depende da função de servidor).

O token do Actions não tem permissão para ligar o Pages sozinho, e o workflow não
falha por isso: ele avisa no log e segue. Sem os segredos do Vercel, mesma coisa.

No Pages não existe função de servidor. O painel inteiro funciona, e no `/admin`
a tela de **responsáveis** também, porque ela fala direto com o Supabase. **Criar
pessoa e definir senha** passam pela função com a chave `service_role` e só
funcionam no endereço do Vercel — a tela avisa quando você tenta no lugar errado.

### Redefinição de senha

Três coisas do lado do Supabase, e as três já derrubaram o fluxo:

1. **Authentication → URL Configuration → Site URL** = `https://crm-oren.vercel.app/`.
   Ele nasce como `http://localhost:3000`, e é onde a pessoa cai quando "o reset
   não funciona".
2. **Redirect URLs**, na mesma tela, precisam listar os endereços de onde o
   pedido pode sair: `https://crm-oren.vercel.app/**` e, se o time usa o espelho,
   `https://theneilagencia.github.io/pipe-oren/**`. O painel manda `redirect_to`
   com o endereço de onde a pessoa clicou; endereço fora da lista é ignorado, e o
   Supabase volta a usar o Site URL.
3. **Limite de e-mail.** O SMTP embutido do Supabase envia poucos e-mails por
   hora. Estourado o limite, `/auth/v1/recover` responde 429 e ninguém recebe
   nada — o painel mostra isso em vez de um erro genérico. Para uso de verdade,
   configure um SMTP próprio em **Project Settings → Auth → SMTP**.

O modelo de e-mail de **Reset Password** precisa continuar usando
`{{ .ConfirmationURL }}`. Modelo com `?code=` é fluxo PKCE, que só se completa com
a biblioteca que iniciou o pedido — este painel não usa biblioteca, e avisa em
vez de falhar calado.

Cada link vale uma hora e serve uma vez só. Link vencido volta com `#error=` e a
tela de entrada mostra o motivo.

Quando alguém não consegue entrar, `supabase/acesso-usuario.sql` diagnostica e
conserta: e-mail confirmado, `aud`/`role`, bandeiras de SSO e anonimato, senha em
bcrypt, identidade e a linha em `public.perfil`. Ele não cria conta -- criar é
pela tela `/admin`, que passa pela API e monta identidade e perfil sozinha.

À mão, quando quiser:

```
cd ~/oren-publicar && git pull && ./publicar.sh
```

A versão da CLI do Vercel está travada no script (`vercel@59.3.0`). Não é
capricho: sem travar, o `npx` baixa a versão mais nova a qualquer momento, e uma
CLI recém-baixada não encontra a sessão do login anterior — o deploy morre com
`Error: Not authorized` sem nada ter mudado no repositório. Se acontecer, o
script diz o comando de login. Para experimentar outra versão:
`VERCEL_CLI=vercel@latest ./publicar.sh`.

Ele monta a pasta de trabalho com os três arquivos que o Vercel serve — o painel
como `index.html`, a página de administração em `admin/index.html` e a função de
servidor em `api/admin.js` — e chama `npx vercel --prod`. Copiar arquivo à mão foi
o que já colocou no ar um deploy sem a página `/admin`.

A função de administração precisa de quatro variáveis no projeto Vercel:
`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE` e `ADMIN_EMAIL`.
A chave secreta fica só ali, nunca no repositório e nunca no navegador. Variável
nova só passa a valer no deploy seguinte.

No banco, `supabase/admin.sql` precisa ter rodado uma vez: ele acrescenta o e-mail
e a marca de senha provisória no perfil, e a função que a pessoa usa para desligar
essa marca depois de trocar a senha.

## No dia a dia

Salva sozinho. Cada alteração vai para o banco em menos de um segundo e o canto do
cabeçalho mostra "Salvando…" e depois "Salvo".

Se duas pessoas gravarem no mesmo instante, a segunda recebe um aviso e a tela é
recarregada com o que está no banco — ninguém escreve por cima do trabalho do
outro em silêncio.

Cada pessoa troca a própria senha no rodapé da lateral esquerda. Quem esqueceu usa
**Esqueci minha senha** na tela de entrada, e o Supabase manda o link.

### Atividades de comercial e marketing

A tela **Atividades** (atalho `G` `A`) guarda o trabalho que não pende de negócio
nenhum: campanhas, materiais, listas para prospectar, uma apresentação a refazer.

Sete campos: **nome da atividade**, **breve descrição**, **área** (Comercial ou
Marketing), **responsável** (quem faz), **demandante** (quem pediu), **status** e
as datas de **início** e de **fim**. A lista mostra o essencial numa linha; o
resto fica na gaveta, que abre clicando no nome.

A lista é densa e agrupada por status — **A fazer**, **Em andamento**,
**Concluída** — com os cabeçalhos grudando no topo ao rolar. O círculo à
esquerda de cada linha é o status: clicar nele abre o seletor dos três. O `+` no
cabeçalho de um grupo cria já naquele status.

O atraso é medido pela **data de fim**, e só ela: uma atividade que começou e
não acabou não está atrasada. Data em branco é estado legítimo para atividade
nova — é a pastilha "sem data de fim" que lembra de marcar, e o painel não
inventa prazo. Atividade concluída não tem atraso: coisa entregue não está
vencida.

**Concluir exige evidência**, como a pendência de um negócio: descreva o que foi
entregue, ou cole um link que comprove (o cartão no Linear, o material, a pasta).
Reabrir exige o motivo por escrito — link não explica o que mudou. Tudo fica
registrado com quem fez e quando, e nada é sobrescrito.

Tudo o que está em aberto aqui também aparece no **To Do** da pessoa
responsável, marcado como atividade, com o demandante na coluna de quem
responde: cadastrar e mover status é na tela de Atividades, cobrar é no To Do.

#### Agrupar e compartilhar

O interruptor **agrupar por** troca o eixo da lista: por **status** responde "em
que pé está o plano"; por **responsável** responde "o que está no nome de cada
um" — e é essa a vista que se compartilha. Cada pessoa vira uma seção com a
contagem, quantos P0 e quantas atrasadas, ordenada por quem tem mais coisa
atrasada e mais P0 primeiro. Quem não tem responsável fica no fim: é lacuna, não
pessoa.

**Encaminhar** (na barra, ou no cabeçalho de cada pessoa) abre uma gaveta com:

- o **link** — `.../#atividades?agrupar=quem`, mais `quem=`, `area=` e `filtro=`
  quando estiverem ligados, para quem recebe ver a mesma lista de quem enviou;
- a **mensagem** em texto puro, agrupada por responsável, com prioridade, área,
  status e data por extenso (em WhatsApp não há cor nem etiqueta);
- botões de copiar, WhatsApp e e-mail.

O link é **endereço, não dado**: quem abre entra com a conta dele e o banco
decide o que ele pode ver. Um link com `quem=` cai na lista daquela pessoa com a
pastilha "Só de <nome>" e o × que devolve a lista inteira; se aquela pessoa não
tiver nada com aqueles filtros, o painel diz isso em vez de abrir tudo em
silêncio.

Atalhos: `J` e `K` andam pela lista, `Enter` abre a gaveta, `S` abre o seletor de
status da linha em foco, `C` cria uma atividade.

Atividade não tem frente, tipo de venda nem público: são atributos de negócio.
Por isso, nesta tela, o único filtro que sobra é o de responsável.

**Exportar** baixa o documento do pipeline inteiro: parceiros, clientes,
negócios, pendências, atividades, histórico de etapas e a lista de responsáveis. O arquivo é
idêntico ao que está no banco — dá para reimportar e voltar ao mesmo estado.

Antes de gerar, o painel relê o banco, para o backup não sair de uma aba aberta
desde a manhã. O nome do arquivo traz data e hora
(`oren-backup-2026-08-24-1330.json`) e, se algo saiu do combinado, o nome diz:
`-NAO-CONFERIDO-COM-O-BANCO` quando a releitura falhou,
`-COM-ALTERACAO-NAO-GRAVADA` quando havia edição pendente nesta aba. Dentro do
arquivo, a chave `_backup` registra data, versão do documento, quem exportou e a
contagem de registros; a importação descarta essa chave.

**O que não entra nesse arquivo:** as contas de acesso (tabela `perfil` e
`auth.users`) e o histórico de versões (`pipeline_historico`). Isso vive no banco.
`supabase/backup-completo.sql` tem as consultas para baixar cada um em CSV.

## O que o banco guarda

O pipeline inteiro é um documento numa linha só, com número de versão. A cada
gravação, a versão anterior é arquivada em `pipeline_historico` — nada se perde
por alteração errada.

Versão, data e autor são carimbados pelo próprio banco, não pelo navegador. Não
existe como mentir sobre quem alterou.

Para ver o que existia antes:

```sql
select versao, atualizado_em, atualizado_por,
       jsonb_array_length(dados->'deals') as negocios
  from public.pipeline_historico order by versao desc;
```

## Limites do plano gratuito do Supabase

- 500 MB de banco. Nosso documento tem menos de 100 KB.
- **O projeto pausa depois de cerca de uma semana sem nenhum acesso.** Voltar é um
  clique no painel do Supabase. Com o time usando toda semana, não acontece.

## O que foi testado, e o que não foi

As regras de acesso foram testadas de verdade, contra um Postgres com o mesmo
esquema: sem login o banco recusa leitura e gravação, leitor não grava, e a
tentativa de forjar versão ou autor é sobrescrita pelo gatilho.

O painel foi testado contra uma imitação dos endpoints do Supabase: entrada,
senha errada, carga dos dados, gravação, renovação de token vencido, conflito
entre duas abas, troca de senha e acesso somente leitura.

O que **não** foi possível testar aqui: o Supabase real, porque o ambiente onde
este código foi escrito não tem acesso à rede do Supabase. O primeiro login no
projeto de verdade é a hora de conferir.

## Passo a passo, do zero ao ar

Tudo pelo painel do Supabase. Não precisa de terminal.

**1. Criar as tabelas.** SQL Editor → New query → cole o `supabase/schema.sql`
inteiro → Run. Roda uma vez só.

**2. Carregar os dados.** SQL Editor → New query → cole o
`supabase/carga-inicial.sql` → Run. São os 43 parceiros, 4 clientes e 47
negócios. No fim ele mostra uma tabelinha com esses três números: se bater, deu
certo. (Alternativa: pular este passo e usar **Importar** dentro do painel, com o
`carga-inicial.json`.)

**3. Criar as pessoas.** Authentication → Users → **Add user** → *Create new
user*. Para cada uma:

- E-mail e senha
- Marque **Auto Confirm User** (senão a pessoa fica esperando um e-mail de
  confirmação que ninguém mandou)
- No campo **User Metadata**, escreva quem é a pessoa:

```json
{"nome": "Adriano"}
```

Para alguém que só pode olhar, sem mexer em nada:

```json
{"nome": "Ana", "papel": "leitor"}
```

Deixando o metadata em branco, o nome sai do e-mail e o papel é editor. Papel
escrito errado vira editor — nunca impede o cadastro.

**4. Entrar.** Abra o `painel-oren.html` e entre com uma das contas.

Para mudar o papel de alguém depois, sem recriar a conta, no SQL Editor:

```sql
update public.perfil set papel = 'leitor' where nome = 'Ana';
```

