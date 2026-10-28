#===============================================================================
# Tuta maze - Map113 event 14 (tuta_statue) runs pbTutaStatue(get_self).
# The player never moves and the BGM is never touched (dec:tg-11).
#===============================================================================

module TutaMaze
  TEMPLE_MAP = 113
  STATUE = [10, 18].freeze

  def self.prompt_key(state)
    state[:wins] > 0 ? "TUTA_STATUE_PROMPT_WON" : "TUTA_STATUE_PROMPT"
  end

  # diff: nil = from the saved state (F9 passes one). Returns the scene's result hash.
  def self.play(state, diff = nil)
    result = nil
    pbFadeOutIn { result = Scene.new(state, diff).run }
    result
  end
end

def pbTutaStatue(event)
  return false unless event
  state = TutaMaze.state
  unless pbConfirmMessage(_INTL(TutaMaze.prompt_key(state)))
    pbMessage(_INTL("TUTA_STATUE_LATER"))
    return true
  end
  TutaMaze.play(state)
  true
end
