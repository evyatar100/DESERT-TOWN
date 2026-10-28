#===============================================================================
# DJ Rush Hour (TG53/TG56) - Ido DJs the stage tile until :freed; then car event 82 is She Se
# there (map event dt_fc898478 is always hidden), Ido is on the floor, all dance.
# (34,12) is unreachable (counter (34,13), partygoer 92958f4d on (34,14)), so the DJ tile is (33,12).
#===============================================================================

module DJRush
  CAR_HOME = [12, 23].freeze
  IDO_EVENT = "dt_cace0cde"
  IDO_HOME = DJRushRules::STAGE_TILE
  CROWD_PREFIX = "dt_"
  STAND_TILE = [33, 14].freeze   # below the booth; the player is moved here off She Se's tile
  CROWD_NAMES = Object.new
  def CROWD_NAMES.include?(name) = name.to_s.start_with?(CROWD_PREFIX)

  # Map event dt_fc898478 stays out of the party: she is stuck in the art car, then car event 82 plays her.
  def self.hide_she_se_rpg(map) = map.events.delete_if { |_, ev| ev.name == PLAYER_DJ }

  # The RPG map before its events are built (freed only; the map itself is never saved).
  def self.stage_dress_rpg(map)
    map.events.each_value do |ev|
      if ev.name == CAR_EVENT
        ev.x, ev.y = DJRushRules::STAGE_TILE
        ev.pages.each do |pg|
          pg.graphic.character_name = PLAYER_DJ
          pg.graphic.direction = 2
          pg.graphic.pattern = 0
          pg.direction_fix = true
          pg.step_anime = true
        end
      elsif ev.name == IDO_EVENT
        ev.x, ev.y = DJRushRules::IDO_FLOOR[0]
        ev.pages.each { |pg| pg.graphic.direction = 2 }
      end
      ev.pages.each { |pg| pg.step_anime = true } if ev.name.start_with?(CROWD_PREFIX)
    end
  end

  def self.place(ev, tile)
    ev.moveto(tile[0], tile[1]) unless ev.x == tile[0] && ev.y == tile[1]
  end

  # She Se: a normal 4-direction charset facing down (row 0), her lower half behind the deck tile.
  def self.stage_look(ev)
    set_row(ev, 0, PLAYER_DJ)
    ev.instance_variable_set(:@pattern, 0)
    ev.instance_variable_set(:@original_pattern, 0)
  end

  # Stays where it is when already on a floor tile the player is not standing on.
  def self.ido_tile(ev)
    px = [$game_player.x, $game_player.y] if $game_player.respond_to?(:x)
    tiles = DJRushRules::IDO_FLOOR.reject { |t| t == px }
    tiles.include?([ev.x, ev.y]) ? [ev.x, ev.y] : tiles.first
  end

  def self.authored_anime(ev)
    pg = ev.instance_variable_get(:@page)
    pg ? !!pg.step_anime : false
  end

  # Idempotent: right after the win, for a restored save, and for the F9 rollback.
  def self.stage_dress_live(st)
    freed = DJRushRules.freed?(st)
    if freed && $game_player.respond_to?(:x) && [$game_player.x, $game_player.y] == DJRushRules::STAGE_TILE
      $game_player.moveto(*STAND_TILE)
    end
    live_events([PLAYER_DJ]).each(&:erase)
    live_events([CAR_EVENT]).each do |ev|
      place(ev, freed ? DJRushRules::STAGE_TILE : CAR_HOME)
      freed ? stage_look(ev) : set_row(ev, car_row(st))
    end
    live_events([IDO_EVENT]).each do |ev|
      if freed
        tile = ido_tile(ev)
        moved = [ev.x, ev.y] != tile
        place(ev, tile)
        ev.direction = 2 if moved
      else
        place(ev, IDO_HOME)
      end
    end
    live_events(CROWD_NAMES).each do |ev|
      ev.instance_variable_set(:@step_anime, freed ? true : authored_anime(ev))
    end
  end
end
