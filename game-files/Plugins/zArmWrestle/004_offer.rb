#===============================================================================
# Arm wrestling - the challenge after cowboy Shirpaz's line (called from zBags'
# cowboy_talk). A win gives exactly one Surprise Bag, then autosaves; a loss only counts.
#===============================================================================

module ArmWrestle
  NAME_KEY = "NAME_670F79E3"        # שירפז, the cowboy
  CHOICES = %w[AW_CHOICE_PLAY AW_CHOICE_LATER].freeze

  def self.say(key)
    DesertTalk.name_key = NAME_KEY if defined?(DesertTalk)
    pbMessage(_INTL(key))
  end

  # Back picks the last option (not now).
  def self.choose(key, choice_keys)
    DesertTalk.name_key = NAME_KEY if defined?(DesertTalk)
    pbMessage(_INTL(key), choice_keys.map { |k| _INTL(k) }, choice_keys.length)
  end

  # busy: the unicorns' song runs (its overlay must not get a modal on top).
  # Returns :busy, :later, :back, :win or :loss.
  def self.offer(busy: false)
    if busy
      say("AW_BUSY")
      return :busy
    end
    if choose("AW_CHALLENGE", CHOICES) != 0
      say("AW_LATER")
      return :later
    end
    st = state
    result = nil
    pbFadeOutIn { result = Scene.new(ArmWrestleRules.tier(st)).run }
    outcome = result.is_a?(Hash) ? result[:outcome] : nil
    case outcome
    when :win
      ArmWrestleRules.record!(st, :win)
      say(ArmWrestleRules.win_line(st))
      DesertTalk.name_key = nil if defined?(DesertTalk)
      pbReceiveItem(:SURPRISEBAG)
      DesertTownAutosave.save_now(:arm_wrestle) if defined?(DesertTownAutosave)
      :win
    when :loss
      ArmWrestleRules.record!(st, :loss)
      say(ArmWrestleRules.lose_line(st))
      :loss
    else
      say("AW_LATER")
      :back
    end
  end
end
