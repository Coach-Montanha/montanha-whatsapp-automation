-- ====================================================================
-- ECOSYSTEM MONTANHA CENTRAL DATABASE SCHEMA
-- Apps: Smart Language, EduFlow Finance, Construtor de PDFs,
--       Sistema Híbrido de Treinamento, WhatsApp Lovable App
-- ====================================================================

-- 1. ECOSYSTEM USERS TABLE
CREATE TABLE IF NOT EXISTS public.ecosystem_users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT UNIQUE NOT NULL,
    full_name TEXT,
    role TEXT DEFAULT 'user', -- 'user', 'admin', 'superadmin'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. ECOSYSTEM GUEST LOCKOUT TABLE (Anti-Abuse Guest Lockout)
CREATE TABLE IF NOT EXISTS public.ecosystem_guest_lockout (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT UNIQUE NOT NULL,
    device_fingerprint TEXT,
    ip_address TEXT,
    locked_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    reason TEXT DEFAULT 'demo_used',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 3. ECOSYSTEM OTP TOKENS TABLE (6-digit Double Opt-In Tokens)
CREATE TABLE IF NOT EXISTS public.ecosystem_otp_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT NOT NULL,
    token VARCHAR(6) NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    used BOOLEAN DEFAULT false NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 4. ECOSYSTEM SUBSCRIPTIONS TABLE (Cross-App Subscriptions & Access Control)
CREATE TABLE IF NOT EXISTS public.ecosystem_subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.ecosystem_users(id) ON DELETE CASCADE,
    tenant_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    project_id TEXT NOT NULL, -- 'smart-language', 'eduflow-finance', 'construtor-pdf', 'sistema-hibrido', 'whatsapp-lovable'
    payment_status TEXT DEFAULT 'PENDENTE' NOT NULL, -- 'PAGO', 'PENDENTE', 'INADIMPLENTE', 'CANCELADO'
    access_expires_at TIMESTAMP WITH TIME ZONE,
    is_active BOOLEAN DEFAULT true NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(email, project_id)
);

-- INDEXES FOR PERFORMANCE
CREATE INDEX IF NOT EXISTS idx_ecosystem_guest_lockout_email ON public.ecosystem_guest_lockout(email);
CREATE INDEX IF NOT EXISTS idx_ecosystem_otp_tokens_email_token ON public.ecosystem_otp_tokens(email, token);
CREATE INDEX IF NOT EXISTS idx_ecosystem_subscriptions_email_project ON public.ecosystem_subscriptions(email, project_id);
CREATE INDEX IF NOT EXISTS idx_ecosystem_subscriptions_user_project ON public.ecosystem_subscriptions(user_id, project_id);
CREATE INDEX IF NOT EXISTS idx_ecosystem_subscriptions_tenant_id ON public.ecosystem_subscriptions(tenant_id);

-- ============================================================================
-- REMEDIAÇÃO DE RLS: Isolamento Estrito Multi-Tenant
-- ============================================================================

-- 1. Revogar políticas públicas vulneráveis
DROP POLICY IF EXISTS "Public select ecosystem_users" ON public.ecosystem_users;
DROP POLICY IF EXISTS "Public insert ecosystem_users" ON public.ecosystem_users;
DROP POLICY IF EXISTS "Public update ecosystem_users" ON public.ecosystem_users;

DROP POLICY IF EXISTS "Public select ecosystem_subscriptions" ON public.ecosystem_subscriptions;
DROP POLICY IF EXISTS "Public insert ecosystem_subscriptions" ON public.ecosystem_subscriptions;
DROP POLICY IF EXISTS "Public update ecosystem_subscriptions" ON public.ecosystem_subscriptions;
DROP POLICY IF EXISTS "Public delete ecosystem_subscriptions" ON public.ecosystem_subscriptions;

DROP POLICY IF EXISTS "Public select ecosystem_otp_tokens" ON public.ecosystem_otp_tokens;
DROP POLICY IF EXISTS "Public insert ecosystem_otp_tokens" ON public.ecosystem_otp_tokens;
DROP POLICY IF EXISTS "Public update ecosystem_otp_tokens" ON public.ecosystem_otp_tokens;

-- 2. Habilitar RLS estrito
ALTER TABLE public.ecosystem_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ecosystem_guest_lockout ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ecosystem_otp_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ecosystem_subscriptions ENABLE ROW LEVEL SECURITY;

-- 3. Políticas seguras para ecosystem_users
CREATE POLICY "Users can only read own profile"
  ON public.ecosystem_users
  FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

CREATE POLICY "Users can only update own profile"
  ON public.ecosystem_users
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- 4. Políticas seguras para ecosystem_subscriptions
CREATE POLICY "Users can read own subscriptions"
  ON public.ecosystem_subscriptions
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id OR auth.uid() = tenant_id);

CREATE POLICY "Service role manages all subscriptions"
  ON public.ecosystem_subscriptions
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- 5. Outras políticas restritivas
CREATE POLICY "Select guest lockout" ON public.ecosystem_guest_lockout FOR SELECT USING (true);
CREATE POLICY "Insert guest lockout" ON public.ecosystem_guest_lockout FOR INSERT WITH CHECK (true);
CREATE POLICY "No update guest lockout" ON public.ecosystem_guest_lockout FOR UPDATE USING (auth.role() = 'service_role');

CREATE POLICY "Select OTP tokens" ON public.ecosystem_otp_tokens FOR SELECT USING ((auth.jwt() ->> 'email') = email OR auth.role() = 'service_role' OR used = false);
CREATE POLICY "Insert OTP tokens" ON public.ecosystem_otp_tokens FOR INSERT WITH CHECK (true);
CREATE POLICY "Update OTP tokens" ON public.ecosystem_otp_tokens FOR UPDATE USING (used = false OR auth.role() = 'service_role');
