-- =============================================================================
-- Oren · como os negócios de Capital seriam redistribuídos
-- Cole no SQL Editor e execute. NÃO ALTERA NADA: só propõe e mostra por quê.
-- =============================================================================
-- Capital vira quatro frentes: Built to Suit, Sale & Leaseback, Reperfilamento
-- de dívida e Financiamento de Aeronaves. A proposta abaixo sai do que já está
-- gravado em cada negócio, nunca de suposição sobre o nome do cliente:
--
--   1. campo "estrutura" = Sale & Leaseback  ->  slb
--   2. campo "estrutura" = Built to Suit     ->  bts
--   3. aeronave/aeronáutic/aircraft no título, na tese ou nas notas -> aeronaves
--   4. reperfilamento/dívida/debt nos mesmos campos -> reperfilamento
--
-- A ordem importa: aeronave e dívida são mais específicos que a estrutura, e
-- por isso vêm antes. O que não casar com nenhuma regra fica como REVISAR e
-- continua em Capital: sem evidência no dado, a escolha é sua, não minha.

select d->>'id' as id,
       left(coalesce(nullif(d->>'titulo',''),'(sem título)'),46) as negocio,
       case
         when lower(coalesce(d->>'titulo','')||' '||coalesce(d->>'notas','')||' '
                    ||coalesce(d->>'tese','')) ~ 'aeronav|aeronáut|aeronaut|aircraft'
              then 'aeronaves'
         when lower(coalesce(d->>'titulo','')||' '||coalesce(d->>'notas','')||' '
                    ||coalesce(d->>'tese','')) ~ 'reperfil|dívida|divida|debt'
              then 'reperfilamento'
         when d->>'estrutura' = 'Sale & Leaseback' then 'slb'
         when d->>'estrutura' = 'Built to Suit'    then 'bts'
         else 'REVISAR — segue em Capital'
       end as frente_proposta,
       case
         when lower(coalesce(d->>'titulo','')||' '||coalesce(d->>'notas','')||' '
                    ||coalesce(d->>'tese','')) ~ 'aeronav|aeronáut|aeronaut|aircraft'
              then 'texto cita aeronave'
         when lower(coalesce(d->>'titulo','')||' '||coalesce(d->>'notas','')||' '
                    ||coalesce(d->>'tese','')) ~ 'reperfil|dívida|divida|debt'
              then 'texto cita dívida ou reperfilamento'
         when d->>'estrutura' in ('Sale & Leaseback','Built to Suit')
              then 'campo estrutura = '||(d->>'estrutura')
         else 'estrutura em branco e nada no texto'
       end as por_que,
       coalesce(nullif(d->>'estrutura',''),'—') as estrutura_gravada,
       coalesce(nullif(d->>'segmento',''),'—')  as segmento,
       d->>'etapa' as etapa,
       case when (d->>'valor') ~ '^[0-9]+(\.[0-9]+)?$' and (d->>'valor')::numeric > 0
            then to_char((d->>'valor')::numeric,'FM999G999G999G999') else '—' end as valor
  from public.pipeline p, jsonb_array_elements(p.dados->'deals') d
 where p.id = 1
   and (d->>'frente' = 'capital' or coalesce(d->'frentes','[]'::jsonb) ? 'capital')
 order by 3, 2;
