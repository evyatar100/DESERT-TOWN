#===============================================================================
# Bags - saved state ($PokemonGlobal.bags_quest) and the S106 mirror. Leaf under BagsRules.
#===============================================================================

class PokemonGlobalMetadata
  attr_writer :bags_quest

  def bags_quest
    @bags_quest = BagsRules.normalize(@bags_quest)
    return @bags_quest
  end
end

module Bags
  SWITCH = 106   # "bags-unicorns": on exactly while the duo stands by Inbar (unicorns_home?)
  INBAR_MAP = 95
  NAME_KEYS = {
    inbar: "NAME_C414CF08", esther: "BAGS_NAME_ESTHER", shirpaz: "BAGS_NAME_SHIRPAZ",
    duo: "BAGS_NAME_DUO", pixel: "NAME_D5383627", toga: "NAME_7A2A022C", cowboy: "NAME_670F79E3"
  }.freeze

  def self.state
    return BagsRules.new_state if !$PokemonGlobal
    return $PokemonGlobal.bags_quest
  end

  def self.rng
    @rng ||= Random.new
  end

  # One-way mirror of BagsRules.unicorns_home?; refreshes map pages when it flips.
  def self.sync_switch
    return if !$game_switches
    want = BagsRules.unicorns_home?(state)
    return if $game_switches[SWITCH] == want
    $game_switches[SWITCH] = want
    $game_map.need_refresh = true if $game_map
  end

  # TG40: the Music Bag counts for Inbar once the DJ quest's Playa delivery is done.
  def self.music_delivered?
    !!(defined?(DJRush) && DJRush.delivery_done?)
  end

  def self.inbar_count
    BagsRules.inbar_count($bag, music_delivered?)
  end

  # Removes 2 bags, sets :done and S106 in one call, before any message.
  def self.hand_over!
    return false if !$bag || !BagsRules.hand_over!(state, $bag, music_delivered?)
    sync_switch
    true
  end
end
