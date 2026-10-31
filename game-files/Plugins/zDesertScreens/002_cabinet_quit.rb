#===============================================================================
# DesertScreens (TG57) - the load screen drops Quit Game on the Pi cabinet.
# The pause menu keeps Quit Game on the laptop and on the Pi (10.0.0.10).
# Load screen: the row is dropped from the command list (it is always last,
# so no other index moves).
#===============================================================================

module DesertScreens
  # Kept so older callers do not strip Quit from the pause menu.
  def self.hide_pause_quit(_handlers, _ruby_platform = RUBY_PLATFORM)
    return false
  end

  def self.strip_quit(commands)
    commands.pop if commands.last == _INTL("Quit Game")
    return commands
  end

  module LoadSceneNoQuit
    def pbStartScene(commands, *args)
      DesertScreens.strip_quit(commands) if DesertScreens.hide_quit?
      super
    end
  end
end

class PokemonLoad_Scene
  prepend DesertScreens::LoadSceneNoQuit
end
