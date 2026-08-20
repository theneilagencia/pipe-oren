-- =============================================================================
-- Oren · área administrativa
-- Cole no SQL Editor do Supabase e execute uma vez, depois do tudo-em-um.sql.
-- =============================================================================
-- Desenho: a página /admin não fala direto com o banco para o que é privilegiado.
-- Ela chama uma função de servidor no Vercel, que guarda a chave service_role.
-- Por isso aqui não existe política nova de escrita no perfil: quem escreve é a
-- função, com a chave, fora do navegador. O que o navegador ganha é só a coluna
-- de e-mail para exibição e um jeito seguro de desligar a marca de senha
-- provisória depois que a pessoa troca a própria senha.

-- E-mail no perfil: o painel precisa mostrar quem é quem sem poder ler auth.users.
alter table public.perfil add column if not exists email text;
-- Marca de senha provisória: enquanto for true, o painel exige a troca.
alter table public.perfil add column if not exists senha_provisoria boolean not null default false;

-- Preenche o e-mail de quem já existe.
update public.perfil p
   set email = u.email
  from auth.users u
 where u.id = p.id and p.email is distinct from u.email;

-- O gatilho passa a gravar o e-mail e a nascer com senha provisória.
create or replace function public.cria_perfil()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  meta   jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  v_nome text;
  v_papel text;
begin
  v_nome := nullif(trim(coalesce(meta->>'nome', meta->>'name', '')), '');
  if v_nome is null then
    v_nome := initcap(split_part(coalesce(new.email, 'pessoa'), '@', 1));
  end if;

  v_papel := case lower(trim(coalesce(meta->>'papel', meta->>'role', '')))
               when 'leitor' then 'leitor'
               else 'editor'
             end;

  insert into public.perfil (id, nome, papel, email, senha_provisoria)
  values (new.id, v_nome, v_papel, new.email, true)
  on conflict (id) do nothing;
  return new;
end;
$$;

-- Desligar a marca de senha provisória é a única escrita que a pessoa faz no
-- próprio perfil. Uma política de update aberta deixaria um leitor se promover
-- a editor, então isto é uma função que mexe só nessa coluna, e só na linha de
-- quem está logado.
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

-- Conferência: deve listar as pessoas com e-mail e a marca de senha.
select nome, papel, email, senha_provisoria from public.perfil order by nome;
