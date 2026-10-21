#===============================================================================
# DesertTownArcade - Debug > Desert Town submenu.
#
# Shortcuts for arcade tools (full pause menu, autosave, new game depth).
# The stock menu button opens the pause menu again; this submenu remains for
# debug convenience.
#===============================================================================

MenuHandlers.add(:debug_menu, :desert_town_menu, {
  "name"        => "Desert Town...",
  "parent"      => :main,
  "description" => "Arcade mode: full pause menu, autosave, new game depth.",
  "always_show" => true
})

MenuHandlers.add(:debug_menu, :dt_full_pause_menu, {
  "name"        => "Full pause menu",
  "parent"      => :desert_town_menu,
  "description" => "Open the stock pause menu (Pokedex, Pokemon, Pokegear, Trainer Card, Save, Options, Quit).",
  "always_show" => true,
  "effect"      => proc {
    if !$player
      pbMessage("No player loaded yet.")
      next false
    end
    pbFadeOutIn do
      DesertTownArcade.open_full_pause_menu
    end
    next false
  }
})

MenuHandlers.add(:debug_menu, :dt_save_now, {
  "name"        => "Save now",
  "parent"      => :desert_town_menu,
  "description" => "Write the save file immediately (same path as the autosave).",
  "always_show" => true,
  "effect"      => proc {
    if !$player
      pbMessage("No player loaded yet.")
      next false
    end
    if DesertTownAutosave.save_now(:debug)
      pbMessage("\\se[]" + _INTL("The game was saved.") + "\\me[GUI save game]\\wtnp[20]")
    else
      pbMessage("\\se[]" + _INTL("Save failed.") + "\\wtnp[30]")
    end
    next false
  }
})

MenuHandlers.add(:debug_menu, :dt_new_arcade_game, {
  "name"        => "New deserttown game",
  "parent"      => :desert_town_menu,
  "description" => "Run the arcade cabinet flow: ask in Hebrew, then restart one depth deeper.",
  "always_show" => true,
  "effect"      => proc {
    if !$player
      pbMessage("No player loaded yet.")
      next false
    end
    pbDesertTownArcadeNewGame
    if $game_temp.desert_town_restart_pending
      pbMessage("Restart queued. Close the debug menu to start the new game.")
    end
    next false
  }
})

MenuHandlers.add(:debug_menu, :dt_set_depth, {
  "name"        => "Set game depth",
  "parent"      => :desert_town_menu,
  "description" => "Edit the Inception depth counter saved with the game.",
  "always_show" => true,
  "effect"      => proc {
    state = DesertTownArcade.state
    params = ChooseNumberParams.new
    params.setRange(0, 9999)
    params.setDefaultValue(state.depth)
    state.depth = pbMessageChooseNumber("\\ts[]" + "Set the game depth.", params)
    next false
  }
})

MenuHandlers.add(:debug_menu, :dt_autosave_info, {
  "name"        => "Autosave info",
  "parent"      => :desert_town_menu,
  "description" => "Show depth, seconds since the last save, and the last save reason.",
  "always_show" => true,
  "effect"      => proc {
    state = DesertTownArcade.state
    since = DesertTownAutosave.seconds_since_last_save
    since_text = since ? since.to_i.to_s : "never"
    reason = DesertTownAutosave.last_reason || "none"
    pbMessage(sprintf("Depth: %d\nSeconds since last save: %s\nLast save reason: %s\nAutosave interval: %d s",
                      state.depth, since_text, reason, DesertTownAutosave::INTERVAL))
    next false
  }
})
