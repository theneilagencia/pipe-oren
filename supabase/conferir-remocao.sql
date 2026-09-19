-- =============================================================================
-- Oren · o que a remoção de Theo e Adriano vai levar
-- Cole no SQL Editor e execute. NÃO ALTERA NADA: só lista.
-- =============================================================================
-- Rode antes do remover-theo-adriano.sql. Sem função auxiliar e sem tabela
-- temporária, pelo mesmo motivo do outro: sessão agrupada pode não guardá-las.

select 'NEGÓCIO' as tipo, d->>'id' as id,
       coalesce(nullif(d->>'titulo',''),'(sem título)') as nome,
       d->>'responsavel' as responsavel,
       case when (d->>'valor') ~ '^[0-9]+(\.[0-9]+)?$'
            then to_char((d->>'valor')::numeric,'FM999G999G999G999') else '—' end as valor
  from public.pipeline p, jsonb_array_elements(p.dados->'deals') d
 where p.id = 1 and (d->>'responsavel') in ('Theo','Adriano')
union all
select 'CLIENTE', c->>'id', coalesce(nullif(c->>'nome',''),'(sem nome)'), c->>'responsavel', '—'
  from public.pipeline p, jsonb_array_elements(p.dados->'customers') c
 where p.id = 1 and (c->>'responsavel') in ('Theo','Adriano')
union all
select 'PARCEIRO', q->>'id', coalesce(nullif(q->>'nome',''),'(sem nome)'), q->>'responsavel', '—'
  from public.pipeline p, jsonb_array_elements(p.dados->'partners') q
 where p.id = 1 and (q->>'responsavel') in ('Theo','Adriano')
union all
select 'ATIVIDADE', a->>'id', coalesce(nullif(a->>'titulo',''),'(sem título)'), a->>'responsavel', '—'
  from public.pipeline p, jsonb_array_elements(coalesce(p.dados->'atividades','[]'::jsonb)) a
 where p.id = 1 and (a->>'responsavel') in ('Theo','Adriano')
union all
select 'PENDÊNCIA', coalesce(pd->>'id','—'), left(coalesce(pd->>'texto','(sem texto)'),60),
       pd->>'responsavel', '—'
  from public.pipeline p, jsonb_array_elements(p.dados->'deals') d,
       jsonb_array_elements(coalesce(d->'pendencias','[]'::jsonb)) pd
 where p.id = 1 and (pd->>'responsavel') in ('Theo','Adriano')
union all
select '== TOTAL ==', '',
       (select count(*)::text||' registros' from jsonb_array_elements(
          (p.dados->'deals') || (p.dados->'customers') || (p.dados->'partners')
          || coalesce(p.dados->'atividades','[]'::jsonb)) r
         where (r->>'responsavel') in ('Theo','Adriano')),
       '',
       (select to_char(coalesce(sum((x->>'valor')::numeric),0),'FM999G999G999G999')
          from jsonb_array_elements(p.dados->'deals') x
         where (x->>'responsavel') in ('Theo','Adriano')
           and (x->>'valor') ~ '^[0-9]+(\.[0-9]+)?$')
  from public.pipeline p where p.id = 1
 order by 1, 2;
