#===============================================================================
# LilyHappy - after the usual pbDesertTalk line: Lily (648b924a) on maps 98/91/93, and the
# eleven pinned camp encounters (spec D5, A1). Every other (map, id) pair falls through.
#===============================================================================

module LilyHappy
  def self.after_talk(character_id)
    return unless $game_map
    return if defined?(MomDadBattle) && MomDadBattle.active?
    map_id = $game_map.map_id
    if R.lily_here?(map_id, character_id)
      lily_talk
    elsif (enc = R.encounter_at(map_id, character_id))
      camp_talk(enc)
    end
  end

  # The complaint comes before hear!, so a quit mid-dialogue counts nothing.
  def self.camp_talk(enc)
    st = state
    up = enc.to_s.upcase
    case R.camp_decide(st, enc)
    when :complain
      keys = %w[1 2 3].map { |n| "LILY_#{up}_#{n}" }
      keys.pop unless copy?(keys.last)   # _3 is optional
      lines(keys, :keep)
      return false unless R.hear!(st, enc)
      autosave
      return say("LILY_HEARD_EXTRA", nil) if st[:heard].size > R::NEED
      return say("LILY_HEARD_ALL", nil) if R.ready?(st)
      say("LILY_HEARD", nil, st[:heard].size)
    when :again then say("LILY_#{up}_AGAIN", :keep)
    end
    true
  end
end

alias lily_happy_pbDesertTalk pbDesertTalk unless defined?(lily_happy_pbDesertTalk)
def pbDesertTalk(character_id, line_key = nil)
  ret = lily_happy_pbDesertTalk(character_id, line_key)
  LilyHappy.after_talk(character_id)
  ret
end
