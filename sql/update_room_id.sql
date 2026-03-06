-- ============================================================
-- HeartSync Database Update
-- Run this script in the Supabase SQL Editor
-- This updates the room IDs from UUID to TEXT (e.g. AB1234)
-- ============================================================

-- 1. Drop existing policies that depend on the room_id column
DROP POLICY IF EXISTS "answers: insert own" ON public.answers;
DROP POLICY IF EXISTS "answers: read room" ON public.answers;

-- 2. Drop existing constraints that depend on rooms.id being a UUID
ALTER TABLE public.answers DROP CONSTRAINT IF EXISTS answers_room_id_fkey;

-- 3. Change the data type of rooms.id and answers.room_id to TEXT
-- Note: Existing rooms might have UUIDs casted to TEXT.
ALTER TABLE public.rooms ALTER COLUMN id DROP DEFAULT;
ALTER TABLE public.rooms ALTER COLUMN id TYPE TEXT USING id::TEXT;
ALTER TABLE public.answers ALTER COLUMN room_id TYPE TEXT USING room_id::TEXT;

-- 4. Re-add the foreign key constraint
ALTER TABLE public.answers
  ADD CONSTRAINT answers_room_id_fkey
  FOREIGN KEY (room_id) REFERENCES public.rooms(id) ON DELETE CASCADE;

-- 5. Recreate the dropped policies
-- Users can insert their own answers in their rooms
CREATE POLICY "answers: insert own"
  ON public.answers FOR INSERT
  WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.rooms r
      WHERE r.id = room_id
      AND (r.created_by = auth.uid() OR r.partner_id = auth.uid())
    )
  );

-- Users can read answers in completed rooms (both partners done) or their own answers always
CREATE POLICY "answers: read room"
  ON public.answers FOR SELECT
  USING (
    public.is_admin()
    OR user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.rooms r
      WHERE r.id = room_id
      AND (r.created_by = auth.uid() OR r.partner_id = auth.uid())
      AND r.status = 'completed'
    )
  );

-- 6. Enable Realtime on the rooms table! (IMPORTANT FOR LIVE NOTIFICATIONS)
ALTER PUBLICATION supabase_realtime ADD TABLE public.rooms;
