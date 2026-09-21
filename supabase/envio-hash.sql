-- =============================================================================
-- Oren · guardar só a impressão (SHA-256) do token de envio
-- Cole no SQL Editor do Supabase e execute uma vez.
-- =============================================================================
-- Antes, a tabela guardava o token em claro. Qualquer pessoa logada no painel
-- — inclusive quem só tem papel de leitor — podia ler a tabela e usar o link
-- de qualquer cliente. Agora fica só o hash: serve para achar o registro, não
-- serve para abrir nada.
--
-- Os links já entregues continuam valendo: o hash é calculado a partir dos
-- tokens que estão aqui, e depois a coluna em claro é apagada.

do $$
begin
  if exists (select 1 from information_schema.columns
              where table_schema = 'public' and table_name = 'envio'
                and column_name = 'token') then

    alter table public.envio add column if not exists token_hash text;

    update public.envio
       set token_hash = encode(sha256(convert_to(token, 'UTF8')), 'hex')
     where token_hash is null;

    alter table public.envio drop constraint if exists envio_pkey;
    alter table public.envio drop column token;
    alter table public.envio alter column token_hash set not null;
    alter table public.envio add constraint envio_pkey primary key (token_hash);

  end if;
end $$;

-- Conferência: 'token' tem de sumir e 'token_hash' tem de ser a chave.
select
  (select count(*) from information_schema.columns
    where table_schema='public' and table_name='envio' and column_name='token')      as coluna_em_claro_deve_ser_0,
  (select count(*) from information_schema.columns
    where table_schema='public' and table_name='envio' and column_name='token_hash') as coluna_hash_deve_ser_1,
  (select count(*) from public.envio)                                               as links,
  (select count(*) from public.envio
     where revogado_em is null and expira_em > now())                                as ativos;
