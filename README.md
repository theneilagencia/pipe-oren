# Oren · Painel comercial

Painel de pipeline comercial com os dados no Postgres e entrada por e-mail e senha.

O painel em si é um arquivo HTML único, sem framework e sem dependência externa.
O servidor faz três coisas: entrega esse arquivo, guarda quem pode entrar, e lê e
grava o pipeline no banco.

## Como rodar na sua máquina

```bash
npm install
cp .env.example .env          # preencha o DATABASE_URL
npm run migrate               # cria as tabelas
npm run seed                  # cria as pessoas e carrega o pipeline inicial
npm start                     # http://localhost:3000
```

O `seed` imprime uma senha temporária para cada pessoa. Anote: elas não aparecem
de novo. Cada um troca a própria senha no painel, no rodapé da lateral esquerda.

Para criar ou reajustar alguém depois:

```bash
node src/usuario.js maria@empresa.com "Maria" senhaComOitoOuMais editor
```

O papel pode ser `editor` (mexe em tudo) ou `leitor` (só vê).

## Como publicar no Render

1. Suba este repositório no GitHub.
2. No Render: **New → Blueprint**, aponte para o repositório. O `render.yaml`
   cria o banco e o serviço já conectados.
3. No primeiro deploy, abra os **Logs** do serviço: as senhas temporárias
   aparecem ali uma única vez.
4. Entre no endereço que o Render devolver, e cada pessoa troca a própria senha.

Dois avisos sobre o plano free, que o `render.yaml` usa por padrão:

- O serviço **dorme** quando ninguém acessa; o primeiro acesso depois disso
  demora alguns segundos.
- O banco free **expira**. A data aparece no painel do Render. Para uso de
  verdade, mude os dois `plan: free` para um plano pago.

Enquanto estiver no free, use **Exportar** de vez em quando: baixa um arquivo com
todos os dados, que serve de cópia de segurança fora do Render.

## De graça, sem prazo de validade

No Render, o que expira é **só o banco** — o serviço gratuito não expira, apenas
dorme. Então a saída é separar as duas coisas:

| Peça | Onde | O que você aceita |
|---|---|---|
| Aplicação | Render, plano free | dorme sem uso; o primeiro acesso demora cerca de um minuto |
| Banco | Neon, plano free | 0,5 GB e pausa por inatividade, mas **não expira e não apaga dado** |

Nosso documento tem menos de 100 KB, então 0,5 GB é folga de sobra.

Para montar assim: apague o bloco `databases` do `render.yaml`, crie o banco no
Neon, e cole a connection string dele na variável `DATABASE_URL` do serviço, pelo
painel do Render. Nenhuma linha de código muda — o servidor liga TLS sozinho
quando o banco não é local.

Se um minuto de espera no primeiro acesso for inaceitável, as saídas são pagar o
plano mais barato do Render, ou levar o contêiner para o Google Cloud Run, que
tem cota gratuita permanente e acorda mais rápido — em troca de exigir cartão
cadastrado e um Dockerfile.

## Como os dados são guardados

O pipeline inteiro é um documento JSON numa linha só da tabela `pipeline`, com um
número de versão. Ao salvar, o painel manda a versão que recebeu; se outra pessoa
gravou nesse meio tempo, o servidor recusa e devolve os dados novos, e o painel
avisa em vez de passar por cima do trabalho alheio.

Toda gravação guarda a versão anterior em `pipeline_historico`. Nada se perde por
alteração errada: dá para consultar `GET /api/versoes` e ver o que existia antes.

Quando duas pessoas precisarem editar negócios diferentes ao mesmo tempo sem se
atropelar, o próximo passo é quebrar esse documento em tabelas por registro. Até
lá, com um punhado de usuários, o documento com versão dá conta.

## Rotas

| Rota | O que faz |
|---|---|
| `POST /api/login` | entra com e-mail e senha, devolve o cookie de sessão |
| `POST /api/logout` | sai |
| `GET /api/eu` | quem está logado |
| `POST /api/senha` | a própria pessoa troca a própria senha |
| `GET /api/pipeline` | lê o pipeline e a versão atual |
| `PUT /api/pipeline` | grava; recusa com 409 se a versão estiver velha |
| `GET /api/versoes` | lista as versões guardadas |
| `GET /health` | usado pelo Render para saber se está de pé |

Tudo abaixo de `/api`, fora login e logout, exige sessão. O HTML entregue não traz
dado nenhum embutido: o pipeline só chega depois da autenticação.

## Segurança

- Senha guardada com scrypt e sal por pessoa, nunca em texto puro.
- Sessão em cookie `HttpOnly`, `SameSite=Lax`, `Secure` quando publicado.
- Sem cadastro aberto: só existe quem foi criado por linha de comando.
- Cabeçalhos fechados, inclusive `Content-Security-Policy` e `noindex`.
- Trocar a senha derruba as outras sessões da pessoa.
