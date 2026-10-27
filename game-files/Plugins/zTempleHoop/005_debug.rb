#===============================================================================
# Temple hoop - F9 debug entry (Debug > Desert Town... > Temple hoop):
# warp to the shooting line (6,13), or let Toga come again this run.
#===============================================================================

module TempleHoop
  TEMPLE_MAP = 113

  def self.debug_warp
    $game_temp.player_new_map_id    = TEMPLE_MAP
    $game_temp.player_new_x         = STAND[0]
    $game_temp.player_new_y         = STAND[1]
    $game_temp.player_new_direction = 4
    $scene.transfer_player
    $game_map.refresh
  end
end

MenuHandlers.add(:debug_menu, :dt_temple_hoop, {
  "name"        => "Temple hoop",
  "parent"      => :desert_town_menu,
  "description" => "Warp to the hoop on Map113, or reset Toga's visit for this run.",
  "always_show" => true,
  "effect"      => proc { |sprites, viewport|
    if !$PokemonGlobal || !$scene.is_a?(Scene_Map)
      pbMessage("Load a game on the map first.")
      next false
    end
    choice = pbShowCommands(nil, ["Warp to the hoop", "Reset Toga", "Cancel"], 3)
    if choice == 1
      TempleHoopRules.reset_toga!(TempleHoop.state)
      pbMessage("Toga will come after the next finished round.")
    end
    next false unless choice == 0
    pbFadeOutAndHide(sprites)
    pbDisposeMessageWindow(sprites["textbox"])
    pbDisposeSpriteHash(sprites)
    viewport.dispose
    TempleHoop.debug_warp
    next true   # Closes the debug menu, like the stock warp
  }
})
