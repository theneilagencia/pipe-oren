-- Troca o e-mail de acesso do Paulo para paulo.lopes@orencorp.com.
-- 25/08/2026
--
-- Por que isto não mexe em mais nada:
--
-- O painel identifica a pessoa por public.perfil.nome, nunca pelo e-mail. O
-- e-mail é lido da sessão só para aparecer na tela de troca de senha e para o
-- servidor decidir quem é o administrador -- e nunca é gravado no documento do
-- pipeline. Os negócios do Paulo, as pendências, o To Do e o histórico apontam
-- para a string "Paulo", que não muda aqui. O id da conta também não muda,
-- então perfil, papel e senha continuam os mesmos.
--
-- COMO RODAR: cole tudo no SQL Editor do Supabase e mande rodar de uma vez.
-- O bloco abaixo é um comando só, então ou tudo se aplica ou nada se aplica.
-- Ele para com erro em voz alta -- sem gravar nada -- se não achar exatamente
-- um perfil chamado Paulo, ou se o e-mail novo já pertencer a outra conta.
-- Rodar duas vezes é seguro.
--
-- Casa por perfil.nome de propósito: assim não é preciso saber o e-mail antigo,
-- e não há risco de acertar a conta errada por digitação.

do $$
declare
  v_novo   text := 'paulo.lopes@orencorp.com';
  v_nome   text := 'Paulo';
  v_id     uuid;
  v_antigo text;
  n        integer;
  ident    integer;
begin
  -- 1. Uma pessoa, e uma só.
  select count(*) into n from public.perfil where nome = v_nome;
  if n <> 1 then
    raise exception 'Esperava exatamente 1 perfil chamado "%", encontrei %. Nada foi alterado.', v_nome, n;
  end if;

  select p.id, u.email into v_id, v_antigo
    from public.perfil p join auth.users u on u.id = p.id
   where p.nome = v_nome;

  if v_id is null then
    raise exception 'O perfil "%" não tem conta correspondente em auth.users. Nada foi alterado.', v_nome;
  end if;

  -- 2. O e-mail novo não pode ser de outra pessoa. O índice único também
  --    barraria, mas com uma mensagem que não diz de quem é o endereço.
  if exists (select 1 from auth.users where lower(email) = lower(v_novo) and id <> v_id) then
    raise exception 'O e-mail % já pertence a outra conta. Nada foi alterado.', v_novo;
  end if;

  -- 3. A credencial. Os campos de email_change são limpos porque uma troca
  --    administrativa não é uma troca pedida pelo usuário: deixar token
  --    pendente ali faz o GoTrue pedir uma confirmação que ninguém pediu.
  update auth.users
     set email = v_novo,
         email_change = '',
         email_change_token_new = '',
         email_change_token_current = '',
         updated_at = now()
   where id = v_id;

  -- 4. A cópia do e-mail dentro de auth.identities.identity_data. Sem este
  --    passo o painel do Supabase e a recuperação de senha continuam vendo o
  --    endereço antigo -- é o erro clássico de trocar e-mail por SQL.
  update auth.identities
     set identity_data = jsonb_set(identity_data, '{email}', to_jsonb(v_novo), true),
         updated_at = now()
   where user_id = v_id and provider = 'email';
  get diagnostics ident = row_count;

  -- 5. A cópia em public.perfil.email. A coluna existe no banco em uso mas não
  --    no schema canônico, então só age se existir.
  if exists (
    select 1 from information_schema.columns
     where table_schema = 'public' and table_name = 'perfil' and column_name = 'email'
  ) then
    execute 'update public.perfil set email = $1 where id = $2' using v_novo, v_id;
  end if;

  raise notice 'Pronto. % : %  ->  %  (id %, % identidade(s) atualizada(s))',
    v_nome, coalesce(v_antigo, '(sem e-mail)'), v_novo, v_id, ident;
end $$;

-- ------------------------------------------------------------- conferência
-- O e-mail novo nos três lugares, o mesmo id, e a conta ainda confirmada.
select p.id, p.nome, p.papel, u.email,
       u.email_confirmed_at is not null as confirmado,
       i.identity_data->>'email'       as email_na_identidade
  from public.perfil p
  join auth.users u on u.id = p.id
  left join auth.identities i on i.user_id = p.id and i.provider = 'email'
 where p.nome = 'Paulo';

-- A prova de que o pipeline não foi tocado: mesma versão, mesmos registros,
-- e o Paulo com os mesmos negócios no nome.
select versao,
       jsonb_array_length(dados->'deals')     as negocios,
       jsonb_array_length(dados->'customers') as clientes,
       jsonb_array_length(dados->'partners')  as parceiros,
       (select count(*) from jsonb_array_elements(dados->'deals') d
         where d->>'responsavel' = 'Paulo')   as negocios_do_paulo
  from public.pipeline where id = 1;
