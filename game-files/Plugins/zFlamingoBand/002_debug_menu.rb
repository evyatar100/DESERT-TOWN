#===============================================================================
# Debug > Desert Town > Flamingo Band... (debug builds only, like the stock menu).
#===============================================================================

module FlamingoBand
  DOOR_MAP_ID = FlamingoBandRules::OUTSIDE_MAP
  DOOR_X      = 16
  DOOR_Y      = 26

  def self.debug_state_text
    st = state
    roll_in = st[:next_roll_at] && $stats ? (st[:next_roll_at] - $stats.play_time).to_i : nil
    return sprintf("Intro done: %s\nStage: %d\nConsumed: %s\nProcession: %s\nEscape attempts: %d\n" \
                   "Next roll in: %s s\nInterrupt pending: %s",
                   st[:intro_done].to_s, st[:stage], st[:consumed].join(", "), st[:procession].to_s,
                   st[:escape_attempts].to_i, roll_in.nil? ? "-" : roll_in.to_s, interrupt_pending?.to_s)
  end
end

MenuHandlers.add(:debug_menu, :flamingo_band_menu, {
  "name"        => "Flamingo Band...",
  "parent"      => :desert_town_menu,
  "description" => "Flamingo Band quest: state, reset, stage 4, interruption, tent door.",
  "always_show" => true
})

MenuHandlers.add(:debug_menu, :flamingo_band_state, {
  "name"        => "Show state",
  "parent"      => :flamingo_band_menu,
  "description" => "Show the saved Flamingo Band quest state.",
  "always_show" => true,
  "effect"      => proc {
    if !$PokemonGlobal
      pbMessage("No game loaded yet.")
      next false
    end
    pbMessage(FlamingoBand.debug_state_text)
    next false
  }
})

MenuHandlers.add(:debug_menu, :flamingo_band_reset, {
  "name"        => "Reset quest",
  "parent"      => :flamingo_band_menu,
  "description" => "Forget the quest and remove the band followers.",
  "always_show" => true,
  "effect"      => proc {
    if !$PokemonGlobal
      pbMessage("No game loaded yet.")
      next false
    end
    FlamingoBand.reset
    pbMessage("Flamingo Band quest reset. Standing NPCs come back when the map reloads.")
    next false
  }
})

MenuHandlers.add(:debug_menu, :flamingo_band_stage4, {
  "name"        => "Jump to stage 4",
  "parent"      => :flamingo_band_menu,
  "description" => "Mark the intro done and set stage 4. Leave the tent to start the procession.",
  "always_show" => true,
  "effect"      => proc {
    if !$PokemonGlobal
      pbMessage("No game loaded yet.")
      next false
    end
    FlamingoBand.jump_to_final_stage
    pbMessage("Stage 4 set. Walk out of the tent (map 99 to 77) to start the procession.")
    next false
  }
})

MenuHandlers.add(:debug_menu, :flamingo_band_interrupt, {
  "name"        => "Force interruption now",
  "parent"      => :flamingo_band_menu,
  "description" => "Queue the visitor scene without the 25% roll. It starts once the map is free.",
  "always_show" => true,
  "effect"      => proc {
    if !$PokemonGlobal
      pbMessage("No game loaded yet.")
      next false
    end
    FlamingoBand.force_interrupt
    pbMessage("Interruption queued. Close the debug menu.")
    next false
  }
})

MenuHandlers.add(:debug_menu, :flamingo_band_door, {
  "name"        => "Teleport to the tent door",
  "parent"      => :flamingo_band_menu,
  "description" => "Warp to map 77 just below the Flamingods tent door.",
  "always_show" => true,
  "effect"      => proc { |sprites, viewport|
    if !$PokemonGlobal || !$scene.is_a?(Scene_Map)
      pbMessage("Load a game on the map first.")
      next false
    end
    pbFadeOutAndHide(sprites)
    pbDisposeMessageWindow(sprites["textbox"])
    pbDisposeSpriteHash(sprites)
    viewport.dispose
    $game_temp.player_new_map_id    = FlamingoBand::DOOR_MAP_ID
    $game_temp.player_new_x         = FlamingoBand::DOOR_X
    $game_temp.player_new_y         = FlamingoBand::DOOR_Y
    $game_temp.player_new_direction = 2
    $scene.transfer_player
    $game_map.refresh
    next true   # Closes the debug menu, like the stock warp
  }
})

MenuHandlers.add(:debug_menu, :flamingo_band_escape, {
  "name"        => "Simulate escape attempt",
  "parent"      => :flamingo_band_menu,
  "description" => "Inside the tent (map 99): act as if the player stepped on the exit.",
  "always_show" => true,
  "effect"      => proc {
    if !$PokemonGlobal || !$game_map || $game_map.map_id != FlamingoBandRules::TENT_MAP
      pbMessage("Go inside the tent (map 99) first.")
      next false
    end
    exit_event = FlamingoBand.find_event($game_map, FlamingoBandRules::EXIT_EVENT)
    action = FlamingoBandRules.escape_action(FlamingoBand.state)
    if !exit_event || action == :none
      pbMessage("No escape rule applies now (#{action}).")
    elsif FlamingoBand.intercept_exit?(exit_event)
      pbMessage("Caught. Close the debug menu to see the scene.")
    else
      pbMessage("Released: the quest is reset. Use the real exit to leave.")
    end
    next false
  }
})

MenuHandlers.add(:debug_menu, :flamingo_band_finish, {
  "name"        => "End quest now (as interruption)",
  "parent"      => :flamingo_band_menu,
  "description" => "Skip the visitor scene: remove the band, reset the quest, restore map music.",
  "always_show" => true,
  "effect"      => proc {
    if !$PokemonGlobal
      pbMessage("No game loaded yet.")
      next false
    end
    FlamingoBand.finish_quest
    pbMessage("Quest ended and reset. Standing flamingos return when their map reloads; the tent door starts it over.")
    next false
  }
})
