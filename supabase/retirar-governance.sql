-- =============================================================================
-- Oren · retirar os dados de Governance
-- Cole no SQL Editor do Supabase e execute UMA vez.
-- =============================================================================
-- Apaga os REGISTROS de Governance. A frente continua existindo no código: o
-- funil de 7 etapas, o rótulo e a opção de cadastro seguem lá, então dá para
-- voltar a usar sem mexer em uma linha de programa.
--
-- Regra dos conjugados: um registro que é só Governance sai. Um registro que é
-- Governance E outra frente FICA, perdendo apenas a marca de Governance —
-- apagá-lo levaria junto uma operação de Capital ou Payments, que ninguém pediu.
--
-- Antes de rodar: use Exportar no painel. O gatilho do banco também arquiva a
-- versão anterior em pipeline_historico, e o fim deste arquivo traz o comando
-- de volta, mas um arquivo na sua máquina não depende de nada.

-- As frentes que sobram num registro, na ordem original e sem Governance.
create or replace function pg_temp.restantes(e jsonb) returns text[]
language sql immutable as $$
  select array(
    select f from (
      select f, ord
        from jsonb_array_elements_text(coalesce(e->'frentes','[]'::jsonb))
             with ordinality as t(f, ord)
      union all
      select e->>'frente', 0 where coalesce(e->>'frente','') <> ''
    ) u
    where f <> 'governance' and f <> ''
    group by f
    order by min(ord)
  )
$$;

-- Toca em Governance? Serve para não reescrever quem não tem nada com isso.
create or replace function pg_temp.toca(e jsonb) returns boolean
language sql immutable as $$
  select e->>'frente' = 'governance'
      or coalesce(e->'frentes','[]'::jsonb) ? 'governance'
$$;

-- null = o registro sai. Senão, volta sem a marca de Governance.
create or replace function pg_temp.limpa(e jsonb) returns jsonb
language sql immutable as $$
  select case when cardinality(pg_temp.restantes(e)) = 0 then null
              else jsonb_set(jsonb_set(e,'{frentes}',to_jsonb(pg_temp.restantes(e))),
                             '{frente}', to_jsonb((pg_temp.restantes(e))[1]))
         end
$$;

-- Como estava, para o relatório do fim conseguir comparar.
create temp table _antes as
select jsonb_array_length(dados->'deals')     as negocios,
       jsonb_array_length(dados->'partners')  as parceiros,
       jsonb_array_length(dados->'customers') as clientes,
       versao
  from public.pipeline where id = 1;

-- =============================================================================
-- A retirada, num único UPDATE: uma versão nova, um registro no histórico.
-- =============================================================================
with atual as (
  select dados from public.pipeline where id = 1
),
parc as (
  select coalesce(jsonb_agg(novo order by ord), '[]'::jsonb) as v
    from (select case when pg_temp.toca(e) then pg_temp.limpa(e) else e end as novo, ord
            from atual, jsonb_array_elements(dados->'partners') with ordinality as t(e, ord)) s
   where novo is not null
),
parc_ids as (
  select jsonb_array_elements(v)->>'id' as id from parc
),
negs as (
  select coalesce(jsonb_agg(
           /* Parceiro que saiu deixa referência órfã. Apontar para quem não
              existe faria o painel exibir o título do negócio como se fosse a
              conta, escondendo o buraco. Melhor o campo vazio. */
           case when novo->>'parceiroId' is not null
                 and not exists (select 1 from parc_ids pi where pi.id = novo->>'parceiroId')
                then jsonb_set(novo, '{parceiroId}', 'null'::jsonb)
                else novo end
           order by ord), '[]'::jsonb) as v
    from (select case when pg_temp.toca(e) then pg_temp.limpa(e) else e end as novo, ord
            from atual, jsonb_array_elements(dados->'deals') with ordinality as t(e, ord)) s
   where novo is not null
)
update public.pipeline
   set dados = jsonb_set(jsonb_set(dados, '{deals}', (select v from negs)),
                         '{partners}', (select v from parc))
 where id = 1;

-- =============================================================================
-- Conferência
-- =============================================================================
select 'negócios'  as registro, a.negocios  as antes,
       jsonb_array_length(p.dados->'deals')     as depois,
       a.negocios  - jsonb_array_length(p.dados->'deals')     as saíram
  from _antes a, public.pipeline p where p.id = 1
union all
select 'parceiros', a.parceiros, jsonb_array_length(p.dados->'partners'),
       a.parceiros - jsonb_array_length(p.dados->'partners')
  from _antes a, public.pipeline p where p.id = 1
union all
select 'clientes (não mexidos)', a.clientes, jsonb_array_length(p.dados->'customers'), 0
  from _antes a, public.pipeline p where p.id = 1
union all
select 'sobrou alguma marca de Governance?', 0,
       (select count(*)::int from jsonb_array_elements(p.dados->'deals') e
         where pg_temp.toca(e))
     + (select count(*)::int from jsonb_array_elements(p.dados->'partners') e
         where pg_temp.toca(e)), 0
  from public.pipeline p where p.id = 1
union all
select 'clientes ainda marcados como Governance', 0,
       (select count(*)::int from jsonb_array_elements(p.dados->'customers') e
         where pg_temp.toca(e)), 0
  from public.pipeline p where p.id = 1;

-- =============================================================================
-- Para voltar atrás, se precisar. Troque N pela versão anterior, que é a que
-- aparece em "antes" no relatório acima:
--
--   update public.pipeline
--      set dados = (select dados from public.pipeline_historico
--                    where versao = N order by id desc limit 1)
--    where id = 1;
-- =============================================================================
