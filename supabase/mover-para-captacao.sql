-- =============================================================================
-- Oren · mover os dois negócios de captação para a frente nova
-- Cole no SQL Editor e execute UMA vez.
-- =============================================================================
-- Move exatamente dois negócios, nomeados por id, para "Captação de Recursos":
--
--   N-052     Dois shoppings: mandato de venda ou captação de R$ 100 milhões cada
--   N-UG7204  Funding de U$60M - financiamento internacional
--
-- Por id, e não por palavra no texto, de propósito: são dois registros que você
-- e eu olhamos um a um. Regra automática aqui pegaria qualquer negócio que
-- mencionasse "captação" de passagem.
--
-- A etapa não muda: Captação de Recursos usa o mesmo funil de dez etapas das
-- outras frentes de Capital.
--
-- Antes de rodar: Exportar no painel. O gatilho arquiva a versão anterior.

with antes as (
  select dados as d0, versao as v0 from public.pipeline where id = 1
),
novos as (
  select coalesce(jsonb_agg(
    case when e->>'id' in ('N-052','N-UG7204')
         then jsonb_set(jsonb_set(e,'{frente}','"captacao"'::jsonb),
                        '{frentes}','["captacao"]'::jsonb)
         else e end
    order by ord),'[]'::jsonb) as v
    from antes, jsonb_array_elements(d0->'deals') with ordinality as t(e, ord)
),
gravado as (
  update public.pipeline p set dados = jsonb_set(p.dados,'{deals}',(select v from novos))
   where p.id = 1
  returning p.dados as d1
)
select x.item, x.antes, x.depois
  from antes a, gravado g,
  lateral (values
    ('negócios em Captação de Recursos',
      (select count(*)::int from jsonb_array_elements(a.d0->'deals') d where d->>'frente'='captacao'),
      (select count(*)::int from jsonb_array_elements(g.d1->'deals') d where d->>'frente'='captacao')),
    ('negócios ainda em Capital',
      (select count(*)::int from jsonb_array_elements(a.d0->'deals') d where d->>'frente'='capital'),
      (select count(*)::int from jsonb_array_elements(g.d1->'deals') d where d->>'frente'='capital')),
    ('os dois ids foram encontrados? (tem de ser 2)', 2,
      (select count(*)::int from jsonb_array_elements(g.d1->'deals') d
        where d->>'id' in ('N-052','N-UG7204') and d->>'frente'='captacao')),
    ('TOTAL de negócios (tem de ser igual)',
      jsonb_array_length(a.d0->'deals'), jsonb_array_length(g.d1->'deals')),
    ('PARA VOLTAR ATRÁS: restaure esta versão', a.v0, a.v0)
  ) as x(item, antes, depois);
