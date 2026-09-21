-- =============================================================================
-- Oren · desmembrar Capital nas quatro frentes
-- Cole no SQL Editor e execute UMA vez. Rode antes o conferir-frentes-capital.
-- =============================================================================
-- Move cada negócio de Capital para bts, slb, reperfilamento ou aeronaves
-- pelas MESMAS regras do conferir, na mesma ordem. O que não casa com regra
-- nenhuma continua em Capital: sem evidência no dado, a escolha é sua.
--
-- A etapa não muda, e não precisa mudar: as quatro frentes usam o mesmo funil
-- de dez etapas de Capital. Isto aqui é troca de rótulo, não de processo.
--
-- Uma instrução só, sem tabela temporária e sem função auxiliar: no SQL Editor
-- do Supabase a sessão é agrupada e objeto temporário pode não sobreviver entre
-- instruções. Ou muda tudo, ou não muda nada.
--
-- Antes de rodar: Exportar no painel. O gatilho arquiva a versão anterior em
-- pipeline_historico, e o relatório diz qual restaurar.

with antes as (
  select dados as d0, versao as v0 from public.pipeline where id = 1
),
novos as (
  select coalesce(jsonb_agg(
    case when (e->>'frente' = 'capital' or coalesce(e->'frentes','[]'::jsonb) ? 'capital')
         then (
           select case when nova = 'capital' then e
                       else jsonb_set(jsonb_set(e,'{frente}',to_jsonb(nova)),
                                      '{frentes}', to_jsonb(array[nova])) end
             from (select case
                     when lower(coalesce(e->>'titulo','')||' '||coalesce(e->>'notas','')||' '
                                ||coalesce(e->>'tese','')) ~ 'aeronav|aeronáut|aeronaut|aircraft'
                          then 'aeronaves'
                     when lower(coalesce(e->>'titulo','')||' '||coalesce(e->>'notas','')||' '
                                ||coalesce(e->>'tese','')) ~ 'reperfil|dívida|divida|debt'
                          then 'reperfilamento'
                     when e->>'estrutura' = 'Sale & Leaseback' then 'slb'
                     when e->>'estrutura' = 'Built to Suit'    then 'bts'
                     else 'capital' end as nova) t
         )
         else e end
    order by ord),'[]'::jsonb) as v
    from antes, jsonb_array_elements(d0->'deals') with ordinality as t(e, ord)
),
gravado as (
  update public.pipeline p set dados = jsonb_set(p.dados,'{deals}',(select v from novos))
   where p.id = 1
  returning p.dados as d1
)
select x.frente, x.antes, x.depois
  from antes a, gravado g,
  lateral (values
    ('capital (o que ficou para você decidir)',
      (select count(*)::int from jsonb_array_elements(a.d0->'deals') d where d->>'frente'='capital'),
      (select count(*)::int from jsonb_array_elements(g.d1->'deals') d where d->>'frente'='capital')),
    ('bts · Built to Suit',
      (select count(*)::int from jsonb_array_elements(a.d0->'deals') d where d->>'frente'='bts'),
      (select count(*)::int from jsonb_array_elements(g.d1->'deals') d where d->>'frente'='bts')),
    ('slb · Sale & Leaseback',
      (select count(*)::int from jsonb_array_elements(a.d0->'deals') d where d->>'frente'='slb'),
      (select count(*)::int from jsonb_array_elements(g.d1->'deals') d where d->>'frente'='slb')),
    ('reperfilamento · Reperfilamento de dívida',
      (select count(*)::int from jsonb_array_elements(a.d0->'deals') d where d->>'frente'='reperfilamento'),
      (select count(*)::int from jsonb_array_elements(g.d1->'deals') d where d->>'frente'='reperfilamento')),
    ('aeronaves · Financiamento de Aeronaves',
      (select count(*)::int from jsonb_array_elements(a.d0->'deals') d where d->>'frente'='aeronaves'),
      (select count(*)::int from jsonb_array_elements(g.d1->'deals') d where d->>'frente'='aeronaves')),
    ('TOTAL de negócios (tem de ser igual)',
      jsonb_array_length(a.d0->'deals'), jsonb_array_length(g.d1->'deals')),
    ('PARA VOLTAR ATRÁS: restaure esta versão', a.v0, a.v0)
  ) as x(frente, antes, depois);
