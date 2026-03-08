-- ============================================================
-- Room Configuration Updates
-- Run this script in the Supabase SQL Editor
-- ============================================================

-- 1. Add new columns to the rooms table
ALTER TABLE public.rooms 
  ADD COLUMN IF NOT EXISTS question_count INTEGER DEFAULT 10,
  ADD COLUMN IF NOT EXISTS same_questions BOOLEAN DEFAULT TRUE;

-- 2. Update the auto-calculate compatibility trigger
CREATE OR REPLACE FUNCTION check_room_completion()
RETURNS TRIGGER AS $$
DECLARE
  v_room          RECORD;
  v_creator_count INTEGER;
  v_partner_count INTEGER;
  v_question_count INTEGER;
  v_score         NUMERIC;
  v_total_weight  NUMERIC;
  v_earned_weight NUMERIC;
  q               RECORD;
  ans_creator     TEXT;
  ans_partner     TEXT;
  q_weight        INTEGER;
  q_type          TEXT;
  diff            NUMERIC;
BEGIN
  -- Get room info
  SELECT * INTO v_room FROM public.rooms WHERE id = NEW.room_id;
  
  IF v_room.partner_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Use the room's specific question configuration
  v_question_count := v_room.question_count;

  -- Count creator answers
  SELECT COUNT(*) INTO v_creator_count
  FROM public.answers
  WHERE room_id = NEW.room_id AND user_id = v_room.created_by;

  -- Count partner answers
  SELECT COUNT(*) INTO v_partner_count
  FROM public.answers
  WHERE room_id = NEW.room_id AND user_id = v_room.partner_id;

  -- Mark individual done flags
  IF NEW.user_id = v_room.created_by AND v_creator_count >= v_question_count THEN
    UPDATE public.rooms SET creator_done = TRUE WHERE id = NEW.room_id;
  END IF;

  IF NEW.user_id = v_room.partner_id AND v_partner_count >= v_question_count THEN
    UPDATE public.rooms SET partner_done = TRUE WHERE id = NEW.room_id;
  END IF;

  -- Both done → calculate score + mark completed
  IF v_creator_count >= v_question_count AND v_partner_count >= v_question_count THEN
    v_total_weight  := 0;
    v_earned_weight := 0;

    -- We only grade questions that BOTH users have answered
    FOR q IN 
      SELECT DISTINCT qu.* 
      FROM public.questions qu
      JOIN public.answers a1 ON a1.question_id = qu.id AND a1.room_id = NEW.room_id AND a1.user_id = v_room.created_by
      JOIN public.answers a2 ON a2.question_id = qu.id AND a2.room_id = NEW.room_id AND a2.user_id = v_room.partner_id
      WHERE qu.active = TRUE
    LOOP
      SELECT answer_value INTO ans_creator
      FROM public.answers
      WHERE room_id = NEW.room_id AND user_id = v_room.created_by AND question_id = q.id;

      SELECT answer_value INTO ans_partner
      FROM public.answers
      WHERE room_id = NEW.room_id AND user_id = v_room.partner_id AND question_id = q.id;

      q_weight := q.weight;
      q_type   := q.type;
      v_total_weight := v_total_weight + q_weight;

      IF q_type = 'scale' THEN
        diff := ABS(ans_creator::NUMERIC - ans_partner::NUMERIC);
        v_earned_weight := v_earned_weight + q_weight * (1 - diff / 4.0);
      ELSE
        IF LOWER(TRIM(ans_creator)) = LOWER(TRIM(ans_partner)) THEN
          v_earned_weight := v_earned_weight + q_weight;
        END IF;
      END IF;
    END LOOP;

    IF v_total_weight > 0 THEN
      v_score := ROUND((v_earned_weight / v_total_weight) * 100, 2);
    ELSE
      v_score := 0;
    END IF;

    UPDATE public.rooms
    SET
      status              = 'completed',
      compatibility_score = v_score,
      creator_done        = TRUE,
      partner_done        = TRUE,
      completed_at        = NOW()
    WHERE id = NEW.room_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
