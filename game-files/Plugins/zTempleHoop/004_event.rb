#===============================================================================
# Temple hoop - Map113 event 12 runs pbTempleHoop(get_self); the first finished
# round of a run brings Toga (event 13) in for his one line, then it autosaves.
#===============================================================================

module TempleHoop
  STAND = [6, 13].freeze                  # shooting line, facing the hoop at (5,13)
  TOGA_EVENT = "temple_hoop_toga"
  TOGA_EVENT_NAMES = [TOGA_EVENT, "temple_hoop_evyatar"].freeze   # Map113 event 13 keeps the old name
  TOGA_ID = "7a2a022c"                    # Toga, the barrel philosopher
  TOGA_CHARSET = "dt_7a2a022c"
  TOGA_HOME = [0, 23].freeze              # unreachable void tile
  TOGA_ENTRY = [6, 21].freeze             # inside the arch art
  TOGA_SPEED = 2                          # slower than the player's walk (3)
  EVYATAR_EVENT = TOGA_EVENT
  EVYATAR_CHARSET = TOGA_CHARSET
  EVYATAR_HOME = TOGA_HOME
  EVYATAR_ENTRY = TOGA_ENTRY
  EVYATAR_SPEED = TOGA_SPEED

  # (6,21) -> (6,19) -> (7,19) -> (7,13), facing the player; out is the same path back.
  def self.in_route
    [PBMoveRoute::UP] * 2 + [PBMoveRoute::RIGHT] + [PBMoveRoute::UP] * 6 + [PBMoveRoute::TURN_LEFT]
  end

  def self.out_route
    [PBMoveRoute::DOWN] * 6 + [PBMoveRoute::LEFT] + [PBMoveRoute::DOWN] * 2
  end

  # Under the black fade: the player stands on the shooting line facing the hoop.
  def self.place_player
    $game_player.moveto(*STAND)
    $game_player.turn_left
    $game_temp.followers.put_followers_on_player if $game_temp && $game_temp.followers
    pbUpdateSceneMap
  end

  def self.toga_event
    $game_map.events.values.find { |e| TOGA_EVENT_NAMES.include?(e.name) }
  end

  # Walk in, the line with his name plate, save (flag set first), walk out.
  def self.toga_visit(state)
    ev = toga_event
    return false unless ev
    pbWait(0.6)
    pbSEPlay("Door enter")
    ev.character_name = TOGA_CHARSET
    ev.moveto(*TOGA_ENTRY)
    ev.through = true
    ev.move_speed = TOGA_SPEED
    ev.turn_up
    TempleStickers.walk(ev, *in_route)
    $game_player.turn_right
    pbWait(0.4)
    pbDesertSpeaker(TOGA_ID)
    pbMessage(_INTL("HOOP_EVYATAR_LINE"))
    TempleHoopRules.mark_toga!(state)
    DesertTownAutosave.save_now(:temple_hoop) if defined?(DesertTownAutosave)
    pbWait(0.3)
    TempleStickers.walk(ev, *out_route)
    pbSEPlay("Door exit")
    ev.character_name = ""
    ev.moveto(*TOGA_HOME)
    ev.through = false
    true
  end

  class << self
    alias_method :evyatar_event, :toga_event
    alias_method :evyatar_visit, :toga_visit
  end
end

# Event Script command on the hoop: pbTempleHoop(get_self).
def pbTempleHoop(event)
  return false unless event
  return true unless pbConfirmMessage(_INTL("HOOP_APPROACH"))
  state = TempleHoop.state
  result = nil
  pbFadeOutIn do
    TempleHoop.place_player
    result = TempleHoop::Scene.new(state).run
  end
  return true unless result && result[:finished]
  TempleHoop.toga_visit(state) if TempleHoopRules.finish!(state, result[:made])
  true
end
