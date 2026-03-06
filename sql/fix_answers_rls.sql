-- ============================================================
-- Fix Answers RLS Policies (Fix for UPSERT 'Next Question' button)
-- Run this script in the Supabase SQL Editor
-- ============================================================

-- 1. Enable RLS
ALTER TABLE public.answers ENABLE ROW LEVEL SECURITY;

-- 2. Drop existing answers policies to start fresh
DROP POLICY IF EXISTS "answers: insert own" ON public.answers;
DROP POLICY IF EXISTS "answers: update own" ON public.answers;
DROP POLICY IF EXISTS "answers: read room" ON public.answers;
DROP POLICY IF EXISTS "answers: admin all" ON public.answers;
DROP POLICY IF EXISTS "answers_insert_policy" ON public.answers;
DROP POLICY IF EXISTS "answers_select_policy" ON public.answers;
DROP POLICY IF EXISTS "answers_update_policy" ON public.answers;
DROP POLICY IF EXISTS "answers_delete_policy" ON public.answers;

-- 3. SELECT Policy:
-- Users can read their own answers, or read all answers in their room if the room is completed.
CREATE POLICY "answers_select_policy"
  ON public.answers FOR SELECT
  USING (
    public.is_admin()
    OR user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.rooms r
      WHERE r.id = answers.room_id
      AND (r.created_by = auth.uid() OR r.partner_id = auth.uid())
      AND r.status = 'completed'
    )
  );

-- 4. INSERT Policy:
-- Users can insert their own answers in their rooms.
CREATE POLICY "answers_insert_policy"
  ON public.answers FOR INSERT
  WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.rooms r
      WHERE r.id = room_id
      AND (r.created_by = auth.uid() OR r.partner_id = auth.uid())
    )
  );

-- 5. UPDATE Policy:
-- Required for UPSERT. Users can update their own answers in their rooms.
CREATE POLICY "answers_update_policy"
  ON public.answers FOR UPDATE
  USING (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.rooms r
      WHERE r.id = room_id
      AND (r.created_by = auth.uid() OR r.partner_id = auth.uid())
    )
  )
  WITH CHECK (
    user_id = auth.uid()
  );

-- 6. DELETE Policy:
-- Admin full access
CREATE POLICY "answers_delete_policy"
  ON public.answers FOR DELETE
  USING (public.is_admin());
