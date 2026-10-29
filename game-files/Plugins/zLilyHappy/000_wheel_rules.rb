#===============================================================================
# LilyHappy - Wheel of Happiness game rules (pure, fixed 1/60 s steps, all clocks in frames).
# Cap proof: hearts rise only by a fix on i, which lowers opp(i) in the same step, and all
# start at 2, so a pair {i, opp(i)} is never both at 5: at most 3 of 6 are happy at once.
#===============================================================================

module LilyHappyRules
  FPS = 60
  DT = 1.0 / 60
  SEATS = 6
  HEART_START = 2
  HEART_MAX = 5
  FIX_GAIN = 2
  FIX_HIT = 1
  CHAIN = 11
  COMP_LINES = 3
  PLAY_F = 5400          # 90.0 s
  FINALE_F = 120         # 2.0 s, no input
  TURN_F = 9             # 0.15 s
  MOOP_LOCK_F = 36       # 0.6 s
  HALF_DELAY_F = 180     # 3.0 s
  SPREAD_DELAY_F = 60    # 1.0 s
  FIRST_SPAWN_F = 30     # 0.5 s, on seat 0
  # [starts at frame, patience, spawn every, max bubbles, fix spawns] (spec D7 phase table)
  PHASES = [[0, 480, 300, 2, 1], [1800, 360, 210, 3, 1], [3600, 270, 150, 4, 2]].freeze
  INPUTS = %i[left right fix comp moop].freeze

  # The 64-bit LCG of ArmWrestleRules::Lcg, copied so the Python mirror matches.
  class Lcg
    MASK = (1 << 64) - 1
    attr_reader :s

    def initialize(seed)
      @s = seed.to_i & MASK
    end

    def rand
      @s = (@s * 6364136223846793005 + 1442695040888963407) & MASK
      (@s >> 11) / 9007199254740992.0
    end
  end

  def self.opp(i) = (i + 3) % SEATS
  def self.front(g) = g[:rot] % SEATS
  def self.phase_at(f) = PHASES.rindex { |p| f >= p[0] }
  def self.happy(g) = g[:hearts].count(HEART_MAX)
  def self.bubble_count(g) = g[:bubbles].count { |b| b }

  def self.new_game(seed)
    { f: 0, phase: 0, hearts: [HEART_START] * SEATS, bubbles: [nil] * SEATS, rot: 0, turn: 0, last_turn: 0,
      buffer: nil, lock: 0, k: 1, laps: 0, fixes: 0, peak: 0, comp_n: 0, spawn_t: FIRST_SPAWN_F,
      first: true, pending: [], over: nil, finale: 0, rng: Lcg.new(seed) }
  end

  # One fixed step. input: nil or one of INPUTS. Returns this step's events (arrays).
  def self.tick(g, input)
    return [] if g[:over] == :done
    return tick_finale(g) if g[:over] == :finale
    ev = []
    g[:f] += 1
    ph = phase_at(g[:f])
    if ph != g[:phase]
      g[:phase] = ph
      ev << [:phase, ph]
    end
    take_input(g, input, ev)
    run_pending(g, ev)
    run_patience(g, ev)
    run_spawner(g, ev)
    g[:peak] = [g[:peak], happy(g)].max
    start_finale(g, ev) if g[:f] >= PLAY_F
    ev
  end

  def self.tick_finale(g)
    g[:finale] += 1
    return [] if g[:finale] < FINALE_F
    g[:over] = :done
    [[:end]]
  end

  def self.start_finale(g, ev)
    g[:over] = :finale
    g[:turn] = 0           # the wheel stops where it is heading
    g[:buffer] = nil
    SEATS.times { |s| g[:bubbles][s] ||= bubble(g, g[:k], false) }
    ev << [:finale]
  end

  # MOOP lockout drops input; a turn holds the latest input (1 deep) until it ends.
  def self.take_input(g, input, ev)
    input = nil unless INPUTS.include?(input)
    if g[:lock] > 0
      g[:lock] -= 1
    elsif g[:turn] > 0
      g[:turn] -= 1
      g[:buffer] = input if input
    else
      act = input || g[:buffer]
      g[:buffer] = nil
      apply(g, act, ev) if act
    end
  end

  def self.apply(g, act, ev)
    case act
    when :left, :right
      d = act == :right ? 1 : -1
      g[:rot] += d
      g[:turn] = TURN_F
      g[:last_turn] = d
      ev << [:turn, d]
    when :fix then fix(g, ev)
    when :comp then compromise(g, ev)
    when :moop
      g[:lock] = MOOP_LOCK_F
      ev << [:moop]
    end
  end

  def self.fix(g, ev)
    fr = front(g)
    return ev << [:nofix] unless g[:bubbles][fr]
    o = opp(fr)
    g[:hearts][fr] = [g[:hearts][fr] + FIX_GAIN, HEART_MAX].min
    g[:hearts][o] = [g[:hearts][o] - FIX_HIT, 0].max
    g[:bubbles][fr] = nil
    g[:fixes] += 1
    ev << [:fix, fr, g[:k]]
    nxt = g[:k] % CHAIN + 1
    seat = o
    PHASES[g[:phase]][4].times do
      seat = free_from(g, seat, fr)
      break unless seat
      spawn(g, seat, nxt, false, ev)
      seat = (seat + 1) % SEATS
    end
    g[:k] = nxt
    g[:laps] += 1 if nxt == 1
  end

  def self.compromise(g, ev)
    fr = front(g)
    o = opp(fr)
    return ev << [:nocomp] unless g[:bubbles][fr] && g[:bubbles][o]
    g[:bubbles][fr] = g[:bubbles][o] = nil
    g[:comp_n] = g[:comp_n] % COMP_LINES + 1
    ev << [:comp, g[:comp_n]]
    [fr, o].each { |s| g[:pending] << [g[:f] + HALF_DELAY_F, s, g[:k], true] }
  end

  # The first seat from start (clockwise = +1) that is free and not the front seat.
  def self.free_from(g, start, fr)
    SEATS.times do |i|
      s = (start + i) % SEATS
      return s if s != fr && g[:bubbles][s].nil?
    end
    nil
  end

  def self.bubble(g, step, half)
    pat = PHASES[g[:phase]][1]
    { step: step, left: pat, total: pat, half: half }
  end

  def self.spawn(g, seat, step, half, ev)
    g[:bubbles][seat] = bubble(g, step, half)
    ev << [:spawn, seat, step, half ? 1 : 0]
  end

  # Delayed spawns (spread after an expiry, HALF after a compromise) land only on a free seat.
  def self.run_pending(g, ev)
    due, g[:pending] = g[:pending].partition { |p| p[0] <= g[:f] }
    due.each { |_t, seat, step, half| spawn(g, seat, step, half, ev) unless g[:bubbles][seat] }
  end

  def self.run_patience(g, ev)
    SEATS.times do |s|
      b = g[:bubbles][s]
      next unless b
      b[:left] -= 1
      next if b[:left] > 0
      g[:bubbles][s] = nil
      g[:hearts][s] = [g[:hearts][s] - 1, 0].max
      ev << [:expire, s]
      g[:pending] << [g[:f] + SPREAD_DELAY_F, (s + 1) % SEATS, b[:step], b[:half]]
    end
  end

  def self.run_spawner(g, ev)
    g[:spawn_t] -= 1 if g[:spawn_t] > 0
    return if g[:spawn_t] > 0 || bubble_count(g) >= PHASES[g[:phase]][3]
    free = (0...SEATS).select { |s| g[:bubbles][s].nil? }
    return if free.empty?
    seat = g[:first] && free.include?(0) ? 0 : free[(g[:rng].rand * free.size).floor]
    g[:first] = false
    spawn(g, seat, g[:k], false, ev)
    g[:spawn_t] = PHASES[g[:phase]][2]
  end

  #--- bots (tests and smoke; pure) ----------------------------------------------------
  def self.random_input(rng)
    r = rng.rand
    return :left if r < 0.05
    return :right if r < 0.10
    return :fix if r < 0.18
    return :comp if r < 0.21
    return :moop if r < 0.22
    nil
  end

  # Fixes only seats 0..2 (one per pair) and turns toward the nearest one with a bubble.
  def self.bot_input(g)
    fr = front(g)
    return :fix if fr < 3 && g[:bubbles][fr]
    best = nil
    [0, 1, 2].each do |t|
      next unless g[:bubbles][t]
      d = (t - fr) % SEATS
      d -= SEATS if d > 3
      best = d if best.nil? || d.abs < best.abs
    end
    return nil unless best
    best > 0 ? :right : :left
  end
end
