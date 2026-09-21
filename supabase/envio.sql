-- =============================================================================
-- Oren · links de envio de documentos
-- Cole no SQL Editor do Supabase e execute uma vez.
-- =============================================================================
-- Um link por negócio, com validade e revogação. O token é gerado pela função
-- de servidor, não aqui, e é longo o bastante para não ser adivinhado.
--
-- Nenhuma política para anon, de propósito: o cliente que abre o link NÃO fala
-- com o banco. Ele fala com /api/envio, que valida o token e usa a chave
-- secreta do lado de fora do navegador. Abrir o banco para visitante anônimo
-- seria trocar uma porta controlada por uma porta aberta.

create table if not exists public.envio (
  token         text primary key,
  negocio_id    text not null,
  criado_em     timestamptz not null default now(),
  criado_por    text,
  expira_em     timestamptz not null,
  revogado_em   timestamptz,
  ultimo_acesso timestamptz,
  acessos       integer not null default 0,
  enviados      integer not null default 0
);
create index if not exists envio_negocio_idx on public.envio (negocio_id);

alter table public.envio enable row level security;

-- O painel mostra o estado do link: criado quando, vale até quando, se foi
-- usado. Só leitura, e só para quem entrou.
drop policy if exists "envio: quem entrou lê" on public.envio;
create policy "envio: quem entrou lê"
  on public.envio for select to authenticated using (true);

grant usage on schema public to anon, authenticated;
grant select on public.envio to authenticated;
revoke all on public.envio from anon;

-- Conferência: deve devolver a tabela vazia, sem erro.
select count(*) as links, 0 as ativos from public.envio;
