#===============================================================================
# Spacesheep cool mode (switch 104).
# Music and lights for maps 86/87 only — driven by Game_Map#autoplay, not events.
# Neighbor camps never run this logic because autoplay is only called for the
# map the player actually arrives on.
#===============================================================================

module SpacesheepCool
  MAPS   = [86, 87].freeze
  SWITCH = 104
  COLORS = [
    Tone.new(100, -30, -30, 0),
    Tone.new(-30, -30, 100, 0),
    Tone.new(-30, 100, -30, 0)
  ].freeze
  STEP = 1.0   # seconds per color

  module_function

  def here?
    MAPS.include?($game_map.map_id)
  end

  def cool?
    $game_switches[SWITCH]
  end

  def track
    cool? ? "Alien Party" : "Aliens"
  end

  # Play the right track only if it is not already playing.
  def refresh
    return unless defined?($game_system) && $game_system
    b = $game_system.playing_bgm
    pbBGMPlay(track) if !b || b.name != track
  end

  def update_lights
    return unless defined?($game_map) && $game_map && defined?($game_screen) && $game_screen
    want = here? && cool? && !($game_temp && $game_temp.in_battle)
    if want
      i = ($stats.play_time / STEP).to_i % COLORS.length
      if i != @index
        @index = i
        $game_screen.start_tone_change(COLORS[i], 20)   # 1 s blend
      end
      @lit = true
    elsif @lit
      @lit = false
      @index = nil
      $game_screen.start_tone_change(Tone.new(0, 0, 0, 0), 0)
    end
  end
end

class Game_Map
  alias spacesheep_autoplay autoplay
  alias spacesheep_autoplay_cue autoplayAsCue

  def autoplay
    if SpacesheepCool::MAPS.include?(@map_id)
      SpacesheepCool.refresh
    else
      spacesheep_autoplay
    end
  end

  def autoplayAsCue
    if SpacesheepCool::MAPS.include?(@map_id)
      SpacesheepCool.refresh
    else
      spacesheep_autoplay_cue
    end
  end
end

EventHandlers.add(:on_frame_update, :spacesheep_lights,
  proc { SpacesheepCool.update_lights }
)
