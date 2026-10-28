#===============================================================================
# __NAME__ - __CHARID__ hooks in after the usual pbDesertTalk line; every other id falls through.
#===============================================================================

module __NAME__
  TALKER = "__CHARID__"

  def self.after_talk(character_id)
    return unless character_id == TALKER && $game_map && $game_map.map_id == MAP_ID
    offer
  end
end

alias __SNAKE___pbDesertTalk pbDesertTalk unless defined?(__SNAKE___pbDesertTalk)
def pbDesertTalk(character_id, line_key = nil)
  ret = __SNAKE___pbDesertTalk(character_id, line_key)
  __NAME__.after_talk(character_id)
  ret
end
