-- Diagnóstico e reparo de acesso de UMA pessoa. Reutilizável: troque o e-mail,
-- o nome e a senha provisória nas três primeiras linhas de cada parte.
--
-- Serve para "não consegue entrar" e para "a redefinição de senha não chega".
-- Não escreve em public.pipeline: negócios, pendências e histórico não são
-- tocados por nada aqui. Não contém DELETE, DROP nem TRUNCATE.
--
-- ATENÇÃO: este arquivo fica num repositório público, então a senha NÃO mora
-- aqui. Troque <SENHA-PROVISORIA> antes de rodar; o bloco se recusa a rodar com
-- o lugar-tenente no lugar.

-- =========================================================== PARTE 1 · olhar
-- Tudo que decide se um login passa, numa linha. Zero linhas = a conta não
-- existe em auth.users, e é esse o problema.
select u.id,
       u.email,
       u.aud,
       u.role,
       u.email_confirmed_at is not null                    as confirmado,
       coalesce(u.encrypted_password,'') <> ''             as tem_senha,
       left(coalesce(u.encrypted_password,''),4)           as hash,
       u.banned_until, u.deleted_at,
       to_jsonb(u) ->> 'is_sso_user'                       as sso,
       to_jsonb(u) ->> 'is_anonymous'                      as anonima,
       (select count(*) from auth.identities i where i.user_id = u.id)   as identidades,
       (select i.identity_data->>'email' from auth.identities i
         where i.user_id = u.id and i.provider = 'email')  as email_na_identidade,
       p.nome, p.papel, p.senha_provisoria,
       u.last_sign_in_at, u.created_at
  from auth.users u
  left join public.perfil p on p.id = u.id
 where lower(u.email) = lower('afranio.chaves@orencorp.com');

-- ========================================================= PARTE 2 · reparo
do $$
declare
  v_email text := 'afranio.chaves@orencorp.com';
  v_nome  text := 'Afrânio';          -- só usado se o perfil ainda não existir
  v_senha text := '<SENHA-PROVISORIA>';
  v_id uuid; sch text; tem_pid boolean; v_pnome text;
begin
  if v_senha like '<%>' then
    raise exception 'Preencha a senha provisória antes de rodar. Nada foi alterado.';
  end if;
  if length(v_senha) < 8 then
    raise exception 'Senha provisória muito curta: o painel pede 8. Nada foi alterado.';
  end if;

  select id into v_id from auth.users where lower(email) = lower(v_email);
  if v_id is null then
    raise exception 'Não existe conta com o e-mail % em auth.users. Este script conserta conta existente; criar conta é pela tela /admin (ou Authentication > Users no Supabase), que passa pela API e monta identidade e perfil sozinha. Nada foi alterado.', v_email;
  end if;

  select n.nspname into sch from pg_proc pr
    join pg_namespace n on n.oid = pr.pronamespace where pr.proname = 'crypt' limit 1;
  if sch is null then raise exception 'pgcrypto ausente (função crypt). Nada foi alterado.'; end if;

  -- Confirmação, aud, role, banimento e exclusão lógica. banned_until = null
  -- TIRA um banimento e deleted_at = null DESFAZ uma exclusão: nenhum dos dois
  -- apaga coisa alguma.
  update auth.users
     set email_confirmed_at = coalesce(email_confirmed_at, now()),
         aud  = coalesce(nullif(aud,''),  'authenticated'),
         role = coalesce(nullif(role,''), 'authenticated'),
         banned_until = null, deleted_at = null,
         email_change = '', email_change_token_new = '', email_change_token_current = '',
         updated_at = now()
   where id = v_id;

  -- Duas bandeiras que fazem o GoTrue recusar senha sem olhar o hash.
  if exists (select 1 from information_schema.columns where table_schema='auth'
    and table_name='users' and column_name='is_sso_user') then
    execute 'update auth.users set is_sso_user = false where id = $1' using v_id;
  end if;
  if exists (select 1 from information_schema.columns where table_schema='auth'
    and table_name='users' and column_name='is_anonymous') then
    execute 'update auth.users set is_anonymous = false where id = $1' using v_id;
  end if;

  -- A senha, em bcrypt, que é o formato que o GoTrue lê.
  execute format('update auth.users set encrypted_password = %I.crypt($1, %I.gen_salt(''bf'')),
                  updated_at = now() where id = $2', sch, sch) using v_senha, v_id;

  -- A identidade do provedor e-mail: cria se faltar, sincroniza se existir.
  select exists (select 1 from information_schema.columns where table_schema='auth'
    and table_name='identities' and column_name='provider_id') into tem_pid;
  if exists (select 1 from auth.identities where user_id = v_id and provider = 'email') then
    update auth.identities
       set identity_data = jsonb_set(jsonb_set(identity_data,'{email}',to_jsonb(v_email),true),
                                     '{sub}', to_jsonb(v_id::text), true),
           updated_at = now()
     where user_id = v_id and provider = 'email';
  elsif tem_pid then
    insert into auth.identities (user_id, provider, provider_id, identity_data, created_at, updated_at)
    values (v_id,'email',v_id::text,
      jsonb_build_object('sub',v_id::text,'email',v_email,'email_verified',true), now(), now());
  else
    insert into auth.identities (user_id, provider, identity_data, created_at, updated_at)
    values (v_id,'email',
      jsonb_build_object('sub',v_id::text,'email',v_email,'email_verified',true), now(), now());
  end if;

  -- O perfil, que é o que o painel lê depois do login. Sem ele o login passa e
  -- a tela diz "sua conta entrou, mas não tem perfil cadastrado".
  -- Quando a linha já existe, nome e papel NÃO são sobrescritos: o nome é o que
  -- liga a pessoa aos negócios.
  select nome into v_pnome from public.perfil where id = v_id;
  if v_pnome is null then
    insert into public.perfil (id, nome, papel, senha_provisoria)
    values (v_id, v_nome, 'editor', true);
    raise notice 'Perfil criado como "%" (editor).', v_nome;
  else
    update public.perfil
       set senha_provisoria = true,
           papel = case when papel in ('editor','leitor') then papel else 'editor' end
     where id = v_id;
  end if;

  if exists (select 1 from information_schema.columns where table_schema='public'
    and table_name='perfil' and column_name='email') then
    execute 'update public.perfil set email = $1 where id = $2' using v_email, v_id;
  end if;

  raise notice 'Conta % pronta: %, confirmada, senha regravada, identidade e perfil em ordem.',
    v_id, v_email;
end $$;

-- ========================================================= PARTE 3 · veredito
-- Uma linha: "OK" ou o que ainda falta. Testa a senha pelo mesmo caminho que o
-- GoTrue testa. Se der erro em extensions.crypt, troque por public.crypt.
with alvo as (
  select u.id, u.email, u.encrypted_password, u.email_confirmed_at, u.aud, u.role,
         u.banned_until, u.deleted_at, u.last_sign_in_at,
         to_jsonb(u) ->> 'is_sso_user'  as sso,
         to_jsonb(u) ->> 'is_anonymous' as anon,
         p.nome, p.papel, p.senha_provisoria,
         (select i.identity_data->>'email' from auth.identities i
           where i.user_id = u.id and i.provider = 'email') as ident_email
    from auth.users u left join public.perfil p on p.id = u.id
   where lower(u.email) = lower('afranio.chaves@orencorp.com')
), avaliado as (
  select a.*, array_remove(array[
    case when a.email_confirmed_at is null            then 'e-mail não confirmado' end,
    case when coalesce(a.encrypted_password,'') = ''  then 'conta sem senha' end,
    case when left(coalesce(a.encrypted_password,''),3) not in ('$2a','$2b','$2y')
         then 'o hash da senha não é bcrypt' end,
    case when coalesce(a.encrypted_password,'') <> ''
          and a.encrypted_password <> extensions.crypt('<SENHA-PROVISORIA>', a.encrypted_password)
         then 'a senha informada não é a desta conta' end,
    case when coalesce(a.aud,'') = '' or coalesce(a.role,'') = '' then 'aud ou role vazios' end,
    case when a.banned_until is not null              then 'conta banida' end,
    case when a.deleted_at is not null                then 'conta excluída' end,
    case when a.sso  = 'true'                         then 'conta marcada como SSO' end,
    case when a.anon = 'true'                         then 'conta marcada como anônima' end,
    case when a.nome is null                          then 'sem linha em public.perfil' end,
    case when a.papel is not null and a.papel not in ('editor','leitor')
         then 'papel inválido: ' || a.papel end,
    case when a.ident_email is null                   then 'sem identidade de e-mail' end
  ], null) as problemas from alvo a
)
select email, nome, papel,
       senha_provisoria as vai_pedir_senha_nova,
       last_sign_in_at  as ultimo_acesso,
       case when cardinality(problemas) = 0
            then 'OK -- o login deve passar com esta senha'
            else 'AINDA FALTA: ' || array_to_string(problemas, ' | ') end as veredito
  from avaliado;
