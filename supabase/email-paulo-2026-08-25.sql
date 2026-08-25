-- Troca o e-mail de acesso do Paulo para paulo.lopes@orencorp.com.
-- 25/08/2026
--
-- Por que isto não mexe em mais nada:
--
-- O painel identifica a pessoa por public.perfil.nome, nunca pelo e-mail. O
-- e-mail é lido da sessão só para aparecer na tela de troca de senha e para o
-- servidor decidir quem é o administrador -- e nunca é gravado no documento do
-- pipeline. Os 11 negócios do Paulo, as pendências, o To Do e o histórico
-- apontam para a string "Paulo", que não muda aqui. O id da conta também não
-- muda, então perfil, papel e senha continuam os mesmos.
--
-- Rode no SQL Editor do Supabase, um passo por vez, conferindo o resultado.
-- Casa por perfil.nome de propósito: assim não é preciso saber o e-mail antigo,
-- e não há risco de acertar a conta errada por digitação.

-- ---------------------------------------------------------------- 1. conferir
-- Tem de devolver EXATAMENTE UMA linha. Zero ou duas, pare aqui.
select p.id, p.nome, p.papel, u.email as email_atual,
       u.email_confirmed_at is not null as confirmado
  from public.perfil p
  join auth.users u on u.id = p.id
 where p.nome = 'Paulo';

-- Tem de devolver ZERO linhas: o e-mail novo não pode já pertencer a alguém.
select id, email from auth.users
 where lower(email) = lower('paulo.lopes@orencorp.com');

-- ---------------------------------------------- 2. o e-mail em auth.users
-- Os campos de email_change são limpos porque uma troca administrativa não é
-- uma troca pedida pelo usuário: deixar token pendente ali faz o GoTrue
-- perguntar por uma confirmação que ninguém pediu.
update auth.users u
   set email = 'paulo.lopes@orencorp.com',
       email_change = '',
       email_change_token_new = '',
       email_change_token_current = '',
       updated_at = now()
  from public.perfil p
 where p.id = u.id and p.nome = 'Paulo';

-- --------------------------------------- 3. a cópia do e-mail na identidade
-- auth.identities guarda o e-mail dentro de identity_data. Sem este passo o
-- painel do Supabase e alguns fluxos de recuperação continuam vendo o antigo.
update auth.identities i
   set identity_data = jsonb_set(i.identity_data, '{email}',
         to_jsonb('paulo.lopes@orencorp.com'::text), true),
       updated_at = now()
  from public.perfil p
 where p.id = i.user_id and p.nome = 'Paulo' and i.provider = 'email';

-- ------------------------------------ 4. a cópia do e-mail em public.perfil
-- A coluna existe em alguns projetos e não em outros -- o schema canônico não
-- a tem, mas a função de administração a consulta. O bloco só age se ela
-- existir, e não falha se não existir.
do $$
begin
  if exists (
    select 1 from information_schema.columns
     where table_schema = 'public' and table_name = 'perfil' and column_name = 'email'
  ) then
    update public.perfil set email = 'paulo.lopes@orencorp.com' where nome = 'Paulo';
  end if;
end $$;

-- ------------------------------------------------------------- 5. conferência
-- O e-mail novo, a conta confirmada, e o mesmo id de antes.
select p.id, p.nome, p.papel, u.email, u.email_confirmed_at is not null as confirmado,
       i.identity_data->>'email' as email_na_identidade
  from public.perfil p
  join auth.users u on u.id = p.id
  left join auth.identities i on i.user_id = p.id and i.provider = 'email'
 where p.nome = 'Paulo';

-- E a prova de que o pipeline não foi tocado: o documento continua na mesma
-- versão, e o Paulo continua com os mesmos negócios no nome.
select versao,
       jsonb_array_length(dados->'deals')     as negocios,
       jsonb_array_length(dados->'customers') as clientes,
       jsonb_array_length(dados->'partners')  as parceiros,
       (select count(*) from jsonb_array_elements(dados->'deals') d
         where d->>'responsavel' = 'Paulo')   as negocios_do_paulo
  from public.pipeline where id = 1;
