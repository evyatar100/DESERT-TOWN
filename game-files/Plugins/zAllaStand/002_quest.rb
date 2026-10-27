#===============================================================================
# AllaStand - Alla's talk flow (ask, remind, count, rush, ceremony) and the campers' votes.
# Mutators run before the messages they belong to; the screens only show text.
#===============================================================================

module AllaStand
  ASK = %w[ALLA_ASK_1 ALLA_ASK_2 ALLA_ASK_3 ALLA_ASK_4].freeze
  COUNT = %w[ALLA_COUNT_1 ALLA_COUNT_2 ALLA_COUNT_3 ALLA_COUNT_4 ALLA_COUNT_5].freeze
  CEREMONY = %w[ALLA_CEREMONY_1 ALLA_CEREMONY_2 ALLA_CEREMONY_3].freeze
  AFTER = %w[ALLA_AFTER_1 ALLA_AFTER_2 ALLA_AFTER_3].freeze
  RETRY_CHOICES = %w[ALLA_RETRY_YES ALLA_RETRY_NO].freeze
  VOTE_SE = "Voltorb Flip point"
  CEREMONY_ME = "Slots big win"
  AND_HE = "ו"

  def self.alla_talk
    st = state
    case AllaRules.alla_decide(st)
    when :intro
      AllaRules.campaign!(st)
      lines(ASK, :alla)
    when :remind then say("ALLA_REMIND", :alla, st[:votes].length, missing_names(st))
    when :count
      AllaRules.count!(st)
      lines(COUNT, :alla)
      rush_flow(st)
    when :rush then rush_flow(st)
    when :hotdog_recover
      say("ALLA_HOTDOG_RECOVER", :alla)
      give_hotdog(st)
    when :after
      @after_turn = ((@after_turn || -1) + 1) % AFTER.length
      say(AFTER[@after_turn], :alla)
    end
  end

  # The campers who have not voted, each from their NAME_ key, joined the Hebrew way: "טל ומאריו".
  def self.missing_names(st)
    names = AllaRules.missing(st).map { |c| _INTL(NAME_KEYS[c]) }
    return names.first.to_s if names.length < 2
    names[0...-1].join(", ") + " " + AND_HE + names.last
  end

  # The full intro once a session, then straight into each retry.
  def self.rush_flow(st)
    say("ALLA_RUSH_PRE_1", :alla)
    say("ALLA_RUSH_PRE_2", :alla) unless @pre_seen
    @pre_seen = true
    loop do
      if run_rush[:passed]
        return unless AllaRules.open!(st)
        return unveil(st)
      end
      say("ALLA_RUSH_LOSE", :alla)
      return unless retry?
    end
  end

  # Alla asks "again?"; No or Back is false.
  def self.retry?
    choose("ALLA_RETRY_ASK", :alla, RETRY_CHOICES) == 0
  end

  # One rush at the current easing; record: false for the F9 test run.
  def self.run_rush(record: true)
    DesertTalk.name_key = nil if defined?(DesertTalk)
    result = RushScene.new(rush_losses, rand(1 << 30)).run
    record_rush(result[:passed]) if record
    result
  end

  # The sign: dim, the title as narration, then the ceremony and the hot dog.
  def self.unveil(st)
    dim_screen(true)
    say("ALLA_END_TITLE")
    dim_screen(false)
    pbMEPlay(CEREMONY_ME)
    lines(CEREMONY, :alla)
    give_hotdog(st)
  end

  def self.dim_screen(on)
    return unless $game_screen
    tone = on ? Tone.new(-255, -255, -255, 0) : Tone.new(0, 0, 0, 0)
    $game_screen.start_tone_change(tone, 20)
    pbWait(0.5)
  end

  def self.give_hotdog(st)
    had = AllaRules.held?($bag, AllaRules::ITEM)
    return unless AllaRules.hotdog!(st, $bag)
    say("ALLA_GOT_HOTDOG", :alla)
    announce(AllaRules::ITEM) unless had
  end

  def self.camper_talk(who)
    st = state
    case AllaRules.camper_decide(st, who, camper_after?(who))
    when :vote
      AllaRules.vote!(st, who)
      lines(["ALLA_VOTE_#{who.to_s.upcase}_1", "ALLA_VOTE_#{who.to_s.upcase}_2"], who)
      pbSEPlay(VOTE_SE)
    when :voted then say("ALLA_VOTED_#{who.to_s.upcase}", who)
    when :after
      (@camper_after ||= {})[who] = true
      say("ALLA_AFTER_#{who.to_s.upcase}", who)
    end
  end

  def self.camper_after?(who)
    !!(@camper_after && @camper_after[who])
  end
end
