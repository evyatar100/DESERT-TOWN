# Kusomo TV toilets on deep-playa 1b: a title line, then the video; BGM is paused and restored.
module KusomoTV
  def self.movie_path(id)
    base = KusomoTVRules.file_for(id)
    return nil if !base
    return FileTest.exist?(base + ".ogv") ? base + ".ogv" : nil
  end

  # Plays the video skippable with the action/cancel button. Returns true if it played.
  def self.play(id)
    path = movie_path(id)
    return false if !path
    bgm = $game_system.playing_bgm
    pos = (Audio.bgm_pos rescue 0)
    $game_system.bgm_stop
    ok = true
    begin
      Graphics.play_movie(path, 100, true)
    rescue StandardError, NotImplementedError => e
      echoln("KusomoTV: #{e.class}: #{e.message}")
      ok = false
    end
    $game_system.bgm_play_internal(bgm, pos) if bgm
    Input.update
    return ok
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
