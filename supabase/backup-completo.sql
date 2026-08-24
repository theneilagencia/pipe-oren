-- =============================================================================
-- Oren · backup do que NÃO cabe no Exportar do painel
-- =============================================================================
-- O Exportar do painel baixa o documento do pipeline inteiro — parceiros,
-- clientes, negócios, pendências, histórico de etapas, lista de responsáveis.
-- Isso é o dado de trabalho, e é o que importa no dia a dia.
--
-- Três coisas vivem no banco e não entram naquele arquivo. Rode cada consulta
-- no SQL Editor e use "Download CSV" no resultado.

-- 1. Quem tem acesso, com nome e papel. Sem isto, restaurar o pipeline devolve
--    os dados e não devolve quem entra.
select id, nome, papel, email, senha_provisoria
  from public.perfil
 order by nome;

-- 2. O histórico de versões do documento. Cada gravação arquiva a versão
--    anterior aqui; é o que permite voltar a um estado de ontem sem ter feito
--    backup ontem.
select versao, atualizado_em, atualizado_por,
       jsonb_array_length(dados->'partners')  as parceiros,
       jsonb_array_length(dados->'customers') as clientes,
       jsonb_array_length(dados->'deals')     as negocios
  from public.pipeline_historico
 order by versao desc;

-- 3. O documento atual direto do banco, para conferir contra o arquivo baixado.
--    O número da versão tem de ser o mesmo que o painel mostrou no aviso.
select versao, atualizado_em, atualizado_por, dados
  from public.pipeline where id = 1;

-- Uma versão específica do histórico, quando precisar voltar no tempo:
-- select dados from public.pipeline_historico where versao = 31;

-- As contas de login em si (auth.users) só saem pela API de administração do
-- Supabase, com a chave service_role — não por SQL daqui. Em Authentication →
-- Users existe exportação na própria tela.
