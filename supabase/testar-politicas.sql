\set ON_ERROR_STOP off
\pset pager off
-- Duas pessoas de mentira: uma editora, uma leitora.
insert into auth.users (id) values
  ('11111111-1111-1111-1111-111111111111'),
  ('22222222-2222-2222-2222-222222222222') on conflict do nothing;
insert into public.perfil (id, nome, papel) values
  ('11111111-1111-1111-1111-111111111111','Paulo','editor'),
  ('22222222-2222-2222-2222-222222222222','Leitora','leitor') on conflict (id) do update set nome=excluded.nome, papel=excluded.papel;
update public.pipeline set dados = '{"partners":[],"customers":[],"deals":[{"id":"N-001"}]}'::jsonb where id = 1;

\echo '=== 1. SEM LOGIN (papel anon) ==='
set role anon;
select 'perfil    -> ' || count(*)::text || ' linhas' from public.perfil;
select 'pipeline  -> ' || count(*)::text || ' linhas' from public.pipeline;
select 'historico -> ' || count(*)::text || ' linhas' from public.pipeline_historico;
update public.pipeline set dados = '{"invadido":true}'::jsonb where id = 1;
reset role;

\echo '=== 2. LOGADA COMO EDITOR (Paulo) ==='
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
select 'le o pipeline -> versao ' || versao::text || ', negocios ' || jsonb_array_length(dados->'deals')::text from public.pipeline;
update public.pipeline set dados = jsonb_set(dados,'{deals}','[{"id":"N-001"},{"id":"N-002"}]'::jsonb) where id = 1;
select 'depois de gravar -> versao ' || versao::text || ', autor ' || coalesce(atualizado_por,'?') || ', negocios ' || jsonb_array_length(dados->'deals')::text from public.pipeline;
select 'historico guardou -> ' || count(*)::text || ' versao(oes)' from public.pipeline_historico;
\echo '-- tentativa de mentir sobre versao e autor:'
update public.pipeline set dados = dados, versao = 999, atualizado_por = 'Fulano' where id = 1;
select 'resultado -> versao ' || versao::text || ', autor ' || coalesce(atualizado_por,'?') from public.pipeline;
\echo '-- gravacao com versao velha (o que o painel envia em conflito):'
update public.pipeline set dados = '{"partners":[],"customers":[],"deals":[]}'::jsonb where id = 1 and versao = 1;
reset role; reset request.jwt.claim.sub;

\echo '=== 3. LOGADA COMO LEITOR ==='
set role authenticated;
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
select 'le o pipeline -> versao ' || versao::text from public.pipeline;
update public.pipeline set dados = '{"partners":[],"customers":[],"deals":[]}'::jsonb where id = 1;
\echo '-- tenta apagar historico:'
delete from public.pipeline_historico;
reset role; reset request.jwt.claim.sub;
