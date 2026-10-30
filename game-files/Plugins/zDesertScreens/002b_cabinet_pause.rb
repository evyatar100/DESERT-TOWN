#===============================================================================
# DesertScreens - Cabinet-only pause-menu extras: New Game and Restart.
#
# New Game starts a nested Desert Town game (same as the arcade cabinet event).
# Restart reboots the Raspberry Pi hardware.
# Both appear only on the Pi (ARM Linux), after Options and before Quit Game.
#===============================================================================

MenuHandlers.add(:pause_menu, :dt_new_game, {
  "name"      => _INTL("New Game"),
  "order"     => 85,
  "condition" => proc { next DesertScreens.cabinet_platform? && $player != nil },
  "effect"    => proc { |menu|
    menu.pbHideMenu
    if DesertTownArcade.ask_new_game
      $game_temp.desert_town_restart_pending = true
      next true
    end
    menu.pbShowMenu
    next false
  }
})

MenuHandlers.add(:pause_menu, :dt_restart_rpi, {
  "name"      => _INTL("Restart"),
  "order"     => 95,
  "condition" => proc { next DesertScreens.cabinet_platform? },
  "effect"    => proc { |menu|
    menu.pbHideMenu
    if pbConfirmMessage(_INTL("MSG_PAUSE_RESTART_RPI_CONFIRM"))
      system("sudo reboot")
      next true
    end
    menu.pbShowMenu
    next false
  }
})
