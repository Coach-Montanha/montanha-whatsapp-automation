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

-- ROW LEVEL SECURITY (RLS) POLICIES
ALTER TABLE public.ecosystem_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ecosystem_guest_lockout ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ecosystem_otp_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ecosystem_subscriptions ENABLE ROW LEVEL SECURITY;

-- 1. ecosystem_users: Restricted by auth.uid() or service_role
DROP POLICY IF EXISTS "Public select ecosystem_users" ON public.ecosystem_users;
DROP POLICY IF EXISTS "Public insert ecosystem_users" ON public.ecosystem_users;
DROP POLICY IF EXISTS "Public update ecosystem_users" ON public.ecosystem_users;

CREATE POLICY "Users read own profile" ON public.ecosystem_users FOR SELECT USING (auth.uid() = id OR (auth.jwt() ->> 'email') = email OR auth.role() = 'service_role');
CREATE POLICY "Users insert own profile" ON public.ecosystem_users FOR INSERT WITH CHECK (auth.uid() = id OR (auth.jwt() ->> 'email') = email OR auth.role() = 'service_role');
CREATE POLICY "Users update own profile" ON public.ecosystem_users FOR UPDATE USING (auth.uid() = id OR (auth.jwt() ->> 'email') = email OR auth.role() = 'service_role');

-- 2. ecosystem_guest_lockout: Public insert for demo tracking; select/update restricted
DROP POLICY IF EXISTS "Public select ecosystem_guest_lockout" ON public.ecosystem_guest_lockout;
DROP POLICY IF EXISTS "Public insert ecosystem_guest_lockout" ON public.ecosystem_guest_lockout;
DROP POLICY IF EXISTS "Public update ecosystem_guest_lockout" ON public.ecosystem_guest_lockout;

CREATE POLICY "Select guest lockout" ON public.ecosystem_guest_lockout FOR SELECT USING (true);
CREATE POLICY "Insert guest lockout" ON public.ecosystem_guest_lockout FOR INSERT WITH CHECK (true);
CREATE POLICY "No update guest lockout" ON public.ecosystem_guest_lockout FOR UPDATE USING (auth.role() = 'service_role');

-- 3. ecosystem_otp_tokens: Select and Insert by email match; Update only if unused/valid
DROP POLICY IF EXISTS "Public select ecosystem_otp_tokens" ON public.ecosystem_otp_tokens;
DROP POLICY IF EXISTS "Public insert ecosystem_otp_tokens" ON public.ecosystem_otp_tokens;
DROP POLICY IF EXISTS "Public update ecosystem_otp_tokens" ON public.ecosystem_otp_tokens;

CREATE POLICY "Select OTP tokens" ON public.ecosystem_otp_tokens FOR SELECT USING ((auth.jwt() ->> 'email') = email OR auth.role() = 'service_role' OR used = false);
CREATE POLICY "Insert OTP tokens" ON public.ecosystem_otp_tokens FOR INSERT WITH CHECK (true);
CREATE POLICY "Update OTP tokens" ON public.ecosystem_otp_tokens FOR UPDATE USING (used = false OR auth.role() = 'service_role');

-- 4. ecosystem_subscriptions: Users view own active subscriptions; Service role manages
DROP POLICY IF EXISTS "Public select ecosystem_subscriptions" ON public.ecosystem_subscriptions;
DROP POLICY IF EXISTS "Public insert ecosystem_subscriptions" ON public.ecosystem_subscriptions;
DROP POLICY IF EXISTS "Public update ecosystem_subscriptions" ON public.ecosystem_subscriptions;
DROP POLICY IF EXISTS "Public delete ecosystem_subscriptions" ON public.ecosystem_subscriptions;

CREATE POLICY "Users read own subscriptions" ON public.ecosystem_subscriptions FOR SELECT USING (auth.uid() = user_id OR (auth.jwt() ->> 'email') = email OR auth.role() = 'service_role');
CREATE POLICY "Service role manages subscriptions insert" ON public.ecosystem_subscriptions FOR INSERT WITH CHECK (auth.role() = 'service_role' OR auth.uid() = user_id);
CREATE POLICY "Service role manages subscriptions update" ON public.ecosystem_subscriptions FOR UPDATE USING (auth.role() = 'service_role' OR auth.uid() = user_id);
CREATE POLICY "Service role manages subscriptions delete" ON public.ecosystem_subscriptions FOR DELETE USING (auth.role() = 'service_role');

-- ====================================================================
-- SEED DATA: ALBERTO SARLY (VITALÍCIO COM ACESSO AOS 5 APPS)
-- ====================================================================
INSERT INTO public.ecosystem_users (id, email, full_name, role)
VALUES ('c7b41574-a499-4f70-8bf1-1122334455aa'::uuid, 'albertosarly@gmail.com', 'Alberto Sarly', 'user')
ON CONFLICT (email) DO UPDATE SET full_name = 'Alberto Sarly', role = 'user', updated_at = timezone('utc'::text, now());

INSERT INTO public.ecosystem_subscriptions (user_id, email, project_id, payment_status, access_expires_at, is_active)
VALUES
    ('c7b41574-a499-4f70-8bf1-1122334455aa'::uuid, 'albertosarly@gmail.com', 'construtor-pdf', 'PAGO', NULL, true),
    ('c7b41574-a499-4f70-8bf1-1122334455aa'::uuid, 'albertosarly@gmail.com', 'eduflow-finance', 'PAGO', NULL, true),
    ('c7b41574-a499-4f70-8bf1-1122334455aa'::uuid, 'albertosarly@gmail.com', 'sistema-hibrido', 'PAGO', NULL, true),
    ('c7b41574-a499-4f70-8bf1-1122334455aa'::uuid, 'albertosarly@gmail.com', 'smart-language', 'PAGO', NULL, true),
    ('c7b41574-a499-4f70-8bf1-1122334455aa'::uuid, 'albertosarly@gmail.com', 'whatsapp-lovable', 'PAGO', NULL, true)
ON CONFLICT (email, project_id) DO UPDATE
SET payment_status = 'PAGO', access_expires_at = NULL, is_active = true, updated_at = timezone('utc'::text, now());
