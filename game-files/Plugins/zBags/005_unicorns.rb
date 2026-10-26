#===============================================================================
# Bags - the two unicorn events on Map095 (S106 pages): charsets, standing still,
# the walk-in from row 0, and walking several characters together.
#===============================================================================

module Bags
  UNICORN_PREFIX = "bags_unicorn_"
  UNICORNS = %i[esther shirpaz].freeze
  WALK_SPEED = 4
  WALK_FRAMES_PER_STEP = 30
  MOVE_CODES = { down: 1, left: 2, right: 3, up: 4, away: 11 }.freeze   # PBMoveRoute

  # The real charset when present, else "<name>_placeholder".
  def self.unicorn_charset(name)
    return name if name.empty? || name.end_with?("_placeholder")
    return name if pbResolveBitmap("Graphics/Characters/#{name}")
    "#{name}_placeholder"
  end

  # map is the RPG::Map being set up; its events are not built yet, so they read the new pages.
  # They stand still (no step animation) and animate only while walking.
  def self.dress_unicorns(map)
    map.events.each_value do |ev|
      next unless ev.name.start_with?(UNICORN_PREFIX)
      ev.pages.each do |page|
        page.graphic.character_name = unicorn_charset(page.graphic.character_name)
        page.step_anime = false
      end
    end
  end

  # The Game_Event for :esther / :shirpaz on the current map, or nil.
  def self.unicorn_event(which)
    return nil unless $game_map
    name = "#{UNICORN_PREFIX}#{which}"
    $game_map.events.each_value { |ev| return ev if ev.name == name }
    nil
  end

  # Called right after the hand-over turns S106 on: pages on now, then row 0 (off-screen).
  def self.place_offscreen
    @walk_in = {}
    UNICORNS.each do |which|
      ev = unicorn_event(which)
      next unless ev
      ev.refresh
      @walk_in[which] = [ev.x, ev.y]
      ev.moveto(walk_in_start_x(ev.x), 0)
    end
  end

  def self.walk_in_start_x(end_x)
    open = (0...$game_map.width).select { |x| [2, 4, 6, 8].any? { |d| $game_map.passable?(x, 0, d) } }
    BagsRules.walk_in_start(end_x, open)
  end

  # Both walk down to their spots together, through anything; a stuck walk snaps to the spot.
  def self.walk_in
    spots = @walk_in || {}
    @walk_in = nil
    walkers = spots.filter_map do |which, (x, y)|
      ev = unicorn_event(which)
      next unless ev
      [ev, x, y, BagsRules.walk_in_moves(ev.x, x, y - ev.y)]
    end
    walk_together(walkers.map { |ev, _, _, moves| [ev, moves] })
    walkers.each { |ev, x, y, _| ev.moveto(x, y) if ev.x != x || ev.y != y }
  end

  # One map frame while a script holds the interpreter.
  def self.update_frame
    Graphics.update
    Input.update
    pbUpdateSceneMap
  end

  # [[character, [:down, ...]], ...]: one forced route each, run at the same time.
  def self.walk_together(plans, speed = WALK_SPEED)
    plans = plans.reject { |_, moves| moves.empty? }
    return if plans.empty?
    saved = plans.map { |ch, _| [ch, ch.through, ch.move_speed] }
    plans.each do |ch, moves|
      ch.through = true
      ch.bags_speed_lock = speed if ch.respond_to?(:bags_speed_lock=)
      ch.move_speed = speed
      ch.force_move_route(move_route(moves))
    end
    cap = WALK_FRAMES_PER_STEP * plans.map { |_, m| m.length }.max + 60
    map = $game_map
    cap.times do
      break if $game_map != map || plans.none? { |ch, _| ch.move_route_forcing || ch.moving? }
      update_frame
    end
  ensure
    (saved || []).each do |ch, through, speed_was|
      ch.through = through
      ch.bags_speed_lock = nil if ch.respond_to?(:bags_speed_lock=)
      ch.move_speed = speed_was
    end
  end

  def self.move_route(moves)
    route = RPG::MoveRoute.new
    route.repeat = false
    route.skippable = true
    route.list.clear
    moves.each { |m| route.list.push(RPG::MoveCommand.new(MOVE_CODES[m])) }
    route.list.push(RPG::MoveCommand.new(0))
    route
  end
end

# Fires inside Game_Map#setup after the map loads and before its events are created,
# so S106 and the charsets are right when the unicorn pages are first chosen.
EventHandlers.add(:on_game_map_setup, :bags_unicorns,
  proc { |map_id, map, _tileset|
    next if map_id != Bags::INBAR_MAP
    Bags.sync_switch if $PokemonGlobal
    Bags.dress_unicorns(map)
  }
)

# Game_FollowerFactory#update copies the leader's speed onto each follower every frame;
# while walk_together locks a follower's speed (the duo's leave walk), the lock wins.
if defined?(Game_Follower)
  class Game_Follower
    attr_accessor :bags_speed_lock
    alias bags_speed_set move_speed= unless method_defined?(:bags_speed_set)

    def move_speed=(val)
      bags_speed_set(@bags_speed_lock || val)
    end
  end
end
