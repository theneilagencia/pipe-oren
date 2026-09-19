-- =============================================================================
-- Oren · remover Theo e Adriano
-- Cole no SQL Editor do Supabase e execute UMA vez.
-- =============================================================================
-- Apaga negócio, conta, atividade e pendência no nome dos dois, tira os nomes
-- da lista de responsáveis e limpa as citações em notas e textos de apoio.
--
-- Isto é destrutivo: a carteira pode estar num nome só. Rode antes o
-- conferir-remocao.sql, que lista o que vai sair e não altera nada.
--
-- Tudo numa instrução só, de propósito: sem tabela temporária e sem função
-- auxiliar. No SQL Editor do Supabase a sessão é agrupada, e objeto temporário
-- pode não sobreviver entre instruções -- o script quebraria no meio, depois de
-- já ter mudado parte do dado. Uma instrução ou muda tudo, ou não muda nada.
--
-- O histórico não é reescrito: "movido por" é registro do que aconteceu. O
-- relatório conta quantos são, para você decidir em separado.
--
-- Antes de rodar: Exportar no painel. O gatilho também arquiva a versão
-- anterior em pipeline_historico, e o relatório diz qual restaurar.

with antes as (
  select dados as d0, versao as v0 from public.pipeline where id = 1
),
-- Atividades: as deles saem; nas que ficam, o nome sai do texto de apoio.
ativ as (
  select coalesce(jsonb_agg(jsonb_set(e,'{descricao}',
           to_jsonb(coalesce(nullif(trim(regexp_replace(regexp_replace(regexp_replace(
       coalesce(e->>'descricao',''),
       '\s*(Theo|Adriano) é quem [^.]*\.', '', 'g'),
       '(Apoio:\s*)(Theo|Adriano),\s*', '\1', 'g'),
       ',?\s*(e\s+)?(Theo|Adriano)(,|\.|\s|$)', '\3', 'g')), ''),''))) order by ord),'[]'::jsonb) as v
    from antes, jsonb_array_elements(coalesce(d0->'atividades','[]'::jsonb))
         with ordinality as t(e, ord)
   where not (e->>'responsavel') in ('Theo','Adriano')
),
-- Contas deles saem; nas que ficam, o nome sai da nota.
conts as (
  select coalesce(jsonb_agg(jsonb_set(e,'{notas}',
           to_jsonb(coalesce(nullif(trim(regexp_replace(regexp_replace(regexp_replace(
       coalesce(e->>'notas',''),
       '\s*(Theo|Adriano) é quem [^.]*\.', '', 'g'),
       '(Apoio:\s*)(Theo|Adriano),\s*', '\1', 'g'),
       ',?\s*(e\s+)?(Theo|Adriano)(,|\.|\s|$)', '\3', 'g')), ''),''))) order by ord),'[]'::jsonb) as v
    from antes, jsonb_array_elements(d0->'customers') with ordinality as t(e, ord)
   where not (e->>'responsavel') in ('Theo','Adriano')
),
parcs as (
  select coalesce(jsonb_agg(jsonb_set(e,'{notas}',
           to_jsonb(coalesce(nullif(trim(regexp_replace(regexp_replace(regexp_replace(
       coalesce(e->>'notas',''),
       '\s*(Theo|Adriano) é quem [^.]*\.', '', 'g'),
       '(Apoio:\s*)(Theo|Adriano),\s*', '\1', 'g'),
       ',?\s*(e\s+)?(Theo|Adriano)(,|\.|\s|$)', '\3', 'g')), ''),''))) order by ord),'[]'::jsonb) as v
    from antes, jsonb_array_elements(d0->'partners') with ordinality as t(e, ord)
   where not (e->>'responsavel') in ('Theo','Adriano')
),
ids_cli as (select jsonb_array_elements(v)->>'id' as id from conts),
ids_par as (select jsonb_array_elements(v)->>'id' as id from parcs),
-- Negócios deles saem. Nos que ficam: pendência deles sai, nome sai da nota, e
-- referência para conta que saiu vira vazia, senão o painel mostraria o título
-- do negócio no lugar do nome da conta.
negs as (
  select coalesce(jsonb_agg(
           jsonb_set(
             jsonb_set(
               jsonb_set(
                 jsonb_set(e,'{pendencias}',
                   coalesce((select jsonb_agg(p order by o)
                               from jsonb_array_elements(coalesce(e->'pendencias','[]'::jsonb))
                                    with ordinality as q(p,o)
                              where not (p->>'responsavel') in ('Theo','Adriano')), '[]'::jsonb)),
                 '{notas}', to_jsonb(coalesce(nullif(trim(regexp_replace(regexp_replace(regexp_replace(
       coalesce(e->>'notas',''),
       '\s*(Theo|Adriano) é quem [^.]*\.', '', 'g'),
       '(Apoio:\s*)(Theo|Adriano),\s*', '\1', 'g'),
       ',?\s*(e\s+)?(Theo|Adriano)(,|\.|\s|$)', '\3', 'g')), ''),''))),
               '{clienteId}',
               case when e->>'clienteId' is not null
                     and not exists (select 1 from ids_cli where id = e->>'clienteId')
                    then 'null'::jsonb else coalesce(e->'clienteId','null'::jsonb) end),
             '{parceiroId}',
             case when e->>'parceiroId' is not null
                   and not exists (select 1 from ids_par where id = e->>'parceiroId')
                  then 'null'::jsonb else coalesce(e->'parceiroId','null'::jsonb) end)
           order by ord),'[]'::jsonb) as v
    from antes, jsonb_array_elements(d0->'deals') with ordinality as t(e, ord)
   where not (e->>'responsavel') in ('Theo','Adriano')
),
resp as (
  select coalesce(jsonb_agg(to_jsonb(r) order by ord),'[]'::jsonb) as v
    from antes, jsonb_array_elements_text(coalesce(d0->'responsaveis','[]'::jsonb))
         with ordinality as t(r, ord)
   where r not in ('Theo','Adriano')
),
novo as (
  select jsonb_set(jsonb_set(jsonb_set(jsonb_set(jsonb_set(
           d0,'{atividades}',(select v from ativ)),
           '{deals}',(select v from negs)),
           '{customers}',(select v from conts)),
           '{partners}',(select v from parcs)),
           '{responsaveis}',(select v from resp)) as v
    from antes
),
gravado as (
  update public.pipeline p set dados = (select v from novo)
   where p.id = 1
  returning p.dados as d1, p.versao as v1
)
select x.registro, x.antes, x.depois
  from antes a, gravado g,
  lateral (values
    ('negócios',        jsonb_array_length(a.d0->'deals'),      jsonb_array_length(g.d1->'deals')),
    ('clientes',        jsonb_array_length(a.d0->'customers'),  jsonb_array_length(g.d1->'customers')),
    ('parceiros',       jsonb_array_length(a.d0->'partners'),   jsonb_array_length(g.d1->'partners')),
    ('atividades',      jsonb_array_length(coalesce(a.d0->'atividades','[]'::jsonb)),
                        jsonb_array_length(coalesce(g.d1->'atividades','[]'::jsonb))),
    ('nomes na lista de responsáveis',
                        jsonb_array_length(coalesce(a.d0->'responsaveis','[]'::jsonb)),
                        jsonb_array_length(coalesce(g.d1->'responsaveis','[]'::jsonb))),
    ('registros ainda no nome deles (tem de ser 0)', 0,
      (select count(*)::int from jsonb_array_elements(
         (g.d1->'deals') || (g.d1->'customers') || (g.d1->'partners')
         || coalesce(g.d1->'atividades','[]'::jsonb)) r
        where (r->>'responsavel') in ('Theo','Adriano'))),
    ('pendências ainda no nome deles (tem de ser 0)', 0,
      (select count(*)::int from jsonb_array_elements(g.d1->'deals') d,
              jsonb_array_elements(coalesce(d->'pendencias','[]'::jsonb)) q
        where (q->>'responsavel') in ('Theo','Adriano'))),
    ('no histórico, "movido por" com o nome deles (não mexo)', 0,
      (select count(*)::int from jsonb_array_elements(g.d1->'deals') d,
              jsonb_array_elements(coalesce(d->'historico','[]'::jsonb)) h
        where (h->>'quem') in ('Theo','Adriano'))),
    ('PARA VOLTAR ATRÁS: restaure esta versão', a.v0, a.v0)
  ) as x(registro, antes, depois);

-- Para voltar atrás, com o número que o relatório mostrou na última linha:
--   update public.pipeline
--      set dados = (select dados from public.pipeline_historico
--                    where versao = <aquele numero> order by id desc limit 1)
--    where id = 1;
