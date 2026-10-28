#===============================================================================
# __NAME__ - map entry: the event at Map__MAPID3__ (__TX__,__TY__) runs pb__NAME__Start(get_self).
# The player never moves and the BGM is never touched.
#===============================================================================

module __NAME__
  MAP_ID = __MAPID__
  SPOT = [__TX__, __TY__].freeze

  def self.play(state, record: true)
    result = nil
    pbFadeOutIn { result = Scene.new(state, record: record).run }
    result
  end
end

module __NAME__
  # Ask, then play. Saying no shows the later line and changes nothing.
  def self.offer
    unless pbConfirmMessage(_INTL("__PREFIX___PROMPT"))
      pbMessage(_INTL("__PREFIX___LATER"))
      return true
    end
    play(state)
    true
  end
end

def pb__NAME__Start(event)
  return false unless event
  __NAME__.offer
end
