-- ============================================================
-- Fix Rooms RLS Policies
-- Run this script in the Supabase SQL Editor
-- This strictly replaces all RLS policies for rooms
-- and guarantees that Room Creation / Joining works.
-- ============================================================

-- 1. Make sure RLS is enabled
ALTER TABLE public.rooms ENABLE ROW LEVEL SECURITY;

-- 2. Drop all potential existing policies on rooms to start fresh
DROP POLICY IF EXISTS "rooms: member access"  ON public.rooms;
DROP POLICY IF EXISTS "rooms: insert own"     ON public.rooms;
DROP POLICY IF EXISTS "rooms: update own"     ON public.rooms;
DROP POLICY IF EXISTS "rooms: select member"  ON public.rooms;
DROP POLICY IF EXISTS "rooms: update member"  ON public.rooms;
DROP POLICY IF EXISTS "rooms: admin delete"   ON public.rooms;
DROP POLICY IF EXISTS "rooms: select any"     ON public.rooms;
DROP POLICY IF EXISTS "rooms: update join"    ON public.rooms;

-- 3. SELECT Policy: Anyone authenticated can see rooms (necessary to join by code)
CREATE POLICY "rooms_select_policy"
  ON public.rooms FOR SELECT
  USING (auth.uid() IS NOT NULL);

-- 4. INSERT Policy: User can create a room, ensuring they set themselves as created_by
CREATE POLICY "rooms_insert_policy"
  ON public.rooms FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL AND auth.uid() = created_by
  );

-- 5. UPDATE Policy: Users can update if they are creator, partner, or joining as a new partner
CREATE POLICY "rooms_update_policy"
  ON public.rooms FOR UPDATE
  USING (
    auth.uid() = created_by 
    OR auth.uid() = partner_id 
    OR partner_id IS NULL -- allows joining
    OR public.is_admin()
  );

-- 6. DELETE Policy: Only Admins can delete
CREATE POLICY "rooms_delete_policy"
  ON public.rooms FOR DELETE
  USING (public.is_admin());

-- Done!
