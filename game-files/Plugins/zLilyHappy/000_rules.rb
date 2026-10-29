#===============================================================================
# LilyHappy - quest rules (pure, no engine calls). Python mirror: tests/lily_happy_rules.py.
# The wheel game itself is in 000_wheel_rules.rb (same module).
#===============================================================================

module LilyHappyRules
  LILY = "648b924a"
  LILY_NAME_KEY = "NAME_648B924A"
  LILY_CHARSET = "dt_648b924a"
  LILY_MAPS = [98, 91, 93].freeze
  # Encounter -> [map id, character id] (spec D5); order = the order camps are named in.
  ENCOUNTERS = {
    kusomo: [95, "a715ed37"],
    circus: [89, "a4012984"],
    cats: [78, "3dc31934"],
    escher: [110, "b3fb6767"],
    glass: [109, "661f55e6"]
  }.freeze
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
    state[:stage] = :none unless STAGES.include?(state[:stage])
    heard = state[:heard].is_a?(Array) ? state[:heard] : []
    state[:heard] = heard.select { |e| ENCOUNTERS.key?(e) }.uniq
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
    ENCOUNTERS.each { |enc, pair| return enc if pair == [map_id, character_id] }
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
end
