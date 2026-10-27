#===============================================================================
# Arm wrestling (TG14) - pure rules. No engine calls: tests load this file directly.
# Python mirror: tests/arm_rules.py.
#===============================================================================

module ArmWrestleRules
  CAP = 45.0                 # seconds after GO
  COUNTDOWN = 2.4            # 3, 2, 1 (0.6 s each), then GO for 0.6 s
  EPS = 1e-9
  SLIP = 6                   # a press that misses its nearest beat or finds it taken (was 3, dec:tg-31)
  FLINCH = 4                 # Blue outside a brace window
  EDGE_IN = -65              # on the edge at or below this...
  EDGE_OUT = -40             # ...until above this
  EDGE_WIDEN = 1.5
  EDGE_PERFECT = 14
  EDGE_PULL = 0.5
  BRACE_AFTER = 0.15         # the brace window stays open this long after the surge lands
  HIT_TIME = 0.4             # a hit drains over this long
  STRAIN_TIME = 0.6
  MAX_ANGLE = 72
  ANGLE_STEP = 3
  FRAMES = 49
  FACES = %i[steady tell strain taunt pinned won].freeze   # aw_shirpaz.png cells, row-major
  FACE_STEADY_MIN = -30
  FACE_STEADY_MAX = 40
  WIN_LINES = 3
  LOSE_LINES = 3
  # Playtest-tunable (spec table); tests check the winnability properties, not these numbers.
  TIERS = [
    { period: 0.80, perfect: 0.10, good: 0.20, push_perfect: 10, push_good: 6, pull: 2,
      surge_min: 8, surge_max: 10, tell: 1.4, brace: 0.6, hit: 14, block: 12 },
    { period: 0.75, perfect: 0.09, good: 0.18, push_perfect: 10, push_good: 6, pull: 3,
      surge_min: 6, surge_max: 8, tell: 1.2, brace: 0.5, hit: 16, block: 12 },
    { period: 0.68, perfect: 0.08, good: 0.15, push_perfect: 10, push_good: 6, pull: 4,
      surge_min: 5, surge_max: 7, tell: 1.0, brace: 0.45, hit: 19, block: 12 },
    { period: 0.60, perfect: 0.07, good: 0.13, push_perfect: 10, push_good: 6, pull: 5,
      surge_min: 4, surge_max: 6, tell: 0.8, brace: 0.4, hit: 22, block: 12 }
  ].freeze

  # Seeded generator with the same sequence in Ruby and Python (any object with #rand works).
  class Lcg
    MASK = (1 << 64) - 1
    def initialize(seed)
      @s = seed.to_i & MASK
    end

    def rand
      @s = (@s * 6364136223846793005 + 1442695040888963407) & MASK
      (@s >> 11) / 9007199254740992.0
    end
  end

  #-----------------------------------------------------------------------------
  # Difficulty
  #-----------------------------------------------------------------------------
  def self.tier(state)
    t = 1 + [state[:wins], 2].min
    t -= 1 if state[:loss_streak] >= 2
    t -= 1 if state[:loss_streak] >= 4
    [t, 0].max
  end

  #-----------------------------------------------------------------------------
  # The bout. t counts from GO. surge = landing time of the telegraphed surge, or nil.
  #-----------------------------------------------------------------------------
  def self.new_bout(tier, rng)
    tier = tier.to_i.clamp(0, TIERS.length - 1)
    bout = { tier: tier, cfg: TIERS[tier], rng: rng, t: 0.0, b: 0.0, beats: 0, judged: 0,
             surge: nil, next_surge: 0.0, drain: 0.0, edge: false, strain_until: -1.0,
             over: nil, reason: nil }
    bout[:next_surge] = interval(bout)
    bout
  end

  def self.interval(bout)
    c = bout[:cfg]
    bout[:t] + c[:surge_min] + bout[:rng].rand * (c[:surge_max] - c[:surge_min])
  end

  def self.widen(bout)
    bout[:edge] ? EDGE_WIDEN : 1.0
  end

  # [perfect, good] half-widths in seconds right now.
  def self.windows(bout)
    c = bout[:cfg]
    [c[:perfect] * widen(bout), c[:good] * widen(bout)]
  end

  # Advances dt seconds; red/blue are this frame's button triggers. Returns the events.
  def self.step(bout, dt, red: false, blue: false)
    return [] if bout[:over]
    ev = []
    c = bout[:cfg]
    bout[:t] += dt
    beat = (bout[:t] / c[:period]).floor
    if beat > bout[:beats]
      bout[:beats] = beat
      ev << :beat
    end
    judge_red(bout, ev) if red
    judge_blue(bout, ev) if blue
    bout[:b] -= c[:pull] * (bout[:edge] ? EDGE_PULL : 1.0) * dt
    if bout[:drain] > 0
      d = [bout[:drain], c[:hit] / HIT_TIME * dt].min
      bout[:b] -= d
      bout[:drain] -= d
    end
    surge_tick(bout, ev)
    bout[:b] = bout[:b].clamp(-100.0, 100.0)
    edge_tick(bout, ev)
    end_tick(bout, ev)
    ev
  end

  # A press is judged against its nearest beat and consumes it, hit or slip (dec:tg-31).
  def self.judge_red(bout, ev)
    c = bout[:cfg]
    k = (bout[:t] / c[:period]).round
    d = (bout[:t] - k * c[:period]).abs
    perfect, good = windows(bout)
    if k >= 1 && bout[:judged] < k && d <= good + EPS
      bout[:judged] = k
      if d <= perfect + EPS
        bout[:b] += bout[:edge] ? EDGE_PERFECT : c[:push_perfect]
        ev << :perfect
      else
        bout[:b] += c[:push_good]
        ev << :good
      end
    else
      bout[:judged] = k if k > bout[:judged]
      bout[:b] -= SLIP
      ev << :slip
    end
  end

  def self.brace_open?(bout)
    s = bout[:surge]
    !s.nil? && bout[:t] >= s - bout[:cfg][:brace] - EPS && bout[:t] <= s + BRACE_AFTER + EPS
  end

  # After the tell, before the brace window opens.
  def self.lead_in?(bout)
    s = bout[:surge]
    !s.nil? && bout[:t] < s - bout[:cfg][:brace] - EPS
  end

  # Blue in the tell lead-in (surge set, window not open yet) is ignored (dec:tg-31).
  def self.judge_blue(bout, ev)
    if brace_open?(bout)
      bout[:surge] = nil
      bout[:b] += bout[:cfg][:block]
      bout[:strain_until] = bout[:t] + STRAIN_TIME
      bout[:next_surge] = interval(bout)
      ev << :block
    elsif !lead_in?(bout)
      bout[:b] -= FLINCH
      ev << :flinch
    end
  end

  # An unblocked surge hits when its brace window closes; a new one never starts on the edge.
  def self.surge_tick(bout, ev)
    s = bout[:surge]
    if s
      return unless bout[:t] > s + BRACE_AFTER + EPS
      bout[:surge] = nil
      bout[:drain] += bout[:cfg][:hit]
      bout[:next_surge] = interval(bout)
      ev << :hit
    elsif !bout[:edge] && bout[:t] >= bout[:next_surge]
      bout[:surge] = bout[:t] + bout[:cfg][:tell]
      ev << :tell
    end
  end

  def self.edge_tick(bout, ev)
    if !bout[:edge] && bout[:b] <= EDGE_IN
      bout[:edge] = true
      ev << :edge_in
    elsif bout[:edge] && bout[:b] > EDGE_OUT
      bout[:edge] = false
      bout[:strain_until] = bout[:t] + STRAIN_TIME
      bout[:next_surge] = [bout[:next_surge], interval(bout)].max
      ev << :edge_out
    end
  end

  def self.end_tick(bout, ev)
    if bout[:b] >= 100
      finish(bout, :win, :pin, ev, :pin_win)
    elsif bout[:b] <= -100
      finish(bout, :loss, :pin, ev, :pin_loss)
    elsif bout[:t] >= CAP - EPS
      finish(bout, bout[:b] >= 0 ? :win : :loss, :timeup, ev, :timeup)
    end
  end

  def self.finish(bout, outcome, reason, ev, event)
    bout[:over] = outcome
    bout[:reason] = reason
    ev << event
  end

  def self.over?(bout)
    !bout[:over].nil?
  end

  # :win, :loss, or nil while the bout runs.
  def self.outcome(bout)
    bout[:over]
  end

  # 1.0 when a beat has just passed, 0.0 on the next beat centre (the gold ring's shrink).
  def self.ring(bout)
    p = bout[:cfg][:period]
    nxt = ((bout[:t] / p).floor + 1) * p
    ((nxt - bout[:t]) / p).clamp(0.0, 1.0)
  end

  # Degrees for the hands; the player wins to the left (b = +100 -> -72).
  def self.angle(b)
    -b.to_f.clamp(-100.0, 100.0) / 100.0 * MAX_ANGLE
  end

  # aw_arms.png frame i shows angle -72 + 3i.
  def self.frame(b)
    ((angle(b) + MAX_ANGLE) / ANGLE_STEP).round.clamp(0, FRAMES - 1)
  end

  def self.face(bout)
    return :pinned if bout[:over] == :win
    return :won if bout[:over] == :loss
    return :tell if bout[:surge]
    return :strain if bout[:t] < bout[:strain_until]
    return :taunt if bout[:edge]
    return :strain if bout[:b] > FACE_STEADY_MAX
    return :taunt if bout[:b] < FACE_STEADY_MIN
    :steady
  end

  #-----------------------------------------------------------------------------
  # Per-run state ($PokemonGlobal.arm_wrestle). Only these methods write it.
  #-----------------------------------------------------------------------------
  def self.new_state
    { wins: 0, losses: 0, loss_streak: 0, plays: 0 }
  end

  # nil or garbage becomes a fresh state; a Hash is repaired in place.
  def self.normalize(x)
    return new_state unless x.is_a?(Hash)
    new_state.each_key { |k| x[k] = 0 unless x[k].is_a?(Integer) && x[k] >= 0 }
    x.keep_if { |k, _| new_state.key?(k) }
  end

  # :win / :loss count; anything else (:back) changes nothing. Returns the state.
  def self.record!(state, outcome)
    case outcome
    when :win
      state[:wins] += 1
      state[:loss_streak] = 0
      state[:plays] += 1
    when :loss
      state[:losses] += 1
      state[:loss_streak] += 1
      state[:plays] += 1
    end
    state
  end

  # Call after record!: the win line rotates 1, 2, 3 by wins, the loss line by losses.
  def self.win_line(state)
    "BAGS_SHIRPAZ_COWBOY_GIFT_#{(state[:wins] - 1) % WIN_LINES + 1}"
  end

  def self.lose_line(state)
    "AW_LOSE_#{(state[:losses] - 1) % LOSE_LINES + 1}"
  end
end
