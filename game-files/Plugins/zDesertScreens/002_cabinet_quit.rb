#===============================================================================
# DesertScreens (TG57) - Quit Game is hidden on the Pi cabinet only.
# Pause menu: the handler is removed at load. Load screen: the row is dropped
# from the command list (it is always last, so no other index moves).
#===============================================================================

module DesertScreens
  def self.hide_pause_quit(handlers, ruby_platform = RUBY_PLATFORM)
    return false if !hide_quit?(ruby_platform)
    handlers.remove(:pause_menu, :quit_game)
    return true
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

DesertScreens.hide_pause_quit(MenuHandlers)

class PokemonLoad_Scene
  prepend DesertScreens::LoadSceneNoQuit
end
