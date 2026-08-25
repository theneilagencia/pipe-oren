-- Diagnóstico e reparo do acesso do Paulo (paulo.lopes@orencorp.com).
-- 25/08/2026
--
-- Rode a PARTE 1 e me mande o resultado. Se quiser resolver direto, a PARTE 2
-- conserta as seis causas possíveis de uma vez -- ela é um comando só, atômico,
-- e não toca em nada além da conta do Paulo.
--
-- ATENÇÃO: a PARTE 2 pede a senha provisória na primeira linha. Este arquivo
-- fica num repositório público, então a senha NÃO mora aqui: troque
-- <SENHA-PROVISORIA> antes de rodar. O bloco se recusa a rodar sem isso.

-- =========================================================== PARTE 1 · olhar
-- Tudo que decide se um login passa ou não, numa linha por conta. Traz a conta
-- pelo e-mail novo E o perfil chamado Paulo, para o caso de serem contas
-- diferentes -- que é uma das causas.
select u.id,
       u.email,
       u.aud,
       u.role,
       u.email_confirmed_at is not null                          as confirmado,
       coalesce(u.encrypted_password, '') <> ''                   as tem_senha,
       left(coalesce(u.encrypted_password, ''), 4)                as hash,
       u.banned_until,
       u.deleted_at,
       to_jsonb(u) ->> 'is_sso_user'                               as sso,
       to_jsonb(u) ->> 'is_anonymous'                              as anonima,
       coalesce(u.email_change, '')                               as troca_pendente,
       (select count(*) from auth.identities i where i.user_id = u.id)          as identidades,
       (select i.identity_data->>'email' from auth.identities i
         where i.user_id = u.id and i.provider = 'email')         as email_na_identidade,
       p.nome, p.papel, p.senha_provisoria,
       u.last_sign_in_at
  from auth.users u
  left join public.perfil p on p.id = u.id
 where lower(u.email) = lower('paulo.lopes@orencorp.com')
    or p.nome = 'Paulo';

-- O que cada coluna acusa:
--   nome vazio ................. login passa e o painel diz "sem perfil cadastrado"
--   confirmado = false ......... o Supabase responde "Email not confirmed"
--   tem_senha = false .......... a senha provisória não chegou nesta conta
--   hash <> '$2a$' ou '$2b$' ... hash gravado em formato que o GoTrue não lê
--   aud/role vazios ............ conta criada por INSERT direto; login recusa
--   sso = true ................. GoTrue recusa senha nesta conta
--   anonima = true ............. idem
--   identidades = 0 ............ falta auth.identities; alguns fluxos recusam
--   email_na_identidade antigo . troca de e-mail feita só em auth.users
--   duas linhas ................ há duas contas, e o perfil está na errada

-- ========================================================= PARTE 2 · reparo
do $$
declare
  v_email  text := 'paulo.lopes@orencorp.com';
  v_senha  text := '<SENHA-PROVISORIA>';
  v_nome   text := 'Paulo';
  v_id     uuid;
  n        integer;
  sch      text;
  tem_pid  boolean;
  v_pnome  text;
  v_deals  integer;
begin
  -- O teste é pelo formato <...>, não pelo texto do lugar-tenente: quem preenche
  -- com "substituir tudo" trocaria os dois lados e o guarda dispararia à toa.
  if v_senha like '<%>' then
    raise exception 'Preencha a senha provisória na primeira linha do bloco antes de rodar. Nada foi alterado.';
  end if;
  if length(v_senha) < 8 then
    raise exception 'Senha provisória muito curta: o Supabase exige 6 e o painel pede 8. Nada foi alterado.';
  end if;

  -- A conta: pelo e-mail novo, ou pelo perfil chamado Paulo. Uma, e uma só.
  select count(distinct u.id) into n
    from auth.users u left join public.perfil p on p.id = u.id
   where lower(u.email) = lower(v_email) or p.nome = v_nome;
  if n <> 1 then
    raise exception 'Esperava 1 conta (e-mail % ou perfil "%"), encontrei %. Rode a PARTE 1 e resolva a duplicidade primeiro. Nada foi alterado.', v_email, v_nome, n;
  end if;
  select distinct u.id into v_id
    from auth.users u left join public.perfil p on p.id = u.id
   where lower(u.email) = lower(v_email) or p.nome = v_nome;

  -- Em que schema mora o pgcrypto deste projeto.
  select n2.nspname into sch
    from pg_proc pr join pg_namespace n2 on n2.oid = pr.pronamespace
   where pr.proname = 'crypt' limit 1;
  if sch is null then
    raise exception 'pgcrypto não está instalado (função crypt ausente). Nada foi alterado.';
  end if;

  -- 1. E-mail, confirmação, e o que trava login: aud, role, banimento, exclusão.
  --    A troca administrativa não deixa token de email_change pendente.
  update auth.users
     set email = v_email,
         email_confirmed_at = coalesce(email_confirmed_at, now()),
         aud  = coalesce(nullif(aud, ''),  'authenticated'),
         role = coalesce(nullif(role, ''), 'authenticated'),
         banned_until = null,
         deleted_at = null,
         email_change = '',
         email_change_token_new = '',
         email_change_token_current = '',
         updated_at = now()
   where id = v_id;

  -- 1b. Duas bandeiras que fazem o GoTrue recusar senha sem nem olhar o hash,
  --     e que respondem exatamente "Invalid login credentials": conta marcada
  --     como de SSO, e conta anônima. As colunas não existem em projeto antigo,
  --     então cada uma só é tocada se existir.
  if exists (select 1 from information_schema.columns
    where table_schema='auth' and table_name='users' and column_name='is_sso_user') then
    execute 'update auth.users set is_sso_user = false where id = $1 and is_sso_user is distinct from false' using v_id;
  end if;
  if exists (select 1 from information_schema.columns
    where table_schema='auth' and table_name='users' and column_name='is_anonymous') then
    execute 'update auth.users set is_anonymous = false where id = $1 and is_anonymous is distinct from false' using v_id;
  end if;

  -- 2. A senha, em bcrypt, que é o formato que o GoTrue lê.
  execute format(
    'update auth.users set encrypted_password = %I.crypt($1, %I.gen_salt(''bf'')), updated_at = now() where id = $2',
    sch, sch) using v_senha, v_id;

  -- 3. A identidade do provedor e-mail: cria se faltar, sincroniza se existir.
  select exists (select 1 from information_schema.columns
    where table_schema='auth' and table_name='identities' and column_name='provider_id')
    into tem_pid;

  if exists (select 1 from auth.identities where user_id = v_id and provider = 'email') then
    update auth.identities
       set identity_data = jsonb_set(
             jsonb_set(identity_data, '{email}', to_jsonb(v_email), true),
             '{sub}', to_jsonb(v_id::text), true),
           updated_at = now()
     where user_id = v_id and provider = 'email';
  elsif tem_pid then
    insert into auth.identities (user_id, provider, provider_id, identity_data, created_at, updated_at)
    values (v_id, 'email', v_id::text,
            jsonb_build_object('sub', v_id::text, 'email', v_email, 'email_verified', true), now(), now());
  else
    insert into auth.identities (user_id, provider, identity_data, created_at, updated_at)
    values (v_id, 'email',
            jsonb_build_object('sub', v_id::text, 'email', v_email, 'email_verified', true), now(), now());
  end if;

  -- 4. O perfil, que é o que o painel lê depois do login. Sem esta linha o
  --    login passa e a tela diz "sua conta entrou, mas não tem perfil".
  --
  --    nome e papel NÃO são sobrescritos quando a linha já existe: o nome é o
  --    que liga a pessoa aos negócios, e reescrevê-lo por conta própria é a
  --    única coisa aqui que poderia desassociar dado. Se o nome divergir, este
  --    bloco avisa e deixa a decisão para quem sabe.
  select nome into v_pnome from public.perfil where id = v_id;
  if v_pnome is null then
    insert into public.perfil (id, nome, papel, senha_provisoria)
    values (v_id, v_nome, 'editor', true);
    raise notice 'Perfil criado como "%" (editor).', v_nome;
  else
    update public.perfil
       set senha_provisoria = true,
           papel = case when papel in ('editor', 'leitor') then papel else 'editor' end
     where id = v_id;
    if v_pnome <> v_nome then
      raise warning 'O perfil desta conta chama-se "%", e não "%". NÃO mudei o nome: é ele que liga a pessoa aos negócios. Se os negócios estão no nome "%", me diga antes de trocar.', v_pnome, v_nome, v_nome;
    end if;
  end if;

  -- 5. A cópia do e-mail em perfil, quando a coluna existe.
  if exists (select 1 from information_schema.columns
    where table_schema='public' and table_name='perfil' and column_name='email') then
    execute 'update public.perfil set email = $1 where id = $2' using v_email, v_id;
  end if;

  -- Nada aqui escreve em public.pipeline, onde vivem os negócios, as
  --    pendências e o histórico. A contagem abaixo é só leitura, para ficar
  --    provado na mesma saída que nada foi perdido.
  select count(*) into v_deals
    from public.pipeline pl, jsonb_array_elements(pl.dados->'deals') d
   where pl.id = 1 and d->>'responsavel' = coalesce(v_pnome, v_nome);

  raise notice 'Conta % pronta: e-mail %, confirmada, senha regravada, identidade e perfil em ordem. Negócios no nome "%": % (intactos -- este bloco não escreve em public.pipeline).',
    v_id, v_email, coalesce(v_pnome, v_nome), v_deals;
end $$;

-- ===================================================== conferência do reparo
select u.id, u.email, u.aud, u.role,
       u.email_confirmed_at is not null            as confirmado,
       left(u.encrypted_password, 4)               as hash,
       (select i.identity_data->>'email' from auth.identities i
         where i.user_id = u.id and i.provider='email') as email_na_identidade,
       p.nome, p.papel, p.senha_provisoria
  from auth.users u join public.perfil p on p.id = u.id
 where p.nome = 'Paulo';

-- E o pipeline, intocado.
select versao,
       jsonb_array_length(dados->'deals')     as negocios,
       jsonb_array_length(dados->'customers') as clientes,
       jsonb_array_length(dados->'partners')  as parceiros,
       (select count(*) from jsonb_array_elements(dados->'deals') d
         where d->>'responsavel' = 'Paulo')   as negocios_do_paulo
  from public.pipeline where id = 1;

-- ====================================================== PARTE 3 · veredito
-- Responde "deu certo?" numa linha. Testa as treze condições que decidem um
-- login, inclusive a senha -- pelo mesmo teste que o GoTrue faz: comparar o
-- hash guardado com o hash da senha usando o próprio hash como salt.
--
-- Troque <SENHA-PROVISORIA> pela senha antes de rodar. Se der erro dizendo que
-- extensions.crypt não existe, troque "extensions." por "public." nas duas
-- ocorrências.
with alvo as (
  select u.id, u.email, u.encrypted_password, u.email_confirmed_at, u.aud, u.role,
         u.banned_until, u.deleted_at, u.last_sign_in_at,
         to_jsonb(u) ->> 'is_sso_user'  as sso,
         to_jsonb(u) ->> 'is_anonymous' as anon,
         p.nome, p.papel, p.senha_provisoria,
         (select i.identity_data->>'email' from auth.identities i
           where i.user_id = u.id and i.provider = 'email') as ident_email
    from auth.users u
    left join public.perfil p on p.id = u.id
   where lower(u.email) = lower('paulo.lopes@orencorp.com') or p.nome = 'Paulo'
), avaliado as (
  select a.*, array_remove(array[
    case when lower(a.email) <> lower('paulo.lopes@orencorp.com')
         then 'o e-mail da conta ainda é ' || a.email end,
    case when a.email_confirmed_at is null            then 'e-mail não confirmado' end,
    case when coalesce(a.encrypted_password,'') = ''  then 'conta sem senha' end,
    case when left(coalesce(a.encrypted_password,''),3) not in ('$2a','$2b','$2y')
         then 'o hash da senha não é bcrypt' end,
    case when coalesce(a.encrypted_password,'') <> ''
          and a.encrypted_password <> extensions.crypt('<SENHA-PROVISORIA>', a.encrypted_password)
         then 'a senha informada não é a desta conta' end,
    case when coalesce(a.aud,'') = '' or coalesce(a.role,'') = ''
         then 'aud ou role vazios' end,
    case when a.banned_until is not null              then 'conta banida' end,
    case when a.deleted_at is not null                then 'conta excluída' end,
    case when a.sso  = 'true'                         then 'conta marcada como SSO' end,
    case when a.anon = 'true'                         then 'conta marcada como anônima' end,
    case when a.nome is null                          then 'sem linha em public.perfil' end,
    case when a.papel is not null and a.papel not in ('editor','leitor')
         then 'papel inválido: ' || a.papel end,
    case when a.ident_email is null                   then 'sem identidade de e-mail' end,
    case when a.ident_email is not null
          and lower(a.ident_email) <> lower('paulo.lopes@orencorp.com')
         then 'a identidade ainda tem ' || a.ident_email end
  ], null) as problemas from alvo a
)
select email,
       nome,
       papel,
       senha_provisoria as vai_pedir_senha_nova,
       (select count(*) from public.pipeline pl, jsonb_array_elements(pl.dados->'deals') d
         where pl.id = 1 and d->>'responsavel' = avaliado.nome) as negocios_no_nome,
       last_sign_in_at as ultimo_acesso,
       case when cardinality(problemas) = 0
            then 'OK -- o login deve passar com esta senha'
            else 'AINDA FALTA: ' || array_to_string(problemas, ' | ') end as veredito
  from avaliado;
