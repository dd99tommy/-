-- ============================================================
-- HeartSync — Add Room Delete Policy
-- Allow creators to delete their own rooms
-- ============================================================

-- 1. Ensure creators can delete their own rooms
DROP POLICY IF EXISTS "rooms: delete own" ON public.rooms;
CREATE POLICY "rooms: delete own"
  ON public.rooms FOR DELETE
  USING (auth.uid() = created_by);

-- 2. Admin still has full delete access (already in rls.sql but ensuring)
DROP POLICY IF EXISTS "rooms: admin delete" ON public.rooms;
CREATE POLICY "rooms: admin delete"
  ON public.rooms FOR DELETE
  USING (public.is_admin());

-- Note: Ensure ON DELETE CASCADE is set for answers. 
-- It is already set in schema.sql: 
-- room_id UUID NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE
