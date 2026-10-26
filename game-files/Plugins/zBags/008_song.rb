#===============================================================================
# Bags - "שקיות הפתעה" runs over normal play: the player walks, the duo follows,
# the overlay draws lyrics and stickers. One session-only run (Song.current),
# ticked by :on_frame_update. The music carries over map changes while it runs.
#===============================================================================

module Bags
  module Song
    AUDIO = BagsRules::SONG_BGM
    TIMING_FILE = "Data/sakiyot_haftaa_timing.json"

    # global: the $PokemonGlobal it started under; reason: nil, :done or :interrupted.
    Run = Struct.new(:global, :duo, :timing, :clock, :audio, :overlay, :reason, :ending)

    def self.current
      @current
    end

    # This game's run, playing or waiting for its end scene (a load, new game or F12 swaps $PokemonGlobal).
    def self.active?
      !!(@current && $PokemonGlobal && @current.global.equal?($PokemonGlobal))
    end

    # The song plays for this game: no end reason yet.
    def self.running?
      active? && @current.reason.nil?
    end

    # Map autoplay and autofade are held only while the song is what actually plays.
    def self.holds_map_music?
      running? && bgm_name == AUDIO
    end

    def self.load_timing
      unless File.exist?(TIMING_FILE)
        echoln("[Bags] #{TIMING_FILE} missing: no song")
        return nil
      end
      doc = SimpleJSONParser.parse(File.read(TIMING_FILE, encoding: "utf-8"))
      timing, err = BagsRules.parse_timing(doc)
      echoln("[Bags] #{TIMING_FILE} invalid (#{err}): no song") unless timing
      timing
    rescue StandardError => e
      echoln("[Bags] #{TIMING_FILE} unreadable (#{e.message}): no song")
      nil
    end

    # duo: true makes Esther and Shirpaz follow and leave at the end. Returns once the
    # music and overlay are up; the caller's event then ends and the player walks.
    # The run is published only after setup: the audio fade runs map frames (on_frame).
    def self.start(duo:)
      return false if active?
      stop
      if duo
        joining = true
        return false unless Duo.join
      end
      timing = load_timing
      run = Run.new($PokemonGlobal, duo, timing)
      if timing
        DesertTalk.clear_speaker if defined?(DesertTalk)
        start_audio(run)
        run.overlay = Overlay.new(timing)
      else
        run.reason = :done   # no song: the duo goes straight to the end scene
      end
      @current = run
      true
    rescue StandardError => e
      echoln("[Bags] song start error: #{e.class}: #{e.message}")
      if run
        run.reason = :done   # the end path brings the map music back and sends the duo off
        @current = run
      elsif joining
        cleanup_failed_join
      end
      false
    end

    # Duo.join raised after tour!: take back any added followers and mark them gone.
    def self.cleanup_failed_join
      Duo.gone!
    rescue StandardError => e
      echoln("[Bags] duo cleanup error: #{e.class}: #{e.message}")
    end

    def self.start_audio(run)
      run.audio = FileTest.audio_exist?("Audio/BGM/#{AUDIO}")
      if $game_system && $game_system.playing_bgm
        pbBGMFade(0.5)
        pbWait(0.5)
      end
      # Played even when the file is missing, so playing_bgm names the song (silent, frame clock).
      pbBGMPlay(AUDIO, 100, 100)
      echoln("[Bags] Audio/BGM/#{AUDIO}.ogg missing: silent, frame clock") unless run.audio
      run.clock = BagsRules.new_clock(run.audio)
    end

    # Disposes the overlay and forgets the run; music and followers are left alone.
    # Returns true if a song was running for this game.
    def self.stop
      run = @current
      @current = nil
      return false unless run
      run.overlay&.dispose
      run.global.equal?($PokemonGlobal)
    end

    # Debug: force the :done end path now.
    def self.end_now
      return false unless running?
      @current.reason ||= :done
      true
    end

    def self.bgm_name
      bgm = $game_system && $game_system.playing_bgm
      bgm ? bgm.name : nil
    end

    def self.overlay_visible?
      return false unless $scene.is_a?(Scene_Map) && $game_temp
      !($game_temp.message_window_showing || $game_temp.in_menu || $game_temp.in_battle)
    end

    def self.on_frame
      run = @current
      return unless run
      return drop_stale(run) unless run.global.equal?($PokemonGlobal)
      return if run.ending
      if !run.reason && run.clock
        tick(run)
        run.reason = BagsRules.song_end_reason(run.clock, run.timing[:duration], bgm_name)
        overlay = run.reason ? run.overlay : overlay_for(run)
        overlay&.update(run.clock[:t], !run.reason && overlay_visible?, character_xs(run))
      end
      finish(run) if run.reason
    end

    # The overlay, rebuilt after a scene change disposed it; a failed rebuild ends the song.
    def self.overlay_for(run)
      run.overlay ||= Overlay.new(run.timing)
    rescue StandardError => e
      echoln("[Bags] song overlay error: #{e.class}: #{e.message}")
      run.reason = :done
      nil
    end

    # Scene_Map is closing (arcade restart bridge, title): the overlay goes with it.
    def self.scene_left
      run = @current
      return unless run&.overlay
      overlay = run.overlay
      run.overlay = nil
      overlay.dispose
    rescue StandardError => e
      echoln("[Bags] overlay close error: #{e.class}: #{e.message}")
    end

    # Screen x of the player and the following duo, so the rain keeps out of their gutter.
    def self.character_xs(run)
      chars = [$game_player]
      chars += Duo.followers.map { |_, event, _| event } if run.duo
      chars.compact.map(&:screen_x)
    end

    # Load, new game or F12: stop silently. A new game keeps $game_temp, so its follower
    # list would still hold the duo of the old game; rebuild it from the new save data.
    def self.drop_stale(run)
      stop
      $game_temp.followers = Game_FollowerFactory.new if run.duo && $game_temp && $PokemonGlobal
    end

    # No clock yet (setup not finished): nothing to tick.
    def self.tick(run)
      return unless run.clock
      pos = run.audio ? (Audio.bgm_pos rescue nil) : nil
      fps = (Graphics.frame_rate rescue 60)
      echoln("[Bags] Audio.bgm_pos did not move: frame clock") if BagsRules.clock_tick(run.clock, pos, fps)
    end

    # Without the duo the end is just music; with it, the end scene waits for a safe frame.
    def self.finish(run)
      return end_music unless run.duo
      return unless Duo.scene_safe?
      run.ending = true
      Duo.run_scene("Bags::Song.end_scene")
    end

    # Overlay gone; the map's music comes back unless other music took over (never silence).
    def self.end_music
      stop
      return unless BagsRules.restore_map_music?(bgm_name)
      pbBGMStop
      $game_map.autoplay if $game_map
    end

    # Map interpreter script: overlay gone, map music back (unless something else took over), duo leaves.
    def self.end_scene
      run = @current
      return true unless run && run.global.equal?($PokemonGlobal)
      end_music
      Duo.leave_scene
      true
    end
  end
end

#-------------------------------------------------------------------------------
# Engine hooks. Bags loads after TempleStickers and SpacesheepCool, so these wrap
# theirs: while the song runs, maps 86, 96 and 109 keep it too.
#-------------------------------------------------------------------------------

EventHandlers.add(:on_frame_update, :bags_song,
  proc { Bags::Song.on_frame }
)

class Game_Map
  alias bags_song_autoplay autoplay unless method_defined?(:bags_song_autoplay)
  alias bags_song_autoplay_cue autoplayAsCue unless method_defined?(:bags_song_autoplay_cue)

  def autoplay
    bags_song_kept? || bags_song_autoplay
  end

  def autoplayAsCue
    bags_song_kept? || bags_song_autoplay_cue
  end

  private

  # While the song plays: only the map's BGS, the BGM stays the song.
  def bags_song_kept?
    return false unless Bags::Song.holds_map_music?
    pbBGSPlay(@map.bgs) if @map.autoplay_bgs
    true
  end
end

class Scene_Map
  alias bags_song_autofade autofade unless method_defined?(:bags_song_autofade)

  def autofade(mapid)
    if Bags::Song.holds_map_music?
      Graphics.frame_reset
      return
    end
    bags_song_autofade(mapid)
  end
end

# Leaving Scene_Map (title, arcade restart bridge): the overlay goes before the engine
# freezes the screen, so the lyric band is not in the transition frame. dispose is the backstop.
# Guarded so stub engines without #update/#dispose still load the plugin.
if Scene_Map.method_defined?(:update) && Scene_Map.method_defined?(:dispose)
  class Scene_Map
    alias bags_song_update update unless method_defined?(:bags_song_update)
    alias bags_song_dispose dispose unless method_defined?(:bags_song_dispose)

    def update
      bags_song_update
      Bags::Song.scene_left if $scene != self
    end

    def dispose
      Bags::Song.scene_left
      bags_song_dispose
    end
  end
end

# A load never resumes the song: stop it, send a touring duo away, then the map's music.
alias bags_song_autoplay_on_save pbAutoplayOnSave unless defined?(bags_song_autoplay_on_save)
def pbAutoplayOnSave
  Bags::Song.stop
  Bags::Duo.after_load
  bags_song_autoplay_on_save
end
