-- =============================================================================
-- Oren · distribuir os negócios restantes de Capital nas frentes
-- Cole no SQL Editor e execute UMA vez.
-- =============================================================================
-- Move por id, com a frente decidida por análise de quem pediu, não por regra
-- automática e não por campo gravado: o campo "estrutura" está vazio nos oito,
-- porque nove dos dez estão nas etapas 1 e 2 e a estrutura só é definida na
-- etapa 5.
--
-- Por isso cada negócio movido RECEBE UMA LINHA NA NOTA dizendo de onde veio a
-- frente. Sem isso, daqui a três meses a tela mostraria uma inferência com a
-- mesma cara de um dado que alguém registrou — foi assim que a Rede de
-- atacarejo do Nordeste apareceu com o autor errado no histórico.
--
--   N-044  slb        rede existente com lojas próprias
--   N-045  slb        "confirmar interesse em liberar capital do balanço"
--   N-046  slb        rede existente, decisão de investimento imobiliário
--   N-047  slb        "levantar unidades próprias e alugadas"
--   N-049  slb        rede de escolas, estruturação concluída
--   N-051  bts        galpão definido pelo inquilino (Mercado Livre)
--   N-050  captacao   shopping é ativo de renda, não ocupante corporativo
--   N-054  captacao   sem base nenhuma; balde genérico até haver decisão
--
-- A etapa não muda: todas as frentes de Capital usam o mesmo funil.
-- Antes de rodar: Exportar no painel. O gatilho arquiva a versão anterior.

with antes as (
  select dados as d0, versao as v0 from public.pipeline where id = 1
),
mapa(id, nova) as (values
  ('N-044','slb'),('N-045','slb'),('N-046','slb'),('N-047','slb'),('N-049','slb'),
  ('N-051','bts'),('N-050','captacao'),('N-054','captacao')
),
novos as (
  select coalesce(jsonb_agg(
    case when m.nova is null then e
         else jsonb_set(jsonb_set(jsonb_set(
                e,'{frente}', to_jsonb(m.nova)),
                '{frentes}', to_jsonb(array[m.nova])),
                '{notas}', to_jsonb(
                  case when coalesce(e->>'notas','') = '' then ''
                       else (e->>'notas') || E'\n' end
                  || 'Frente definida por análise em 21/09/2026, a partir do título e do '
                  || 'próximo passo. O campo estrutura continua vazio: confirmar com o '
                  || 'responsável antes de tratar como definido.'))
    end order by ord),'[]'::jsonb) as v
    from antes, jsonb_array_elements(d0->'deals') with ordinality as t(e, ord)
    left join mapa m on m.id = e->>'id'
),
gravado as (
  update public.pipeline p set dados = jsonb_set(p.dados,'{deals}',(select v from novos))
   where p.id = 1
  returning p.dados as d1
)
select x.frente, x.antes, x.depois
  from antes a, gravado g,
  lateral (values
    ('capital (tem de sobrar 0)',
      (select count(*)::int from jsonb_array_elements(a.d0->'deals') d where d->>'frente'='capital'),
      (select count(*)::int from jsonb_array_elements(g.d1->'deals') d where d->>'frente'='capital')),
    ('slb · Sale & Leaseback',
      (select count(*)::int from jsonb_array_elements(a.d0->'deals') d where d->>'frente'='slb'),
      (select count(*)::int from jsonb_array_elements(g.d1->'deals') d where d->>'frente'='slb')),
    ('bts · Built to Suit',
      (select count(*)::int from jsonb_array_elements(a.d0->'deals') d where d->>'frente'='bts'),
      (select count(*)::int from jsonb_array_elements(g.d1->'deals') d where d->>'frente'='bts')),
    ('captacao · Captação de Recursos',
      (select count(*)::int from jsonb_array_elements(a.d0->'deals') d where d->>'frente'='captacao'),
      (select count(*)::int from jsonb_array_elements(g.d1->'deals') d where d->>'frente'='captacao')),
    ('reperfilamento · segue vazia',
      (select count(*)::int from jsonb_array_elements(a.d0->'deals') d where d->>'frente'='reperfilamento'),
      (select count(*)::int from jsonb_array_elements(g.d1->'deals') d where d->>'frente'='reperfilamento')),
    ('aeronaves · segue vazia',
      (select count(*)::int from jsonb_array_elements(a.d0->'deals') d where d->>'frente'='aeronaves'),
      (select count(*)::int from jsonb_array_elements(g.d1->'deals') d where d->>'frente'='aeronaves')),
    ('os 8 ids foram encontrados? (tem de ser 8)', 8,
      (select count(*)::int from jsonb_array_elements(g.d1->'deals') d
        where d->>'id' in ('N-044','N-045','N-046','N-047','N-049','N-050','N-051','N-054')
          and d->>'frente' <> 'capital')),
    ('negócios com a nota de origem da frente', 0,
      (select count(*)::int from jsonb_array_elements(g.d1->'deals') d
        where (d->>'notas') like '%Frente definida por análise%')),
    ('TOTAL de negócios (tem de ser igual)',
      jsonb_array_length(a.d0->'deals'), jsonb_array_length(g.d1->'deals')),
    ('PARA VOLTAR ATRÁS: restaure esta versão', a.v0, a.v0)
  ) as x(frente, antes, depois);
