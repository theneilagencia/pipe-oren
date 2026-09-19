-- =============================================================================
-- Oren · o que a remoção de Theo e Adriano vai levar
-- Cole no SQL Editor e execute. NÃO ALTERA NADA: só lista.
-- =============================================================================
-- Rode isto antes do remover-theo-adriano.sql. Ele apaga negócio, conta,
-- atividade e pendência no nome dos dois, e a carteira inteira pode estar num
-- nome só. Ver a lista antes é a diferença entre decidir e descobrir depois.

create or replace function pg_temp.sai(nome text) returns boolean
language sql immutable as $$ select nome in ('Theo','Adriano') $$;

select 'NEGÓCIO' as tipo, d->>'id' as id,
       coalesce(nullif(d->>'titulo',''),'(sem título)') as nome,
       d->>'responsavel' as responsavel,
       case when (d->>'valor') ~ '^[0-9.]+$'
            then to_char((d->>'valor')::numeric,'FM999G999G999G999')
            else '—' end as valor
  from public.pipeline p, jsonb_array_elements(p.dados->'deals') d
 where p.id = 1 and pg_temp.sai(d->>'responsavel')
union all
select 'CLIENTE', c->>'id', coalesce(nullif(c->>'nome',''),'(sem nome)'), c->>'responsavel', '—'
  from public.pipeline p, jsonb_array_elements(p.dados->'customers') c
 where p.id = 1 and pg_temp.sai(c->>'responsavel')
union all
select 'PARCEIRO', q->>'id', coalesce(nullif(q->>'nome',''),'(sem nome)'), q->>'responsavel', '—'
  from public.pipeline p, jsonb_array_elements(p.dados->'partners') q
 where p.id = 1 and pg_temp.sai(q->>'responsavel')
union all
select 'ATIVIDADE', a->>'id', coalesce(nullif(a->>'titulo',''),'(sem título)'), a->>'responsavel', '—'
  from public.pipeline p, jsonb_array_elements(coalesce(p.dados->'atividades','[]'::jsonb)) a
 where p.id = 1 and pg_temp.sai(a->>'responsavel')
union all
select 'PENDÊNCIA', coalesce(pd->>'id','—'), left(coalesce(pd->>'texto','(sem texto)'),60),
       pd->>'responsavel', '—'
  from public.pipeline p, jsonb_array_elements(p.dados->'deals') d,
       jsonb_array_elements(coalesce(d->'pendencias','[]'::jsonb)) pd
 where p.id = 1 and pg_temp.sai(pd->>'responsavel')
union all
select '── TOTAL ──', '', (select count(*)::text||' registros' from (
         select 1 from jsonb_array_elements(p2.dados->'deals') x where pg_temp.sai(x->>'responsavel')
         union all select 1 from jsonb_array_elements(p2.dados->'customers') x where pg_temp.sai(x->>'responsavel')
         union all select 1 from jsonb_array_elements(p2.dados->'partners') x where pg_temp.sai(x->>'responsavel')
         union all select 1 from jsonb_array_elements(coalesce(p2.dados->'atividades','[]'::jsonb)) x
                    where pg_temp.sai(x->>'responsavel')) t),
       '',
       (select to_char(coalesce(sum((x->>'valor')::numeric),0),'FM999G999G999G999')
          from jsonb_array_elements(p2.dados->'deals') x
         where pg_temp.sai(x->>'responsavel') and (x->>'valor') ~ '^[0-9.]+$')
  from public.pipeline p2 where p2.id = 1
 order by 1, 2;
