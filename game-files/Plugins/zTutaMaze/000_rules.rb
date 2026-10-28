#===============================================================================
# Tuta maze - pure rules (no engine calls). Maze, actors, the fixed 1/60 s tick,
# owner AI, phases, melt/lick/return, catch, win, and the saved-state helpers.
# tests/tuta_rules.py mirrors this file line for line (same floats, same order).
#===============================================================================

module TutaMazeRules
  # Legend: # wall, . strawberry, o golden, T Tuta's spawn, H couch, - couch door, = tunnel.
  ROWS = [
    "#####################",
    "#o........#........o#",
    "#.###.###.#.###.###.#",
    "#...................#",
    "#.###.#.#####.#.###.#",
    "#.....#...#...#.....#",
    "#####.#.......#.#####",
    "=====.#.##-##.#.=====",
    "#####.#.#HHH#.#.#####",
    "#####.#.#####.#.#####",
    "#.........T.........#",
    "#.###.###.#.###.###.#",
    "#o..#.....#.....#..o#",
    "#.......#####.......#",
    "#####################"
  ].freeze
  W = 21
  H = 15
  DT = 1.0 / 60
  MAX_TICKS = 3                 # per frame, so a hitch never spirals
  TOTAL = 140
  LIVES = 3
  TUTA_SPEED = 6.6
  TURN_WINDOW = 0.30
  CATCH_R = 0.55
  OWNER_BASE = 5.0
  OWNER_RAMP = 1.2
  OWNER_MIN = 4.0
  OWNER_MAX = 6.4
  TUNNEL_SPEED = 2.5
  MELT_FACTOR = 0.55
  MELT_TIME = 6.0
  MELT_FLASH = 1.5
  RETURN_SPEED = 9.0
  SIT_TIME = 1.0
  READY_TIME = 1.5
  GRACE = 1.0
  CATCH_FREEZE = 1.2
  HOP_TIME = 1.0
  CUT_AHEAD = 4
  EPS = 1e-9
  # [name, seconds]; nil = forever. Restarts each life.
  PHASES = [[:scatter, 6.0], [:chase, 20.0], [:scatter, 5.0], [:chase, 20.0], [:scatter, 4.0], [:chase, nil]].freeze
  OWNERS = [:man, :woman].freeze
  RELEASE = { man: 1.0, woman: 4.0 }.freeze
  SCATTER = { man: [19, 14], woman: [1, 0] }.freeze
  HOME = { man: [9, 8], woman: [11, 8] }.freeze
  EXIT = [10, 6].freeze
  COUCH_Y = 8
  DIFF_STEP = 3                 # tenths of a tile/s per step
  DIFF_MIN_STEPS = -3
  DIFF_MAX_STEPS = 2
  LAST_BERRY = [9, 10].freeze   # the one the F9 "leave 1 strawberry" keeps
  DIRS = { up: [0, -1], left: [-1, 0], down: [0, 1], right: [1, 0] }.freeze
  ORDER = [:up, :left, :down, :right].freeze
  OPP = { up: :down, down: :up, left: :right, right: :left }.freeze

  # Same generator as ArmWrestleRules::Lcg (64-bit, seeded) so Ruby and Python agree.
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

  def self.cell(x, y)
    return "#" if y < 0 || y >= H
    ROWS[y][x % W]
  end

  # Floor for Tuta and for owners choosing a way (door and couch are scripted moves).
  def self.open?(x, y)
    ".o=T".include?(cell(x, y))
  end

  def self.berries
    @berries ||= begin
      list = []
      H.times { |y| W.times { |x| list << [x, y] if ".o".include?(ROWS[y][x]) } }
      list.freeze
    end
  end

  def self.goldens
    @goldens ||= berries.select { |x, y| ROWS[y][x] == "o" }.freeze
  end

  # O(1) membership for the per-tick checks (a frozen Hash: mkxp-z ships no `set` library).
  def self.berry_set
    @berry_set ||= berries.to_h { |c| [c, true] }.freeze
  end

  def self.golden_set
    @golden_set ||= goldens.to_h { |c| [c, true] }.freeze
  end

  def self.spawn
    @spawn ||= begin
      y = ROWS.index { |r| r.include?("T") }
      [ROWS[y].index("T"), y].freeze
    end
  end

  def self.tile(a)
    [(a[:x] + 0.5).floor % W, (a[:y] + 0.5).floor]
  end

  def self.wrap(a)
    a[:x] += W if a[:x] < -0.5
    a[:x] -= W if a[:x] > W - 0.5
  end

  def self.gap(a, b)
    dx = (a[:x] - b[:x]).abs
    dx = W - dx if dx > W / 2.0
    dy = (a[:y] - b[:y]).abs
    Math.sqrt(dx * dx + dy * dy)
  end

  #-----------------------------------------------------------------------------
  # Game
  #-----------------------------------------------------------------------------
  def self.new_game(diff: 0.0, seed: 1, eaten: [])
    g = { mode: :ready, mode_t: 0.0, lives: LIVES, diff: diff.to_f, rng: Lcg.new(seed), eaten: {},
          time: 0.0, started: false, win_time: nil, life_t: 0.0, phase_i: 0, phase_t: 0.0,
          melt_t: 0.0, catcher: nil, tuta: nil, owners: nil }
    eaten.each { |c| g[:eaten][[c[0], c[1]]] = true if berry_set[[c[0], c[1]]] }
    reset_positions(g)
    g
  end

  def self.reset_positions(g)
    sx, sy = spawn
    g[:tuta] = { x: sx.to_f, y: sy.to_f, dir: nil, face: :left, want: nil, snap: nil }
    g[:owners] = OWNERS.map do |id|
      { id: id, x: HOME[id][0].to_f, y: HOME[id][1].to_f, dir: nil, state: :couch, melted: false, sit_t: 0.0 }
    end
    g[:life_t] = 0.0
    g[:phase_i] = 0
    g[:phase_t] = 0.0
    g[:melt_t] = 0.0
    g[:catcher] = nil
  end

  def self.eaten_count(g) = g[:eaten].size
  def self.over?(g) = g[:mode] == :won || g[:mode] == :lost
  def self.owner(g, id) = g[:owners].find { |o| o[:id] == id }

  def self.phase(g)
    PHASES[[g[:phase_i], PHASES.length - 1].min][0]
  end

  def self.owner_speed(g)
    (OWNER_BASE + OWNER_RAMP * eaten_count(g) / TOTAL.to_f + g[:diff]).clamp(OWNER_MIN, OWNER_MAX)
  end

  def self.tunnel?(a)
    x, y = tile(a)
    y == 7 && (x <= 4 || x >= 16)
  end

  def self.speed_of(g, o)
    case o[:state]
    when :returning, :entering then RETURN_SPEED
    when :leaving then owner_speed(g)
    when :active
      s = owner_speed(g)
      s *= MELT_FACTOR if o[:melted]
      s = TUNNEL_SPEED if tunnel?(o) && s > TUNNEL_SPEED
      s
    else 0.0
    end
  end

  # One 1/60 s step. press: a direction symbol (the stick just moved) or nil. Returns events.
  def self.tick(g, press = nil)
    ev = []
    return ev if over?(g)
    g[:tuta][:want] = press if press
    g[:time] += DT if g[:started] && g[:mode] != :hop
    g[:mode_t] += DT
    case g[:mode]
    when :ready
      if g[:mode_t] >= READY_TIME - EPS
        g[:mode] = :play
        g[:mode_t] = 0.0
        g[:started] = true
        ev << [:go]
      end
    when :play then play_tick(g, ev)
    when :caught then lose_life(g, ev) if g[:mode_t] >= CATCH_FREEZE - EPS
    when :hop
      if g[:mode_t] >= HOP_TIME - EPS
        g[:mode] = :won
        ev << [:won]
      end
    end
    ev
  end

  def self.play_tick(g, ev)
    g[:life_t] += DT
    move_tuta(g)
    eat(g, ev)
    if eaten_count(g) >= TOTAL
      g[:mode] = :hop
      g[:mode_t] = 0.0
      g[:win_time] = g[:time]
      ev << [:clear]
      return
    end
    if g[:melt_t] > 0
      g[:melt_t] -= DT
      if g[:melt_t] <= EPS
        g[:melt_t] = 0.0
        g[:owners].each { |o| o[:melted] = false }
        ev << [:melt_end]
      end
    else
      advance_phase(g, ev)
    end
    g[:owners].each do |o|
      o[:state] = :leaving if o[:state] == :couch && g[:life_t] >= RELEASE[o[:id]] - EPS
      if o[:state] == :sitting
        o[:sit_t] -= DT
        o[:state] = :leaving if o[:sit_t] <= EPS
      end
      move_owner(g, o, speed_of(g, o) * DT)
    end
    contacts(g, ev)
  end

  def self.advance_phase(g, ev)
    dur = PHASES[[g[:phase_i], PHASES.length - 1].min][1]
    return unless dur
    g[:phase_t] += DT
    return if g[:phase_t] < dur - EPS
    g[:phase_i] += 1
    g[:phase_t] = 0.0
    g[:owners].each { |o| o[:dir] = OPP[o[:dir]] if o[:state] == :active && o[:dir] }
    ev << [:phase, phase(g)]
  end

  def self.eat(g, ev)
    c = tile(g[:tuta])
    return unless berry_set[c] && !g[:eaten][c]
    g[:eaten][c] = true
    ev << [:eat, c[0], c[1]]
    return unless golden_set[c]
    g[:melt_t] = MELT_TIME
    g[:owners].each do |o|
      next unless o[:state] == :active
      o[:melted] = true
      o[:dir] = OPP[o[:dir]] if o[:dir]
    end
    ev << [:golden]
  end

  # Melted owner touched: a lick, back to the couch. Normal owner after the grace: a catch.
  def self.contacts(g, ev)
    g[:owners].each do |o|
      next unless o[:state] == :active && gap(g[:tuta], o) < CATCH_R
      if o[:melted]
        o[:melted] = false
        o[:state] = :returning
        ev << [:lick, o[:id]]
      elsif g[:life_t] >= GRACE - EPS
        g[:mode] = :caught
        g[:mode_t] = 0.0
        g[:catcher] = o[:id]
        ev << [:catch, o[:id]]
        return
      end
    end
  end

  def self.lose_life(g, ev)
    g[:lives] -= 1
    if g[:lives] <= 0
      g[:mode] = :lost
      ev << [:lost]
    else
      reset_positions(g)
      g[:mode] = :ready
      g[:mode_t] = 0.0
      ev << [:ready]
    end
  end

  #-----------------------------------------------------------------------------
  # Movement
  #-----------------------------------------------------------------------------
  # Reverse anywhere; a perpendicular want within TURN_WINDOW of a centre turns there and
  # eases onto the centre line (Pac-Man cornering): the off-axis slide is at most one tick's travel.
  def self.move_tuta(g)
    t = g[:tuta]
    dist = TUTA_SPEED * DT
    want = t[:want]
    if want && want == t[:dir]
      t[:want] = nil
    elsif want && t[:dir] && want == OPP[t[:dir]]
      t[:dir] = want
      t[:face] = want
      t[:want] = nil
    elsif want
      cx = (t[:x] + 0.5).floor
      cy = (t[:y] + 0.5).floor
      off = (t[:x] - cx).abs + (t[:y] - cy).abs
      dx, dy = DIRS[want]
      if off <= TURN_WINDOW + EPS && open?(cx + dx, cy + dy)
        t[:snap] = dx != 0 ? cy.to_f : cx.to_f
        t[:dir] = want
        t[:face] = want
        t[:want] = nil
      end
    end
    slide_tuta(t, dist)
    step_tuta(t, dist)
  end

  # Moves the off-axis coordinate toward the turn's centre line by at most dist.
  def self.slide_tuta(t, dist)
    return unless t[:snap] && t[:dir]
    key = DIRS[t[:dir]][0] != 0 ? :y : :x
    gap = t[:snap] - t[key]
    if gap.abs <= dist + EPS
      t[key] = t[:snap]
      t[:snap] = nil
    else
      t[key] += gap > 0 ? dist : -dist
    end
    wrap(t)
  end

  def self.step_tuta(t, dist)
    while dist > EPS && t[:dir]
      dx, dy = DIRS[t[:dir]]
      key = dx != 0 ? :x : :y
      s = dx != 0 ? dx : dy
      along = t[key]
      c = (along + 0.5).floor
      if (along - c).abs < EPS
        cx, cy = tile(t)
        break unless open?(cx + dx, cy + dy)
        along = c.to_f
        step = dist < 1.0 ? dist : 1.0
      else
        to = s > 0 ? along.ceil : along.floor
        step = (to - along).abs
        step = dist if dist < step
      end
      t[key] = along + s * step
      dist -= step
      wrap(t)
    end
  end

  def self.at_centre?(a)
    (a[:x] - (a[:x] + 0.5).floor).abs < EPS && (a[:y] - (a[:y] + 0.5).floor).abs < EPS
  end

  # Owners never stop: a decision at every tile centre, then on to the next one.
  def self.move_owner(g, o, dist)
    while dist > EPS && [:leaving, :active, :returning, :entering].include?(o[:state])
      if at_centre?(o)
        o[:x] = ((o[:x] + 0.5).floor % W).to_f
        o[:y] = (o[:y] + 0.5).floor.to_f
        decide(g, o)
        break unless o[:dir] && o[:state] != :sitting
        step = dist < 1.0 ? dist : 1.0
      else
        dx, dy = DIRS[o[:dir]]
        along = dx != 0 ? o[:x] : o[:y]
        s = dx != 0 ? dx : dy
        to = s > 0 ? along.ceil : along.floor
        step = (to - along).abs
        step = dist if dist < step
      end
      dx, dy = DIRS[o[:dir]]
      o[:x] += dx * step
      o[:y] += dy * step
      dist -= step
      wrap(o)
    end
  end

  def self.decide(g, o)
    cx = o[:x].to_i
    cy = o[:y].to_i
    case o[:state]
    when :leaving
      if cx != EXIT[0]
        o[:dir] = cx < EXIT[0] ? :right : :left
      elsif cy > EXIT[1]
        o[:dir] = :up
      else
        o[:state] = :active
        choose(g, o, cx, cy)
      end
    when :entering
      if cy < COUCH_Y
        o[:dir] = :down
      else
        o[:state] = :sitting
        o[:sit_t] = SIT_TIME
        o[:dir] = nil
      end
    when :returning
      if [cx, cy] == EXIT
        o[:state] = :entering
        o[:dir] = :down
      else
        route_home(o, cx, cy)
      end
    else
      choose(g, o, cx, cy)
    end
  end

  # Maze distance of every floor tile to the couch exit (BFS with the wrap).
  def self.home_dist
    @home_dist ||= begin
      d = { EXIT => 0 }
      q = [EXIT]
      until q.empty?
        x, y = q.shift
        ORDER.each do |k|
          nx = (x + DIRS[k][0]) % W
          ny = y + DIRS[k][1]
          next if !open?(nx, ny) || d.key?([nx, ny])
          d[[nx, ny]] = d[[x, y]] + 1
          q << [nx, ny]
        end
      end
      d.freeze
    end
  end

  # A licked owner takes the shortest way home (greedy targeting loops in the 2x2 blocks).
  def self.route_home(o, cx, cy)
    best = nil
    best_d = nil
    ORDER.each do |k|
      v = home_dist[[(cx + DIRS[k][0]) % W, cy + DIRS[k][1]]]
      next if v.nil? || (best_d && v >= best_d)
      best = k
      best_d = v
    end
    o[:dir] = best
  end

  # No reversal; closest next tile to the target (Euclidean), ties up > left > down > right.
  def self.choose(g, o, cx, cy)
    back = OPP[o[:dir]]
    opts = ORDER.select { |d| d != back && open?(cx + DIRS[d][0], cy + DIRS[d][1]) }
    opts = [back] if opts.empty? && back
    return if opts.empty?
    if o[:melted]
      o[:dir] = opts[(g[:rng].rand * opts.length).floor]
      return
    end
    tx, ty = target(g, o)
    best = nil
    best_d = nil
    opts.each do |d|
      nx = cx + DIRS[d][0] - tx
      ny = cy + DIRS[d][1] - ty
      dd = nx * nx + ny * ny
      next if best_d && dd >= best_d
      best = d
      best_d = dd
    end
    o[:dir] = best
  end

  def self.target(g, o)
    return SCATTER[o[:id]] if phase(g) == :scatter
    tx, ty = tile(g[:tuta])
    return [tx, ty] if o[:id] == :man
    dx, dy = DIRS[g[:tuta][:face]]
    [(tx + CUT_AHEAD * dx).clamp(0, W - 1), (ty + CUT_AHEAD * dy).clamp(0, H - 1)]
  end

  # Canonical final-state string: the Ruby/Python parity check compares these.
  def self.digest(g)
    f = ->(v) { format("%.6f", v) }
    n = ->(v) { v.nil? ? "nil" : v.to_s }
    parts = [n.(g[:mode]), g[:lives], eaten_count(g), g[:phase_i], f.(g[:time]), f.(g[:melt_t]),
             f.(g[:tuta][:x]), f.(g[:tuta][:y]), n.(g[:tuta][:dir]), n.(g[:tuta][:face])]
    g[:owners].each { |o| parts += [n.(o[:id]), n.(o[:state]), f.(o[:x]), f.(o[:y]), n.(o[:dir]), o[:melted] ? 1 : 0] }
    parts << g[:eaten].keys.sort.map { |x, y| "#{x},#{y}" }.join(";")
    parts.join("|")
  end

  #-----------------------------------------------------------------------------
  # Saved state ($PokemonGlobal.tuta_maze) and the silent difficulty
  #-----------------------------------------------------------------------------
  def self.new_state
    { wins: 0, losses_streak: 0, best_time: nil, plays: 0 }
  end

  def self.normalize(x)
    return new_state unless x.is_a?(Hash)
    [:wins, :losses_streak, :plays].each { |k| x[k] = 0 unless x[k].is_a?(Integer) && x[k] >= 0 }
    x[:best_time] = nil unless x[:best_time].is_a?(Numeric) && x[:best_time] > 0
    x.keep_if { |k, _| new_state.key?(k) }
  end

  # +0.3 per win (cap +0.6), -0.3 per loss in a row (floor -0.9), in exact tenths.
  def self.diff(state)
    steps = ([state[:wins], 2].min - state[:losses_streak]).clamp(DIFF_MIN_STEPS, DIFF_MAX_STEPS)
    steps * DIFF_STEP / 10.0
  end

  # :won / :lost count; :quit changes nothing. Returns true on a new best time.
  def self.record!(state, result, time = nil)
    case result
    when :won
      state[:wins] += 1
      state[:losses_streak] = 0
      state[:plays] += 1
      if time && time > 0 && (state[:best_time].nil? || time < state[:best_time])
        state[:best_time] = time
        return true
      end
    when :lost
      state[:losses_streak] += 1
      state[:plays] += 1
    end
    false
  end

  def self.clock(t)
    s = t.to_f.floor
    format("%d:%02d", s / 60, s % 60)
  end
end
