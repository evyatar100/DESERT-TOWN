#===============================================================================
# Shira's wedding - Map098 (Playa). Event 16 (Eviatar, (14,22)) runs pbShiraEviatar(get_self);
# event 17 (Shira, parked at (18,5)) runs pbShiraWedding(get_self). No switch is used.
#===============================================================================

module ShiraWedding
  MAP_ID = 98
  SPOT = [14, 22].freeze
  EVIATAR_EVENT = "shira_eviatar"
  EV_ROWS = { sent: "SHIRA_EV_SENT", pass: "SHIRA_EV_PASS", mazaltov: "SHIRA_EV_MAZALTOV" }.freeze

  def self.on_playa? = !!($game_map && $game_map.map_id == MAP_ID)

  # The board inside the fade; nothing is saved here.
  def self.play
    result = nil
    pbFadeOutIn { result = Scene.new.run }
    result || { result: :quit }
  end

  # The same flow whether she was caught crossing or summoned (D4).
  def self.talk
    st = state
    case ShiraWeddingRules.talk_decide(st)
    when :intro
      say("SHIRA_MIRROR", :shira) if mirror?
      lines(%w[SHIRA_INTRO_1 SHIRA_INTRO_2 SHIRA_INTRO_3], :shira)
      ShiraWeddingRules.start!(st)
      offer(st)
    when :ask_again
      say("SHIRA_ASK_AGAIN", :shira)
      offer(st)
    when :reward then reward(st)
    when :final then final(st)
    when :after then after(st)
    end
    true
  end

  def self.offer(st)
    return say("SHIRA_DECLINE", :shira) unless ask("SHIRA_HELP_PROMPT", :shira)
    result = play
    return say("SHIRA_QUIT_LINE", :shira) unless result[:result] == :solved
    ShiraWeddingRules.seat!(st, result[:swaps])
    reward(st)
  end

  # THANKS, the bag, BAG_JOKE, then the final line once.
  def self.reward(st)
    return false unless st[:stage] == :seated
    say("SHIRA_THANKS", :shira)
    return false unless ShiraWeddingRules.give_bag!(st, $bag)
    announce
    say("SHIRA_BAG_JOKE", :shira)
    final(st)
  end

  # :bag -> :done is the only step that shows FINAL.
  def self.final(st)
    return false unless st[:stage] == :bag
    reissue(st)
    say("SHIRA_FINAL", :shira)
    ShiraWeddingRules.finish!(st)
    DesertTownAutosave.save_now(:shira_wedding) if defined?(DesertTownAutosave)
    true
  end

  def self.reissue(st)
    return false unless ShiraWeddingRules.reissue!(st, $bag, inbar_done?)
    say("SHIRA_REISSUE", :shira)
    announce
    true
  end

  # AFTER, a reissue if the bag went missing, then a replay that records nothing.
  def self.after(st)
    say("SHIRA_AFTER", :shira)
    reissue(st)
    play if ask("SHIRA_REPLAY_PROMPT", :shira)
    true
  end

  #--- Eviatar (D6) ---------------------------------------------------------------
  def self.eviatar_talk
    st = state
    say("SHIRA_EV_MIRROR", :eviatar) if mirror?
    rows = ShiraWeddingRules.eviatar_rows(st)
    DesertTalk.name_key = NAME_KEYS[:eviatar] if defined?(DesertTalk)
    pick = pbShowCommands(nil, rows.map { |r| _INTL(EV_ROWS[r]) }, rows.length)
    row = pick.is_a?(Integer) && pick >= 0 ? rows[pick] : :pass
    case ShiraWeddingRules.eviatar_decide(st, row)
    when :summon
      lines(%w[SHIRA_EV_CALL_1 SHIRA_EV_CALL_2], :eviatar)
      summon_and_talk
    when :sent_done then say("SHIRA_EV_SENT_DONE", :eviatar)
    when :thanks then lines(%w[SHIRA_EV_THANKS_1 SHIRA_EV_THANKS_2], :eviatar)
    else say("MSG_F90D4DE9_LINE", :eviatar)
    end
    DesertTalk.name_key = nil if defined?(DesertTalk)
    true
  end

  def self.summon_and_talk
    return false unless Wander.summon_in
    begin
      talk
    ensure
      Wander.walk_out
    end
    true
  end
end

def pbShiraWedding(_event = nil)
  return true unless ShiraWedding.on_playa? && ShiraWedding::Wander.visible?
  ShiraWedding::Wander.hold { ShiraWedding.talk }
  DesertTalk.name_key = nil if defined?(DesertTalk)
  true
end

def pbShiraEviatar(_event = nil)
  ShiraWedding.eviatar_talk if ShiraWedding.on_playa?
  true
end
