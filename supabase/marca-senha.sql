-- A função que desliga a marca de "senha provisória", e o conserto de quem
-- ficou preso pedindo troca a cada login.
-- 26/08/2026
--
-- O painel pede a troca sempre que public.perfil.senha_provisoria é true, e quem
-- desliga essa marca depois da troca é a função abaixo, chamada pelo navegador.
-- Se ela não existe no projeto -- ou existe sem permissão de execute -- a troca
-- acontece de verdade no Supabase mas a marca continua ligada, e o painel
-- pergunta de novo no acesso seguinte. Era exatamente esse o sintoma.
--
-- Rodar isto é seguro mais de uma vez. Não toca em public.pipeline.

-- ---------------------------------------------------------------- 1. a função
-- Desligar a marca é a única escrita que a pessoa faz no próprio perfil. Uma
-- política de update aberta deixaria um leitor se promover a editor, então é
-- uma função que mexe só nessa coluna, e só na linha de quem está logado.
create or replace function public.senha_trocada()
returns void
language sql
security definer
set search_path = public
as $$
  update public.perfil set senha_provisoria = false where id = auth.uid();
$$;
revoke all on function public.senha_trocada() from public;
grant execute on function public.senha_trocada() to authenticated;

-- --------------------------------------------------- 2. conferir que ela existe
select p.proname as funcao,
       pg_get_function_identity_arguments(p.oid) as argumentos,
       p.prosecdef                               as security_definer,
       has_function_privilege('authenticated', p.oid, 'execute') as authenticated_pode_executar
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname = 'senha_trocada';

-- ------------------------------------- 3. quem está preso agora, e o conserto
-- Quem já trocou a senha mas continua com a marca ligada. Confira a lista antes
-- de rodar o update: quem NUNCA trocou precisa continuar marcado.
select p.nome, p.papel, p.senha_provisoria, u.email, u.last_sign_in_at
  from public.perfil p join auth.users u on u.id = p.id
 where p.senha_provisoria
 order by p.nome;

-- Desliga a marca de uma pessoa só. Troque o nome e confira o retorno.
-- update public.perfil set senha_provisoria = false
--  where nome = 'Afrânio'
-- returning nome, senha_provisoria;
