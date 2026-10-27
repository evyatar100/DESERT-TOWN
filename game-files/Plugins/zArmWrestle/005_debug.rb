#===============================================================================
# Arm wrestling - F9 debug entries (Debug > Desert Town...): a bout at a picked tier
# (no bag, no state change), reset the run state, warp in front of Shirpaz.
#===============================================================================

module ArmWrestle
  KUSOMO_MAP = 95
  WARP = [14, 9, 8].freeze      # the tile below Shirpaz (Map095 ev2 at 14,8), facing up at her

  def self.debug_play(tier)
    pbFadeOutIn { Scene.new(tier).run }
  end

  def self.debug_reset
    $PokemonGlobal.arm_wrestle = ArmWrestleRules.new_state if $PokemonGlobal
  end

  def self.debug_warp
    $game_temp.player_new_map_id    = KUSOMO_MAP
    $game_temp.player_new_x         = WARP[0]
    $game_temp.player_new_y         = WARP[1]
    $game_temp.player_new_direction = WARP[2]
    $scene.transfer_player
    $game_map.refresh
  end

  # Closes the debug menu the way the stock warp does.
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

MenuHandlers.add(:debug_menu, :dt_arm_play, {
  "name"        => "Arm wrestle: play a bout (pick tier 0-3)",
  "parent"      => :desert_town_menu,
  "description" => "Runs the arm-wrestling scene only: no bag, no state change.",
  "always_show" => true,
  "effect"      => proc { |sprites, viewport|
    next false unless ArmWrestle.on_map?
    tier = pbShowCommands(nil, ["Tier 0 (assist)", "Tier 1 (first)", "Tier 2", "Tier 3", "Cancel"], 5)
    next false unless tier.between?(0, 3)
    ArmWrestle.close_debug_menu(sprites, viewport)
    ArmWrestle.debug_play(tier)
    next true
  }
})

MenuHandlers.add(:debug_menu, :dt_arm_reset, {
  "name"        => "Arm wrestle: reset",
  "parent"      => :desert_town_menu,
  "description" => "Wins, losses and the loss streak back to 0 (the next bout is tier 1).",
  "always_show" => true,
  "effect"      => proc {
    next false unless ArmWrestle.on_map?
    ArmWrestle.debug_reset
    pbMessage("Arm wrestling reset.")
    next false
  }
})

MenuHandlers.add(:debug_menu, :dt_arm_warp, {
  "name"        => "Arm wrestle: warp to Shirpaz",
  "parent"      => :desert_town_menu,
  "description" => "Warps to Map095 (14,9), facing cowboy Shirpaz.",
  "always_show" => true,
  "effect"      => proc { |sprites, viewport|
    next false unless ArmWrestle.on_map?
    ArmWrestle.close_debug_menu(sprites, viewport)
    ArmWrestle.debug_warp
    next true
  }
})
