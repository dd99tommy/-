-- ============================================================
-- HeartSync Database Update
-- Run this script in the Supabase SQL Editor
-- This updates the room IDs from UUID to TEXT (e.g. AB1234)
-- ============================================================

-- 1. Drop existing constraints that depend on rooms.id being a UUID
ALTER TABLE public.answers DROP CONSTRAINT IF EXISTS answers_room_id_fkey;

-- 2. Change the data type of rooms.id and answers.room_id to TEXT
-- Note: Existing rooms might have UUIDs casted to TEXT, which is fine, 
-- or we can truncate the rooms table if it's safe to do so.
ALTER TABLE public.rooms ALTER COLUMN id DROP DEFAULT;
ALTER TABLE public.rooms ALTER COLUMN id TYPE TEXT USING id::TEXT;
ALTER TABLE public.answers ALTER COLUMN room_id TYPE TEXT USING room_id::TEXT;

-- 3. Re-add the foreign key constraint
ALTER TABLE public.answers
  ADD CONSTRAINT answers_room_id_fkey
  FOREIGN KEY (room_id) REFERENCES public.rooms(id) ON DELETE CASCADE;

-- 4. Enable Realtime on the rooms table! (IMPORTANT FOR LIVE NOTIFICATIONS)
ALTER PUBLICATION supabase_realtime ADD TABLE public.rooms;
