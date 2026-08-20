// Cria as tabelas. Rodar de novo é seguro: tudo é "if not exists".
import { pool, consulta } from "./db.js";

const SQL = `
create table if not exists usuario (
  id          serial primary key,
  email       text not null unique,
  nome        text not null,
  senha_hash  text not null,
  papel       text not null default 'editor' check (papel in ('editor','leitor')),
  ativo       boolean not null default true,
  criado_em   timestamptz not null default now()
);

create table if not exists sessao (
  token      text primary key,
  usuario_id integer not null references usuario(id) on delete cascade,
  criada_em  timestamptz not null default now(),
  expira_em  timestamptz not null
);
create index if not exists sessao_expira_idx on sessao (expira_em);

-- O pipeline inteiro é um documento só. Uma linha, sempre a de id 1.
create table if not exists pipeline (
  id             integer primary key default 1 check (id = 1),
  dados          jsonb   not null,
  versao         integer not null default 1,
  atualizado_em  timestamptz not null default now(),
  atualizado_por text
);

-- Toda gravação guarda a versão anterior. É a rede de segurança contra
-- alteração errada: dá para ver e voltar.
create table if not exists pipeline_historico (
  id             serial primary key,
  versao         integer not null,
  dados          jsonb   not null,
  atualizado_em  timestamptz not null default now(),
  atualizado_por text
);
create index if not exists pipeline_historico_versao_idx on pipeline_historico (versao desc);
`;

await consulta(SQL);
console.log("Tabelas prontas: usuario, sessao, pipeline, pipeline_historico.");
await pool.end();
