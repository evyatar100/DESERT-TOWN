#===============================================================================
# Tuta maze - F9 debug entries (Debug > Desert Town...): play at a picked diff,
# warp to the statue, leave 1 strawberry for the next game, reset the record.
#===============================================================================

module TutaMaze
  WARP = [10, 19, 8].freeze     # below the statue, facing up at it
  DEBUG_DIFFS = [-0.9, -0.6, -0.3, 0.0, 0.3, 0.6].freeze

  def self.debug_warp
    $game_temp.player_new_map_id    = TEMPLE_MAP
    $game_temp.player_new_x         = WARP[0]
    $game_temp.player_new_y         = WARP[1]
    $game_temp.player_new_direction = WARP[2]
    $scene.transfer_player
    $game_map.refresh
  end

  def self.debug_reset
    $PokemonGlobal.tuta_maze = TutaMazeRules.new_state if $PokemonGlobal
    @leave_one = false
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

MenuHandlers.add(:debug_menu, :dt_tuta_play, {
  "name"        => "Tuta: play (pick diff -0.9...+0.6)",
  "parent"      => :desert_town_menu,
  "description" => "Runs the strawberry maze at a picked owner difficulty. Results are recorded.",
  "always_show" => true,
  "effect"      => proc { |sprites, viewport|
    next false unless TutaMaze.on_map?
    names = TutaMaze::DEBUG_DIFFS.map { |d| format("diff %+.1f", d) } + ["Cancel"]
    pick = pbShowCommands(nil, names, names.length)
    next false unless pick.between?(0, TutaMaze::DEBUG_DIFFS.length - 1)
    TutaMaze.close_debug_menu(sprites, viewport)
    TutaMaze.play(TutaMaze.state, TutaMaze::DEBUG_DIFFS[pick])
    next true
  }
})

MenuHandlers.add(:debug_menu, :dt_tuta_warp, {
  "name"        => "Tuta: warp to the statue",
  "parent"      => :desert_town_menu,
  "description" => "Warps to Map113 (10,19), facing the strawberry-dog statue.",
  "always_show" => true,
  "effect"      => proc { |sprites, viewport|
    next false unless TutaMaze.on_map?
    TutaMaze.close_debug_menu(sprites, viewport)
    TutaMaze.debug_warp
    next true
  }
})

MenuHandlers.add(:debug_menu, :dt_tuta_leave_one, {
  "name"        => "Tuta: leave 1 strawberry",
  "parent"      => :desert_town_menu,
  "description" => "The next Tuta game starts with 139 eaten (the one left of the spawn remains).",
  "always_show" => true,
  "effect"      => proc {
    next false unless TutaMaze.on_map?
    TutaMaze.leave_one = true
    pbMessage("The next Tuta game starts with 1 strawberry left.")
    next false
  }
})

MenuHandlers.add(:debug_menu, :dt_tuta_reset, {
  "name"        => "Tuta: reset record",
  "parent"      => :desert_town_menu,
  "description" => "Wins, loss streak, best time and plays back to the default.",
  "always_show" => true,
  "effect"      => proc {
    next false unless TutaMaze.on_map?
    TutaMaze.debug_reset
    pbMessage("Tuta record reset.")
    next false
  }
})
