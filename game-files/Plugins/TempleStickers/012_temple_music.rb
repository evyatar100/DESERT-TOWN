#===============================================================================
# TempleStickers - temple music. Leaving Map113 onto Map096 keeps Time-Warp
# playing on Map096; leaving Map096 for any other map ends it. Map096 entered
# from anywhere else plays its own music as before. Flag lives in $PokemonGlobal.
#===============================================================================

module TempleStickers
  module Music
    TRACK = "Time-Warp"

    # Whether Time-Warp owns new_map_id after the player moves old -> new.
    def self.carry_after(carry, old_map_id, new_map_id)
      return false unless new_map_id == TOWN_MAP
      old_map_id == TEMPLE_MAP || (carry == true && old_map_id == TOWN_MAP)
    end

    # True when map_id must skip its own BGM and keep Time-Warp.
    def self.owns?(carry, map_id)
      carry == true && map_id == TOWN_MAP
    end

    def self.carry?
      !!($PokemonGlobal && $PokemonGlobal.temple_music_carry)
    end

    def self.carry=(value)
      $PokemonGlobal.temple_music_carry = value if $PokemonGlobal
    end

    def self.playing?
      playing = $game_system && $game_system.playing_bgm
      !!(playing && playing.name == TRACK)
    end

    # Keeps the running track; a load (pbAutoplayOnSave) always replays it.
    def self.play
      pbBGMPlay(TRACK) if @replay || !playing?
    end

    # A loaded save restores playing_bgm while the title music is what sounds.
    def self.replaying
      @replay = true
      yield
    ensure
      @replay = false
    end
  end
end

class PokemonGlobalMetadata
  attr_accessor :temple_music_carry
end

# Fires before $game_map changes, on a transfer and on a map-connection walk.
EventHandlers.add(:on_leave_map, :temple_music,
  proc { |new_map_id, _new_map|
    next if !$PokemonGlobal || !$game_map
    m = TempleStickers::Music
    m.carry = m.carry_after(m.carry?, $game_map.map_id, new_map_id)
  }
)

class Game_Map
  alias temple_music_autoplay autoplay unless method_defined?(:temple_music_autoplay)
  alias temple_music_autoplay_cue autoplayAsCue unless method_defined?(:temple_music_autoplay_cue)

  def autoplay
    temple_music_carried? || temple_music_autoplay
  end

  def autoplayAsCue
    temple_music_carried? || temple_music_autoplay_cue
  end

  private

  # Plays the carried Time-Warp (plus the map's BGS); false when the map plays its own.
  def temple_music_carried?
    return false unless TempleStickers::Music.owns?(TempleStickers::Music.carry?, @map_id)
    TempleStickers::Music.play
    pbBGSPlay(@map.bgs) if @map.autoplay_bgs
    true
  end
end

alias temple_music_autoplay_on_save pbAutoplayOnSave unless defined?(temple_music_autoplay_on_save)
def pbAutoplayOnSave
  TempleStickers::Music.replaying { temple_music_autoplay_on_save }
end

class Scene_Map
  alias temple_music_autofade autofade unless method_defined?(:temple_music_autofade)

  # Runs before on_leave_map, so it predicts the carry instead of reading it.
  def autofade(mapid)
    m = TempleStickers::Music
    if $game_map && m.playing? && m.owns?(m.carry_after(m.carry?, $game_map.map_id, mapid), mapid)
      Graphics.frame_reset
      return
    end
    temple_music_autofade(mapid)
  end
end
