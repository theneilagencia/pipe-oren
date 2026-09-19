-- =============================================================================
-- Oren · remover Theo e Adriano
-- Cole no SQL Editor do Supabase e execute UMA vez.
-- =============================================================================
-- Tira as duas pessoas da lista de responsáveis e apaga o que estava no nome
-- delas: atividades e pendências. Também limpa as citações nominais em notas e
-- em textos de apoio de atividades que ficam.
--
-- Apaga também negócio e conta no nome deles. Isto é destrutivo: uma
-- oportunidade comercial some junto com a pessoa. É o que foi pedido depois de
-- a primeira versão deixar esses registros de pé e eles continuarem na tela.
--
-- O histórico NÃO é reescrito. Se o nome deles aparece num "movido por", aquilo
-- é registro do que aconteceu, e o relatório do fim conta quantos são para você
-- decidir. Apagar histórico para limpar a tela é falsificar o passado.
--
-- Antes de rodar: use Exportar no painel. O gatilho também arquiva a versão
-- anterior em pipeline_historico, e o rodapé traz o comando de volta.

create or replace function pg_temp.sai(nome text) returns boolean
language sql immutable as $$ select nome in ('Theo','Adriano') $$;

-- Tira o nome das citações, preservando o resto da frase.
create or replace function pg_temp.limpa_texto(t text) returns text
language sql immutable as $$
  select nullif(trim(regexp_replace(regexp_replace(regexp_replace(coalesce(t,''),
    '\s*(Theo|Adriano) é quem [^.]*\.', '', 'g'),
    '(Apoio:\s*)(Theo|Adriano),\s*', '\1', 'g'),
    ',?\s*(e\s+)?(Theo|Adriano)(,|\.|\s|$)', '\3', 'g')), '')
$$;

create temp table _antes as
select jsonb_array_length(coalesce(dados->'atividades','[]'::jsonb)) as atividades,
       (select count(*) from jsonb_array_elements(dados->'deals') d,
               jsonb_array_elements(coalesce(d->'pendencias','[]'::jsonb)) p
         where pg_temp.sai(p->>'responsavel')) as pendencias,
       jsonb_array_length(coalesce(dados->'responsaveis','[]'::jsonb)) as responsaveis,
       jsonb_array_length(dados->'deals') as negocios,
       jsonb_array_length(dados->'customers') as clientes,
       jsonb_array_length(dados->'partners') as parceiros,
       versao
  from public.pipeline where id = 1;

with atual as (select dados from public.pipeline where id = 1),
ativ as (
  select coalesce(jsonb_agg(
           jsonb_set(e,'{descricao}', to_jsonb(coalesce(pg_temp.limpa_texto(e->>'descricao'),'')))
           order by ord),'[]'::jsonb) as v
    from atual, jsonb_array_elements(coalesce(dados->'atividades','[]'::jsonb))
         with ordinality as t(e, ord)
   where not pg_temp.sai(e->>'responsavel')
),
negs as (
  select coalesce(jsonb_agg(
           jsonb_set(
             jsonb_set(e,'{pendencias}',
               coalesce((select jsonb_agg(p order by o)
                           from jsonb_array_elements(coalesce(e->'pendencias','[]'::jsonb))
                                with ordinality as q(p,o)
                          where not pg_temp.sai(p->>'responsavel')), '[]'::jsonb)),
             '{notas}', to_jsonb(coalesce(pg_temp.limpa_texto(e->>'notas'),'')))
           order by ord),'[]'::jsonb) as v
    from atual, jsonb_array_elements(dados->'deals') with ordinality as t(e, ord)
   where not pg_temp.sai(e->>'responsavel')
),
conts as (
  select coalesce(jsonb_agg(
           jsonb_set(e,'{notas}', to_jsonb(coalesce(pg_temp.limpa_texto(e->>'notas'),'')))
           order by ord),'[]'::jsonb) as v
    from atual, jsonb_array_elements(dados->'customers') with ordinality as t(e, ord)
   where not pg_temp.sai(e->>'responsavel')
),
parcs as (
  select coalesce(jsonb_agg(
           jsonb_set(e,'{notas}', to_jsonb(coalesce(pg_temp.limpa_texto(e->>'notas'),'')))
           order by ord),'[]'::jsonb) as v
    from atual, jsonb_array_elements(dados->'partners') with ordinality as t(e, ord)
   where not pg_temp.sai(e->>'responsavel')
),
resp as (
  select coalesce(jsonb_agg(to_jsonb(r) order by ord),'[]'::jsonb) as v
    from atual, jsonb_array_elements_text(coalesce(dados->'responsaveis','[]'::jsonb))
         with ordinality as t(r, ord)
   where not pg_temp.sai(r)
)
update public.pipeline
   set dados = jsonb_set(
                 jsonb_set(
                   jsonb_set(
                     jsonb_set(
                       jsonb_set(dados,'{atividades}',(select v from ativ)),
                       '{deals}',(select v from negs)),
                     '{customers}',(select v from conts)),
                   '{partners}',(select v from parcs)),
                 '{responsaveis}',(select v from resp))
 where id = 1;

-- Conta que saiu deixa referência órfã em negócio que ficou. Apontar para quem
-- não existe faria o painel exibir o título do negócio como se fosse a conta.
update public.pipeline p
   set dados = jsonb_set(dados, '{deals}', coalesce((
     select jsonb_agg(
       case when d->>'clienteId' is not null and not exists (
              select 1 from jsonb_array_elements(p.dados->'customers') c
               where c->>'id' = d->>'clienteId')
            then jsonb_set(d,'{clienteId}','null'::jsonb) else d end
       order by o)
       from jsonb_array_elements(p.dados->'deals') with ordinality as t(d,o)),'[]'::jsonb))
 where id = 1;

update public.pipeline p
   set dados = jsonb_set(dados, '{deals}', coalesce((
     select jsonb_agg(
       case when d->>'parceiroId' is not null and not exists (
              select 1 from jsonb_array_elements(p.dados->'partners') q
               where q->>'id' = d->>'parceiroId')
            then jsonb_set(d,'{parceiroId}','null'::jsonb) else d end
       order by o)
       from jsonb_array_elements(p.dados->'deals') with ordinality as t(d,o)),'[]'::jsonb))
 where id = 1;

-- =============================================================================
-- Conferência
-- =============================================================================
select 'atividades' as registro, a.atividades as antes,
       jsonb_array_length(coalesce(p.dados->'atividades','[]'::jsonb)) as depois
  from _antes a, public.pipeline p where p.id = 1
union all
select 'pendências no nome deles', a.pendencias,
       (select count(*)::int from jsonb_array_elements(p.dados->'deals') d,
               jsonb_array_elements(coalesce(d->'pendencias','[]'::jsonb)) q
         where pg_temp.sai(q->>'responsavel'))
  from _antes a, public.pipeline p where p.id = 1
union all
select 'nomes na lista de responsáveis', a.responsaveis,
       jsonb_array_length(coalesce(p.dados->'responsaveis','[]'::jsonb))
  from _antes a, public.pipeline p where p.id = 1
union all
select 'menções que sobraram no texto', 0,
       (select count(*)::int from regexp_matches(p.dados::text,'Theo|Adriano','g'))
  from public.pipeline p where p.id = 1
union all
select 'negócios', a.negocios, jsonb_array_length(p.dados->'deals')
  from _antes a, public.pipeline p where p.id = 1
union all
select 'clientes', a.clientes, jsonb_array_length(p.dados->'customers')
  from _antes a, public.pipeline p where p.id = 1
union all
select 'parceiros', a.parceiros, jsonb_array_length(p.dados->'partners')
  from _antes a, public.pipeline p where p.id = 1
union all
select 'registros ainda no nome deles (tem de ser 0)', 0,
       (select count(*)::int from jsonb_array_elements(
          p.dados->'deals'||p.dados->'customers'||p.dados->'partners'
          ||coalesce(p.dados->'atividades','[]'::jsonb)) r
         where pg_temp.sai(r->>'responsavel'))
  from public.pipeline p where p.id = 1
union all
select 'PARA VOLTAR ATRÁS: restaure esta versão', a.versao, a.versao
  from _antes a
union all
select 'no histórico, "movido por" com o nome deles (não mexo)', 0,
       (select count(*)::int from jsonb_array_elements(p.dados->'deals') d,
               jsonb_array_elements(coalesce(d->'historico','[]'::jsonb)) hh
         where pg_temp.sai(hh->>'quem'))
  from public.pipeline p where p.id = 1;

-- Os ids, se sobrou algum:
--   select d->>'id', d->>'titulo' from public.pipeline p,
--          jsonb_array_elements(p.dados->'deals') d
--    where d->>'responsavel' in ('Theo','Adriano') and p.id=1;
--
-- Para voltar atrás, troque N pela versão que aparece em "antes":
--   update public.pipeline
--      set dados = (select dados from public.pipeline_historico
--                    where versao = N order by id desc limit 1)
--    where id = 1;
