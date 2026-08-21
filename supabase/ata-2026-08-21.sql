-- =============================================================================
-- Oren · deal flow da ata de 21/08/2026 · Frente 1 (Payments)
-- Cole no SQL Editor do Supabase e execute UMA vez. Repetir não duplica.
-- =============================================================================
-- Fonte: ata-2026-08-21-gtm-comercial-oren.docx, registro unilateral do Paulo,
-- pendente de validação na OB-20 (seção 9). Campo sem base na ata fica vazio:
-- valor não foi calculado porque o ponto P1 registra divergência de três ordens
-- de grandeza entre a precificação sugerida e o volume.
--
-- Acrescenta C-05 e N-048 concatenando nos arrays do documento. Não altera os
-- 43 negócios de Governance nem os 4 de Capital. O gatilho carimba_pipeline
-- arquiva a versão anterior em pipeline_historico antes de gravar.

update public.pipeline
   set dados = jsonb_set(
                 jsonb_set(dados, '{customers}', (dados->'customers') || $cli$[
 {
  "id": "C-05",
  "nome": "Gestor de fundo (contato: Fred)",
  "tipo": "PJ",
  "parceiroId": null,
  "responsavel": "Paulo",
  "frente": "payments",
  "setor": "Fundos de investimento",
  "uf": "",
  "tier": "",
  "status": "",
  "porte": "",
  "receitaRecorrente": 0,
  "notas": "Contato Fred, gestor de fundo externo. Razão social e CNPJ não informados na ata de 21/08/2026. Registro pendente de validação na OB-20.",
  "exemplo": false,
  "criadoEm": "2026-08-21",
  "atualizadoEm": "2026-08-21",
  "publico": "B2B"
 }
]$cli$::jsonb),
                 '{deals}',       (dados->'deals')     || $neg$[
 {
  "id": "N-048",
  "titulo": "Contas escrow para fundos de investimento",
  "frente": "payments",
  "tipoVenda": "direta",
  "parceiroId": null,
  "clienteId": "C-05",
  "responsavel": "Paulo",
  "valor": "",
  "etapa": 2,
  "proximoPasso": "Levantar volume médio mensal e ticket por transação nas contas escrow dos fundos alvo",
  "prazo": "2026-08-26",
  "chance": "",
  "pendencias": [
   {
    "id": "PD-K4XQ7M",
    "texto": "Volume e ticket das contas escrow desconhecidos. Sem esse dado não existe modelo de precificação. Ref. OB-01",
    "responsavel": "Paulo",
    "prazo": "2026-08-26",
    "bloqueante": true,
    "resolvida": false
   },
   {
    "id": "PD-R9WBT2",
    "texto": "Contraparte de stablecoin BRL não definida. A ata usa BRID e Bridge de forma intercambiável e são contrapartes distintas. Ref. OB-02 e P4",
    "responsavel": "Theo",
    "prazo": "2026-08-27",
    "bloqueante": true,
    "resolvida": false
   },
   {
    "id": "PD-H3ZLD8",
    "texto": "Parecer jurídico sobre o posicionamento comercial da frente pendente. Não abrir conta antes da conclusão. Ref. OB-03 e D1",
    "responsavel": "Vinícius",
    "prazo": "2026-08-29",
    "bloqueante": true,
    "resolvida": false
   },
   {
    "id": "PD-M7VKC5",
    "texto": "Enquadramento nas Res. BCB 519, 520, 521, 561 e 584 não mapeado. Marco externo em 30/10/2026. Ref. OB-04",
    "responsavel": "Vinícius",
    "prazo": "2026-09-03",
    "bloqueante": true,
    "resolvida": false
   },
   {
    "id": "PD-Q2NFJ6",
    "texto": "Razão social e CNPJ da gestora não identificados.",
    "responsavel": "Paulo",
    "prazo": "",
    "bloqueante": false,
    "resolvida": false
   }
  ],
  "tese": "",
  "estrutura": "",
  "frenteCapital": "",
  "investidor": "",
  "statusCaptacao": "",
  "cincoPerguntas": {
   "pagamento": "NaoAvaliada",
   "contrato": "NaoAvaliada",
   "garantias": "NaoAvaliada",
   "valorImovel": "NaoAvaliada",
   "usoAlternativo": "NaoAvaliada"
  },
  "seisCamadas": {
   "qualidadeEmpresa": {
    "nota": 0,
    "obs": ""
   },
   "contratoLongoPrazo": {
    "nota": 0,
    "obs": ""
   },
   "garantias": {
    "nota": 0,
    "obs": ""
   },
   "valorImovel": {
    "nota": 0,
    "obs": ""
   },
   "trocaOcupante": {
    "nota": 0,
    "obs": ""
   },
   "usoAlternativo": {
    "nota": 0,
    "obs": ""
   }
  },
  "situacao": "",
  "segmento": "",
  "origem": "",
  "ufs": "",
  "papeis": {
   "origina": "",
   "estrutura": "",
   "analisaRisco": "",
   "buscaCapital": "",
   "executa": "",
   "acompanha": ""
  },
  "territorio": {
   "populacaoRenda": {
    "status": "NaoAvaliada",
    "obs": ""
   },
   "areaInfluencia": {
    "status": "NaoAvaliada",
    "obs": ""
   },
   "concorrencia": {
    "status": "NaoAvaliada",
    "obs": ""
   },
   "crescimento": {
    "status": "NaoAvaliada",
    "obs": ""
   },
   "usoSolo": {
    "status": "NaoAvaliada",
    "obs": ""
   },
   "liquidez": {
    "status": "NaoAvaliada",
    "obs": ""
   },
   "operadoresAlternativos": {
    "status": "NaoAvaliada",
    "obs": ""
   },
   "potencialDesenvolvimento": {
    "status": "NaoAvaliada",
    "obs": ""
   }
  },
  "comite": {
   "decisao": "",
   "condicoes": "",
   "responsaveis": "",
   "excecoes": "",
   "validadeAte": ""
  },
  "motivoPerda": "",
  "notas": "Origem: ata de 21/08/2026, áudio unilateral do Paulo, pendente de validação na OB-20.\nFred sinalizou intenção de abrir 500 contas escrow.\nPrecificação sugerida por ele: 0,5% de cash-in e 0,5% de cash-out. Não validada contra volume (P1).\nRequisito técnico declarado: operação real contra real, via stablecoin de real, sem exposição cambial.\nIncumbentes citados: Banco Fidúcia e Banco BMP, a R$ 250,00 por mês por conta com movimentação alta, mais tarifa por Pix, TED e boleto.\nDor declarada: bloqueios judiciais recorrentes nas contas escrow atuais.\nContexto de canal: mais de 80 fundos citados, sem contraparte identificada além do Fred.",
  "tags": [],
  "exemplo": false,
  "criadoEm": "2026-08-21",
  "atualizadoEm": "2026-08-21",
  "fechadoEm": null,
  "historico": [
   {
    "de": "—",
    "para": "Qualificação",
    "quando": "2026-08-21T00:00:00.000Z",
    "quem": "Carga da ata de 21/08/2026"
   }
  ],
  "publico": "B2B"
 }
]$neg$::jsonb)
 where id = 1
   and not exists (
     select 1 from jsonb_array_elements(dados->'deals') e where e->>'id' = 'N-048');

-- Conferência 1: deve devolver 43 | 5 | 48.
select jsonb_array_length(dados->'partners')  as parceiros,
       jsonb_array_length(dados->'customers') as clientes,
       jsonb_array_length(dados->'deals')     as negocios,
       versao
  from public.pipeline where id = 1;

-- Conferência 2: o negócio novo, com valor vazio e 4 pendências bloqueantes.
select e->>'id' as id, e->>'frente' as frente, e->>'etapa' as etapa,
       e->>'publico' as publico, e->>'responsavel' as responsavel,
       coalesce(nullif(e->>'valor',''),'(vazio)') as valor,
       jsonb_array_length(e->'pendencias') as pendencias,
       (select count(*) from jsonb_array_elements(e->'pendencias') p
         where (p->>'bloqueante')::boolean) as bloqueantes,
       e->'historico'->0->>'quem' as criado_por
  from public.pipeline, jsonb_array_elements(dados->'deals') e
 where id = 1 and e->>'id' = 'N-048';
