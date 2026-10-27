#===============================================================================
# Toaster - saved state ($PokemonGlobal.toaster_quest) and message helpers.
#===============================================================================

class PokemonGlobalMetadata
  attr_writer :toaster_quest

  def toaster_quest
    @toaster_quest = ToasterRules.normalize(@toaster_quest)
    return @toaster_quest
  end
end

module Toaster
  NOODLES = "c081cd67"
  CLERK = "326f5ab5"
  OREN = "266d65c6"
  KUSOMO_MAP = 95
  CLERK_MAP = 80
  ALTAR_MAP = 94
  NAME_KEYS = {
    noodles: "NAME_C081CD67", clerk: "NAME_326F5AB5", oren: "NAME_266D65C6"
  }.freeze

  # Retry easing, session only (never saved): a reload resets it.
  class << self
    def desk_losses = (@desk_losses ||= 0)
    def vault_losses = (@vault_losses ||= 0)
    def vault_last_hits = (@vault_last_hits ||= 0)
  end

  def self.reset_easing
    @desk_losses = @vault_losses = @vault_last_hits = 0
  end

  # A pass clears the desk easing; a fail adds one step.
  def self.record_desk(passed)
    @desk_losses = passed ? 0 : desk_losses + 1
  end

  def self.record_vault(won, hits)
    @vault_losses = won ? 0 : vault_losses + 1
    @vault_last_hits = won ? 0 : hits
  end

  def self.state
    return ToasterRules.new_state if !$PokemonGlobal
    return $PokemonGlobal.toaster_quest
  end

  # One line with the speaker's name plate; no speaker = narration, no plate.
  def self.say(key, speaker = nil)
    DesertTalk.name_key = NAME_KEYS[speaker] if defined?(DesertTalk)
    pbMessage(_INTL(key))
  end

  def self.lines(keys, speaker = nil)
    keys.each { |k| say(k, speaker) }
  end

  # Choices; Back picks the last option.
  def self.choose(key, speaker, choice_keys)
    DesertTalk.name_key = NAME_KEYS[speaker] if defined?(DesertTalk)
    pbMessage(_INTL(key), choice_keys.map { |k| _INTL(k) }, choice_keys.length)
  end

  # The item fanfare for an item a ToasterRules mutator already put in the bag.
  def self.announce(item_id)
    DesertTalk.name_key = nil if defined?(DesertTalk)
    item = GameData::Item.get(item_id)
    name = item.portion_name
    pbMessage("\\me[Key item get]" + _INTL("You obtained \\c[1]{1}\\c[0]!", name) + "\\wtnp[40]")
    pbMessage(_INTL("You put the {1} in\\nyour Bag's <icon=bagPocket{2}>\\c[1]{3}\\c[0] pocket.",
                    name, item.pocket, PokemonBag.pocket_names[item.pocket - 1]))
  end

  def self.on_map?(map_id)
    $game_map && $game_map.map_id == map_id
  end
end
