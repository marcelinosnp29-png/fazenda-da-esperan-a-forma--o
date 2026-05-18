-- Habilita a extensão uuid-ossp para gerar UUIDs automaticamente
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Funções Auxiliares
----------------------------------------------------------------------------------------------------

-- Função para atualizar automaticamente a coluna 'updated_at'
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Função auxiliar para verificar se o usuário atual é um administrador
-- Esta função é SECURITY DEFINER para que possa acessar a tabela 'usuarios'
-- com privilégios de criador (geralmente postgres) e verificar a role,
-- mesmo que o RLS normalmente impedisse o usuário atual de ver outras roles.
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public.usuarios
    WHERE id = auth.uid() AND role = 'admin'
  );
END;
$$;

-- Concede permissão de execução da função is_admin a todos os roles
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated, anon, service_role;

-- 2. Criação das Tabelas
----------------------------------------------------------------------------------------------------

-- Tabela: public.leads
-- Armazena informações de potenciais clientes interessados nos cursos.
CREATE TABLE public.leads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    nome TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
    telefone TEXT,
    origem TEXT DEFAULT 'site', -- Ex: 'site', 'instagram', 'facebook', 'whatsapp'
    status TEXT DEFAULT 'novo' CHECK (status IN ('novo', 'contatado', 'interessado', 'descartado', 'convertido'))
);

-- Tabela: public.usuarios
-- Armazena perfis de usuários (alunos, professores, administradores) vinculados a auth.users.
CREATE TABLE public.usuarios (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE, -- Referência à tabela de autenticação do Supabase
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    nome_completo TEXT,
    email TEXT NOT NULL UNIQUE CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
    avatar_url TEXT CHECK (avatar_url ~* '^https?:\/\/(?:www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b(?:[-a-zA-Z0-9()@:%_\+.~#?&//=]*)$'),
    role TEXT DEFAULT 'aluno' CHECK (role IN ('aluno', 'professor', 'admin'))
);

-- Tabela: public.posts
-- Conteúdo dinâmico como artigos de blog, páginas de cursos, notícias, etc.
CREATE TABLE public.posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    titulo TEXT NOT NULL,
    slug TEXT NOT NULL UNIQUE, -- Para URLs amigáveis
    conteudo TEXT,
    autor_id UUID REFERENCES public.usuarios(id) ON DELETE SET NULL,
    imagem_capa_url TEXT CHECK (imagem_capa_url ~* '^https?:\/\/(?:www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b(?:[-a-zA-Z0-9()@:%_\+.~#?&//=]*)$'),
    status TEXT DEFAULT 'rascunho' CHECK (status IN ('rascunho', 'publicado', 'arquivado')),
    tipo TEXT DEFAULT 'blog' CHECK (tipo IN ('blog', 'curso', 'pagina', 'noticia')),
    data_publicacao TIMESTAMP WITH TIME ZONE
);

-- Tabela: public.configuracoes
-- Configurações globais do site/plataforma.
CREATE TABLE public.configuracoes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    nome_empresa TEXT NOT NULL,
    cor_primaria TEXT NOT NULL CHECK (cor_primaria ~* '^#[0-9a-fA-F]{6}$'), -- Ex: '#2563eb'
    cor_secundaria TEXT CHECK (cor_secundaria ~* '^#[0-9a-fA-F]{6}$'),
    logo_url TEXT CHECK (logo_url ~* '^https?:\/\/(?:www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b(?:[-a-zA-Z0-9()@:%_\+.~#?&//=]*)$'),
    whatsapp TEXT, -- Ex: '+5511999999999'
    email_contato TEXT CHECK (email_contato ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
    endereco TEXT,
    redes_sociais JSONB -- Ex: '{ "facebook": "url", "instagram": "url" }'
);

-- Tabela: public.arquivos
-- Gerenciamento de arquivos (imagens, documentos, vídeos) carregados pelos usuários.
CREATE TABLE public.arquivos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    nome TEXT NOT NULL,
    url TEXT NOT NULL UNIQUE CHECK (url ~* '^https?:\/\/(?:www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b(?:[-a-zA-Z0-9()@:%_\+.~#?&//=]*)$'),
    mime_type TEXT, -- Ex: 'image/jpeg', 'application/pdf'
    tamanho BIGINT, -- Tamanho do arquivo em bytes
    proprietario_id UUID REFERENCES public.usuarios(id) ON DELETE SET NULL,
    tipo TEXT CHECK (tipo IN ('imagem', 'documento', 'video', 'audio', 'outro')),
    pasta TEXT -- Para organização lógica, ex: 'posts/capas', 'cursos/modulo1'
);


-- 3. Funções de Gatilho (Triggers)
----------------------------------------------------------------------------------------------------

-- Função de gatilho para criar um perfil de usuário na tabela 'public.usuarios'
-- sempre que um novo usuário é registrado em 'auth.users'.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.usuarios (id, email, nome_completo)
  VALUES (NEW.id, NEW.email, NEW.raw_user_meta_data->>'full_name');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER; -- SECURITY DEFINER para garantir que a função possa inserir na tabela public.usuarios


-- 4. Definição dos Gatilhos (Triggers)
----------------------------------------------------------------------------------------------------

-- Gatilho para 'public.leads' para atualizar 'updated_at'
CREATE TRIGGER set_updated_at_leads BEFORE UPDATE ON public.leads FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Gatilho para 'public.usuarios' para atualizar 'updated_at'
CREATE TRIGGER set_updated_at_usuarios BEFORE UPDATE ON public.usuarios FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Gatilho para 'auth.users' para criar um novo usuário em 'public.usuarios'
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Gatilho para 'public.posts' para atualizar 'updated_at'
CREATE TRIGGER set_updated_at_posts BEFORE UPDATE ON public.posts FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Gatilho para 'public.configuracoes' para atualizar 'updated_at'
CREATE TRIGGER set_updated_at_configuracoes BEFORE UPDATE ON public.configuracoes FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Gatilho para 'public.arquivos' para atualizar 'updated_at'
CREATE TRIGGER set_updated_at_arquivos BEFORE UPDATE ON public.arquivos FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- 5. Row Level Security (RLS)
----------------------------------------------------------------------------------------------------

-- Habilita RLS para todas as tabelas
ALTER TABLE public.leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.usuarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.configuracoes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.arquivos ENABLE ROW LEVEL SECURITY;

-- Políticas RLS para 'public.leads'
CREATE POLICY "Anon can insert leads" ON public.leads FOR INSERT WITH CHECK (true); -- Permite inserção anônima
CREATE POLICY "Admins can view all leads" ON public.leads FOR SELECT USING (is_admin());
CREATE POLICY "Admins can update leads" ON public.leads FOR UPDATE USING (is_admin());
CREATE POLICY "Admins can delete leads" ON public.leads FOR DELETE USING (is_admin());

-- Políticas RLS para 'public.usuarios'
-- A inserção é tratada pelo trigger handle_new_user
CREATE POLICY "Users can view their own profile" ON public.usuarios FOR SELECT USING (auth.uid() = id OR is_admin());
CREATE POLICY "Users can update their own profile" ON public.usuarios FOR UPDATE USING (auth.uid() = id OR is_admin());
CREATE POLICY "Admins can delete any user profile" ON public.usuarios FOR DELETE USING (is_admin());

-- Políticas RLS para 'public.posts'
CREATE POLICY "Public can view published posts" ON public.posts FOR SELECT USING (status = 'publicado' OR is_admin());
CREATE POLICY "Admins can insert posts" ON public.posts FOR INSERT WITH CHECK (is_admin());
CREATE POLICY "Admins can update posts" ON public.posts FOR UPDATE USING (is_admin());
CREATE POLICY "Admins can delete posts" ON public.posts FOR DELETE USING (is_admin());

-- Políticas RLS para 'public.configuracoes'
CREATE POLICY "Public can view configurations" ON public.configuracoes FOR SELECT USING (true);
CREATE POLICY "Admins can insert configurations" ON public.configuracoes FOR INSERT WITH CHECK (is_admin());
CREATE POLICY "Admins can update configurations" ON public.configuracoes FOR UPDATE USING (is_admin());
CREATE POLICY "Admins can delete configurations" ON public.configuracoes FOR DELETE USING (is_admin());

-- Políticas RLS para 'public.arquivos'
CREATE POLICY "Authenticated users can insert files" ON public.arquivos FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "Users can view their own files" ON public.arquivos FOR SELECT USING (auth.uid() = proprietario_id OR is_admin());
CREATE POLICY "Users can update their own files" ON public.arquivos FOR UPDATE USING (auth.uid() = proprietario_id OR is_admin());
CREATE POLICY "Users can delete their own files" ON public.arquivos FOR DELETE USING (auth.uid() = proprietario_id OR is_admin());
-- Políticas adicionais para admins (se as políticas acima não forem suficientes ou se quiser sobrepor)
CREATE POLICY "Admins can view all files" ON public.arquivos FOR SELECT USING (is_admin());
CREATE POLICY "Admins can insert files" ON public.arquivos FOR INSERT WITH CHECK (is_admin());
CREATE POLICY "Admins can update files" ON public.arquivos FOR UPDATE USING (is_admin());
CREATE POLICY "Admins