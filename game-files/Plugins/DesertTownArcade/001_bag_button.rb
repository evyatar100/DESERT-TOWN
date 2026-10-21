#===============================================================================
# DesertTownArcade - shared arcade cabinet mode.
#
# The stock menu button opens the pause menu as usual. Keyboard B (or the
# arcade button bound to the same raw key) opens the Bag directly. Extra
# arcade options also live under Debug > Desert Town (see 002_debug_menu.rb).
#===============================================================================

module DesertTownArcade
  # Raw keyboard key that opens the Bag (Input.triggerex? symbol).
  BAG_KEY = :B

  # Decision helper, kept free of engine objects so it can be unit tested.
  # Returns true when a Bag-button press should be accepted.
  def self.bag_button_allowed?(interpreter_running, message_showing, player_moving, menu_disabled, forced_movement)
    return false if interpreter_running
    return false if message_showing
    return false if player_moving
    return false if menu_disabled
    return false if forced_movement
    return true
  end

  def self.bag_key_pressed?
    return false unless defined?(Input) && Input.respond_to?(:triggerex?)
    return Input.triggerex?(BAG_KEY)
  end

  # Opens the Bag the same way the stock :bag pause-menu handler does.
  def self.open_bag
    return if !$player || !$bag
    pbPlayDecisionSE if defined?(pbPlayDecisionSE)
    item = nil
    pbFadeOutIn do
      scene = PokemonBag_Scene.new
      screen = PokemonBagScreen.new(scene, $bag)
      item = screen.pbStartScreen
    end
    return if !item
    $game_temp.in_menu = false
    pbUseKeyItemInField(item)
  end

  # Opens the stock pause menu with every option. Also reachable from Debug.
  def self.open_full_pause_menu
    sscene = PokemonPauseMenu_Scene.new
    sscreen = PokemonPauseMenu.new(sscene)
    sscreen.pbStartPokemonMenu
  end
end

#===============================================================================
# Scene_Map hooks
#===============================================================================
class Scene_Map
  alias desert_town_arcade_update update
  def update
    if $game_temp && !$game_temp.message_window_showing && !$game_temp.menu_calling &&
       !$game_temp.in_menu && $game_player && $game_system && $PokemonGlobal
      if DesertTownArcade.bag_key_pressed? &&
         DesertTownArcade.bag_button_allowed?(pbMapInterpreterRunning?,
                                              $game_temp.message_window_showing,
                                              $game_player.moving?,
                                              $game_system.menu_disabled,
                                              $PokemonGlobal.forced_movement?)
        $game_temp.in_menu = true
        $game_player.straighten
        $game_map.update
        DesertTownArcade.open_bag
        $game_temp.in_menu = false
      end
    end
    desert_town_arcade_update
  end
end
