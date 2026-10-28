#===============================================================================
# Shira's wedding - the wandering Shira (D3) and Eviatar's summon (D6). One :on_frame_update
# handler: a float add and a few flag checks per frame; the row scan runs once per roll.
# The clock and the crossing are session-only (module state), never saved.
#===============================================================================

module ShiraWedding
  module Wander
    R = ShiraWeddingRules
    BALLOON_FRAMES = 60

    @sched = R.new_sched
    @rng = Random.new
    @picks = 0

    class << self
      attr_reader :cross, :sched, :picks
      attr_accessor :rng
    end

    def self.reset_session!
      @sched = R.new_sched
      @last = nil
      @picks = 0
      reset!
    end

    # Her Game_Event on the Playa, cached per events hash.
    def self.event
      return nil unless ShiraWedding.on_playa?
      evs = $game_map.events
      return @ev if @ev && @ev_of.equal?(evs) && evs[@ev.id].equal?(@ev)
      @ev_of = evs
      @ev = evs.values.find { |e| e.name == SHIRA_EVENT }
    end

    def self.visible?
      ev = event
      !!(ev && ev.character_name.to_s != "")
    end

    def self.crossing? = !@cross.nil?
    def self.busy_song? = !!(defined?(Bags::Song) && Bags::Song.active?)

    # A crossing may start only on a plain Scene_Map frame with nothing else going on. Not built on
    # DesertTownAutosave.safe?: that also needs the player standing still, so no crossing would start mid-walk.
    def self.free?
      return false unless $scene.is_a?(Scene_Map) && $game_temp && $game_player && $game_map
      t = $game_temp
      return false if t.message_window_showing || t.in_menu || t.player_transferring || t.in_battle
      return false if t.in_mini_update || t.transition_processing
      return false if pbMapInterpreterRunning? || $game_player.move_route_forcing
      !busy_song?
    end

    # A running crossing waits while a message shows, she is talked to, or in a menu/transfer/song.
    def self.paused?
      t = $game_temp
      return true if @held || !t
      !!(t.message_window_showing || t.in_menu || t.player_transferring || busy_song?)
    end

    def self.hold
      @held = true
      yield
    ensure
      @held = false
    end

    def self.update
      now = System.uptime
      dt = @last ? now - @last : 0.0
      @last = now
      return step(dt.clamp(0.0, R::DT_CAP)) if @cross
      return if @summoned || @held
      park_stray
      ctx = { on_playa: ShiraWedding.on_playa?, free: free?, crossing: false }
      start_crossing if R.tick(@sched, dt, ctx, @rng) == :cross
    end

    # A save made mid-crossing restores her visible with no controller: park her.
    def self.park_stray
      ev = event
      return unless ev
      park(ev) if ev.character_name.to_s != "" || [ev.x, ev.y] != R::PARK
    end

    #--- the crossing -----------------------------------------------------------------
    def self.view
      { x0: ($game_map.display_x / Game_Map::REAL_RES_X).floor, y0: ($game_map.display_y / Game_Map::REAL_RES_Y).floor,
        w: $game_map.width, h: $game_map.height, px: $game_player.x, py: $game_player.y }
    end

    def self.overhead?(x, y)
      (0..2).any? do |z|
        id = $game_map.data[x, y, z]
        id && id > 0 && $game_map.priorities[id].to_i > 0
      end
    end

    def self.tile_ok?(x, y, ev)
      return false if x == $game_player.x && y == $game_player.y
      return false unless $game_map.passable?(x, y, 4) && $game_map.passable?(x, y, 6)
      return false if overhead?(x, y)
      $game_map.events.each_value { |e| return false if e.x == x && e.y == y && !e.equal?(ev) }
      true
    end

    def self.start_crossing
      ev = event
      return false unless ev
      @picks += 1
      plan = R.pick_row(view, @rng, ->(x, y) { tile_ok?(x, y, ev) })
      return false unless plan
      ev.moveto(*plan[:start])
      ev.character_name = CHARSET
      ev.through = false
      ev.move_speed = R::SPEED
      ev.walk_anime = true
      plan[:dir] == 6 ? ev.turn_right : ev.turn_left
      ev.opacity = plan[:fade_in] ? 0 : 255
      @cross = plan.merge(ev: ev, fade: plan[:fade_in] ? :in : nil, frames: 0, noticed: false, notice_t: 0.0, blocked_t: 0.0)
      true
    end

    def self.step(dt)
      c = @cross
      ev = c[:ev]
      return reset! unless event.equal?(ev)
      update_balloon(ev)
      return if paused?
      return if fading(c, ev)
      if c[:notice_t] > 0
        c[:notice_t] -= dt
        return
      end
      return if ev.moving?
      return finish_crossing(c, ev) if [ev.x, ev.y] == c[:stop]
      notice(c, ev) unless c[:noticed]
      return if c[:notice_t] > 0
      if ev.passable?(ev.x, ev.y, c[:dir])
        c[:blocked_t] = 0.0
        c[:dir] == 6 ? ev.move_right : ev.move_left
      else
        c[:blocked_t] += dt
        start_fade(c, :out) if c[:blocked_t] >= R::BLOCK_GIVEUP
      end
    end

    # True while a fade runs; the fade-out ends in the park.
    def self.fading(c, ev)
      return false unless c[:fade]
      c[:frames] += 1
      a = [c[:frames] * 256 / R::FADE_FRAMES, 255].min
      ev.opacity = c[:fade] == :in ? a : 255 - a
      return true if c[:frames] < R::FADE_FRAMES
      return park(ev) || true if c[:fade] == :out
      c[:fade] = nil
      ev.opacity = 255
      false
    end

    def self.start_fade(c, dir)
      c[:fade] = dir
      c[:frames] = 0
    end

    def self.finish_crossing(c, ev)
      c[:fade_out] ? start_fade(c, :out) : park(ev)
    end

    # Within 1 tile: '!' and a 1.5 s stop before :done; a heart and no stop in :done.
    def self.notice(c, ev)
      return unless R.chebyshev([ev.x, ev.y], [$game_player.x, $game_player.y]) <= 1
      c[:noticed] = true
      if ShiraWedding.state[:stage] == :done
        show_heart(ev)
        return
      end
      c[:notice_t] = R::NOTICE_PAUSE
      ev.turn_toward_player
      ss = $scene.respond_to?(:spriteset) ? $scene.spriteset : nil
      ss.addUserAnimation(Settings::EXCLAMATION_ANIMATION_ID, ev.x, ev.y, false, 2) if ss
    end

    def self.show_heart(ev)
      vp = defined?(Spriteset_Map) && Spriteset_Map.respond_to?(:viewport) ? Spriteset_Map.viewport : nil
      return unless vp
      dispose_balloon
      @balloon = Sprite.new(vp)
      @balloon.bitmap = Art.heart_balloon
      @balloon.z = 1000
      @balloon_frames = BALLOON_FRAMES
      update_balloon(ev)
    end

    def self.update_balloon(ev)
      return unless @balloon
      @balloon_frames -= 1
      return dispose_balloon if @balloon_frames <= 0
      @balloon.x = ev.screen_x - 10
      @balloon.y = ev.screen_y - 70
    end

    def self.dispose_balloon
      return unless @balloon
      @balloon.bitmap.dispose if @balloon.bitmap && !@balloon.bitmap.disposed?
      @balloon.dispose unless @balloon.disposed?
      @balloon = nil
    end

    # Blank, back in the walled box, non-blocking.
    def self.park(ev)
      ev.character_name = ""
      ev.moveto(*R::PARK)
      ev.through = true
      ev.opacity = 255
      @cross = nil
      dispose_balloon
      nil
    end

    # Leaving the Playa (a transfer or a walk-across): park her first, since a connected map stays loaded.
    def self.leave!
      park(@ev) if @ev && (@ev.character_name.to_s != "" || [@ev.x, @ev.y] != R::PARK)
      reset!
    end

    def self.reset!
      @cross = nil
      @summoned = false
      @held = false
      @ev = nil
      dispose_balloon
      nil
    end

    #--- Eviatar's summon (runs inside his event; blocking) ----------------------------
    def self.summon_in
      ev = event
      return false unless ev
      waited = 0.0
      while @cross && waited < R::SUMMON_WAIT
        pbWait(0.1)
        waited += 0.1
      end
      park(ev) if @cross
      @summoned = true
      stop = R.summon_stop([$game_player.x, $game_player.y])
      ev.moveto(*R::SUMMON_ENTRY)
      ev.character_name = CHARSET
      ev.through = true
      ev.move_speed = R::SPEED
      ev.opacity = 255
      walk(ev, [PBMoveRoute::LEFT] * (R::SUMMON_ENTRY[0] - stop[0]))
      ev.turn_toward_player
      true
    end

    def self.walk_out
      ev = event
      if ev
        ev.through = true
        walk(ev, [PBMoveRoute::RIGHT] * [R::SUMMON_ENTRY[0] - ev.x, 0].max)
        park(ev)
      end
      @summoned = false
    end

    def self.walk(ev, cmds)
      return if cmds.empty?
      pbMoveRoute(ev, cmds)
      pbWait(0.05) while ev.move_route_forcing
    end
  end
end

EventHandlers.add(:on_frame_update, :shira_wedding_wander,
  proc { ShiraWedding::Wander.update }
)

EventHandlers.add(:on_leave_map, :shira_wedding_wander_reset,
  proc { |_new_map_id, _new_map| ShiraWedding::Wander.leave! }
)
