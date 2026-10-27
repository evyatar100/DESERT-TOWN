#===============================================================================
# Temple hoop (TG11) - pure rules. No engine calls: tests load this file directly.
# Python mirror: tests/hoop_rules.py.
#===============================================================================

module TempleHoopRules
  SHOTS = 5
  PERIODS = [1.8, 1.6, 1.4, 1.3, 1.2].freeze     # marker period per shot, seconds
  # [upper bound, inclusive?, path]: the first band the marker value fits picks the path.
  BANDS = [
    [54, false, :short], [60, false, :rim_front], [68, false, :rim_in], [76, true, :swish],
    [84, true, :board_in], [90, true, :rim_back]
  ].freeze
  OUTCOME = {
    short: :short, rim_front: :rim_out, rim_in: :in, swish: :swish,
    board_in: :in, rim_back: :rim_out, long: :long
  }.freeze
  MADE = %i[in swish].freeze

  SCREEN_W = 512
  SCREEN_H = 384
  BALL_R = 10
  HOOP_ORIGIN = [48, 24].freeze                  # hoop_big.png top-left on screen
  RIM = [152, 163].freeze                        # rim centre on screen; the only copy
  RIM_ART = [RIM[0] - HOOP_ORIGIN[0], RIM[1] - HOOP_ORIGIN[1]].freeze   # same spot inside hoop_big.png
  BALL_START = [420, 300].freeze
  ARC_TIME = 0.9
  POP_TIME = 0.6
  NEXT_DELAY = 0.4
  CARD_LOCK = 0.5
  # Segments [x, y, lift, seconds, SE at its end]; each starts where the last ended.
  PATHS = {
    short:     [[236, 344, 110, ARC_TIME, "Battle ball drop"], [262, 344, 18, 0.3, nil]],
    rim_front: [[180, 152, 150, ARC_TIME, "Mining iron"], [252, 344, 46, 0.5, "Battle ball drop"]],
    rim_in:    [[176, 150, 150, ARC_TIME, "Mining iron"], [152, 146, 12, 0.2, nil],
                [152, 226, 0, 0.25, "Mining ping"], [158, 344, 0, 0.25, nil]],
    swish:     [[152, 150, 150, ARC_TIME, nil], [152, 226, 0, 0.22, "Voltorb Flip point"],
                [156, 344, 0, 0.25, nil]],
    board_in:  [[140, 118, 140, ARC_TIME, "Player bump"], [152, 150, 0, 0.15, nil],
                [152, 226, 0, 0.22, "Mining ping"], [156, 344, 0, 0.25, nil]],
    rim_back:  [[126, 152, 150, ARC_TIME, "Mining iron"], [96, 344, 40, 0.5, "Battle ball drop"]],
    long:      [[118, 64, 110, ARC_TIME, "Player bump"], [200, 344, 10, 0.55, "Battle ball drop"]]
  }.freeze

  # Triangle wave 0 -> 100 -> 0 over one period.
  def self.meter(t, period)
    return 0.0 if period <= 0
    phase = (t % period) / period.to_f
    v = phase < 0.5 ? phase * 200.0 : (1.0 - phase) * 200.0
    v.clamp(0.0, 100.0)
  end

  def self.shot(v)
    BANDS.each { |limit, inclusive, path| return path if inclusive ? v <= limit : v < limit }
    :long
  end

  def self.outcome(v)
    OUTCOME[shot(v)]
  end

  # Only a clean swish shakes the net.
  def self.net_jiggle?(path)
    path == :swish
  end

  def self.made?(outcome)
    MADE.include?(outcome)
  end

  def self.word_key(outcome)
    return "HOOP_SWISH" if outcome == :swish
    made?(outcome) ? "HOOP_MADE" : "HOOP_MISSED"
  end

  def self.duration(path)
    PATHS[path].sum { |seg| seg[3] }
  end

  # [x, y, segment index] at t seconds after release; holds the last point after the end.
  def self.ball_at(path, t)
    x0, y0 = BALL_START
    PATHS[path].each_with_index do |(x1, y1, lift, secs, _), i|
      if t < secs || i == PATHS[path].length - 1
        s = (t / secs.to_f).clamp(0.0, 1.0)
        return [x0 + (x1 - x0) * s, y0 + (y1 - y0) * s - 4.0 * lift * s * (1 - s), i]
      end
      t -= secs
      x0, y0 = x1, y1
    end
  end

  # [[seconds after release, SE name], ...] for the segment ends that make a sound.
  def self.sounds(path)
    at = 0.0
    PATHS[path].filter_map { |seg| at += seg[3]; [at, seg[4]] if seg[4] }
  end

  # A made ball below the rim line, after the arc, drops behind the front rim and net.
  def self.behind_front?(path, t)
    return false unless made?(OUTCOME[path])
    _, y, seg = ball_at(path, t)
    seg >= 1 && y > RIM[1]
  end

  # What the end card shows; call before finish!. best is nil on the run's first round.
  def self.card(state, made)
    { made: made, of: SHOTS, best: state[:plays] > 0 ? [state[:best], made].max : nil }
  end

  #-----------------------------------------------------------------------------
  # Per-run state ($PokemonGlobal.temple_hoop). Only these methods write it.
  #-----------------------------------------------------------------------------
  def self.new_state
    { evyatar_seen: false, plays: 0, best: 0 }
  end

  # nil or garbage becomes a fresh state; a Hash is repaired in place.
  def self.normalize(x)
    return new_state unless x.is_a?(Hash)
    x[:evyatar_seen] = (x[:evyatar_seen] == true)
    x[:plays] = 0 unless x[:plays].is_a?(Integer) && x[:plays] >= 0
    x[:best] = 0 unless x[:best].is_a?(Integer) && x[:best].between?(0, SHOTS)
    x.keep_if { |k, _| new_state.key?(k) }
  end

  # A finished round: counts it, keeps the best; true when Toga is due.
  def self.finish!(state, made)
    made = made.to_i.clamp(0, SHOTS)
    state[:plays] += 1
    state[:best] = [state[:best], made].max
    !toga_seen?(state)
  end

  # Toga's visit keeps the old :evyatar_seen key, so saves from before the swap count.
  def self.toga_seen?(state)
    state[:evyatar_seen] == true
  end

  def self.mark_toga!(state)
    state[:evyatar_seen] = true
  end

  def self.reset_toga!(state)
    state[:evyatar_seen] = false
  end

  class << self
    alias_method :mark_evyatar!, :mark_toga!
    alias_method :reset_evyatar!, :reset_toga!
  end
end
