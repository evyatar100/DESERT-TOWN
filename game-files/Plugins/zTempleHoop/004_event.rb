#===============================================================================
# Temple hoop - Map113 event 12 runs pbTempleHoop(get_self); the first finished
# round of a run brings Evyatar (event 13) in for his one line, then it autosaves.
#===============================================================================

module TempleHoop
  STAND = [6, 13].freeze                  # shooting line, facing the hoop at (5,13)
  VISITOR_EVENT = "temple_hoop_evyatar"
  VISITOR_EVENT_NAMES = [VISITOR_EVENT, "temple_hoop_toga"].freeze   # Map113 event 13; both names work
  VISITOR_ID = "f90d4de9"                 # Evyatar (WindJackal700), TG15
  VISITOR_CHARSET = "dt_f90d4de9"
  VISITOR_HOME = [0, 23].freeze           # unreachable void tile
  VISITOR_ENTRY = [6, 21].freeze          # inside the arch art
  VISITOR_SPEED = 2                       # slower than the player's walk (3)
  # Old names, kept so nothing that still says Toga or the first Evyatar breaks.
  TOGA_EVENT = VISITOR_EVENT
  TOGA_EVENT_NAMES = VISITOR_EVENT_NAMES
  TOGA_ID = VISITOR_ID
  TOGA_CHARSET = VISITOR_CHARSET
  TOGA_HOME = VISITOR_HOME
  TOGA_ENTRY = VISITOR_ENTRY
  TOGA_SPEED = VISITOR_SPEED
  EVYATAR_EVENT = VISITOR_EVENT
  EVYATAR_CHARSET = VISITOR_CHARSET
  EVYATAR_HOME = VISITOR_HOME
  EVYATAR_ENTRY = VISITOR_ENTRY
  EVYATAR_SPEED = VISITOR_SPEED

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

  def self.visitor_event
    $game_map.events.values.find { |e| VISITOR_EVENT_NAMES.include?(e.name) }
  end

  # Walk in, the line with his name plate, save (flag set first), walk out.
  def self.visitor_visit(state)
    ev = visitor_event
    return false unless ev
    pbWait(0.6)
    pbSEPlay("Door enter")
    ev.character_name = VISITOR_CHARSET
    ev.moveto(*VISITOR_ENTRY)
    ev.through = true
    ev.move_speed = VISITOR_SPEED
    ev.turn_up
    TempleStickers.walk(ev, *in_route)
    $game_player.turn_right
    pbWait(0.4)
    pbDesertSpeaker(VISITOR_ID)
    pbMessage(_INTL("HOOP_EVYATAR_LINE"))
    pbMessage(_INTL("HOOP_EVYATAR_HINT"))
    TempleHoopRules.mark_visitor!(state)
    DesertTownAutosave.save_now(:temple_hoop) if defined?(DesertTownAutosave)
    pbWait(0.3)
    TempleStickers.walk(ev, *out_route)
    pbSEPlay("Door exit")
    ev.character_name = ""
    ev.moveto(*VISITOR_HOME)
    ev.through = false
    true
  end

  class << self
    alias_method :toga_event, :visitor_event
    alias_method :toga_visit, :visitor_visit
    alias_method :evyatar_event, :visitor_event
    alias_method :evyatar_visit, :visitor_visit
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
  TempleHoop.visitor_visit(state) if TempleHoopRules.finish!(state, result[:made])
  true
end
