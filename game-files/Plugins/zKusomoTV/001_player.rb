# Kusomo TV toilets on deep-playa 1b: a title line, then the video; BGM is paused and restored.
module KusomoTV
  # The .ogv paths of a video, in play order; nil if the id is unknown or any part is missing.
  def self.movie_paths(id)
    paths = KusomoTVRules.parts_for(id).map { |base| base + ".ogv" }
    return nil if paths.empty? || !paths.all? { |p| FileTest.exist?(p) }
    return paths
  end

  # mkxp-z ends a skippable movie on a fresh Use/Back press and leaves that trigger set.
  def self.movie_skipped?
    return Input.trigger?(Input::USE) || Input.trigger?(Input::BACK)
  end

  # Plays the video (skippable), then the poster for 10 s. Returns true if the video played.
  # A split video plays its parts back to back; skipping one skips the rest.
  # movie:/poster: false are for the F9 isolation entries only.
  def self.play(id, movie: true, poster: true)
    trace("play #{id} movie=#{movie} poster=#{poster}")
    paths = movie_paths(id)
    trace("play: paths=#{paths.inspect}")
    return false if !paths
    bgm = $game_system.playing_bgm
    pos = (Audio.bgm_pos rescue 0)
    $game_system.bgm_stop
    ok = true
    begin
      if movie
        paths.each do |path|
          trace("play: before play_movie #{path}")
          Graphics.play_movie(path, 100, true)
          skipped = movie_skipped?
          trace("play: after play_movie #{path} skipped=#{skipped}")
          break if skipped
        end
      end
    rescue StandardError, NotImplementedError => e
      trace("play: play_movie raised #{e.class}: #{e.message}")
      echoln("KusomoTV: #{e.class}: #{e.message}")
      ok = false
    end
    begin
      KusomoTV.show_poster if ok && poster
    rescue StandardError => e
      # A poster fault must not end the game (a non-debug run has no error log); it is traced instead.
      trace("poster: #{e.class}: #{e.message.to_s[0, 300]} @ #{(e.backtrace || [])[0, 4].join(' | ')}")
      echoln("KusomoTV poster: #{e.class}: #{e.message}")
    end
    trace("play: restoring bgm=#{(bgm.name rescue bgm).inspect}")
    $game_system.bgm_play_internal(bgm, pos) if bgm
    Input.update
    trace("play: done ok=#{ok}")
    return ok
  rescue Exception => e
    trace("play: #{e.class} escaped: #{e.message.to_s[0, 300]} @ #{(e.backtrace || [])[0, 4].join(' | ')}")
    raise
  end
end

# Event helper: pbKusomoTV(:mohel)
def pbKusomoTV(id)
  pbMessage(_INTL("KUSOMO_TV_TITLE"))
  pbMessage(_INTL("KUSOMO_TV_MISSING")) if !KusomoTV.play(id)
end

# Event helper for every other toilet door.
def pbKusomoToiletBusy
  pbMessage(_INTL("KUSOMO_TOILET_BUSY"))
end
