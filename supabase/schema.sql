-- ============================================================
-- SCHEMA COMPLETO — Fazenda da Esperança Formação
-- Supabase SQL Editor
-- ============================================================

-- ------------------------------------------------------------
-- EXTENSÕES
-- ------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ------------------------------------------------------------
-- ENUM TYPES
-- ------------------------------------------------------------
CREATE TYPE user_role AS ENUM ('admin', 'editor', 'aluno');
CREATE TYPE post_status AS ENUM ('rascunho', 'publicado', 'arquivado');
CREATE TYPE lead_status AS ENUM ('novo', 'contatado', 'convertido', 'descartado');
CREATE TYPE arquivo_tipo AS ENUM ('imagem', 'video', 'documento', 'audio', 'outro');

-- ============================================================
-- TABELA: leads
-- ============================================================
CREATE TABLE IF NOT EXISTS public.leads (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    nome            TEXT NOT NULL CHECK (char_length(nome) BETWEEN 2 AND 150),
    email           TEXT NOT NULL CHECK (email ~* '^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$'),
    telefone        TEXT CHECK (telefone IS NULL OR char_length(telefone) BETWEEN 8 AND 20),
    mensagem        TEXT CHECK (mensagem IS NULL OR char_length(mensagem) <= 2000),
    origem          TEXT DEFAULT 'site' CHECK (char_length(origem) <= 100),
    status          lead_status NOT NULL DEFAULT 'novo',
    ip_address      INET,
    user_agent      TEXT CHECK (user_agent IS NULL OR char_length(user_agent) <= 500),
    utm_source      TEXT CHECK (utm_source IS NULL OR char_length(utm_source) <= 100),
    utm_medium      TEXT CHECK (utm_medium IS NULL OR char_length(utm_medium) <= 100),
    utm_campaign    TEXT CHECK (utm_campaign IS NULL OR char_length(utm_campaign) <= 100),
    observacoes     TEXT CHECK (observacoes IS NULL OR char_length(observacoes) <= 3000),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ------------------------------------------------------------
-- TABELA: usuarios
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.usuarios (
    id              UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    nome_completo   TEXT NOT NULL CHECK (char_length(nome_completo) BETWEEN 2 AND 200),
    avatar_url      TEXT CHECK (avatar_url IS NULL OR char_length(avatar_url) <= 500),
    bio             TEXT CHECK (bio IS NULL OR char_length(bio) <= 1000),
    role            user_role NOT NULL DEFAULT 'aluno',
    ativo           BOOLEAN NOT NULL DEFAULT TRUE,
    telefone        TEXT CHECK (telefone IS NULL OR char_length(telefone) BETWEEN 8 AND 20),
    data_nascimento DATE CHECK (data_nascimento IS NULL OR data_nascimento <= CURRENT_DATE),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ------------------------------------------------------------
-- TABELA: posts
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.posts (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    titulo          TEXT NOT NULL CHECK (char_length(titulo) BETWEEN 3 AND 300),
    slug            TEXT NOT NULL UNIQUE CHECK (slug ~* '^[a-z0-9]+(?:-[a-z0-9]+)*$' AND char_length(slug) BETWEEN 3 AND 300),
    resumo          TEXT CHECK (resumo IS NULL OR char_length(resumo) <= 500),
    conteudo        TEXT,
    capa_url        TEXT CHECK (capa_url IS NULL OR char_length(capa_url) <= 500),
    status          post_status NOT NULL DEFAULT 'rascunho',
    autor_id        UUID REFERENCES public.usuarios(id) ON DELETE SET NULL,
    categoria       TEXT CHECK (categoria IS NULL OR char_length(categoria) <= 100),
    tags            TEXT[] DEFAULT '{}',
    visualizacoes   BIGINT NOT NULL DEFAULT 0 CHECK (visualizacoes >= 0),
    destaque        BOOLEAN NOT NULL DEFAULT FALSE,
    publicado_em    TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ------------------------------------------------------------
-- TABELA: configuracoes
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.configuracoes (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    chave           TEXT NOT NULL UNIQUE CHECK (char_length(chave) BETWEEN 1 AND 100),
    valor           TEXT CHECK (valor IS NULL OR char_length(valor) <= 5000),
    descricao       TEXT CHECK (descricao IS NULL OR char_length(descricao) <= 500),
    publico         BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ------------------------------------------------------------
-- TABELA: arquivos
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.arquivos (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    nome_original   TEXT NOT NULL CHECK (char_length(nome_original) BETWEEN 1 AND 255),
    nome_storage    TEXT NOT NULL CHECK (char_length(nome_storage) BETWEEN 1 AND 255),
    bucket          TEXT NOT NULL DEFAULT 'arquivos' CHECK (char_length(bucket) <= 100),
    caminho         TEXT NOT NULL CHECK (char_length(caminho) BETWEEN 1 AND 500),
    url_publica     TEXT CHECK (url_publica IS NULL OR char_length(url_publica) <= 500),
    tipo            arquivo_tipo NOT NULL DEFAULT 'outro',
    mime_type       TEXT CHECK (mime_type IS NULL OR char_length(mime_type) <= 100),
    tamanho_bytes   BIGINT CHECK (tamanho_bytes IS NULL OR tamanho_bytes >= 0),
    uploader_id     UUID REFERENCES public.usuarios(id) ON DELETE SET NULL,
    referencia_tipo TEXT CHECK (referencia_tipo IS NULL OR char_length(referencia_tipo) <= 50),
    referencia_id   UUID,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- ÍNDICES
-- ============================================================
-- leads
CREATE INDEX IF NOT EXISTS idx_leads_email        ON public.leads(email);
CREATE INDEX IF NOT EXISTS idx_leads_status       ON public.leads(status);
CREATE INDEX IF NOT EXISTS idx_leads_created_at   ON public.leads(created_at DESC);

-- usuarios
CREATE INDEX IF NOT EXISTS idx_usuarios_role      ON public.usuarios(role);
CREATE INDEX IF NOT EXISTS idx_usuarios_ativo      ON public.usuarios(ativo);

-- posts
CREATE INDEX IF NOT EXISTS idx_posts_status       ON public.posts(status);
CREATE INDEX IF NOT EXISTS idx_posts_slug         ON public.posts(slug);
CREATE INDEX IF NOT EXISTS idx_posts_autor_id     ON public.posts(autor_id);
CREATE INDEX IF NOT EXISTS idx_posts_publicado_em ON public.posts(publicado_em DESC);
CREATE INDEX IF NOT EXISTS idx_posts_destaque     ON public.posts(destaque) WHERE destaque = TRUE;

-- configuracoes
CREATE INDEX IF NOT EXISTS idx_config_chave       ON public.configuracoes(chave);
CREATE INDEX IF NOT EXISTS idx_config_publico     ON public.configuracoes(publico) WHERE publico = TRUE;

-- arquivos
CREATE INDEX IF NOT EXISTS idx_arquivos_uploader  ON public.arquivos(uploader_id);
CREATE INDEX IF NOT EXISTS idx_arquivos_tipo      ON public.arquivos(tipo);
CREATE INDEX IF NOT EXISTS idx_arquivos_ref       ON public.arquivos(referencia_tipo, referencia_id);

-- ============================================================
-- FUNÇÕES AUXILIARES
-- ============================================================

-- Função genérica para atualizar updated_at
CREATE OR REPLACE FUNCTION public.fn_set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

-- Função para criar perfil em usuarios ao registrar em auth.users
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_nome TEXT;
BEGIN
    -- Tenta obter nome dos metadados; usa parte do e-mail como fallback
    v_nome := COALESCE(
        NEW.raw_user_meta_data->>'nome_completo',
        NEW.raw_user_meta_data->>'full_name',
        NEW.raw_user_meta_data->>'name',
        split_part(NEW.email, '@', 1)
    );

    INSERT INTO public.usuarios (
        id,
        nome_completo,
        avatar_url,
        role,
        ativo,
        created_at,
        updated_at
    ) VALUES (
        NEW.id,
        v_nome,
        NEW.raw_user_meta_data->>'avatar_url',
        'aluno',
        TRUE,
        NOW(),
        NOW()
    )
    ON CONFLICT (id) DO NOTHING;

    RETURN NEW;
END;
$$;

-- Função helper: verifica se usuário autenticado é admin
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.usuarios
        WHERE id = auth.uid()
          AND role = 'admin'
          AND ativo = TRUE
    );
$$;

-- Função helper: verifica se usuário autenticado é admin ou editor
CREATE OR REPLACE FUNCTION public.is_admin_or_editor()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.usuarios
        WHERE id = auth.uid()
          AND role IN ('admin', 'editor')
          AND ativo = TRUE
    );
$$;

-- ============================================================
-- TRIGGERS — updated_at
-- ============================================================
CREATE TRIGGER trg_leads_updated_at
    BEFORE UPDATE ON public.leads
    FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();

CREATE TRIGGER trg_usuarios_updated_at
    BEFORE UPDATE ON public.usuarios
    FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();

CREATE TRIGGER trg_posts_updated_at
    BEFORE UPDATE ON public.posts
    FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();

CREATE TRIGGER trg_configuracoes_updated_at
    BEFORE UPDATE ON public.configuracoes
    FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();

CREATE TRIGGER trg_arquivos_updated_at
    BEFORE UPDATE ON public.arquivos
    FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();

-- TRIGGER — novo usuário auth → cria perfil
CREATE TRIGGER trg_on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- ROW LEVEL SECURITY — habilitar
-- ============================================================
ALTER TABLE public.leads          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.usuarios       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.posts          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.configuracoes  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.arquivos       ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- POLICIES — leads
-- ============================================================

-- Qualquer pessoa (anônima ou autenticada) pode criar um lead
CREATE POLICY "leads_insert_anonimo"
    ON public.leads
    FOR INSERT
    TO anon, authenticated
    WITH CHECK (TRUE);

-- Apenas admins podem ler, atualizar e deletar leads
CREATE POLICY "leads_select_admin"
    ON public.leads
    FOR SELECT
    TO authenticated
    USING (public.is_admin());

CREATE POLICY "leads_update_admin"
    ON public.leads
    FOR UPDATE
    TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

CREATE POLICY "leads_delete_admin"
    ON public.leads
    FOR DELETE
    TO authenticated
    USING (public.is_admin());

-- ============================================================
-- POLICIES — usuarios
-- ============================================================

-- Usuário autenticado pode ver seu próprio perfil
CREATE POLICY "usuarios_select_proprio"
    ON public.usuarios
    FOR SELECT
    TO authenticated
    USING (id = auth.uid());

-- Admin pode ver todos os perfis
CREATE POLICY "usuarios_select_admin"
    ON public.usuarios
    FOR SELECT
    TO authenticated
    USING (public.is_admin());

-- Usuário pode atualizar seu próprio perfil (exceto role)
CREATE POLICY "usuarios_update_proprio"
    ON public.usuarios
    FOR UPDATE
    TO authenticated
    USING (id = auth.uid())
    WITH CHECK (
        id = auth.uid()
        -- impede alteração de role pelo próprio usuário
        AND role = (SELECT role FROM public.usuarios WHERE id = auth.uid())
    );

-- Admin tem acesso total
CREATE POLICY "usuarios_all_admin"
    ON public.usuarios
    FOR ALL
    TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

-- ============================================================
-- POLICIES — posts
-- ============================================================

-- Qualquer pessoa pode ler posts publicados
CREATE POLICY "posts_select_publicado"
    ON public.posts
    FOR SELECT
    TO anon, authenticated
    USING (status = 'publicado');

-- Autores (admin/editor) podem ver todos os seus posts
CREATE POLICY "posts_select_autor"
    ON public.posts
    FOR SELECT
    TO authenticated
    USING (
        public.is_admin_or_editor()
        AND autor_id = auth.uid()
    );

-- Admin vê tudo
CREATE POLICY "posts_select_admin"
    ON public.posts
    FOR SELECT
    TO authenticated
    USING (public.is_admin());

-- Admin/editor podem criar posts
CREATE POLICY "posts_insert_editor"
    ON public.posts
    FOR INSERT
    TO authenticated
    WITH CHECK (public.is_admin_or_editor());

-- Autor pode atualizar seu próprio post; admin pode atualizar qualquer um
CREATE POLICY "posts_update_autor_ou_admin"
    ON public.posts
    FOR UPDATE
    TO authenticated
    USING (
        public.is_admin()
        OR (public.is_admin_or_editor() AND autor_id = auth.uid())
    )
    WITH CHECK (
        public.is_admin()
        OR (public.is_admin_or_editor() AND autor_id = auth.uid())
    );

-- Apenas admin pode deletar posts
CREATE POLICY "posts_delete_admin"
    ON public.posts
    FOR DELETE
    TO authenticated
    USING (public.is_admin());

-- ============================================================
-- POLICIES — configuracoes
-- ============================================================

-- Qualquer pessoa pode ler configurações marcadas como públicas
CREATE POLICY "config_select_publico"
    ON public.configuracoes
    FOR SELECT
    TO anon, authenticated
    USING (publico = TRUE);

-- Usuários autenticados podem ler todas as configurações
CREATE POLICY "config_select_autenticado"
    ON public.configuracoes
    FOR SELECT
    TO authenticated
    USING (TRUE);

-- Apenas admin pode inserir, atualizar e deletar configurações
CREATE POLICY "config_insert_admin"
    ON public.configuracoes
    FOR INSERT
    TO authenticated
    WITH CHECK (public.is_admin());

CREATE POLICY "config_update_admin"
    ON public.configuracoes
    FOR UPDATE
    TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

CREATE POLICY "config_delete_admin"
    ON public.configuracoes
    FOR DELETE
    TO authenticated
    USING (public.is_admin());

-- ============================================================
-- POLICIES — arquivos
-- ============================================================

-- URLs públicas são visíveis para todos
CREATE POLICY "arquivos_select_publico"
    ON public.arquivos
    FOR SELECT
    TO anon, authenticated
    USING (url_publica IS NOT NULL);

-- Uploader pode ver seus próprios arquivos
CREATE POLICY "arquivos_select_uploader"
    ON public.arquivos
    FOR SELECT
    TO authenticated
    USING (uploader_id = auth.uid());

-- Admin vê tudo
CREATE POLICY "arquivos_select_admin"
    ON public.arquivos
    FOR SELECT
    TO authenticated
    USING (public.is_admin());

-- Usuários autenticados podem fazer upload
CREATE POLICY "arquivos_insert_autenticado"
    ON public.arquivos
    FOR INSERT
    TO authenticated
    WITH CHECK (uploader_id = auth.uid() OR public.is_admin());

-- Uploader pode atualizar seus arquivos; admin pode atualizar qualquer um
CREATE POLICY "arquivos_update_uploader_ou_admin"
    ON public.arquivos
    FOR UPDATE
    TO authenticated
    USING (uploader_id = auth.uid() OR public.is_admin())
    WITH CHECK (uploader_id = auth.uid() OR public.is_admin());

-- Apenas admin pode deletar arquivos
CREATE POLICY "arquivos_delete_admin"
    ON public.arquivos
    FOR DELETE
    TO authenticated
    USING (public.is_admin());

-- ============================================================
-- INSERT INICIAL — configuracoes
-- ============================================================
INSERT INTO public.configuracoes (chave, valor, descricao, publico) VALUES
    ('nome_empresa',        'Fazenda da Esperança Formação',    'Nome da empresa exibido no site',          TRUE),
    ('cor_primaria',        '#2563eb',                           'Cor primária da identidade visual (hex)',  TRUE),
    ('whatsapp',            '+5511999999999',                    'Número WhatsApp para contato',             TRUE),
    ('email_contato',       'contato@fazendaesperanca.org',      'E-mail principal de contato',              TRUE),
    ('descricao_site',      'Plataforma de cursos online da Fazenda da Esperança', 'Meta descrição do site', TRUE),
    ('logo_url',            NULL,                                'URL do logotipo principal',                TRUE),
    ('favicon_url',         NULL,                                'URL do favicon',                           TRUE),
    ('cor_secundaria',      '#1e40af',                           'Cor secundária da identidade visual (hex)',TRUE),
    ('manutencao',          'false',                             'Modo manutenção ativo (true/false)',       FALSE),
    ('max_upload_mb',       '50',                                'Tamanho máximo de upload em MB',          FALSE)
ON CONFLICT (chave) DO NOTHING;

-- ============================================================
-- GRANTS — segurança adicional
-- ============================================================
GRANT USAGE ON SCHEMA public TO anon, authenticated;

GRANT SELECT, INSERT ON public.leads         TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.leads         TO authenticated;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.usuarios      TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.posts         TO authenticated;
GRANT SELECT ON public.posts                                 TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.configuracoes TO authenticated;
GRANT SELECT ON public.configuracoes                         TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.arquivos      TO authenticated;
GRANT SELECT ON public.arquivos                              TO anon;

-- Funções públicas
GRANT EXECUTE ON FUNCTION public.is_admin()             TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_admin_or_editor()   TO authenticated;

-- ============================================================
-- FIM DO SCHEMA
-- ============================================================