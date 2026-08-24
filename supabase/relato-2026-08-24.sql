-- =============================================================================
-- Oren · carga do relato de 24/08/2026 (negócios sob responsabilidade do Paulo)
-- Cole no SQL Editor do Supabase e execute. Rodar de novo é seguro: insere
-- registro por registro, só o que ainda não existe.
-- =============================================================================
-- Fonte: relato de Vinícius em 24/08/2026. Campo sem base no relato fica vazio.
-- Valor vazio em todos: nenhum foi dito. Os R$ 100 milhões do N-052 são a
-- hipótese de captação por shopping, não o valor do negócio; os US$ 100 mil do
-- N-053 são volume em dólar. Cada negócio leva a tag "revisar-cadastro" e
-- pendências dizendo o que falta confirmar, inclusive etapa e frente.
--
-- O painel publicado já faz esta mesma carga na primeira entrada de um editor.
-- Este arquivo existe para quem preferir aplicar pelo banco.

update public.pipeline set dados = jsonb_set(dados,'{customers}',(dados->'customers') || $j$[
 {
  "id": "C-06",
  "nome": "Alphabeto",
  "tipo": "PJ",
  "parceiroId": null,
  "responsavel": "Paulo",
  "frente": "capital",
  "setor": "",
  "uf": "",
  "tier": "",
  "status": "",
  "porte": "",
  "receitaRecorrente": 0,
  "notas": "Razão social, CNPJ e setor não informados no relato de 24/08/2026.",
  "exemplo": false,
  "criadoEm": "2026-08-24",
  "atualizadoEm": "2026-08-24",
  "publico": "B2B"
 }
]$j$::jsonb)
 where id = 1 and not exists (
   select 1 from jsonb_array_elements(dados->'customers') e where e->>'id' = 'C-06');

update public.pipeline set dados = jsonb_set(dados,'{customers}',(dados->'customers') || $j$[
 {
  "id": "C-07",
  "nome": "Goulart e Collepicolo",
  "tipo": "PJ",
  "parceiroId": null,
  "responsavel": "Paulo",
  "frente": "capital",
  "setor": "",
  "uf": "",
  "tier": "",
  "status": "",
  "porte": "",
  "receitaRecorrente": 0,
  "notas": "Razão social e CNPJ não informados. Theo é quem detém o detalhe da negociação.",
  "exemplo": false,
  "criadoEm": "2026-08-24",
  "atualizadoEm": "2026-08-24",
  "publico": "B2B"
 }
]$j$::jsonb)
 where id = 1 and not exists (
   select 1 from jsonb_array_elements(dados->'customers') e where e->>'id' = 'C-07');

update public.pipeline set dados = jsonb_set(dados,'{customers}',(dados->'customers') || $j$[
 {
  "id": "C-08",
  "nome": "Mercado Livre",
  "tipo": "PJ",
  "parceiroId": null,
  "responsavel": "Paulo",
  "frente": "capital",
  "setor": "",
  "uf": "",
  "tier": "",
  "status": "",
  "porte": "",
  "receitaRecorrente": 0,
  "notas": "Nome como citado no relato. Razão social, CNPJ e a contraparte que assina não informados.",
  "exemplo": false,
  "criadoEm": "2026-08-24",
  "atualizadoEm": "2026-08-24",
  "publico": "B2B"
 }
]$j$::jsonb)
 where id = 1 and not exists (
   select 1 from jsonb_array_elements(dados->'customers') e where e->>'id' = 'C-08');

update public.pipeline set dados = jsonb_set(dados,'{customers}',(dados->'customers') || $j$[
 {
  "id": "C-09",
  "nome": "Fred",
  "tipo": "PF",
  "parceiroId": null,
  "responsavel": "Paulo",
  "frente": "payments",
  "setor": "",
  "uf": "",
  "tier": "",
  "status": "",
  "porte": "",
  "receitaRecorrente": 0,
  "notas": "Pessoa física. Mesmo contato citado na ata de 21/08/2026 como gestor de fundo externo. Nome completo, CPF e residência fiscal não informados.",
  "exemplo": false,
  "criadoEm": "2026-08-24",
  "atualizadoEm": "2026-08-24",
  "publico": "B2C"
 }
]$j$::jsonb)
 where id = 1 and not exists (
   select 1 from jsonb_array_elements(dados->'customers') e where e->>'id' = 'C-09');

update public.pipeline set dados = jsonb_set(dados,'{deals}',(dados->'deals') || $j$[
 {
  "id": "N-049",
  "titulo": "Transferência da estruturação — Alphabeto",
  "frente": "capital",
  "tipoVenda": "direta",
  "parceiroId": null,
  "clienteId": "C-06",
  "responsavel": "Paulo",
  "valor": "",
  "etapa": 5,
  "proximoPasso": "",
  "prazo": "",
  "chance": "",
  "pendencias": [
   {
    "id": "PD-A49",
    "texto": "O que exatamente falta transferir, para quem e em que prazo — o relato só diz que falta a transferência.",
    "responsavel": "Paulo",
    "prazo": "",
    "bloqueante": true,
    "resolvida": false
   },
   {
    "id": "PD-B49",
    "texto": "Confirmar a etapa: a estruturação está feita, mas o funil de Capital tem Aprovação, Busca de capital e Documentação depois de Estrutura indicativa.",
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
  "notas": "Estruturação concluída, segundo o relato. O que falta é a transferência.\nEtapa 5 (Estrutura indicativa) registrada porque o relato diz que a estruturação foi feita; confirmar se a etapa correta é esta ou uma adiante.\nOrigem: relato de Vinícius em 24/08/2026. Campo sem base no relato fica vazio. Nada aqui foi calculado ou inferido além do que está escrito nas notas.",
  "tags": [
   "revisar-cadastro"
  ],
  "exemplo": false,
  "criadoEm": "2026-08-24",
  "atualizadoEm": "2026-08-24",
  "fechadoEm": null,
  "historico": [
   {
    "de": "—",
    "para": "Estrutura indicativa",
    "quando": "2026-08-24T00:00:00.000Z",
    "quem": "Carga do relato de 24/08/2026"
   }
  ],
  "publico": "B2B"
 }
]$j$::jsonb)
 where id = 1 and not exists (
   select 1 from jsonb_array_elements(dados->'deals') e where e->>'id' = 'N-049');

update public.pipeline set dados = jsonb_set(dados,'{deals}',(dados->'deals') || $j$[
 {
  "id": "N-050",
  "titulo": "Operação do Shopping Oiapoque — Goulart e Collepicolo",
  "frente": "capital",
  "tipoVenda": "direta",
  "parceiroId": null,
  "clienteId": "C-07",
  "responsavel": "Paulo",
  "valor": "",
  "etapa": 2,
  "proximoPasso": "",
  "prazo": "",
  "chance": "",
  "pendencias": [
   {
    "id": "PD-A50",
    "texto": "Esclarecer o estágio e o objeto da negociação do Shopping Oiapoque.",
    "responsavel": "Theo",
    "prazo": "",
    "bloqueante": true,
    "resolvida": false
   },
   {
    "id": "PD-B50",
    "texto": "Definir valor e estrutura da operação.",
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
  "notas": "Em negociação, segundo o relato. Theo é quem sabe esclarecer.\nOrigem: relato de Vinícius em 24/08/2026. Campo sem base no relato fica vazio. Nada aqui foi calculado ou inferido além do que está escrito nas notas.",
  "tags": [
   "revisar-cadastro"
  ],
  "exemplo": false,
  "criadoEm": "2026-08-24",
  "atualizadoEm": "2026-08-24",
  "fechadoEm": null,
  "historico": [
   {
    "de": "—",
    "para": "Qualificação",
    "quando": "2026-08-24T00:00:00.000Z",
    "quem": "Carga do relato de 24/08/2026"
   }
  ],
  "publico": "B2B"
 }
]$j$::jsonb)
 where id = 1 and not exists (
   select 1 from jsonb_array_elements(dados->'deals') e where e->>'id' = 'N-050');

update public.pipeline set dados = jsonb_set(dados,'{deals}',(dados->'deals') || $j$[
 {
  "id": "N-051",
  "titulo": "200.000 m² de telha do Mercado Livre em Betim",
  "frente": "capital",
  "tipoVenda": "direta",
  "parceiroId": null,
  "clienteId": "C-08",
  "responsavel": "Paulo",
  "valor": "",
  "etapa": 1,
  "proximoPasso": "",
  "prazo": "",
  "chance": "",
  "pendencias": [
   {
    "id": "PD-A51",
    "texto": "Definir o que é a operação — venda, locação, sale and leaseback — e quem é a contraparte que assina.",
    "responsavel": "Paulo",
    "prazo": "",
    "bloqueante": true,
    "resolvida": false
   },
   {
    "id": "PD-B51",
    "texto": "Levantar valor por metro quadrado e valor total.",
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
  "ufs": "MG",
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
  "notas": "Operação imobiliária citada no relato: 200.000 m² de telha do Mercado Livre em Betim (MG).\nMetragem é a do relato; não foi convertida em valor.\nOrigem: relato de Vinícius em 24/08/2026. Campo sem base no relato fica vazio. Nada aqui foi calculado ou inferido além do que está escrito nas notas.",
  "tags": [
   "revisar-cadastro"
  ],
  "exemplo": false,
  "criadoEm": "2026-08-24",
  "atualizadoEm": "2026-08-24",
  "fechadoEm": null,
  "historico": [
   {
    "de": "—",
    "para": "Entrada",
    "quando": "2026-08-24T00:00:00.000Z",
    "quem": "Carga do relato de 24/08/2026"
   }
  ],
  "publico": "B2B"
 }
]$j$::jsonb)
 where id = 1 and not exists (
   select 1 from jsonb_array_elements(dados->'deals') e where e->>'id' = 'N-051');

update public.pipeline set dados = jsonb_set(dados,'{deals}',(dados->'deals') || $j$[
 {
  "id": "N-052",
  "titulo": "Dois shoppings: mandato de venda ou captação de R$ 100 milhões cada",
  "frente": "capital",
  "tipoVenda": "direta",
  "parceiroId": null,
  "clienteId": null,
  "responsavel": "Paulo",
  "valor": "",
  "etapa": 1,
  "proximoPasso": "",
  "prazo": "",
  "chance": "",
  "pendencias": [
   {
    "id": "PD-A52",
    "texto": "Decidir entre mandato de venda e captação: são estruturas diferentes e mudam o negócio inteiro.",
    "responsavel": "Paulo",
    "prazo": "",
    "bloqueante": true,
    "resolvida": false
   },
   {
    "id": "PD-B52",
    "texto": "Identificar o cliente e quais são os dois shoppings.",
    "responsavel": "Paulo",
    "prazo": "",
    "bloqueante": true,
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
  "notas": "Possibilidade em avaliação, segundo o relato: mandato de venda dos dois shoppings, OU captação de R$ 100 milhões para cada um. São dois caminhos excludentes e nenhum foi escolhido, então o valor do negócio fica vazio: R$ 100 milhões é o valor citado por shopping na hipótese de captação, não o valor deste negócio.\nCliente não identificado no relato.\nOrigem: relato de Vinícius em 24/08/2026. Campo sem base no relato fica vazio. Nada aqui foi calculado ou inferido além do que está escrito nas notas.",
  "tags": [
   "revisar-cadastro",
   "valor a definir"
  ],
  "exemplo": false,
  "criadoEm": "2026-08-24",
  "atualizadoEm": "2026-08-24",
  "fechadoEm": null,
  "historico": [
   {
    "de": "—",
    "para": "Entrada",
    "quando": "2026-08-24T00:00:00.000Z",
    "quem": "Carga do relato de 24/08/2026"
   }
  ],
  "publico": "B2B"
 }
]$j$::jsonb)
 where id = 1 and not exists (
   select 1 from jsonb_array_elements(dados->'deals') e where e->>'id' = 'N-052');

update public.pipeline set dados = jsonb_set(dados,'{deals}',(dados->'deals') || $j$[
 {
  "id": "N-053",
  "titulo": "Envio de US$ 100 mil pela Oren — operação pessoal do Fred",
  "frente": "payments",
  "tipoVenda": "direta",
  "parceiroId": null,
  "clienteId": "C-09",
  "responsavel": "Paulo",
  "valor": "",
  "etapa": 1,
  "proximoPasso": "",
  "prazo": "",
  "chance": "",
  "pendencias": [
   {
    "id": "PD-A53",
    "texto": "Confirmar se a Oren pode executar remessa de pessoa física e sob qual enquadramento — ver as pendências regulatórias do N-048.",
    "responsavel": "Vinícius",
    "prazo": "",
    "bloqueante": true,
    "resolvida": false
   },
   {
    "id": "PD-B53",
    "texto": "Definir corredor, prazo e tarifa da remessa.",
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
  "notas": "Operação pessoal do Fred, distinta das contas escrow dos fundos (N-048).\nUS$ 100 mil é o volume citado no relato, em dólar. Não foi convertido para real nem lançado como valor do negócio.\nOrigem: relato de Vinícius em 24/08/2026. Campo sem base no relato fica vazio. Nada aqui foi calculado ou inferido além do que está escrito nas notas.",
  "tags": [
   "revisar-cadastro"
  ],
  "exemplo": false,
  "criadoEm": "2026-08-24",
  "atualizadoEm": "2026-08-24",
  "fechadoEm": null,
  "historico": [
   {
    "de": "—",
    "para": "Entrada",
    "quando": "2026-08-24T00:00:00.000Z",
    "quem": "Carga do relato de 24/08/2026"
   }
  ],
  "publico": "B2C"
 }
]$j$::jsonb)
 where id = 1 and not exists (
   select 1 from jsonb_array_elements(dados->'deals') e where e->>'id' = 'N-053');

update public.pipeline set dados = jsonb_set(dados,'{deals}',(dados->'deals') || $j$[
 {
  "id": "N-054",
  "titulo": "Master em Brasília — Daniela",
  "frente": "payments",
  "tipoVenda": "direta",
  "parceiroId": null,
  "clienteId": null,
  "responsavel": "Paulo",
  "valor": "",
  "etapa": 1,
  "proximoPasso": "",
  "prazo": "",
  "chance": "",
  "pendencias": [
   {
    "id": "PD-A54",
    "texto": "Dizer o que é a operação Master e quem é o cliente.",
    "responsavel": "Paulo",
    "prazo": "",
    "bloqueante": true,
    "resolvida": false
   },
   {
    "id": "PD-B54",
    "texto": "Confirmar a frente: entrou em Payments por proximidade com as outras operações do relato, sem base no texto.",
    "responsavel": "Paulo",
    "prazo": "",
    "bloqueante": true,
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
  "notas": "Citado no relato apenas como “Master com a Daniela em BSB”. Não há no relato o que é a operação Master, quem é a Daniela na estrutura, nem quem é o cliente. Registrado para não se perder; tudo o mais precisa de confirmação.\nOrigem: relato de Vinícius em 24/08/2026. Campo sem base no relato fica vazio. Nada aqui foi calculado ou inferido além do que está escrito nas notas.",
  "tags": [
   "revisar-cadastro"
  ],
  "exemplo": false,
  "criadoEm": "2026-08-24",
  "atualizadoEm": "2026-08-24",
  "fechadoEm": null,
  "historico": [
   {
    "de": "—",
    "para": "Entrada",
    "quando": "2026-08-24T00:00:00.000Z",
    "quem": "Carga do relato de 24/08/2026"
   }
  ],
  "publico": "B2B"
 }
]$j$::jsonb)
 where id = 1 and not exists (
   select 1 from jsonb_array_elements(dados->'deals') e where e->>'id' = 'N-054');

-- Conferência: deve devolver 43 | 9 | 54.
select jsonb_array_length(dados->'partners')  as parceiros,
       jsonb_array_length(dados->'customers') as clientes,
       jsonb_array_length(dados->'deals')     as negocios,
       versao
  from public.pipeline where id = 1;

-- Conferência: os seis do relato, no nome do Paulo.
select e->>'id' as id, e->>'frente' as frente, e->>'etapa' as etapa,
       e->>'responsavel' as responsavel,
       coalesce(nullif(e->>'valor',''),'(vazio)') as valor,
       jsonb_array_length(e->'pendencias') as pendencias,
       e->>'titulo' as titulo
  from public.pipeline, jsonb_array_elements(dados->'deals') e
 where id = 1 and e->>'id' in ('N-049','N-050','N-051','N-052','N-053','N-054')
 order by 1;
