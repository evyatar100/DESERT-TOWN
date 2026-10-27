#===============================================================================
# AllaStand - hook after Alla and the Happy Hour campers on the Playa (map 98 only).
#===============================================================================

module AllaStand
  def self.after_talk(character_id)
    return unless on_map?(PLAYA_MAP)
    if character_id == ALLA
      alla_talk
    elsif (who = CAMPER_IDS[character_id])
      camper_talk(who)
    end
  end
end

alias alla_pbDesertTalk pbDesertTalk unless defined?(alla_pbDesertTalk)
def pbDesertTalk(character_id, line_key = nil)
  ret = alla_pbDesertTalk(character_id, line_key)
  AllaStand.after_talk(character_id)
  ret
end
