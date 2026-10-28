#===============================================================================
# __NAME__ - F9 entries (Debug > Desert Town...): play without recording, warp, reset.
#===============================================================================

module __NAME__
  WARP = [SPOT[0], SPOT[1] + 1, 8].freeze   # below the spot, facing up

  def self.debug_warp
    $game_temp.player_new_map_id    = MAP_ID
    $game_temp.player_new_x         = WARP[0]
    $game_temp.player_new_y         = WARP[1]
    $game_temp.player_new_direction = WARP[2]
    $scene.transfer_player
    $game_map.refresh
  end

  def self.debug_reset
    $PokemonGlobal.__SNAKE__ = __NAME__Rules.new_state if $PokemonGlobal
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

MenuHandlers.add(:debug_menu, :dt___SNAKE___play, {
  "name"        => "__NAME__: play (not recorded)",
  "parent"      => :desert_town_menu,
  "description" => "Runs the __NAME__ scene. The result is not saved.",
  "always_show" => true,
  "effect"      => proc { |sprites, viewport|
    next false unless __NAME__.on_map?
    __NAME__.close_debug_menu(sprites, viewport)
    __NAME__.play(__NAME__.state, record: false)
    next true
  }
})

MenuHandlers.add(:debug_menu, :dt___SNAKE___warp, {
  "name"        => "__NAME__: warp to the spot",
  "parent"      => :desert_town_menu,
  "description" => "Warps to Map__MAPID3__ below (__TX__,__TY__), facing up.",
  "always_show" => true,
  "effect"      => proc { |sprites, viewport|
    next false unless __NAME__.on_map?
    __NAME__.close_debug_menu(sprites, viewport)
    __NAME__.debug_warp
    next true
  }
})

MenuHandlers.add(:debug_menu, :dt___SNAKE___reset, {
  "name"        => "__NAME__: reset record",
  "parent"      => :desert_town_menu,
  "description" => "Wins, plays and best time back to the default.",
  "always_show" => true,
  "effect"      => proc {
    next false unless __NAME__.on_map?
    __NAME__.debug_reset
    pbMessage("__NAME__ record reset.")
    next false
  }
})
