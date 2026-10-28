#===============================================================================
# Shira's wedding - F9 entries (Debug > Desert Town...): play the board (not recorded),
# force a crossing, set the stage, drop the bag, warp to Eviatar, reset.
#===============================================================================

module ShiraWedding
  WARP = [SPOT[0], SPOT[1] + 1, 8].freeze   # below Eviatar, facing up

  def self.debug_warp
    $game_temp.player_new_map_id    = MAP_ID
    $game_temp.player_new_x         = WARP[0]
    $game_temp.player_new_y         = WARP[1]
    $game_temp.player_new_direction = WARP[2]
    $scene.transfer_player
    $game_map.refresh
  end

  def self.debug_reset
    $PokemonGlobal.shira_wedding = ShiraWeddingRules.new_state if $PokemonGlobal
    $bag.remove(ShiraWeddingRules::ITEM, $bag.quantity(ShiraWeddingRules::ITEM)) if $bag
    Wander.reset_session!
  end

  def self.close_debug_menu(sprites, viewport)
    pbFadeOutAndHide(sprites)
    pbDisposeMessageWindow(sprites["textbox"])
    pbDisposeSpriteHash(sprites)
    viewport.dispose
  end

  def self.on_map?
    return true if $PokemonGlobal && $scene.is_a?(Scene_Map)
    pbMessage("Load a game on the map first.")
    false
  end
end

MenuHandlers.add(:debug_menu, :dt_shira_wedding_play, {
  "name"        => "ShiraWedding: play the board (not recorded)",
  "parent"      => :desert_town_menu,
  "description" => "Runs the seating board. Nothing is saved.",
  "always_show" => true,
  "effect"      => proc { |sprites, viewport|
    next false unless ShiraWedding.on_map?
    ShiraWedding.close_debug_menu(sprites, viewport)
    ShiraWedding.play
    next true
  }
})

MenuHandlers.add(:debug_menu, :dt_shira_wedding_cross, {
  "name"        => "ShiraWedding: force a crossing now",
  "parent"      => :desert_town_menu,
  "description" => "On the Playa: Shira crosses the screen right away (if a clear row exists).",
  "always_show" => true,
  "effect"      => proc { |sprites, viewport|
    next false unless ShiraWedding.on_map?
    unless ShiraWedding.on_playa?
      pbMessage("Go to the Playa (Map098) first.")
      next false
    end
    ShiraWedding.close_debug_menu(sprites, viewport)
    pbMessage("No clear row on this screen.") unless ShiraWedding::Wander.start_crossing
    next true
  }
})

MenuHandlers.add(:debug_menu, :dt_shira_wedding_stage, {
  "name"        => "ShiraWedding: set the stage",
  "parent"      => :desert_town_menu,
  "description" => "Sets the quest stage; holds one Wedding Bag in bag/done, none before.",
  "always_show" => true,
  "effect"      => proc {
    next false unless ShiraWedding.on_map?
    stages = ShiraWeddingRules::STAGES
    pick = pbShowCommands(nil, stages.map(&:to_s) + ["Cancel"], stages.length + 1)
    next false unless pick.is_a?(Integer) && pick.between?(0, stages.length - 1)
    ShiraWeddingRules.debug_set!(ShiraWedding.state, $bag, stages[pick])
    pbMessage("Stage: #{stages[pick]}")
    next false
  }
})

MenuHandlers.add(:debug_menu, :dt_shira_wedding_drop, {
  "name"        => "ShiraWedding: drop the Wedding Bag",
  "parent"      => :desert_town_menu,
  "description" => "Removes every Wedding Bag (tests the reissue).",
  "always_show" => true,
  "effect"      => proc {
    next false unless ShiraWedding.on_map?
    $bag.remove(ShiraWeddingRules::ITEM, $bag.quantity(ShiraWeddingRules::ITEM))
    pbMessage("Wedding Bag dropped.")
    next false
  }
})

MenuHandlers.add(:debug_menu, :dt_shira_wedding_warp, {
  "name"        => "ShiraWedding: warp to Eviatar",
  "parent"      => :desert_town_menu,
  "description" => "Warps to Map098 (14,23), facing Eviatar.",
  "always_show" => true,
  "effect"      => proc { |sprites, viewport|
    next false unless ShiraWedding.on_map?
    ShiraWedding.close_debug_menu(sprites, viewport)
    ShiraWedding.debug_warp
    next true
  }
})

MenuHandlers.add(:debug_menu, :dt_shira_wedding_reset, {
  "name"        => "ShiraWedding: reset",
  "parent"      => :desert_town_menu,
  "description" => "Stage back to none, the Wedding Bag removed, the wander clock reset.",
  "always_show" => true,
  "effect"      => proc {
    next false unless ShiraWedding.on_map?
    ShiraWedding.debug_reset
    pbMessage("ShiraWedding reset.")
    next false
  }
})
