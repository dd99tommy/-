-- ============================================================
-- HeartSync — Quick Fix for 500 Error
-- Simplifies the trigger to the absolute minimum to ensure stability
-- ============================================================

-- 1. Drop old triggers to prevent conflicts
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP TRIGGER IF EXISTS on_auth_user_updated ON auth.users;
DROP TRIGGER IF EXISTS on_auth_user_sync_insert ON auth.users;
DROP TRIGGER IF EXISTS on_auth_user_sync_update ON auth.users;

-- 2. Simplified Sync Function
CREATE OR REPLACE FUNCTION public.handle_auth_user_sync()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, name, email, avatar_url, role)
  VALUES (
    NEW.id,
    COALESCE(NULLIF(NEW.raw_user_meta_data->>'full_name', ''), NULLIF(NEW.raw_user_meta_data->>'name', ''), 'مستخدم'),
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'avatar_url', 'https://ui-avatars.com/api/?name=U&background=7c3aed&color=fff&rounded=true'),
    'user'
  )
  ON CONFLICT (id) DO UPDATE SET
    name = CASE 
      WHEN EXCLUDED.name NOT IN ('مستخدم', '') THEN EXCLUDED.name 
      ELSE public.users.name 
    END,
    avatar_url = COALESCE(NULLIF(EXCLUDED.avatar_url, ''), public.users.avatar_url),
    email = COALESCE(NEW.email, public.users.email);

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Re-attach triggers
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_auth_user_sync();

CREATE TRIGGER on_auth_user_updated
  AFTER UPDATE OF raw_user_meta_data, email ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_auth_user_sync();
