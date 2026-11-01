#===============================================================================
# Party map lights + zone BGM. Map 93 defaults to Calm Camps Area. Stair events
# call PartyLights.enter_zone / .exit_zone so Alien Party and the RGB cycle only run
# inside the main dance floor (switch 105). Same three tones as Spacesheep cool.
#===============================================================================

module PartyLights
  MAP_ID = 93
  SWITCH = 105
  COOL_BGM = "Alien Party"
  CALM_BGM = "Calm Camps Area"
  COLORS = [
    Tone.new(100, -30, -30, 0),
    Tone.new(-30, -30, 100, 0),
    Tone.new(-30, 100, -30, 0)
  ].freeze
  NEUTRAL = Tone.new(0, 0, 0, 0)
  STEP = 1.0

  module_function

  def here?
    defined?($game_map) && $game_map && $game_map.map_id == MAP_ID
  end

  def active?
    defined?($game_switches) && $game_switches && $game_switches[SWITCH]
  end

  def playing?(name)
    return false unless defined?($game_system) && $game_system
    b = $game_system.playing_bgm
    b && b.name == name
  end

  # Stair enter tiles (idempotent). Starts cool BGM; lights follow on the next frame.
  def enter_zone
    return unless defined?($game_switches) && $game_switches
    $game_switches[SWITCH] = true
    pbBGMPlay(COOL_BGM) unless playing?(COOL_BGM)
  end

  # Stair exit tiles (idempotent). Restores calm BGM and drops the party tint.
  def exit_zone
    return unless defined?($game_switches) && $game_switches
    $game_switches[SWITCH] = false
    clear_lights
    pbBGMPlay(CALM_BGM) unless playing?(CALM_BGM)
  end

  def clear_lights
    was_lit = @lit
    @lit = false
    @index = nil
    return unless was_lit
    return unless defined?($game_screen) && $game_screen
    $game_screen.start_tone_change(NEUTRAL, 1)
  end

  def update_lights
    return unless defined?($game_map) && $game_map && defined?($game_screen) && $game_screen
    return unless defined?($stats) && $stats
    want = here? && active? && !($game_temp && $game_temp.in_battle)
    if want
      i = ($stats.play_time / STEP).to_i % COLORS.length
      if i != @index
        @index = i
        $game_screen.start_tone_change(COLORS[i], 20)
      end
      @lit = true
    elsif @lit
      clear_lights
    end
  end

  # Leaving the map: drop tint and the zone switch so a later visit starts calm.
  def leave_map
    if defined?($game_switches) && $game_switches
      $game_switches[SWITCH] = false
    end
    clear_lights if @lit
  end
end

EventHandlers.add(:on_frame_update, :party_lights,
  proc { PartyLights.update_lights }
)

# Fires before $game_map changes. Drop the party tint when leaving the floor.
EventHandlers.add(:on_leave_map, :party_lights_off,
  proc { |new_map_id, _new_map|
    PartyLights.leave_map if new_map_id != PartyLights::MAP_ID
  }
)
