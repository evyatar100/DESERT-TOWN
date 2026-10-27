#===============================================================================
# AllaStand - saved state ($PokemonGlobal.alla_stand), session easing and message helpers.
#===============================================================================

class PokemonGlobalMetadata
  attr_writer :alla_stand

  def alla_stand
    @alla_stand = AllaRules.normalize(@alla_stand)
    return @alla_stand
  end
end

module AllaStand
  ALLA = "4c4e039d"
  CAMPER_IDS = { "9b3660d1" => :tal, "788b2614" => :elias, "bb70b1dd" => :mario }.freeze
  PLAYA_MAP = 98
  STAND_XY = [11, 14].freeze
  NAME_KEYS = {
    alla: "NAME_4C4E039D", tal: "NAME_9B3660D1", elias: "NAME_788B2614", mario: "NAME_BB70B1DD"
  }.freeze

  # Retry easing, session only (never saved): a reload resets it.
  class << self
    def rush_losses = (@rush_losses ||= 0)
  end

  def self.reset_easing
    @rush_losses = 0
  end

  # A pass clears the easing; a fail adds one step.
  def self.record_rush(passed)
    @rush_losses = passed ? 0 : rush_losses + 1
  end

  def self.state
    return AllaRules.new_state if !$PokemonGlobal
    return $PokemonGlobal.alla_stand
  end

  # One line with the speaker's name plate; no speaker = narration, no plate.
  def self.say(key, speaker = nil, *args)
    DesertTalk.name_key = NAME_KEYS[speaker] if defined?(DesertTalk)
    pbMessage(_INTL(key, *args))
  end

  def self.lines(keys, speaker = nil)
    keys.each { |k| say(k, speaker) }
  end

  # Choices; Back picks the last option.
  def self.choose(key, speaker, choice_keys)
    DesertTalk.name_key = NAME_KEYS[speaker] if defined?(DesertTalk)
    pbMessage(_INTL(key), choice_keys.map { |k| _INTL(k) }, choice_keys.length)
  end

  # The item fanfare for an item an AllaRules mutator already put in the bag.
  def self.announce(item_id)
    DesertTalk.name_key = nil if defined?(DesertTalk)
    item = GameData::Item.get(item_id)
    name = item.portion_name
    pbMessage("\me[Key item get]" + _INTL("You obtained \c[1]{1}\c[0]!", name) + "\wtnp[40]")
    pbMessage(_INTL("You put the {1} in\nyour Bag's <icon=bagPocket{2}>\c[1]{3}\c[0] pocket.",
                    name, item.pocket, PokemonBag.pocket_names[item.pocket - 1]))
  end

  def self.on_map?(map_id)
    $game_map && $game_map.map_id == map_id
  end
end
