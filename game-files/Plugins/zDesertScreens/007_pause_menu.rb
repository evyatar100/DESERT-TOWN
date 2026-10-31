#===============================================================================
# DesertScreens - one pause menu for the laptop and the Pi (PI_HOST).
#
#   Close menu, player name, Bag, Save, Game in a Game, Quit, Restart Pi,
#   Start Over.
# Restart Pi reboots the cabinet. On a laptop it only says it cannot.
# Quit closes the game. On the Pi that returns to the Pi.
# Start Over deletes the save and the depth counter, after a confirm.
#===============================================================================

module DesertScreens
  PAUSE_ORDER = {
    dt_close: 10,
    trainer_card: 20,
    bag: 30,
    save: 40,
    dt_new_game: 50,
    quit_game: 60,
    dt_restart_rpi: 70,
    dt_wipe_game: 80
  }.freeze

  HIDDEN_PAUSE_IDS = [:pokedex, :party, :pokegear, :town_map, :options, :debug, :new_game].freeze

  def self.clear_depth!(state)
    state.depth = 0
    state.started_at = Time.now
    return state
  end

  # Deletes the save file when one exists. Depth is cleared by the caller.
  def self.erase_save_file
    return false unless defined?(SaveData) && SaveData.respond_to?(:exists?) && SaveData.exists?
    SaveData.delete_file
    return true
  end

  def self.reboot_pi
    system("sudo reboot")
  end

  def self.pause_close(menu)
    pbPlayCloseMenuSE if defined?(pbPlayCloseMenuSE)
    menu.pbEndScene
    return true
  end

  def self.pause_nested(menu)
    menu.pbHideMenu
    if DesertTownArcade.ask_new_game
      $game_temp.desert_town_restart_pending = true
      return true
    end
    menu.pbRefresh
    menu.pbShowMenu
    return false
  end

  def self.pause_quit(menu)
    menu.pbHideMenu
    if confirm?(_INTL("Are you sure you want to quit the game?"))
      menu.pbEndScene
      $scene = nil
      return true
    end
    menu.pbRefresh
    menu.pbShowMenu
    return false
  end

  # cabinet nil means this machine. A laptop never reboots.
  def self.pause_restart(menu, cabinet = nil)
    cabinet = cabinet_platform? if cabinet.nil?
    menu.pbHideMenu
    unless cabinet
      pbMessage(_INTL("MSG_PAUSE_RESTART_PI_LAPTOP"))
      menu.pbRefresh
      menu.pbShowMenu
      return false
    end
    if confirm?(_INTL("MSG_PAUSE_RESTART_RPI_CONFIRM")) && reboot_pi
      menu.pbEndScene
      return true
    end
    menu.pbRefresh
    menu.pbShowMenu
    return false
  end

  def self.pause_wipe(menu)
    menu.pbHideMenu
    unless confirm?(_INTL("MSG_PAUSE_WIPE_CONFIRM"))
      menu.pbRefresh
      menu.pbShowMenu
      return false
    end
    clear_depth!(DesertTownArcade.state)
    erase_save_file
    menu.pbEndScene
    pbCaveEntranceEx(false) if defined?(pbCaveEntranceEx)
    pbBGMStop if defined?(pbBGMStop)
    $scene = Scene_DesertNewGame.new
    return true
  end

  def self.pause_commands
    order = PAUSE_ORDER
    return [
      [:dt_close, {
        "name"   => _INTL("MSG_PAUSE_CLOSE"),
        "order"  => order[:dt_close],
        "effect" => proc { |menu| next DesertScreens.pause_close(menu) }
      }],
      [:dt_new_game, {
        "name"   => _INTL("Game in a Game"),
        "order"  => order[:dt_new_game],
        "effect" => proc { |menu| next DesertScreens.pause_nested(menu) }
      }],
      [:quit_game, {
        "name"   => _INTL("Quit Game"),
        "order"  => order[:quit_game],
        "effect" => proc { |menu| next DesertScreens.pause_quit(menu) }
      }],
      [:dt_restart_rpi, {
        "name"   => _INTL("MSG_PAUSE_RESTART_PI"),
        "order"  => order[:dt_restart_rpi],
        "effect" => proc { |menu| next DesertScreens.pause_restart(menu) }
      }],
      [:dt_wipe_game, {
        "name"   => _INTL("Start Over"),
        "order"  => order[:dt_wipe_game],
        "effect" => proc { |menu| next DesertScreens.pause_wipe(menu) }
      }]
    ]
  end

  def self.install_pause_menu(handlers)
    HIDDEN_PAUSE_IDS.each { |id| handlers.remove(:pause_menu, id) }
    pause_commands.each { |id, hash| handlers.add(:pause_menu, id, hash) }
    return unless handlers.respond_to?(:each)
    handlers.each(:pause_menu) do |id, hash|
      next unless hash.is_a?(Hash) && PAUSE_ORDER[id]
      hash["order"] = PAUSE_ORDER[id]
    end
  end
end

DesertScreens.install_pause_menu(MenuHandlers)
