#===============================================================================
# Flamingo Band quest: pure decisions (no game objects, loadable by tests).
#===============================================================================

module FlamingoBandRules
  # Every Flamingods placement on maps 77 and 99; HOST is the one who asks for help.
  FLAMINGOS = %w[708d6c34 9923f1c4 c626f0d6 671405a6 754ba04a
                 5990bffc f9a7cff7 574177dd 1988218f].freeze
  HOST         = "9923f1c4"
  VISITOR      = "468de6d4"
  OUTSIDE_MAP  = 77
  TENT_MAP     = 99
  MAPS         = [OUTSIDE_MAP, TENT_MAP].freeze
  FINAL_STAGE  = 4
  INTRO_X      = (12..19).freeze
  INTRO_Y      = (26..29).freeze
  ROLL_INTERVAL = 90
  ROLL_CHANCE   = 0.25
  SKIP_CHANCE   = 0.2
  SPAWN_MIN     = 4
  SPAWN_MAX     = 6
  TRACK_PREFIX  = "Flamingo Band stage_"
  EXIT_EVENT    = "Exit"
  # Map099 floor in front of the second small tent (back wall); player tile, then helper tile.
  BACK_TENT_PLAYER = [11, 7].freeze
  BACK_TENT_HELPER = [12, 7].freeze
  STAGE_LINES = %w[MSG_FLAMINGO_BAND_1 MSG_FLAMINGO_BAND_2
                   MSG_FLAMINGO_BAND_3 MSG_FLAMINGO_BAND_4].freeze

  module_function

  def new_state
    return { intro_done: false, stage: 0, consumed: [], procession: false, next_roll_at: nil,
             escape_attempts: 0 }
  end

  # Saves from the build that kept a permanent :finished flag load as a fresh quest.
  def normalize(state)
    return new_state if !state.is_a?(Hash) || state[:finished]
    return state
  end

  def stage_track(stage)
    return "#{TRACK_PREFIX}#{stage}"
  end

  def band_track?(name)
    return name.is_a?(String) && name.start_with?(TRACK_PREFIX)
  end

  def stage_line(stage)
    return STAGE_LINES[stage - 1]
  end

  def in_intro_zone?(map_id, x, y)
    return map_id == OUTSIDE_MAP && INTRO_X.include?(x) && INTRO_Y.include?(y)
  end

  # Stage number this talk unlocks (state is updated first), or nil for the default line.
  def claim(state, char_id, map_id)
    return nil if !state[:intro_done] || state[:stage] >= FINAL_STAGE
    return nil if !MAPS.include?(map_id)
    return nil if char_id == HOST || !FLAMINGOS.include?(char_id)
    return nil if state[:consumed].include?(char_id)
    state[:consumed] << char_id
    state[:stage] += 1
    return state[:stage]
  end

  # [next_roll_at, interrupt?]. Calls rng (returns 0...1) only when a roll is due.
  def roll(now, next_roll_at, rng)
    return [now + ROLL_INTERVAL, false] if next_roll_at.nil?
    return [next_roll_at, false] if now < next_roll_at
    return [now + ROLL_INTERVAL, rng.call < ROLL_CHANCE]
  end

  # Music on map entry: :original, :silence, or a BGM name.
  def music_for(state, map_id)
    return stage_track(FINAL_STAGE) if state[:procession]
    return :original if !state[:intro_done] || !MAPS.include?(map_id)
    return :silence if state[:stage] <= 0
    return stage_track(state[:stage])
  end

  # Tent exit while the quest runs: first time caught (:catch), second time the quest ends (:release).
  def escape_action(state)
    return :none if !state[:intro_done] || state[:procession] || state[:stage] >= FINAL_STAGE
    return (state[:escape_attempts].to_i >= 1) ? :release : :catch
  end

  # Interruption rolls run only during the procession.
  def rolling?(state)
    return !!state[:procession]
  end

  def intro_due?(state)
    return !state[:intro_done]
  end

  # Intro hold-back after the quest ends with the player in the zone: [start?, still_held].
  def intro_gate(state, held, in_zone)
    held = held && in_zone
    return [in_zone && !held && intro_due?(state), held]
  end

  def start_procession?(state, old_map_id, map_id)
    return false if state[:procession] || state[:stage] < FINAL_STAGE
    return old_map_id == TENT_MAP && map_id == OUTSIDE_MAP
  end

  # A follower may hop instead of stepping only on a straight stretch, so its catch-up is a straight 2.
  def skip_step?(missed_last, distance, chance_roll, straight)
    return false if missed_last || distance >= 2 || !straight
    return chance_roll < SKIP_CHANCE
  end

  # True when the step to the target runs along the leader's facing (no corner).
  def straight_step?(dx, dy, leader_direction)
    want = { 2 => [0, 1], 4 => [-1, 0], 6 => [1, 0], 8 => [0, -1] }[leader_direction]
    return [dx, dy] == want
  end

  def spawn_offsets(min = SPAWN_MIN, max = SPAWN_MAX)
    offsets = []
    (-max..max).each do |dx|
      (-max..max).each do |dy|
        d = dx.abs + dy.abs
        offsets << [dx, dy] if d >= min && d <= max
      end
    end
    return offsets
  end
end
