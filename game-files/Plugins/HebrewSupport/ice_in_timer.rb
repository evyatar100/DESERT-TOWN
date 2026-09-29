#===============================================================================
# Ice Factory ("Ice In" - Map 088) Hypothermia Timer & Rescue System
#===============================================================================

module IceInTimer
  ICE_IN_MAP_ID   = 88
  ICE_CAMP_MAP_ID = 91
  TIME_LIMIT      = 7 * 60 # 7 minutes = 420 seconds
  RESCUE_X        = 41
  RESCUE_Y        = 35

  RESCUE_MESSAGE = "יותר מדי זמן במפעל הקרח, היפוטרמיה הביאה אותך למצב קריטי. צוות המפעל חילץ אותך החוצה"

  @active         = false
  @timer_start    = nil
  @duration       = TIME_LIMIT
  @rescuing       = false

  def self.start(duration = TIME_LIMIT)
    @active       = true
    @duration     = duration
    @timer_start  = (defined?($stats) && $stats&.play_time) ? $stats.play_time : (defined?(System.uptime) ? System.uptime : Time.now.to_i)
    @rescuing     = false

    # Link to global game system so built-in Sprite_Timer displays on-screen MM:SS HUD
    if defined?($game_system) && $game_system
      $game_system.timer_start    = @timer_start
      $game_system.timer_duration = @duration
    end
    echoln "[IceInTimer] Started 7-minute timer for Ice In (#{@duration}s)" if defined?(echoln)
  end

  def self.stop
    @active      = false
    @timer_start = nil
    @duration    = TIME_LIMIT
    if defined?($game_system) && $game_system
      $game_system.timer_start    = nil
      $game_system.timer_duration = 0
    end
    echoln "[IceInTimer] Stopped timer" if defined?(echoln)
  end

  def self.active?
    return @active && defined?($game_map) && $game_map && $game_map.map_id == ICE_IN_MAP_ID
  end

  def self.rescuing?
    return @rescuing
  end

  def self.timer_start
    @timer_start
  end

  def self.duration
    @duration || TIME_LIMIT
  end

  def self.time_elapsed
    return 0 unless @timer_start
    now = (defined?($stats) && $stats&.play_time) ? $stats.play_time : (defined?(System.uptime) ? System.uptime : Time.now.to_i)
    return [now - @timer_start, 0].max
  end

  def self.time_remaining
    rem = duration - time_elapsed
    return [rem, 0].max
  end

  def self.expired?
    return false unless active?
    return time_remaining <= 0
  end

  # For testing/debug: set remaining seconds
  def self.set_time_remaining(seconds)
    return unless @active
    now = (defined?($stats) && $stats&.play_time) ? $stats.play_time : (defined?(System.uptime) ? System.uptime : Time.now.to_i)
    @duration    = seconds
    @timer_start = now
    if defined?($game_system) && $game_system
      $game_system.timer_start    = @timer_start
      $game_system.timer_duration = @duration
    end
  end

  def self.trigger_rescue
    return if @rescuing
    @rescuing = true
    stop

    # 1. Blue effect and screen shake for some frames
    if defined?($game_screen) && $game_screen
      # Screen shake (power 6, speed 8, 40 frames)
      pbShake(6, 8, 40) if defined?(pbShake)
      # Blue flash
      pbFlash(Color.new(0, 120, 255, 180), 40) if defined?(pbFlash)
      # Blue tone tint
      pbToneChangeAll(Tone.new(-60, -30, 80, 0), 20) if defined?(pbToneChangeAll)
    end

    # Run effect frames with scene updates (~40 frames / 2 seconds)
    40.times do
      Graphics.update if defined?(Graphics)
      Input.update if defined?(Input)
      pbUpdateSceneMap if defined?(pbUpdateSceneMap)
    end

    # Reset screen tone smoothly
    if defined?(pbToneChangeAll)
      pbToneChangeAll(Tone.new(0, 0, 0, 0), 10)
      10.times do
        Graphics.update if defined?(Graphics)
        Input.update if defined?(Input)
        pbUpdateSceneMap if defined?(pbUpdateSceneMap)
      end
    end

    # 2. Move player to Ice Camp (Map 91) at (41, 35)
    pbTransferPlayer(ICE_CAMP_MAP_ID, RESCUE_X, RESCUE_Y, 2)

    # Wait until player transfer completes
    if defined?($game_temp) && $game_temp
      while $game_temp.player_transferring
        Graphics.update if defined?(Graphics)
        Input.update if defined?(Input)
        pbUpdateSceneMap if defined?(pbUpdateSceneMap)
      end
    end

    # 3. Show message
    if defined?(pbMessage)
      if defined?(_INTL)
        pbMessage(_INTL("MSG_ICE_IN_TIMEOUT"))
      else
        pbMessage(RESCUE_MESSAGE)
      end
    end

    @rescuing = false
  end
end

# Helper to transfer player to any map and coordinate
def pbTransferPlayer(map_id, x, y, direction = 2)
  if defined?($game_temp) && $game_temp
    $game_temp.player_transferring   = true
    $game_temp.player_new_map_id    = map_id
    $game_temp.player_new_x         = x
    $game_temp.player_new_y         = y
    $game_temp.player_new_direction = direction
    $scene.transfer_player if defined?($scene) && $scene && $scene.is_a?(Scene_Map)
  end
end

#===============================================================================
# Event Handlers: Map Enter, Map Leave, and Frame Update
#===============================================================================

EventHandlers.add(:on_enter_map, :ice_in_timer_on_enter,
  proc { |_old_map_id|
    next unless defined?($game_map) && $game_map
    if $game_map.map_id == IceInTimer::ICE_IN_MAP_ID
      IceInTimer.start unless IceInTimer.active?
    else
      IceInTimer.stop if IceInTimer.active?
    end
  }
)

EventHandlers.add(:on_leave_map, :ice_in_timer_on_leave,
  proc { |new_map_id, _new_map|
    if new_map_id != IceInTimer::ICE_IN_MAP_ID
      IceInTimer.stop if IceInTimer.active?
    end
  }
)

EventHandlers.add(:on_map_or_spriteset_change, :ice_in_timer_spriteset,
  proc { |_scene, _map_changed|
    next unless defined?($game_map) && $game_map
    if $game_map.map_id == IceInTimer::ICE_IN_MAP_ID
      IceInTimer.start unless IceInTimer.active?
    end
  }
)

EventHandlers.add(:on_frame_update, :ice_in_timer_frame_check,
  proc {
    next unless IceInTimer.active?
    next if $game_map.map_id != IceInTimer::ICE_IN_MAP_ID
    next if IceInTimer.rescuing?
    # Do not interrupt ongoing dialogue, scene animations, battle, or movement routing
    next if defined?($game_temp) && ($game_temp.message_window_showing || $game_temp.in_battle)
    next if defined?(pbMapInterpreterRunning?) && pbMapInterpreterRunning?
    next if defined?($game_player) && $game_player&.move_route_forcing

    if IceInTimer.expired?
      IceInTimer.trigger_rescue
    end
  }
)
