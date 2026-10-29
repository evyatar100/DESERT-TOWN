#===============================================================================
# LilyHappy - quest rules (pure, no engine calls). Python mirror: tests/lily_happy_rules.py.
# The wheel game itself is in 000_wheel_rules.rb (same module).
#===============================================================================

module LilyHappyRules
  LILY = "648b924a"
  LILY_NAME_KEY = "NAME_648B924A"
  LILY_CHARSET = "dt_648b924a"
  LILY_MAPS = [98, 91, 93].freeze
  # Encounter -> [[map id, character id], ...] (spec D5, A1); originals first, then the A1 rows.
  ENCOUNTERS = {
    kusomo: [[95, "a715ed37"]],
    circus: [[89, "a4012984"]],
    cats: [[78, "3dc31934"]],
    escher: [[110, "b3fb6767"]],
    glass: [[109, "661f55e6"]],
    shorty: [[91, "f9348fd0"], [98, "f9348fd0"]],
    loooo: [[98, "6b53f14c"]],
    gufak: [[97, "1be29576"]],
    turtle: [[97, "8d654949"]],
    razit: [[96, "64aeedbe"]],
    sushi: [[95, "b201fb8a"]]
  }.freeze
  # LEFT names places in this order (D5), nearest to Lily first.
  EASY_ORDER = %i[shorty loooo gufak turtle kusomo sushi razit cats escher glass circus].freeze
  LEFT_CAP = 3
  REPORT_CAP = 5
  # The wheel's six seats (D6): the five encounter characters plus Loooo.
  SEAT_IDS = %w[a715ed37 a4012984 3dc31934 b3fb6767 661f55e6 6b53f14c].freeze
  STAGES = %i[none asked wheeled done].freeze
  NEED = 4
  CAP = 3          # the most seats ever happy at once (proof in 000_wheel_rules.rb)
  MAX_LAPS = 99
  KEYS = %i[stage heard best laps].freeze

  def self.new_state
    { stage: :none, heard: [], best: nil, laps: 0 }
  end

  # In place, so a held reference to the saved hash stays live; garbage loads fresh.
  def self.normalize(state)
    return new_state unless state.is_a?(Hash)
    state.keys.each { |k| state.delete(k) unless KEYS.include?(k) }
    heard = state[:heard].is_a?(Array) ? state[:heard] : []
    state[:heard] = heard.select { |e| ENCOUNTERS.key?(e) }.uniq
    unless STAGES.include?(state[:stage])   # a bad stage restarts the quest: no half-heard survey
      state[:stage] = :none
      state[:heard] = []
    end
    best = state[:best]
    state[:best] = best.is_a?(Integer) ? best.clamp(0, CAP) : nil
    state[:laps] = state[:laps].is_a?(Integer) ? state[:laps].clamp(0, MAX_LAPS) : 0
    state
  end

  #--- where the hooks fire (D2, D5) ---------------------------------------------
  def self.lily_here?(map_id, character_id)
    character_id == LILY && LILY_MAPS.include?(map_id)
  end

  def self.encounter_at(map_id, character_id)
    ENCOUNTERS.each { |enc, pairs| return enc if pairs.include?([map_id, character_id]) }
    nil
  end

  #--- mutators (D3) ---------------------------------------------------------------
  def self.start!(s)
    return false unless s[:stage] == :none
    s[:stage] = :asked
    true
  end

  def self.hear!(s, enc)
    return false unless s[:stage] == :asked && ENCOUNTERS.key?(enc) && !s[:heard].include?(enc)
    s[:heard] << enc
    true
  end

  def self.ready?(s)
    s[:heard].size >= NEED
  end

  # True only for the :asked -> :wheeled step; a replay in :wheeled/:done only raises best.
  def self.wheel_done!(s, peak, laps)
    peak = peak.to_i.clamp(0, CAP)
    if s[:stage] == :asked
      return false unless ready?(s)
      s[:stage] = :wheeled
      s[:best] = peak
      s[:laps] = laps.to_i.clamp(0, MAX_LAPS)
      return true
    end
    return false unless %i[wheeled done].include?(s[:stage])
    s[:best] = peak if s[:best].nil? || peak > s[:best]
    false
  end

  def self.finish!(s)
    return false unless s[:stage] == :wheeled
    s[:stage] = :done
    true
  end

  # The scene's writer: only a finished wheel game reaches wheel_done!.
  def self.record!(s, g)
    return false unless g.is_a?(Hash) && g[:over] == :done
    wheel_done!(s, g[:peak], g[:laps])
  end

  #--- decisions (D4, D5) -----------------------------------------------------------
  def self.lily_decide(s)
    case s[:stage]
    when :none then :intro
    when :asked then ready?(s) ? :ready : :not_yet
    when :wheeled then :payoff
    else :idle
    end
  end

  def self.camp_decide(s, enc)
    return nil unless ENCOUNTERS.key?(enc)
    heard = s[:heard].include?(enc)
    case s[:stage]
    when :asked then heard ? :again : :complain
    when :wheeled then heard ? :again : nil
    end
  end

  # F9 "set stage": a fresh state walked through the real mutators to that stage.
  def self.state_at(stage)
    s = new_state
    return s if stage == :none
    start!(s)
    ENCOUNTERS.keys.first(NEED).each { |e| hear!(s, e) }
    return s if stage == :asked
    wheel_done!(s, 2, 1)
    finish!(s) if stage == :done
    s
  end

  # Encounters not heard yet, in ENCOUNTERS order.
  def self.left(s)
    ENCOUNTERS.keys - s[:heard]
  end

  # LEFT (D4): at most LEFT_CAP distinct place labels from the unheard encounters in
  # EASY_ORDER; the block gives an encounter's label. Returns [labels, more_left?].
  def self.left_places(s)
    labels = []
    EASY_ORDER.each do |enc|
      next if s[:heard].include?(enc)
      label = yield(enc)
      labels << label unless labels.include?(label)
    end
    [labels.first(LEFT_CAP), labels.size > LEFT_CAP]
  end

  # The payoff (D9): the first REPORT_CAP heard, reported one by one, and how many more.
  def self.report_list(s)
    [s[:heard].first(REPORT_CAP), [s[:heard].size - REPORT_CAP, 0].max]
  end

  #--- the "!" (D5a, TG65 D8) -----------------------------------------------------------
  def self.mark?(s, enc)
    camp_decide(s, enc) == :complain
  end

  # QuestMarks client: next = unheard complainers pinned on this map, plus Lily once
  # ready (:asked) and in :wheeled; giver = Lily in :none. Targets are event names.
  def self.marks(s, map_id)
    nxt = []
    ENCOUNTERS.each do |enc, pairs|
      next unless mark?(s, enc)
      pairs.each { |m, id| nxt << "dt_#{id}" if m == map_id }
    end
    return { next: nxt.uniq } unless LILY_MAPS.include?(map_id)
    return { next: nxt.uniq, giver: [LILY_CHARSET] } if s[:stage] == :none
    nxt << LILY_CHARSET if (s[:stage] == :asked && ready?(s)) || s[:stage] == :wheeled
    { next: nxt.uniq }
  end
end

# Shared by 004-007 so they do not depend on 004 loading first.
module LilyHappy
  R = LilyHappyRules
  MAP_ID = 98
  SPOT = [5, 3].freeze   # Lily on the Playa (Map098 ev2)
end
