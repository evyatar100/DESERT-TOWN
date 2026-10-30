#===============================================================================
# DesertScreens (TG67) - the load screen shows one command (Continue, or New Game
# when there is no save); New Game moves into the pause menu behind a confirm.
#===============================================================================

module DesertScreens
  # Pause-menu slot: after Save (60), before Options (70).
  PAUSE_NEW_GAME_ORDER = 65

  # The stock list starts with Continue (save) or New Game (no save); keep only that row, in place.
  def self.primary_load_command(commands)
    commands.slice!(1..-1) if commands.length > 1
    return commands
  end

  # Index handed to pbMessage as the highlighted row: No.
  CONFIRM_DEFAULT_NO = 1

  def self.confirm_new_game?
    choice = pbMessage(_INTL("Start a new game? Progress since your last save will be lost."),
                       [_INTL("Yes"), _INTL("No")], 2, nil, CONFIRM_DEFAULT_NO)
    return choice == 0
  end

  # Pause-menu effect. Returns true when the menu must close (a new game is starting).
  def self.pause_new_game(menu)
    menu.pbHideMenu
    if confirm_new_game?
      menu.pbEndScene
      pbCaveEntranceEx(false) if defined?(pbCaveEntranceEx)
      pbBGMStop if defined?(pbBGMStop)
      $scene = Scene_DesertNewGame.new
      return true
    end
    menu.pbRefresh
    menu.pbShowMenu
    return false
  end

  module LoadSceneOneCommand
    def pbStartScene(commands, *args)
      DesertScreens.primary_load_command(commands)
      super
    end
  end
end

# Runs after the old Scene_Map has disposed (Game.start_new assigns a new Scene_Map).
# Values already loaded are reset first; the save file on disk is not touched.
class Scene_DesertNewGame
  def main
    SaveData.mark_values_as_unloaded
    Game.start_new
    if $game_system
      $game_system.save_disabled = false
      $game_system.menu_disabled = false
    end
  end
end

MenuHandlers.add(:pause_menu, :new_game, {
  "name"      => _INTL("New Game"),
  "order"     => DesertScreens::PAUSE_NEW_GAME_ORDER,
  "effect"    => proc { |menu| next DesertScreens.pause_new_game(menu) }
})

class PokemonLoad_Scene
  prepend DesertScreens::LoadSceneOneCommand
end
