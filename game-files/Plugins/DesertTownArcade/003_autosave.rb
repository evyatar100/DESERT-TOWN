#===============================================================================
# DesertTownArcade - automatic saving.
#
# The cabinet runs all day and players come and go, so the game saves itself:
#   1. every INTERVAL seconds of play,
#   2. when the player walks from an indoor map to an outdoor map,
#   3. right after a "New deserttown Game" restart (see 004_arcade_new_game.rb).
#
# Triggers only *request* a save. The write happens on a later frame, once the
# map scene is idle, so a save never lands in the middle of a transfer, a
# message, a battle, or an event.
#===============================================================================

module DesertTownAutosave
  INTERVAL = 20 * 60   # seconds

  @last_save_uptime = nil
  @pending_reason   = nil
  @last_reason      = nil
  @saving           = false

  #-----------------------------------------------------------------------------
  # Pure decision helpers (no engine objects; covered by tests/plugin_rules_test.rb)
  #-----------------------------------------------------------------------------

  # True when the timer-based autosave should fire.
  def self.due?(now, last_save, interval = INTERVAL)
    return false if now.nil?
    return true if last_save.nil?
    return (now - last_save) >= interval
  end

  # True only for an indoor -> outdoor transition. nil counts as indoor.
  def self.inside_to_outside?(old_outdoor, new_outdoor)
    return false if old_outdoor
    return new_outdoor ? true : false
  end

  #-----------------------------------------------------------------------------
  # State
  #-----------------------------------------------------------------------------

  def self.clock_now
    return System.uptime if defined?(System) && System.respond_to?(:uptime)
    return Time.now.to_f
  end

  def self.last_reason
    return @last_reason
  end

  def self.pending_reason
    return @pending_reason
  end

  def self.seconds_since_last_save
    return nil if @last_save_uptime.nil?
    return clock_now - @last_save_uptime
  end

  def self.reset_timer
    @last_save_uptime = clock_now
    @pending_reason   = nil
  end

  def self.request(reason)
    @pending_reason ||= reason
  end

  def self.timer_due?
    return due?(clock_now, @last_save_uptime, INTERVAL)
  end

  # True when a save can be written without interrupting anything.
  def self.safe?
    return false if @saving
    return false unless defined?($scene) && $scene.is_a?(Scene_Map)
    return false unless $player && $game_temp && $game_system && $game_player && $game_map
    return false if $game_temp.in_battle
    return false if $game_temp.message_window_showing
    return false if $game_temp.in_menu
    return false if $game_temp.player_transferring
    return false if $game_temp.in_mini_update
    return false if $game_temp.transition_processing
    return false if pbMapInterpreterRunning?
    return false if $game_player.moving?
    return false if $game_player.move_route_forcing
    return false if $game_system.save_disabled
    return false if $game_temp.respond_to?(:desert_town_restart_pending) && $game_temp.desert_town_restart_pending
    return true
  end

  # Writes the save file now. Returns whether Game.save succeeded.
  def self.save_now(reason)
    return false if @saving
    return false if !$player || !$game_system
    @saving = true
    ok = false
    begin
      $game_temp.begun_new_game = false if $game_temp
      ok = Game.save
      if ok
        @last_reason = reason
        echoln "[DesertTownAutosave] Saved (#{reason})" if defined?(echoln)
      else
        echoln "[DesertTownAutosave] Save FAILED (#{reason})" if defined?(echoln)
      end
    rescue => e
      echoln "[DesertTownAutosave] Save raised #{e.class}: #{e.message}" if defined?(echoln)
      ok = false
    ensure
      @saving = false
      @pending_reason = nil
      @last_save_uptime = clock_now
    end
    return ok
  end

  # Called every frame from the map scene.
  def self.update
    request(:interval) if @pending_reason.nil? && @last_save_uptime && timer_due?
    return if @pending_reason.nil?
    return unless safe?
    save_now(@pending_reason)
  end
end

#===============================================================================
# Keep the timer in step with every save and with every (re)start.
#===============================================================================
module Game
  class << self
    alias desert_town_autosave_save save
    def save(*args, **kwargs)
      ret = desert_town_autosave_save(*args, **kwargs)
      DesertTownAutosave.reset_timer if ret
      return ret
    end

    alias desert_town_autosave_start_new start_new
    def start_new(*args)
      ret = desert_town_autosave_start_new(*args)
      DesertTownAutosave.reset_timer
      return ret
    end

    alias desert_town_autosave_load load
    def load(*args)
      ret = desert_town_autosave_load(*args)
      DesertTownAutosave.reset_timer
      return ret
    end
  end
end

#===============================================================================
# Triggers
#===============================================================================
EventHandlers.add(:on_frame_update, :desert_town_autosave_tick,
  proc { DesertTownAutosave.update }
)

# Fires after $game_map points at the new map (transfer or walking across a
# connection) but before the player is placed, so only a request is made here.
EventHandlers.add(:on_enter_map, :desert_town_autosave_went_outside,
  proc { |old_map_id|
    next if !$game_map || old_map_id.nil? || old_map_id == 0
    next if old_map_id == $game_map.map_id
    old_meta = GameData::MapMetadata.try_get(old_map_id)
    new_meta = $game_map.metadata
    old_outdoor = old_meta ? old_meta.outdoor_map : false
    new_outdoor = new_meta ? new_meta.outdoor_map : false
    if DesertTownAutosave.inside_to_outside?(old_outdoor, new_outdoor)
      DesertTownAutosave.request(:went_outside)
    end
  }
)
