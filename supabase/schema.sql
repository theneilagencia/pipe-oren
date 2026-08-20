-- =============================================================================
-- Oren · esquema para rodar SÓ no Supabase
-- Cole isto inteiro no SQL Editor do Supabase e execute uma vez.
-- =============================================================================
-- Desenho: o painel no navegador fala direto com o banco. Quem protege o dado
-- não é servidor nenhum, são as políticas de acesso (RLS) daqui. Ninguém sem
-- login vê nada, e só quem é editor grava.

-- Nome e papel de cada pessoa, amarrado ao usuário do Auth do Supabase.
create table if not exists public.perfil (
  id        uuid primary key references auth.users (id) on delete cascade,
  nome      text not null,
  papel     text not null default 'editor' check (papel in ('editor', 'leitor')),
  criado_em timestamptz not null default now()
);

-- O pipeline inteiro é um documento só: uma linha, sempre a de id 1.
create table if not exists public.pipeline (
  id             integer primary key default 1 check (id = 1),
  dados          jsonb   not null default '{"partners":[],"customers":[],"deals":[]}'::jsonb,
  versao         integer not null default 1,
  atualizado_em  timestamptz not null default now(),
  atualizado_por text
);

-- Cada gravação arquiva a versão que estava lá antes.
create table if not exists public.pipeline_historico (
  id             bigserial primary key,
  versao         integer not null,
  dados          jsonb   not null,
  atualizado_em  timestamptz not null default now(),
  atualizado_por text
);
create index if not exists pipeline_historico_versao_idx
  on public.pipeline_historico (versao desc);

-- O navegador manda só os dados novos. Versão, data e autor são carimbados aqui,
-- onde ninguém consegue mentir: nem sobre quem alterou, nem sobre qual versão é.
create or replace function public.carimba_pipeline()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.pipeline_historico (versao, dados, atualizado_em, atualizado_por)
  values (old.versao, old.dados, old.atualizado_em, old.atualizado_por);

  new.versao := old.versao + 1;
  new.atualizado_em := now();
  new.atualizado_por := coalesce(
    (select nome from public.perfil where id = auth.uid()),
    'desconhecido'
  );
  return new;
end;
$$;

drop trigger if exists pipeline_carimbo on public.pipeline;
create trigger pipeline_carimbo
  before update on public.pipeline
  for each row execute function public.carimba_pipeline();

-- Garante que a linha existe.
insert into public.pipeline (id) values (1) on conflict (id) do nothing;

-- Quando você criar uma pessoa em Authentication → Users, o perfil nasce junto.
--
-- No formulário do Supabase existe o campo "User Metadata". Se você preencher
--   {"nome": "Adriano", "papel": "leitor"}
-- o perfil nasce com esse nome e esse papel. Deixando em branco, o nome sai do
-- e-mail e o papel é editor.
--
-- Papel inválido não derruba o cadastro: qualquer coisa diferente de "leitor"
-- vira editor. Um erro aqui impediria a pessoa de ser criada, e o dono do
-- projeto não teria como adivinhar o motivo.
create or replace function public.cria_perfil()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  meta   jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  v_nome text;
  v_papel text;
begin
  v_nome := nullif(trim(coalesce(meta->>'nome', meta->>'name', '')), '');
  if v_nome is null then
    v_nome := initcap(split_part(coalesce(new.email, 'pessoa'), '@', 1));
  end if;

  v_papel := case lower(trim(coalesce(meta->>'papel', meta->>'role', '')))
               when 'leitor' then 'leitor'
               else 'editor'
             end;

  insert into public.perfil (id, nome, papel)
  values (new.id, v_nome, v_papel)
  on conflict (id) do nothing;
  return new;
end;
$$;

-- Criar gatilho em auth.users depende de privilégio. Se o seu projeto recusar,
-- o resto do script continua valendo: você só precisará inserir o perfil na mão
-- depois de criar cada pessoa (o comando está no README).
do $$
begin
  drop trigger if exists cria_perfil_no_cadastro on auth.users;
  create trigger cria_perfil_no_cadastro
    after insert on auth.users
    for each row execute function public.cria_perfil();
exception when insufficient_privilege or undefined_table then
  raise notice 'Sem privilégio para o gatilho em auth.users. Insira o perfil na mão (veja o README).';
end $$;

-- =============================================================================
-- REGRAS DE ACESSO
-- =============================================================================
alter table public.perfil             enable row level security;
alter table public.pipeline           enable row level security;
alter table public.pipeline_historico enable row level security;

-- Sem login (chave publicável no navegador) não existe política nenhuma que
-- permita: todo acesso é negado por omissão.

drop policy if exists "perfil: quem entrou lê todos" on public.perfil;
create policy "perfil: quem entrou lê todos"
  on public.perfil for select to authenticated using (true);

drop policy if exists "pipeline: quem entrou lê" on public.pipeline;
create policy "pipeline: quem entrou lê"
  on public.pipeline for select to authenticated using (true);

-- Gravar é só para editor. Leitor recebe recusa do próprio banco.
drop policy if exists "pipeline: editor grava" on public.pipeline;
create policy "pipeline: editor grava"
  on public.pipeline for update to authenticated
  using (exists (select 1 from public.perfil p where p.id = auth.uid() and p.papel = 'editor'))
  with check (true);

drop policy if exists "historico: quem entrou lê" on public.pipeline_historico;
create policy "historico: quem entrou lê"
  on public.pipeline_historico for select to authenticated using (true);

-- Ninguém apaga nem insere histórico pelo navegador: só o gatilho escreve lá,
-- e ele roda com permissão própria.

-- =============================================================================
-- PERMISSÕES DE TABELA (o RLS filtra as linhas; isto libera o verbo)
-- =============================================================================
grant usage on schema public to anon, authenticated;
grant select                     on public.perfil             to authenticated;
grant select, update             on public.pipeline           to authenticated;
grant select                     on public.pipeline_historico to authenticated;
revoke all on public.perfil, public.pipeline, public.pipeline_historico from anon;
