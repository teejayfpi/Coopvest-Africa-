-- =============================================================================
-- KYC Synchronization Migration - Adds comprehensive member profile fields
-- and supporting tables for full KYC management
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Enhance profiles table with missing personal information fields
-- -----------------------------------------------------------------------------
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS member_id TEXT UNIQUE;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS gender TEXT CHECK (gender IN ('male', 'female', 'other'));
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS date_of_birth DATE;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS marital_status TEXT CHECK (marital_status IN ('single', 'married', 'divorced', 'widowed', 'separated'));
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS nationality TEXT DEFAULT 'Nigerian';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS state TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS lga TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS city TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS residential_address TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS occupation TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS employer_name TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS employment_status TEXT CHECK (employment_status IN ('employed', 'self_employed', 'unemployed', 'retired', 'student'));
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS monthly_income DECIMAL(18, 2);
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS profile_photo_url TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS selfie_url TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS registration_channel TEXT CHECK (registration_channel IN ('android', 'ios', 'web'));
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS last_login TIMESTAMPTZ;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS last_device TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS last_ip_address INET;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS kyc_verified BOOLEAN DEFAULT false;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS kyc_verified_at TIMESTAMPTZ;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS kyc_verified_by UUID REFERENCES public.profiles(id);
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS kyc_rejection_reason TEXT;

-- Add indexes for common queries
CREATE INDEX IF NOT EXISTS idx_profiles_member_id ON public.profiles(member_id);
CREATE INDEX IF NOT EXISTS idx_profiles_kyc_status ON public.profiles(kyc_verified);
CREATE INDEX IF NOT EXISTS idx_profiles_gender ON public.profiles(gender);
CREATE INDEX IF NOT EXISTS idx_profiles_state ON public.profiles(state);
CREATE INDEX IF NOT EXISTS idx_profiles_employment_status ON public.profiles(employment_status);

-- -----------------------------------------------------------------------------
-- 2. Enhance KYC table with comprehensive document and verification fields
-- -----------------------------------------------------------------------------
ALTER TABLE public.kyc ADD COLUMN IF NOT EXISTS id_type TEXT CHECK (id_type IN ('national_id', 'international_passport', 'drivers_license', 'voters_card'));
ALTER TABLE public.kyc ADD COLUMN IF NOT EXISTS id_number TEXT;
ALTER TABLE public.kyc ADD COLUMN IF NOT EXISTS id_issue_date DATE;
ALTER TABLE public.kyc ADD COLUMN IF NOT EXISTS id_expiry_date DATE;
ALTER TABLE public.kyc ADD COLUMN IF NOT EXISTS id_front_image_url TEXT;
ALTER TABLE public.kyc ADD COLUMN IF NOT EXISTS id_back_image_url TEXT;
ALTER TABLE public.kyc ADD COLUMN IF NOT EXISTS bvn TEXT;
ALTER TABLE public.kyc ADD COLUMN IF NOT EXISTS nin TEXT;
ALTER TABLE public.kyc ADD COLUMN IF NOT EXISTS verification_notes TEXT;
ALTER TABLE public.kyc ADD COLUMN IF NOT EXISTS reviewed_by UUID REFERENCES public.profiles(id);
ALTER TABLE public.kyc ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ;
ALTER TABLE public.kyc ADD COLUMN IF NOT EXISTS passport_photo_url TEXT;
ALTER TABLE public.kyc ADD COLUMN IF NOT EXISTS signature_url TEXT;

-- Add indexes
CREATE INDEX IF NOT EXISTS idx_kyc_status ON public.kyc(status);
CREATE INDEX IF NOT EXISTS idx_kyc_id_type ON public.kyc(id_type);

-- -----------------------------------------------------------------------------
-- 3. Create Bank Accounts table
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.bank_accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  bank_name TEXT NOT NULL,
  account_name TEXT NOT NULL,
  account_number TEXT NOT NULL,
  bank_verification_status TEXT DEFAULT 'pending' CHECK (bank_verification_status IN ('pending', 'verified', 'rejected')),
  bank_verified_at TIMESTAMPTZ,
  bank_verified_by UUID REFERENCES public.profiles(id),
  is_primary BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(profile_id, account_number)
);

CREATE INDEX IF NOT EXISTS idx_bank_accounts_profile ON public.bank_accounts(profile_id);
CREATE INDEX IF NOT EXISTS idx_bank_accounts_status ON public.bank_accounts(bank_verification_status);

-- -----------------------------------------------------------------------------
-- 4. Create Next of Kin table
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.next_of_kin (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID UNIQUE NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL,
  relationship TEXT NOT NULL,
  phone TEXT,
  email TEXT,
  residential_address TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_next_of_kin_profile ON public.next_of_kin(profile_id);

-- -----------------------------------------------------------------------------
-- 5. Create Member Documents table (for additional documents)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.member_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  document_type TEXT NOT NULL CHECK (document_type IN (
    'passport_photograph', 'signature', 'means_of_identification', 
    'proof_of_address', 'employment_letter', 'payslip', 
    'additional_supporting', 'utility_bill', 'bank_statement'
  )),
  file_url TEXT NOT NULL,
  file_name TEXT,
  file_size INTEGER,
  mime_type TEXT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'verified', 'rejected', 'expired')),
  rejection_reason TEXT,
  uploaded_at TIMESTAMPTZ DEFAULT NOW(),
  verified_at TIMESTAMPTZ,
  verified_by UUID REFERENCES public.profiles(id)
);

CREATE INDEX IF NOT EXISTS idx_member_documents_profile ON public.member_documents(profile_id);
CREATE INDEX IF NOT EXISTS idx_member_documents_type ON public.member_documents(document_type);
CREATE INDEX IF NOT EXISTS idx_member_documents_status ON public.member_documents(status);

-- -----------------------------------------------------------------------------
-- 6. Create Loan Guarantors table
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.loan_guarantors (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  loan_id UUID NOT NULL REFERENCES public.loans(id) ON DELETE CASCADE,
  guarantor_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  request_status TEXT DEFAULT 'pending' CHECK (request_status IN ('pending', 'approved', 'rejected')),
  approved_at TIMESTAMPTZ,
  rejected_at TIMESTAMPTZ,
  rejection_reason TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(loan_id, guarantor_id)
);

CREATE INDEX IF NOT EXISTS idx_loan_guarantors_loan ON public.loan_guarantors(loan_id);
CREATE INDEX IF NOT EXISTS idx_loan_guarantors_guarantor ON public.loan_guarantors(guarantor_id);
CREATE INDEX IF NOT EXISTS idx_loan_guarantors_status ON public.loan_guarantors(request_status);

-- -----------------------------------------------------------------------------
-- 7. Create Admin Notes table (internal notes visible only to admins)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.admin_notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  admin_id UUID NOT NULL REFERENCES public.profiles(id),
  note TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_admin_notes_profile ON public.admin_notes(profile_id);
CREATE INDEX IF NOT EXISTS idx_admin_notes_admin ON public.admin_notes(admin_id);

-- -----------------------------------------------------------------------------
-- 8. Create Member Activity Timeline table
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.member_activity_timeline (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  activity_type TEXT NOT NULL CHECK (activity_type IN (
    'registration', 'login', 'profile_update', 'kyc_submitted', 'kyc_verified', 'kyc_rejected',
    'document_uploaded', 'document_verified', 'document_rejected', 'account_suspended',
    'account_reactivated', 'bank_updated', 'loan_applied', 'loan_approved', 'loan_rejected',
    'guarantee_given', 'guarantee_received', 'contribution_made', 'password_changed',
    'settings_updated', 'admin_action', 'support_ticket_created', 'support_ticket_resolved'
  )),
  description TEXT,
  metadata JSONB DEFAULT '{}'::jsonb,
  actor_id UUID REFERENCES public.profiles(id),
  actor_type TEXT CHECK (actor_type IN ('member', 'admin', 'system')),
  ip_address INET,
  device_info TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_member_timeline_profile ON public.member_activity_timeline(profile_id);
CREATE INDEX IF NOT EXISTS idx_member_timeline_type ON public.member_activity_timeline(activity_type);
CREATE INDEX IF NOT EXISTS idx_member_timeline_date ON public.member_activity_timeline(created_at DESC);

-- -----------------------------------------------------------------------------
-- 9. Create Document Requests table (for requesting additional documents)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.document_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  document_type TEXT NOT NULL,
  reason TEXT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'submitted', 'expired')),
  requested_by UUID REFERENCES public.profiles(id),
  requested_at TIMESTAMPTZ DEFAULT NOW(),
  submitted_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_document_requests_profile ON public.document_requests(profile_id);
CREATE INDEX IF NOT EXISTS idx_document_requests_status ON public.document_requests(status);

-- -----------------------------------------------------------------------------
-- 10. Create Enhanced Audit Logs table (if not exists)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id UUID REFERENCES public.profiles(id),
  actor_type TEXT CHECK (actor_type IN ('member', 'admin', 'system')),
  action TEXT NOT NULL,
  resource TEXT,
  resource_id UUID,
  target_profile_id UUID REFERENCES public.profiles(id),
  details JSONB DEFAULT '{}'::jsonb,
  ip_address INET,
  user_agent TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_actor ON public.audit_logs(actor_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_target ON public.audit_logs(target_profile_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON public.audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_audit_logs_resource ON public.audit_logs(resource);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created ON public.audit_logs(created_at DESC);

-- -----------------------------------------------------------------------------
-- 11. Enhance Loans table with guarantor counts
-- -----------------------------------------------------------------------------
ALTER TABLE public.loans ADD COLUMN IF NOT EXISTS guarantee_count INTEGER DEFAULT 0;
ALTER TABLE public.loans ADD COLUMN IF NOT EXISTS minimum_guarantees_required INTEGER DEFAULT 2;
ALTER TABLE public.loans ADD COLUMN IF NOT EXISTS guarantor_approval_deadline TIMESTAMPTZ;

-- -----------------------------------------------------------------------------
-- 12. Create RLS policies for new tables
-- -----------------------------------------------------------------------------

-- Bank accounts: members see own, admins see all
DROP POLICY IF EXISTS bank_accounts_member_read ON public.bank_accounts;
CREATE POLICY bank_accounts_member_read ON public.bank_accounts FOR SELECT USING (profile_id = auth.uid() OR public.is_staff());
DROP POLICY IF EXISTS bank_accounts_member_write ON public.bank_accounts;
CREATE POLICY bank_accounts_member_write ON public.bank_accounts FOR ALL USING (profile_id = auth.uid() OR public.is_staff()) WITH CHECK (profile_id = auth.uid() OR public.is_staff());

-- Next of kin: members see own, admins see all
DROP POLICY IF EXISTS next_of_kin_member_read ON public.next_of_kin;
CREATE POLICY next_of_kin_member_read ON public.next_of_kin FOR SELECT USING (profile_id = auth.uid() OR public.is_staff());
DROP POLICY IF EXISTS next_of_kin_member_write ON public.next_of_kin;
CREATE POLICY next_of_kin_member_write ON public.next_of_kin FOR ALL USING (profile_id = auth.uid() OR public.is_staff()) WITH CHECK (profile_id = auth.uid() OR public.is_staff());

-- Member documents: members see own, admins see all
DROP POLICY IF EXISTS member_documents_member_read ON public.member_documents;
CREATE POLICY member_documents_member_read ON public.member_documents FOR SELECT USING (profile_id = auth.uid() OR public.is_staff());
DROP POLICY IF EXISTS member_documents_member_write ON public.member_documents;
CREATE POLICY member_documents_member_write ON public.member_documents FOR ALL USING (profile_id = auth.uid() OR public.is_staff()) WITH CHECK (profile_id = auth.uid() OR public.is_staff());

-- Loan guarantors: guarantors and loan owners see their records, admins see all
DROP POLICY IF EXISTS loan_guarantors_member_read ON public.loan_guarantors;
CREATE POLICY loan_guarantors_member_read ON public.loan_guarantors FOR SELECT USING (
  guarantor_id = auth.uid() OR EXISTS (
    SELECT 1 FROM public.loans WHERE id = loan_id AND profile_id = auth.uid()
  ) OR public.is_staff()
);
DROP POLICY IF EXISTS loan_guarantors_member_write ON public.loan_guarantors;
CREATE POLICY loan_guarantors_member_write ON public.loan_guarantors FOR ALL USING (public.is_staff()) WITH CHECK (public.is_staff());

-- Admin notes: only admins can see/write
DROP POLICY IF EXISTS admin_notes_read ON public.admin_notes;
CREATE POLICY admin_notes_read ON public.admin_notes FOR SELECT USING (public.is_staff());
DROP POLICY IF EXISTS admin_notes_write ON public.admin_notes;
CREATE POLICY admin_notes_write ON public.admin_notes FOR ALL USING (public.is_staff()) WITH CHECK (public.is_staff());

-- Member activity timeline: members see own, admins see all
DROP POLICY IF EXISTS member_timeline_read ON public.member_activity_timeline;
CREATE POLICY member_timeline_read ON public.member_activity_timeline FOR SELECT USING (profile_id = auth.uid() OR public.is_staff());
DROP POLICY IF EXISTS member_timeline_write ON public.member_activity_timeline;
CREATE POLICY member_timeline_write ON public.member_activity_timeline FOR ALL USING (auth.uid() = profile_id OR public.is_staff()) WITH CHECK (auth.uid() = profile_id OR public.is_staff());

-- Document requests: members see own, admins see all
DROP POLICY IF EXISTS document_requests_read ON public.document_requests;
CREATE POLICY document_requests_read ON public.document_requests FOR SELECT USING (profile_id = auth.uid() OR public.is_staff());
DROP POLICY IF EXISTS document_requests_write ON public.document_requests;
CREATE POLICY document_requests_write ON public.document_requests FOR ALL USING (public.is_staff()) WITH CHECK (public.is_staff());

-- Audit logs: admins see all
DROP POLICY IF EXISTS audit_logs_read ON public.audit_logs;
CREATE POLICY audit_logs_read ON public.audit_logs FOR SELECT USING (public.is_staff());

-- -----------------------------------------------------------------------------
-- 13. Enable RLS on new tables
-- -----------------------------------------------------------------------------
ALTER TABLE public.bank_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.next_of_kin ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.member_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.loan_guarantors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.member_activity_timeline ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.document_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- -----------------------------------------------------------------------------
-- 14. Create helper function for generating member IDs
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.generate_member_id()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.member_id IS NULL THEN
    NEW.member_id := 'CV-' || upper(substr(NEW.user_id, 1, 4)) || '-' || substr(NEW.id::text, 1, 8);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_member_id ON public.profiles;
CREATE TRIGGER set_member_id BEFORE INSERT ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.generate_member_id();

-- -----------------------------------------------------------------------------
-- 15. Create function to log member activity
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.log_member_activity(
  p_profile_id UUID,
  p_activity_type TEXT,
  p_description TEXT DEFAULT NULL,
  p_metadata JSONB DEFAULT '{}'::jsonb,
  p_actor_id UUID DEFAULT NULL,
  p_actor_type TEXT DEFAULT 'member',
  p_ip_address INET DEFAULT NULL,
  p_device_info TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_activity_id UUID;
BEGIN
  INSERT INTO public.member_activity_timeline (
    profile_id, activity_type, description, metadata, 
    actor_id, actor_type, ip_address, device_info
  ) VALUES (
    p_profile_id, p_activity_type, p_description, p_metadata,
    p_actor_id, p_actor_type, p_ip_address, p_device_info
  ) RETURNING id INTO v_activity_id;
  
  RETURN v_activity_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- -----------------------------------------------------------------------------
-- 16. Create function to log admin actions
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.log_admin_action(
  p_action TEXT,
  p_resource TEXT DEFAULT NULL,
  p_resource_id UUID DEFAULT NULL,
  p_target_profile_id UUID DEFAULT NULL,
  p_details JSONB DEFAULT '{}'::jsonb,
  p_ip_address INET DEFAULT NULL,
  p_user_agent TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_log_id UUID;
BEGIN
  INSERT INTO public.audit_logs (
    actor_id, actor_type, action, resource, resource_id,
    target_profile_id, details, ip_address, user_agent
  ) VALUES (
    NULL, 'admin', p_action, p_resource, p_resource_id,
    p_target_profile_id, p_details, p_ip_address, p_user_agent
  ) RETURNING id INTO v_log_id;
  
  RETURN v_log_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- -----------------------------------------------------------------------------
-- 17. Create index for audit log queries
-- -----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_audit_logs_date_range ON public.audit_logs(created_at DESC) 
WHERE created_at > NOW() - INTERVAL '90 days';
