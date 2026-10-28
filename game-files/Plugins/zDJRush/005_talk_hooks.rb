#===============================================================================
# DJ Rush Hour - Johnny (4b08e38a) after his usual WiFi line: the delivery menu or the
# after line on the Playa (map 98), one hint at the party (map 93). Nowhere else.
#===============================================================================

module DJRush
  @last_complaint = nil
  OK_LINES = %w[DJRUSH_JOHNNY_OK_1 DJRUSH_JOHNNY_OK_2 DJRUSH_JOHNNY_OK_3].freeze

  def self.after_talk(character_id)
    return unless character_id == DJRushRules::JOHNNY && $game_map
    st = state
    case DJRushRules.johnny_decide(st, $bag, $game_map.map_id)
    when :menu then delivery(st)
    when :after then say("DJRUSH_JOHNNY_AFTER", :johnny)
    when :hint then say("DJRUSH_JOHNNY_PARTY_HINT", :johnny)
    end
  end

  # One random complaint under the partygoer's own plate (not say: it would reset the plate).
  def self.complain(character_id)
    return unless $game_map && DJRushRules.complain?(state, $game_map.map_id, character_id)
    @last_complaint = DJRushRules.complaint_key(@last_complaint, rand)
    pbMessage(_INTL(@last_complaint))
  end

  # Ido on the floor after the swap says the founder's line instead of his usual one.
  def self.ido_line(character_id)
    return nil unless $game_map && DJRushRules.ido_floor?(state, $game_map.map_id, character_id)
    "DJRUSH_IDO_SPOTIFY"
  end

  # The phrase among decoys; only the exact phrase delivers.
  def self.delivery(st)
    rows = DJRushRules::SAY_KEYS.map { |k| _INTL(k) }
    pick = choose("DJRUSH_JOHNNY_ASK", nil, rows)
    case DJRushRules.say_result(pick)
    when :wrong then say("DJRUSH_JOHNNY_WRONG", :johnny)
    when :phrase
      return false unless DJRushRules.deliver!(st, $bag)
      pbMEPlay("Slots big win")
      lines(OK_LINES, :johnny)
      say("DJRUSH_JOHNNY_RETURN", :johnny)
      announce
      true
    end
  end
end

alias djrush_pbDesertTalk pbDesertTalk unless defined?(djrush_pbDesertTalk)
def pbDesertTalk(character_id, line_key = nil)
  line_key = DJRush.ido_line(character_id) || line_key
  DJRush.complain(character_id)
  ret = djrush_pbDesertTalk(character_id, line_key)
  DJRush.after_talk(character_id)
  ret
end
