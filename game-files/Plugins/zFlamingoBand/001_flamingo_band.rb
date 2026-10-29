#===============================================================================
# Flamingo Band quest (maps 77 / 99). Decisions live in FlamingoBandRules.
# Music: one pre-mixed BGM per stage, switched at the same playback position.
#===============================================================================

class PokemonGlobalMetadata
  attr_writer :flamingo_band

  def flamingo_band
    @flamingo_band = FlamingoBandRules.normalize(@flamingo_band)
    return @flamingo_band
  end
end

module FlamingoBand
  VISITOR_EVENT_ID = 9999
  FOLLOWER_ID_BASE = 9000
  WALK_STEP_CAP    = 60
  STEP_FRAME_CAP   = 120
  EXIT_STEP_CAP    = 40
  FOLLOWER_PREFIX  = "flamingo_band_"

  # Stands in for a map event so the stock follower system can copy its fields.
  BandProxy = Struct.new(:id, :name, :x, :y, :direction, :character_name, :character_hue)

  @busy              = false
  @interrupt_pending = false
  @next_idle_at      = nil
  @missed_step       = {}
  @fidget_turns      = {}
  @visitor_sprite    = nil
  @intro_suppressed  = false

  def self.state
    return FlamingoBandRules.new_state if !$PokemonGlobal
    return $PokemonGlobal.flamingo_band
  end

  def self.procession?
    return !!($PokemonGlobal && state[:procession])
  end

  def self.busy?
    return @busy
  end

  # Debug: forget the quest and drop the band followers.
  def self.reset
    if $game_temp && $PokemonGlobal
      FlamingoBandRules::FLAMINGOS.each do |id|
        $game_temp.followers.remove_follower_by_name(follower_name(id))
      end
    end
    $PokemonGlobal.flamingo_band = FlamingoBandRules.new_state if $PokemonGlobal
    @busy              = false
    @interrupt_pending = false
    @next_idle_at      = nil
    @missed_step       = {}
    @fidget_turns      = {}
    @intro_suppressed  = false
  end

  # Debug: skip the four talks; music follows on maps 77/99.
  def self.jump_to_final_stage
    st = state
    st[:intro_done] = true
    st[:stage]      = FlamingoBandRules::FINAL_STAGE
    apply_map_music($game_map.map_id) if $game_map
  end

  # Debug: queue the visitor scene now; it still waits until scene_safe?.
  def self.force_interrupt
    @interrupt_pending = true
  end

  def self.interrupt_pending?
    return @interrupt_pending
  end

  def self.follower_name(id)
    return "#{FOLLOWER_PREFIX}#{id}"
  end

  def self.event_name(id)
    return "dt_#{id}"
  end

  #-----------------------------------------------------------------------------
  # Safety and scene plumbing
  #-----------------------------------------------------------------------------

  def self.scene_safe?
    return false if @busy
    return false if !$scene.is_a?(Scene_Map) || !$game_map || !$game_player || !$game_temp
    return false if $game_temp.message_window_showing || $game_temp.in_battle
    return false if $game_temp.player_transferring || $game_temp.in_menu
    return false if pbMapInterpreterRunning?
    return false if $game_player.move_route_forcing
    return true
  end

  # Run a scene through the map interpreter so the player is locked while it plays.
  def self.run_scene(script)
    list = [RPG::EventCommand.new(355, 0, [script]), RPG::EventCommand.new(0, 0, [])]
    pbMapInterpreter.setup(list, 0)
  end

  def self.update_frame
    Graphics.update
    Input.update
    pbUpdateSceneMap
  end

  def self.manhattan(a, b)
    return (a.x - b.x).abs + (a.y - b.y).abs
  end

  def self.find_event(map, name)
    map.events.each_value { |event| return event if event.name == name }
    return nil
  end

  def self.tile_free?(map, x, y)
    return false if !map.valid?(x, y)
    return false if $game_player.x == x && $game_player.y == y
    return false if ![2, 4, 6, 8].any? { |d| map.passable?(x, y, d) }
    map.events.each_value do |event|
      return false if event.at_coordinate?(x, y) && !event.through && event.character_name != ""
    end
    $game_temp.followers.each_follower do |event, _data|
      return false if event && event.map == map && event.at_coordinate?(x, y)
    end
    return true
  end

  def self.free_adjacent_tile(map)
    [[0, 1], [0, -1], [1, 0], [-1, 0]].each do |dx, dy|
      x = $game_player.x + dx
      y = $game_player.y + dy
      return [x, y] if tile_free?(map, x, y)
    end
    return nil
  end

  # One forced step; a forced route keeps the event updating even off-screen.
  def self.force_step(event, code, through)
    old_through = event.through
    event.through = true if through
    route = RPG::MoveRoute.new
    route.repeat    = false
    route.skippable = true
    route.list.clear
    route.list.push(RPG::MoveCommand.new(code))
    route.list.push(RPG::MoveCommand.new(0))
    event.force_move_route(route)
    frames = 0
    map = $game_map
    while event.move_route_forcing || event.moving? || event.jumping?
      update_frame
      frames += 1
      break if frames > STEP_FRAME_CAP || $game_map != map
    end
    event.through = old_through
  end

  # Walk an event up to the player, going through obstacles for a blocked step.
  def self.walk_to_player(event)
    map = $game_map
    steps = 0
    loop do
      break if $game_map != map || map.events[event.id] != event
      break if manhattan(event, $game_player) <= 1
      if steps >= WALK_STEP_CAP
        spot = free_adjacent_tile(map)
        event.moveto(spot[0], spot[1]) if spot
        break
      end
      steps += 1
      old = [event.x, event.y]
      force_step(event, PBMoveRoute::TOWARD_PLAYER, false)
      force_step(event, PBMoveRoute::TOWARD_PLAYER, true) if [event.x, event.y] == old
    end
  end

  def self.face_each_other(event)
    pbTurnTowardEvent(event, $game_player)
    pbTurnTowardEvent($game_player, event)
  end

  #-----------------------------------------------------------------------------
  # Music
  #-----------------------------------------------------------------------------

  # Start a stage track; switching between band tracks keeps the playback position.
  def self.play_track(name)
    return if !$game_system
    playing = $game_system.playing_bgm
    return if playing && playing.name == name
    pos = 0
    pos = (Audio.bgm_pos rescue 0) if playing && FlamingoBandRules.band_track?(playing.name)
    $game_system.bgm_play_internal(RPG::AudioFile.new(name, 100, 100), pos)
  end

  def self.play_stage(stage)
    play_track(FlamingoBandRules.stage_track(stage))
  end

  # True when the band owns this map's music (the caller then skips the map's own BGM).
  # Taking over from a non-band track fades it out instead of cutting it.
  def self.apply_map_music(map_id)
    return false if !$PokemonGlobal || !$game_system
    want = FlamingoBandRules.music_for(state, map_id)
    return false if want == :original
    playing = $game_system.playing_bgm
    if want == :silence
      pbBGMFade(0.8) if playing
    elsif playing && !FlamingoBandRules.band_track?(playing.name)
      pbCueBGM(want, 0.8, 100, 100)
    else
      play_track(want)
    end
    return true
  end

  def self.keeps_music_on?(map_id)
    return false if !$PokemonGlobal || !$game_system
    want = FlamingoBandRules.music_for(state, map_id)
    playing = $game_system.playing_bgm
    return want.is_a?(String) && playing && playing.name == want
  end

  #-----------------------------------------------------------------------------
  # Phase A: intro
  #-----------------------------------------------------------------------------

  def self.check_intro
    return if !$PokemonGlobal
    in_zone = FlamingoBandRules.in_intro_zone?($game_map.map_id, $game_player.x, $game_player.y)
    # After a release or a finish in the zone, wait until the player has left it once.
    start, @intro_suppressed = FlamingoBandRules.intro_gate(state, @intro_suppressed, in_zone)
    return if !start || !scene_safe?
    run_scene("FlamingoBand.intro_scene")
  end

  def self.intro_scene
    return true if @busy
    @busy = true
    begin
      st = state
      st[:intro_done] = true
      st[:stage] = 0
      host = find_event($game_map, event_name(FlamingoBandRules::HOST))
      if host
        walk_to_player(host)
        face_each_other(host)
      end
      pbDesertSpeaker(FlamingoBandRules::HOST)
      pbMessage(_INTL("MSG_FLAMINGO_BAND_INTRO"))
      pbBGMStop
    ensure
      @busy = false
    end
    return true
  end

  #-----------------------------------------------------------------------------
  # Addendum A: leaving the tent early
  #-----------------------------------------------------------------------------

  # Called from Game_Event#start. True means the exit is swallowed (caught).
  def self.intercept_exit?(event)
    return false if !$PokemonGlobal || !$game_map
    return false if event.map_id != FlamingoBandRules::TENT_MAP || event.name != FlamingoBandRules::EXIT_EVENT
    st = state
    case FlamingoBandRules.escape_action(st)
    when :release
      $PokemonGlobal.flamingo_band = FlamingoBandRules.new_state
      @intro_suppressed = true
      return false
    when :catch
      return true if @busy || pbMapInterpreterRunning?
      st[:escape_attempts] = 1
      run_scene("FlamingoBand.escape_scene")
      return true
    end
    return false
  end

  # Nearest band member on this map who has not played yet: [char_id, event or nil].
  def self.escape_speaker(map)
    consumed = state[:consumed]
    best = nil
    FlamingoBandRules::FLAMINGOS.each do |id|
      next if consumed.include?(id)
      event = find_event(map, event_name(id))
      next if !event || event.character_name == ""
      best = [id, event] if !best || manhattan(event, $game_player) < manhattan(best[1], $game_player)
    end
    return best || [FlamingoBandRules::HOST, nil]
  end

  def self.screen_fade(tone, seconds = 0.4)
    $game_screen.start_tone_change(tone, (seconds * 20).round)
    start = System.uptime
    update_frame while System.uptime - start < seconds
  end

  def self.escape_scene
    return true if @busy
    @busy = true
    begin
      map = $game_map
      char_id, helper = escape_speaker(map)
      if helper
        walk_to_player(helper)
        face_each_other(helper) if $game_map == map
      end
      pbDesertSpeaker(char_id)
      pbMessage(_INTL("MSG_FLAMINGO_BAND_WAIT"))
      if $game_map == map && map.map_id == FlamingoBandRules::TENT_MAP
        old_tone = $game_screen.tone.clone
        screen_fade(Tone.new(-255, -255, -255, 0))
        px, py = FlamingoBandRules::BACK_TENT_PLAYER
        $game_player.moveto(px, py)
        $game_player.turn_right
        if helper
          helper.moveto(*FlamingoBandRules::BACK_TENT_HELPER)
          helper.turn_left
        end
        update_frame
        screen_fade(old_tone)
      end
    ensure
      @busy = false
    end
    return true
  end

  #-----------------------------------------------------------------------------
  # Phase B: talking to the band
  #-----------------------------------------------------------------------------

  def self.claim_talk(char_id)
    return nil if !$PokemonGlobal || !$game_map
    return FlamingoBandRules.claim(state, char_id, $game_map.map_id)
  end

  #-----------------------------------------------------------------------------
  # Procession
  #-----------------------------------------------------------------------------

  def self.hide_band_events(map)
    names = FlamingoBandRules::FLAMINGOS.map { |id| event_name(id) }
    map.events.each_value { |event| event.erase if names.include?(event.name) }
  end

  def self.add_band_followers
    FlamingoBandRules::FLAMINGOS.each_with_index do |id, i|
      name = follower_name(id)
      next if $PokemonGlobal.followers.any? { |data| data.name == name }
      proxy = BandProxy.new(FOLLOWER_ID_BASE + i, event_name(id), $game_player.x, $game_player.y,
                            $game_player.direction, event_name(id), 0)
      $game_temp.followers.add_follower(proxy, name)
      data = $PokemonGlobal.followers.last
      data.invisible_after_transfer = true if data && data.name == name
    end
  end

  def self.start_procession
    st = state
    return if st[:procession]
    st[:procession]   = true
    st[:next_roll_at] = $stats.play_time + FlamingoBandRules::ROLL_INTERVAL
    st[:procession_started_at] = $stats.play_time
    add_band_followers
    hide_band_events($game_map)
    play_stage(FlamingoBandRules::FINAL_STAGE)
  end

  def self.on_enter_map(old_map_id)
    return if !$PokemonGlobal || !$game_map
    start_procession if FlamingoBandRules.start_procession?(state, old_map_id, $game_map.map_id)
  end

  def self.band_follower?(follower)
    return false if follower.id < FOLLOWER_ID_BASE
    return follower.id < FOLLOWER_ID_BASE + FlamingoBandRules::FLAMINGOS.length
  end

  # Decide (and remember) whether this follower skips its step this time.
  def self.skip_step?(follower, leader)
    return false if !procession? || leader.map != follower.map
    d = leader.direction
    tx = leader.x - ((d == 6) ? 1 : (d == 4) ? -1 : 0)
    ty = leader.y - ((d == 2) ? 1 : (d == 8) ? -1 : 0)
    dx = tx - follower.x
    dy = ty - follower.y
    straight = FlamingoBandRules.straight_step?(dx, dy, d)
    skip = FlamingoBandRules.skip_step?(@missed_step[follower.id], dx.abs + dy.abs, rand, straight)
    @missed_step[follower.id] = skip
    return skip
  end

  # Undo idle turns before the band follows again, so targets use the real facing.
  def self.restore_fidget_turns
    return if @fidget_turns.empty?
    $game_temp.followers.each_follower do |event, data|
      next if !event || !@fidget_turns.key?(event.id)
      event.direction = @fidget_turns[event.id]
      data.direction  = event.direction
    end
    @fidget_turns.clear
  end

  # While the player stands still, one band member turns or hops every 1-2 s.
  def self.idle_fidget
    return if $game_temp.in_menu || $game_temp.in_battle || $game_temp.message_window_showing
    return if $game_temp.player_transferring || pbMapInterpreterRunning?
    now = System.uptime
    @next_idle_at = now + 1.0 + rand if !@next_idle_at
    return if now < @next_idle_at
    @next_idle_at = now + 1.0 + rand
    return if $game_player.moving? || $game_player.jumping?
    members = []
    $game_temp.followers.each_follower do |event, data|
      next if !event || !band_follower?(event) || !data.visible?
      next if event.moving? || event.jumping?
      members << event
    end
    return if members.empty?
    member = members.sample
    if rand(2) == 0
      @fidget_turns[member.id] = member.direction if !@fidget_turns.key?(member.id)
      member.turn_random
    else
      member.jump(0, 0)
    end
  end

  #-----------------------------------------------------------------------------
  # Interruption: מסטולית walks up, complains, and leaves
  #-----------------------------------------------------------------------------

  def self.check_interrupt
    st = state
    st[:procession_started_at] ||= $stats.play_time   # old saves count from now
    next_at, hit = FlamingoBandRules.roll($stats.play_time, st[:next_roll_at], -> { rand },
                                          st[:procession_started_at])
    st[:next_roll_at] = next_at
    @interrupt_pending = true if hit
  end

  def self.run_pending_interrupt
    return if !@interrupt_pending || !scene_safe?
    @interrupt_pending = false
    run_scene("FlamingoBand.interrupt_scene")
  end

  def self.find_spawn_tile(map)
    FlamingoBandRules.spawn_offsets.shuffle.each do |dx, dy|
      x = $game_player.x + dx
      y = $game_player.y + dy
      return [x, y] if tile_free?(map, x, y)
    end
    return nil
  end

  def self.spawn_visitor(map, x, y)
    rpg = RPG::Event.new(x, y)
    rpg.id   = VISITOR_EVENT_ID
    rpg.name = "flamingo_band_visitor"
    rpg.pages[0].graphic.character_name = event_name(FlamingoBandRules::VISITOR)
    rpg.pages[0].graphic.direction = 2
    event = Game_Event.new(map.map_id, rpg, map)
    map.events[VISITOR_EVENT_ID] = event
    spriteset = $scene.spriteset(map.map_id) rescue nil
    @visitor_sprite = Sprite_Character.new(Spriteset_Map.viewport, event)
    spriteset.addUserSprite(@visitor_sprite) if spriteset
    return event
  end

  def self.remove_visitor(map, event)
    map.events.delete(VISITOR_EVENT_ID) if map.events[VISITOR_EVENT_ID].equal?(event)
    sprite = @visitor_sprite
    @visitor_sprite = nil
    return if !sprite
    spriteset = $scene.spriteset(map.map_id) rescue nil
    spriteset.usersprites.delete(sprite) if spriteset && spriteset.respond_to?(:usersprites)
    sprite.dispose if !sprite.disposed?
  end

  def self.exit_code(dir)
    return { 2 => PBMoveRoute::DOWN, 4 => PBMoveRoute::LEFT,
             6 => PBMoveRoute::RIGHT, 8 => PBMoveRoute::UP }[dir]
  end

  # Walk away from the player until fully off screen; the step cap means it never hangs.
  def self.walk_off_screen(event, map)
    EXIT_STEP_CAP.times do
      break if $game_map != map || map.events[event.id] != event
      break if FlamingoBandRules.off_screen?(event.screen_x, event.screen_y)
      dirs = FlamingoBandRules.exit_directions(event.x, event.y, $game_player.x, $game_player.y)
      moved = dirs.any? do |dir|
        old = [event.x, event.y]
        force_step(event, exit_code(dir), false)
        [event.x, event.y] != old
      end
      force_step(event, exit_code(dirs[0]), true) if !moved && $game_map == map
    end
  end

  def self.interrupt_scene
    return true if @busy
    @busy = true
    map = $game_map
    event = nil
    begin
      spot = find_spawn_tile(map)
      if spot
        event = spawn_visitor(map, spot[0], spot[1])
        pbBGMFade(0.4)
        walk_to_player(event)
        face_each_other(event) if $game_map == map
        pbDesertSpeaker(FlamingoBandRules::VISITOR)
        pbSEPlay("tom_baum_finish")
        pbMessage(_INTL("MSG_FLAMINGO_BAND_HAFARTEM"))
        3.times do
          break if $game_map != map
          force_step(event, PBMoveRoute::AWAY_FROM_PLAYER, true)
        end
        walk_off_screen(event, map)
      end
    ensure
      remove_visitor(map, event) if event
      @busy = false
    end
    finish_quest if event
    return true
  end

  # Addendum B: the interruption ends the quest and resets it; the tent door starts it over.
  def self.finish_quest
    return if !$PokemonGlobal
    if $game_temp
      FlamingoBandRules::FLAMINGOS.each do |id|
        $game_temp.followers.remove_follower_by_name(follower_name(id))
      end
    end
    $PokemonGlobal.flamingo_band = FlamingoBandRules.new_state
    @intro_suppressed  = true
    @interrupt_pending = false
    @fidget_turns      = {}
    @missed_step       = {}
    $game_map.autoplay if $game_map
  end

  #-----------------------------------------------------------------------------

  def self.on_frame_update
    return if !$PokemonGlobal || !$game_map || !$game_player || !$game_temp || !$stats
    return if @busy
    if FlamingoBandRules.rolling?(state)
      check_interrupt
      idle_fidget
    else
      check_intro
    end
    run_pending_interrupt
  end
end

#===============================================================================
# Hooks
#===============================================================================

# Phase B: the first four band members talked to (any order) each add a layer.
alias flamingo_band_pbDesertTalk pbDesertTalk unless defined?(flamingo_band_pbDesertTalk)
def pbDesertTalk(character_id, line_key = nil)
  stage = FlamingoBand.claim_talk(character_id)
  return flamingo_band_pbDesertTalk(character_id, line_key) if !stage
  flamingo_band_pbDesertTalk(character_id, FlamingoBandRules.stage_line(stage))
  FlamingoBand.play_stage(stage)
end

class Game_Map
  alias flamingo_band_autoplay autoplay unless method_defined?(:flamingo_band_autoplay)
  alias flamingo_band_autoplay_cue autoplayAsCue unless method_defined?(:flamingo_band_autoplay_cue)
  alias flamingo_band_setup setup unless method_defined?(:flamingo_band_setup)

  def autoplay
    if FlamingoBand.apply_map_music(@map_id)
      pbBGSPlay(@map.bgs) if @map.autoplay_bgs
      return
    end
    flamingo_band_autoplay
  end

  def autoplayAsCue
    if FlamingoBand.apply_map_music(@map_id)
      pbBGSPlay(@map.bgs) if @map.autoplay_bgs
      return
    end
    flamingo_band_autoplay_cue
  end

  # Keep the band's standing events hidden on every reload while they march.
  def setup(map_id)
    flamingo_band_setup(map_id)
    if FlamingoBand.procession? && FlamingoBandRules::MAPS.include?(map_id)
      FlamingoBand.hide_band_events(self)
    end
  end
end

class Scene_Map
  alias flamingo_band_autofade autofade unless method_defined?(:flamingo_band_autofade)

  # Do not fade a band track the next map will keep playing (keeps its position).
  def autofade(mapid)
    return if FlamingoBand.keeps_music_on?(mapid)
    flamingo_band_autofade(mapid)
  end
end

class Game_Event
  alias flamingo_band_start start unless method_defined?(:flamingo_band_start)

  # Tent exits on map 99 are intercepted while the quest runs (Addendum A).
  def start
    return if FlamingoBand.intercept_exit?(self)
    flamingo_band_start
  end
end

class Game_Follower
  alias flamingo_band_follow_leader follow_leader unless method_defined?(:flamingo_band_follow_leader)

  # Band members sometimes hop in place instead of stepping; the next step catches up.
  def follow_leader(leader, instant = false, leaderIsTrueLeader = true)
    FlamingoBand.restore_fidget_turns if leaderIsTrueLeader
    if !instant && !@move_route_forcing && FlamingoBand.band_follower?(self) &&
       FlamingoBand.skip_step?(self, leader)
      end_movement
      jump(0, 0)
      return
    end
    flamingo_band_follow_leader(leader, instant, leaderIsTrueLeader)
  end
end

EventHandlers.add(:on_frame_update, :flamingo_band_update,
  proc { FlamingoBand.on_frame_update }
)

EventHandlers.add(:on_enter_map, :flamingo_band_enter_map,
  proc { |old_map_id| FlamingoBand.on_enter_map(old_map_id) }
)
