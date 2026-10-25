#===============================================================================
# Party map lights. Map 93 cycles the same three screen tones as Spacesheep
# cool mode (red, blue, green, one second each). The map's own BGM keeps
# playing; this plugin does not start or stop music.
#===============================================================================

module PartyLights
  MAP_ID = 93
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

  def clear_lights
    @lit = false
    @index = nil
    return unless defined?($game_screen) && $game_screen
    $game_screen.start_tone_change(NEUTRAL, 1)
  end

  def update_lights
    return unless defined?($game_map) && $game_map && defined?($game_screen) && $game_screen
    return unless defined?($stats) && $stats
    want = here? && !($game_temp && $game_temp.in_battle)
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
end

EventHandlers.add(:on_frame_update, :party_lights,
  proc { PartyLights.update_lights }
)

# Fires before $game_map changes. Drop the party tint when leaving the floor.
EventHandlers.add(:on_leave_map, :party_lights_off,
  proc { |new_map_id, _new_map|
    PartyLights.clear_lights if new_map_id != PartyLights::MAP_ID && PartyLights.instance_variable_get(:@lit)
  }
)
