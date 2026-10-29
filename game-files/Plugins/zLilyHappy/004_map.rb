#===============================================================================
# LilyHappy - Lily's side (spec D4). The wheel opens from her talk on maps 98/91/93; no map
# event exists for it. The player never moves and the BGM is never touched.
#===============================================================================

module LilyHappy
  # The wheel inside the fade. A quit or an F9 game (record: false) writes nothing.
  def self.play(state, record: true)
    result = nil
    pbFadeOutIn { result = Scene.new(state, record: record).run }
    result || { result: :quit, peak: 0, laps: 0, fixes: 0 }
  end

  def self.lily_talk
    st = state
    case R.lily_decide(st)
    when :intro then intro(st)
    when :not_yet then not_yet(st)
    when :ready then ready(st)
    when :payoff then payoff(st)
    when :idle then idle(st)
    end
    true
  end

  def self.intro(st)
    say("LILY_MIRROR") if mirror?
    lines(%w[LILY_INTRO_1 LILY_INTRO_2 LILY_INTRO_3])
    return say("LILY_DECLINE") unless ask("LILY_ACCEPT_Q", "LILY_ACCEPT_YES", "LILY_ACCEPT_NO")
    return false unless R.start!(st)
    autosave
    lines(%w[LILY_GO_1 LILY_GO_CAMPS])
    true
  end

  # At most 3 places, deduplicated by their text (Kusomo once); LEFT_MORE when more remain.
  def self.not_yet(st)
    say("LILY_NOT_YET")
    say("LILY_PROGRESS", :lily, st[:heard].size)
    places, more = R.left_places(st) { |enc| _INTL("LILY_CAMP_#{enc.to_s.upcase}") }
    say(more ? "LILY_LEFT_MORE" : "LILY_LEFT", :lily, places.join(", "))
  end

  # Finished -> wheel_done! (inside the scene) -> the payoff in the same talk.
  def self.ready(st)
    lines(%w[LILY_SKEPTIC_1 LILY_SKEPTIC_2])
    return say("LILY_LATER") if !ask("LILY_WHEEL_Q", "LILY_WHEEL_YES", "LILY_WHEEL_LATER") || busy?
    play(st)
    return say("LILY_WHEEL_QUIT") unless st[:stage] == :wheeled
    autosave
    payoff(st)
  end

  # After the quest: the idle line and a replay that can only raise best.
  def self.idle(st)
    say("LILY_IDLE")
    return true unless ask("LILY_REPLAY_Q", "LILY_REPLAY_YES", "LILY_REPLAY_NO")
    return say("LILY_LATER") if busy?
    res = play(st)
    return true unless res[:result] == :finished
    autosave
    say(res[:peak] >= R::CAP ? "LILY_REPLAY_AFTER" : "LILY_REPLAY_AFTER_LOW", :lily, res[:peak])
  end
end
