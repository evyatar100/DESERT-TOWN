#===============================================================================
# DesertScreens (TG67) - the load screen shows one command (Continue, or New Game
# when there is no save). The pause menu itself is 007_pause_menu.rb.
#===============================================================================

module DesertScreens
  # The stock list starts with Continue (save) or New Game (no save); keep only that row, in place.
  def self.primary_load_command(commands)
    commands.slice!(1..-1) if commands.length > 1
    return commands
  end

  # Index handed to pbMessage as the highlighted row: No.
  CONFIRM_DEFAULT_NO = 1

  # Yes/No with No highlighted. True when the player picks Yes.
  def self.confirm?(message)
    choice = pbMessage(message, [_INTL("Yes"), _INTL("No")], 2, nil, CONFIRM_DEFAULT_NO)
    return choice == 0
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

class PokemonLoad_Scene
  prepend DesertScreens::LoadSceneOneCommand
end
