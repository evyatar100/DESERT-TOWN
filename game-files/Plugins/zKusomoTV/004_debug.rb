# Kusomo TV - F9 isolation entries (Debug > Desert Town...): the poster alone, or a video with no poster.
# The job is queued and starts on the map once the debug menu is closed (the menu would cover it).
module KusomoTV
  @debug_job = nil

  def self.debug_pick_video
    ids = KusomoTVRules::VIDEOS.keys
    pick = pbShowCommands(nil, ids.map(&:to_s) + ["Cancel"], ids.length + 1)
    return (pick >= 0 && pick < ids.length) ? ids[pick] : nil
  end

  def self.debug_queue(job)
    @debug_job = job
    trace("f9: queued #{job.inspect}")
    pbMessage("Close the debug menu (Back); it starts on the map.")
  end

  def self.debug_job_ready?
    return false if !@debug_job || !$scene.is_a?(Scene_Map) || !$game_temp
    return false if $game_temp.in_mini_update || $game_temp.message_window_showing
    return !pbMapInterpreterRunning?
  end

  def self.debug_run_job
    return if !debug_job_ready?
    job = @debug_job
    @debug_job = nil
    trace("f9: start #{job.inspect}")
    if job[0] == :poster
      show_poster
    else
      play(job[1], poster: false)
    end
    trace("f9: done #{job.inspect}")
  end
end

EventHandlers.add(:on_frame_update, :kusomo_tv_debug_job, proc { KusomoTV.debug_run_job })

MenuHandlers.add(:debug_menu, :dt_kusomo_poster_only, {
  "name"        => "Kusomo TV: poster only",
  "parent"      => :desert_town_menu,
  "description" => "After you close the menu: the 10 s poster with no video (writes kusomo_trace.log).",
  "always_show" => true,
  "effect"      => proc {
    KusomoTV.debug_queue([:poster])
    next false
  }
})

MenuHandlers.add(:debug_menu, :dt_kusomo_movie_only, {
  "name"        => "Kusomo TV: movie only",
  "parent"      => :desert_town_menu,
  "description" => "After you close the menu: a picked video with no poster (writes kusomo_trace.log).",
  "always_show" => true,
  "effect"      => proc {
    id = KusomoTV.debug_pick_video
    KusomoTV.debug_queue([:movie, id]) if id
    next false
  }
})
