#===============================================================================
# DesertTownArcade - "New deserttown Game" cabinet.
#
# Using the cabinet starts a new game inside the current one (Inception style).
# The depth counter is kept outside the per-game save values, so it survives
# Game.start_new and is written to the save file with everything else.
#===============================================================================

class DesertTownArcadeState
  attr_accessor :depth        # how many nested games deep the cabinet is
  attr_accessor :started_at   # Time the current depth was entered

  def initialize
    @depth      = 0
    @started_at = Time.now
  end

  # Pure helper so the increment rule can be tested without the engine.
  def self.next_depth(depth)
    return 1 if depth.nil?
    return depth.to_i + 1
  end
end

$desert_town_arcade = nil

# No ensure_class on purpose: a save written before this plugin existed has no
# :desert_town_arcade key and must still pass SaveData.valid?.
SaveData.register(:desert_town_arcade) do
  load_in_bootup
  save_value { DesertTownArcade.state }
  load_value { |value| $desert_town_arcade = value.is_a?(DesertTownArcadeState) ? value : DesertTownArcadeState.new }
  new_game_value { DesertTownArcadeState.new }
end

class Game_Temp
  attr_accessor :desert_town_restart_pending
end

module DesertTownArcade
  def self.state
    $desert_town_arcade = DesertTownArcadeState.new if !$desert_town_arcade.is_a?(DesertTownArcadeState)
    return $desert_town_arcade
  end

  def self.depth
    return state.depth
  end

  # Asks (in the player's language) whether to start a new game.
  # Returns true when the player confirmed.
  def self.ask_new_game
    pbMessage(_INTL("MSG_ARCADE_NEW_GAME_INTRO", depth.to_s))
    if pbConfirmMessage(_INTL("MSG_ARCADE_NEW_GAME_CONFIRM"))
      return true
    end
    pbMessage(_INTL("MSG_ARCADE_NEW_GAME_CANCEL"))
    return false
  end

  # Performs the restart. Must run from Scene_Map#update, outside the event
  # interpreter, so that Game.start_new can replace the scene cleanly.
  def self.restart!
    $game_temp.desert_town_restart_pending = false if $game_temp
    pbCaveEntranceEx(false)
    st = state
    st.depth = DesertTownArcadeState.next_depth(st.depth)
    st.started_at = Time.now
    echoln "[DesertTownArcade] New deserttown game, depth #{st.depth}" if defined?(echoln)
    pbBGMStop if defined?(pbBGMStop)
    Game.start_new
    # $game_system survives start_new; make sure the new run is not locked out.
    if $game_system
      $game_system.save_disabled = false
      $game_system.menu_disabled = false
    end
    DesertTownAutosave.save_now(:arcade_new_game)
  end
end

# Event Script command for the cabinet.
def pbDesertTownArcadeNewGame
  return false if !$player
  if DesertTownArcade.ask_new_game
    $game_temp.desert_town_restart_pending = true
    return true
  end
  return false
end

class Scene_Map
  alias desert_town_arcade_restart_update update
  def update
    if $game_temp && $game_temp.desert_town_restart_pending &&
       !$game_temp.message_window_showing && !pbMapInterpreterRunning? &&
       !$game_temp.player_transferring && !$game_temp.in_battle
      DesertTownArcade.restart!
      return
    end
    desert_town_arcade_restart_update
  end
end
