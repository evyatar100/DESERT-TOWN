#===============================================================================
# Shira's wedding - saved state ($PokemonGlobal.shira_wedding) and message helpers.
#===============================================================================

class PokemonGlobalMetadata
  attr_writer :shira_wedding

  def shira_wedding
    @shira_wedding = ShiraWeddingRules.normalize(@shira_wedding)
    return @shira_wedding
  end
end

module ShiraWedding
  SHIRA = "50d0eeb7"
  EVIATAR = "f90d4de9"
  NAME_KEYS = { shira: "NAME_50D0EEB7", eviatar: "NAME_F90D4DE9" }.freeze
  PLAYER_EVIATAR = "dt_f90d4de9"
  SHIRA_EVENT = "shira_wedding"   # Map098 ev17, found by name
  CHARSET = "dt_50d0eeb7"

  def self.state
    return ShiraWeddingRules.new_state if !$PokemonGlobal
    return $PokemonGlobal.shira_wedding
  end

  # zBags reads this (one-way): the Wedding Bag counts for Inbar from :bag on.
  def self.bag_given? = ShiraWeddingRules.bag_given?(state)

  # Guarded read of zBags, the mirror of its DJRush read.
  def self.inbar_done?
    !!(defined?(Bags) && Bags.respond_to?(:state) && Bags.state[:inbar] == :done)
  end

  # One line under the speaker's name plate; no speaker = narration, no plate.
  def self.say(key, speaker = nil, *args)
    DesertTalk.name_key = NAME_KEYS[speaker] if defined?(DesertTalk)
    pbMessage(_INTL(key, *args))
  end

  def self.lines(keys, speaker = nil)
    keys.each { |k| say(k, speaker) }
  end

  # Yes/no with the quest's own rows; Blue = no.
  def self.ask(key, speaker)
    DesertTalk.name_key = NAME_KEYS[speaker] if defined?(DesertTalk)
    pbMessage(_INTL(key), [_INTL("SHIRA_YES"), _INTL("SHIRA_NO")], 2) == 0
  end

  # The fanfare for the item a ShiraWeddingRules mutator already put in the bag.
  def self.announce
    DesertTalk.name_key = nil if defined?(DesertTalk)
    item = GameData::Item.get(ShiraWeddingRules::ITEM)
    name = item.portion_name
    pbMessage("\\me[Key item get]" + _INTL("You obtained \\c[1]{1}\\c[0]!", name) + "\\wtnp[40]")
    pbMessage(_INTL("You put the {1} in\\nyour Bag's <icon=bagPocket{2}>\\c[1]{3}\\c[0] pocket.",
                    name, item.pocket, PokemonBag.pocket_names[item.pocket - 1]))
  end

  def self.player_charset
    defined?(TempleStickers) ? TempleStickers.player_charset : nil
  end

  def self.mirror? = player_charset == PLAYER_EVIATAR
end
