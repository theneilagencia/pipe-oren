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

## No dia a dia

Salva sozinho. Cada alteração vai para o banco em menos de um segundo e o canto do
cabeçalho mostra "Salvando…" e depois "Salvo".

Se duas pessoas gravarem no mesmo instante, a segunda recebe um aviso e a tela é
recarregada com o que está no banco — ninguém escreve por cima do trabalho do
outro em silêncio.

Cada pessoa troca a própria senha no rodapé da lateral esquerda. Quem esqueceu usa
**Esqueci minha senha** na tela de entrada, e o Supabase manda o link.

**Exportar** baixa um arquivo com todos os dados. Vale como cópia de segurança
fora do Supabase, e é o caminho de volta se você quiser mudar de ferramenta.

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

