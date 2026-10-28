#===============================================================================
# DJ Rush Hour - saved state ($PokemonGlobal.dj_rush) and message helpers.
#===============================================================================

class PokemonGlobalMetadata
  attr_writer :dj_rush

  def dj_rush
    @dj_rush = DJRushRules.normalize(@dj_rush)
    return @dj_rush
  end
end

module DJRush
  DJ = "fc898478"
  NAME_KEYS = { dj: "NAME_FC898478", johnny: "NAME_4B08E38A" }.freeze

  def self.state
    return DJRushRules.new_state if !$PokemonGlobal
    return $PokemonGlobal.dj_rush
  end

  # One line under the speaker's name plate; no speaker = narration, no plate.
  def self.say(key, speaker = nil, *args)
    DesertTalk.name_key = NAME_KEYS[speaker] if defined?(DesertTalk)
    pbMessage(_INTL(key, *args))
  end

  def self.lines(keys, speaker = nil)
    keys.each { |k| say(k, speaker) }
  end

  # Choices from already-translated rows; Back picks the last row.
  def self.choose(key, speaker, rows)
    DesertTalk.name_key = NAME_KEYS[speaker] if defined?(DesertTalk)
    pbMessage(_INTL(key), rows, rows.length)
  end

  # The fanfare for an item a DJRushRules mutator already put in the bag.
  def self.announce(item_id = DJRushRules::ITEM)
    DesertTalk.name_key = nil if defined?(DesertTalk)
    item = GameData::Item.get(item_id)
    name = item.portion_name
    pbMessage("\\me[Key item get]" + _INTL("You obtained \\c[1]{1}\\c[0]!", name) + "\\wtnp[40]")
    pbMessage(_INTL("You put the {1} in\\nyour Bag's <icon=bagPocket{2}>\\c[1]{3}\\c[0] pocket.",
                    name, item.pocket, PokemonBag.pocket_names[item.pocket - 1]))
  end

  # For other plugins (zBags counts the Music Bag for Inbar only after this).
  def self.delivery_done? = DJRushRules.delivered?(state)

  def self.on_map?(map_id)
    $game_map && $game_map.map_id == map_id
  end

  # "Floor 2/3 · Peak Time" for board index i.
  def self.level_label(i)
    "#{_INTL('DJRUSH_LEVEL', i + 1)} · #{_INTL("DJRUSH_LEVEL_NAME_#{i + 1}")}"
  end
end
