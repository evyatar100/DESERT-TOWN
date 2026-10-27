#===============================================================================
# Planetarium - Eyal in Deep Playa (Map033 ev2 runs pbPlanetEyal; no pbDesertTalk,
# so TG9's Eyal hook never fires there) and Hagar at Kusomo (map 95 only), hooked
# in after her own line through a pbDesertTalk alias.
#===============================================================================

module Planet
  EYAL = "0f0fdcf5"
  HAGAR = "b19b1f15"
  HAGAR_MAP = 95
  NAME_KEYS = { eyal: "NAME_0F0FDCF5", hagar: "NAME_B19B1F15" }.freeze

  # One line with the speaker's name plate (:none clears it).
  def self.say(key, speaker = :none)
    DesertTalk.name_key = NAME_KEYS[speaker] if defined?(DesertTalk)
    pbMessage(_INTL(key))
  end

  def self.lines(keys, speaker)
    keys.each { |k| say(k, speaker) }
  end

  # pbMessage with choices; Back picks the last option.
  def self.choose(key, speaker, choice_keys)
    DesertTalk.name_key = NAME_KEYS[speaker] if defined?(DesertTalk)
    pbMessage(_INTL(key), choice_keys.map { |k| _INTL(k) }, choice_keys.length)
  end

  def self.has_ram?
    PlanetRules.has?($bag)
  end

  def self.eyal_talk
    st = state
    case PlanetRules.eyal_decide(st, has_ram?)
    when :ask
      PlanetRules.ask!(st)
      lines(%w[PLANET_EYAL_ASK_1 PLANET_EYAL_ASK_2 PLANET_EYAL_ASK_3], :eyal)
    when :remind then say("PLANET_EYAL_REMIND", :eyal)
    when :thanks then deliver(st)
    when :warn then offer(st)
    when :after_done, :after_left then after(st)
    end
  end

  # The ram leaves the bag first; no ram, no stage change (REMIND instead).
  def self.deliver(st)
    return say("PLANET_EYAL_REMIND", :eyal) unless PlanetRules.deliver!(st, $bag)
    say("PLANET_EYAL_THANKS", :eyal)
    say("PLANET_EYAL_TAKEN")
    offer(st)
  end

  # WARN is shown before every show, first or replay.
  def self.offer(st)
    say("PLANET_EYAL_WARN", :eyal)
    pick = choose("PLANET_EYAL_START_ASK", :eyal, %w[PLANET_CHOICE_NOW PLANET_CHOICE_LATER])
    return say("PLANET_EYAL_LATER", :eyal) if pick != 0
    start(st)
  end

  # Every refusal (running, broken, wrong stage) is checked before start_show! moves the state.
  def self.start(st)
    return if Show.running?
    show = Show.prepare
    return say("PLANET_EYAL_BROKEN", :eyal) unless show
    return unless PlanetRules.start_show!(st)
    result = show.play
    return if result == false
    PlanetRules.finish!(st) if result == :done
    say(result == :done ? "PLANET_EYAL_AFTER_DONE" : "PLANET_EYAL_AFTER_LEFT", :eyal)
  end

  def self.after(st)
    say(st[:finished] ? "PLANET_EYAL_AFTER_DONE" : "PLANET_EYAL_AFTER_LEFT", :eyal)
    pick = choose("PLANET_EYAL_REPLAY_ASK", :eyal, %w[PLANET_CHOICE_REPLAY PLANET_CHOICE_NOTNOW])
    return say("PLANET_EYAL_REPLAY_NO", :eyal) if pick != 0
    offer(st)
  end

  # Hagar at Kusomo only (map 95 + her id); everywhere else her own line stands alone.
  def self.after_talk(character_id)
    return unless character_id == HAGAR && $game_map && $game_map.map_id == HAGAR_MAP
    st = state
    case PlanetRules.hagar_decide(st, has_ram?)
    when :give
      lines(%w[PLANET_HAGAR_GIVE_1 PLANET_HAGAR_GIVE_2], :hagar)
      return unless PlanetRules.give!(st, $bag)
      DesertTalk.name_key = nil if defined?(DesertTalk)
      pbReceiveItem(PlanetRules::ITEM)
    when :has then say("PLANET_HAGAR_HAS", :hagar)
    when :sent then say("PLANET_HAGAR_SENT", :hagar)
    when :after then say("PLANET_HAGAR_AFTER", :hagar)
    end
  end
end

# Map033 ev2 "planet_eyal": pbDesertSpeaker("0f0fdcf5"), then this.
def pbPlanetEyal
  Planet.eyal_talk
  true
end

alias planet_pbDesertTalk pbDesertTalk unless defined?(planet_pbDesertTalk)
def pbDesertTalk(character_id, line_key = nil)
  ret = planet_pbDesertTalk(character_id, line_key)
  Planet.after_talk(character_id)
  ret
end
