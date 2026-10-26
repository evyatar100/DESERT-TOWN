#===============================================================================
# Bags - F9 debug entries under Desert Town... and Bags.reset (debug playtests only).
#===============================================================================

module Bags
  # Debug and tests: no song, no duo followers, a fresh quest, S106 off, the 3 bag items gone.
  def self.reset
    playing = Song.stop
    Duo.remove_followers
    $PokemonGlobal.bags_quest = BagsRules.new_state if $PokemonGlobal
    if $bag
      %i[SURPRISEBAG BAGOFBAGS DESERTBAG].each { |i| $bag.remove(i, $bag.quantity(i)) if $bag.quantity(i) > 0 }
    end
    sync_switch
    $game_map.autoplay if playing && $game_map
  end

  DEBUG_ENTRIES = [
    [:dt_bags_give_two, "Bags: give 2 surprise bags", "Adds 2 Surprise Bags.",
     proc { $bag.add(:SURPRISEBAG, 2) }],
    [:dt_bags_give_bob, "Bags: give Bag of Bags", "Adds the Bag of Bags (once).",
     proc { $bag.add(:BAGOFBAGS, 1) if $bag.quantity(:BAGOFBAGS) == 0 }],
    [:dt_bags_reset, "Bags: reset quest", "Stops the song, drops the duo followers, new quest state, S106 off, the 3 bag items removed.",
     proc { Bags.reset }],
    [:dt_bags_song, "Bags: play song (no reward)", "Song overlay and music only: no followers, no state change, no end line.",
     proc { Bags::Song.start(duo: false) }],
    [:dt_bags_end_song, "Bags: end song now", "Takes the running song to its normal end (the end scene if the duo follows).",
     proc { Bags::Song.end_now }]
  ].freeze
end

Bags::DEBUG_ENTRIES.each do |id, name, desc, action|
  MenuHandlers.add(:debug_menu, id, {
    "name"        => name,
    "parent"      => :desert_town_menu,
    "description" => desc,
    "always_show" => true,
    "effect"      => proc {
      if !$player || !$bag
        pbMessage("No player loaded yet.")
        next false
      end
      action.call
      pbMessage("Done.")
      next false
    }
  })
end
