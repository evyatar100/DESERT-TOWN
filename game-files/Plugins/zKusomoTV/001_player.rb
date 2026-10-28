# Kusomo TV toilets on deep-playa 1b: a title line, then the video; BGM is paused and restored.
module KusomoTV
  def self.movie_path(id)
    base = KusomoTVRules.file_for(id)
    return nil if !base
    return FileTest.exist?(base + ".ogv") ? base + ".ogv" : nil
  end

  # Plays the video (skippable), then the poster for 10 s. Returns true if the video played.
  # movie:/poster: false are for the F9 isolation entries only.
  def self.play(id, movie: true, poster: true)
    trace("play #{id} movie=#{movie} poster=#{poster}")
    path = movie_path(id)
    trace("play: path=#{path.inspect}")
    return false if !path
    bgm = $game_system.playing_bgm
    pos = (Audio.bgm_pos rescue 0)
    $game_system.bgm_stop
    ok = true
    begin
      if movie
        trace("play: before play_movie")
        Graphics.play_movie(path, 100, true)
        trace("play: after play_movie")
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
