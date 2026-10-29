#===============================================================================
# LilyHappy - saved quest state ($PokemonGlobal.lily_happy); old saves load the default.
# Plus the message helpers every map-side file uses.
#===============================================================================

class PokemonGlobalMetadata
  attr_writer :lily_happy

  def lily_happy
    @lily_happy = LilyHappyRules.normalize(@lily_happy)
    return @lily_happy
  end
end

module LilyHappy
  def self.state
    return LilyHappyRules.new_state if !$PokemonGlobal
    return $PokemonGlobal.lily_happy
  end

  def self.autosave
    DesertTownAutosave.save_now(:lily_happy) if defined?(DesertTownAutosave)
  end

  # speaker :lily shows Lily's plate; nil is narration with no plate; :keep leaves the
  # current plate (a camp NPC set by its own pbDesertSpeaker).
  def self.plate(speaker)
    return unless defined?(DesertTalk)
    return if speaker == :keep
    DesertTalk.name_key = speaker == :lily ? LilyHappyRules::LILY_NAME_KEY : nil
  end

  def self.say(key, speaker = :lily, *args)
    plate(speaker)
    pbMessage(_INTL(key, *args))
  end

  def self.lines(keys, speaker = :lily)
    keys.each { |k| say(k, speaker) }
  end

  # Two rows; Blue picks the second.
  def self.ask(key, yes, no, speaker = :lily)
    plate(speaker)
    pbMessage(_INTL(key), [_INTL(yes), _INTL(no)], 2) == 0
  end

  # True when the copy has the key (a missing key translates to itself).
  def self.copy?(key) = _INTL(key) != key

  def self.player_charset
    defined?(TempleStickers) ? TempleStickers.player_charset : nil
  end

  def self.mirror? = player_charset == LilyHappyRules::LILY_CHARSET

  # The bags song is running over the map: the wheel waits (as zShiraWedding).
  def self.busy? = !!(defined?(Bags::Song) && Bags::Song.active?)
end
