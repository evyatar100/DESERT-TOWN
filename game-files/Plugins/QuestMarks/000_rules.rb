#===============================================================================
# QuestMarks - pure rules for the shared "!" over the next person in a quest (spec TG65).
# No engine calls. Python mirror: tests/quest_marks_rules.py.
#===============================================================================

module QuestMarksRules
  Z = 99_990          # above map, weather and tone; below mini-games, portraits and messages
  BOB = 2             # +-2 px
  CYCLE = 40          # frames per bob cycle, one phase for every mark
  POLL = 60           # safety poll while free (F9 jumps)
  BALLOON_W = 12
  BALLOON_H = 16
  LIFT = 18           # gap between the charset frame top and the balloon
  BOB_STEPS = [0, 1, 2, 1, 0, -1, -2, -1].freeze
  # D4: any of these hides every mark.
  BUSY = %i[message menu battle transfer interpreter forced momdad].freeze

  # results: one {next:, giver:} hash per client; a target is "name" or ["name", cap].
  # names_index: event name -> sorted live event ids on this map. Returns sorted unique ids.
  def self.resolve(results, names_index, givers: false)
    ids = []
    results.each do |res|
      next unless res.is_a?(Hash)
      list = Array(res[:next])
      list += Array(res[:giver]) if givers
      list.each { |t| ids.concat(target_ids(t, names_index)) }
    end
    ids.uniq.sort
  end

  def self.target_ids(target, names_index)
    name, cap = target.is_a?(Array) ? target : [target, nil]
    found = names_index[name] || []
    cap.is_a?(Integer) ? found.first([cap, 0].max) : found
  end

  def self.visible?(flags)
    return false unless flags[:scene_map]
    BUSY.none? { |k| flags[k] }
  end

  def self.bob_offset(frame)
    BOB_STEPS[(frame % CYCLE) / (CYCLE / BOB_STEPS.size)]
  end

  # Top-left of the balloon over a character whose frame is frame_h tall.
  def self.position(screen_x, screen_y, frame_h)
    [screen_x - (BALLOON_W / 2), screen_y - frame_h - LIFT]
  end

  def self.drawable?(erased, transparent, opacity, character_name)
    !erased && !transparent && opacity.to_i > 0 && !character_name.to_s.empty?
  end

  def self.on_screen?(x, y, screen_w, screen_h)
    x + BALLOON_W > 0 && y + BALLOON_H > 0 && x < screen_w && y < screen_h
  end
end

module QuestMarks
  ENABLED = true      # false removes every mark
  GIVERS = false      # quest givers get no mark (dec:tg-41); F9 can flip it for the session
end
