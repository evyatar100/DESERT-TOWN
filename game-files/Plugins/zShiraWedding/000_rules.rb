#===============================================================================
# Shira's wedding (TG48) - pure rules, no engine calls. Python mirror: tests/shira_wedding_rules.py.
# Board "סידורי הושבה בגיהינום" (D7), quest stages (D4/D5), the wandering scheduler (D3).
#===============================================================================

module ShiraWeddingRules
  #-----------------------------------------------------------------------------
  # Board (D7). An arrangement is an Array of 9 guest symbols, index = seat index.
  #-----------------------------------------------------------------------------
  SEATS = %i[A1 A2 B1 B2 C1 C2 K1 K2 K3].freeze
  GUESTS = {
    angel: "2f88eb7f", yaarul: "fcba2ff5", torli: "a7ba5185", johnny: "4b08e38a", djsheshe: "fc898478",
    gavri: "d4540277", tal: "9b3660d1", chen: "a003ee69", toga: "7a2a022c"
  }.freeze
  # rule -> [guests it reads, guests who complain when it is broken]
  RULES = {
    angel_kids: [%i[angel], %i[angel]],
    yaarul_kids: [%i[yaarul], %i[yaarul]],
    torli_lamp: [%i[torli], %i[torli]],
    kids_apart: [%i[yaarul torli], %i[yaarul torli]],
    johnny_bar: [%i[johnny], %i[johnny]],
    dj_not_dj: [%i[djsheshe], %i[djsheshe]],
    food_fight: [%i[gavri tal], %i[gavri tal]],
    gavri_dj: [%i[gavri djsheshe], %i[gavri]],
    chen_toga: [%i[chen toga], %i[chen]]
  }.freeze
  START = %i[angel djsheshe johnny toga yaarul torli gavri tal chen].freeze   # the caterer's draft
  MIN_SWAPS = 6
  # Joystick moves between seats; nil = no move (no wrap).
  NAV = {
    A1: { right: :A2, down: :K1 }, A2: { left: :A1, right: :B1, down: :K1 },
    B1: { left: :A2, right: :B2, down: :K1 }, B2: { left: :B1, right: :C1, down: :K2 },
    C1: { left: :B2, right: :C2, down: :K3 }, C2: { left: :C1, down: :K3 },
    K1: { right: :K2, up: :B1 }, K2: { left: :K1, right: :K3, up: :B1 }, K3: { left: :K2, up: :B2 }
  }.freeze

  def self.table(seat) = seat.to_s[0]
  def self.next_to?(a, b) = table(a) == table(b) && (a.to_s[1].to_i - b.to_s[1].to_i).abs == 1

  # guest -> seat symbol
  def self.seats_of(arr) = arr.each_with_index.to_h { |g, i| [g, SEATS[i]] }

  def self.rule_ok?(rule, p)
    case rule
    when :angel_kids then table(p[:angel]) == "K"
    when :yaarul_kids then table(p[:yaarul]) == "K"
    when :torli_lamp then p[:torli] == :K3
    when :kids_apart then !next_to?(p[:yaarul], p[:torli])
    when :johnny_bar then table(p[:johnny]) == "C"
    when :dj_not_dj then table(p[:djsheshe]) != "A"
    when :food_fight then table(p[:gavri]) != table(p[:tal])
    when :gavri_dj then table(p[:gavri]) != table(p[:djsheshe])
    when :chen_toga then table(p[:chen]) == table(p[:toga])
    end
  end

  # Broken rules in RULES order; `rules` lets the necessity test drop one.
  def self.broken(arr, rules = RULES.keys)
    p = seats_of(arr)
    rules.reject { |r| rule_ok?(r, p) }
  end

  def self.complaints(arr) = broken(arr).length
  def self.solved?(arr) = broken(arr).empty?
  def self.owners(rule) = RULES.fetch(rule)[1]
  def self.unhappy(arr) = broken(arr).flat_map { |r| owners(r) }.uniq
  def self.rules_of(guest) = RULES.keys.select { |r| owners(r).include?(guest) }

  def self.swap(arr, i, j)
    out = arr.dup
    out[i], out[j] = out[j], out[i]
    out
  end

  # Every solution, by backtracking: a rule is checked once all the guests it reads are seated.
  def self.solve_all(rules = RULES.keys)
    out = []
    guests = GUESTS.keys
    pos = {}
    walk = lambda do |k|
      if k == guests.length
        out << SEATS.map { |s| pos.key(s) }
        return
      end
      g = guests[k]
      SEATS.each do |s|
        next if pos.value?(s)
        pos[g] = s
        ok = rules.all? { |r| !RULES[r][0].include?(g) || !RULES[r][0].all? { |x| pos.key?(x) } || rule_ok?(r, pos) }
        walk.call(k + 1) if ok
        pos.delete(g)
      end
    end
    walk.call(0)
    out.sort_by { |arr| arr.map { |g| guests.index(g) } }
  end

  SOLUTIONS = solve_all.freeze

  # Fewest swaps from a to b (same guests): 9 minus the cycles of the seat mapping.
  def self.swap_distance(a, b)
    seen = Array.new(a.length, false)
    cycles = 0
    a.each_index do |i|
      next if seen[i]
      cycles += 1
      j = i
      until seen[j]
        seen[j] = true
        j = b.index(a[j])
      end
    end
    a.length - cycles
  end

  def self.nearest(arr) = SOLUTIONS.min_by.with_index { |s, i| [swap_distance(arr, s), i] }

  # [seat index of the first misplaced guest, seat index where they belong], or nil when solved.
  def self.hint(arr)
    return nil if solved?(arr)
    sol = nearest(arr)
    i = arr.each_index.find { |k| arr[k] != sol[k] }
    [i, sol.index(arr[i])]
  end

  # After swapping seats i and j: the first moved guest whose mood changed, [guest, :happy/:angry].
  def self.react(before, after, i, j)
    was = unhappy(before)
    now = unhappy(after)
    [after[j], after[i]].each do |g|
      next if was.include?(g) == now.include?(g)
      return [g, now.include?(g) ? :angry : :happy]
    end
    nil
  end

  #-----------------------------------------------------------------------------
  # Quest (D4/D5). The saved hash is { stage:, best: }.
  #-----------------------------------------------------------------------------
  ITEM = :WEDDINGBAG
  STAGES = %i[none asked seated bag done].freeze
  KEYS = %i[stage best].freeze

  def self.new_state = { stage: :none, best: nil }

  # In place, so a held reference to the saved hash stays live; garbage loads fresh.
  def self.normalize(state)
    return new_state unless state.is_a?(Hash)
    state.keys.each { |k| state.delete(k) unless KEYS.include?(k) }
    state[:stage] = :none unless STAGES.include?(state[:stage])
    state[:best] = nil unless state[:best].is_a?(Integer) && state[:best] >= MIN_SWAPS
    state
  end

  def self.rank(stage) = STAGES.index(stage)
  def self.held?(bag) = !!(bag && bag.quantity(ITEM).to_i > 0)
  def self.bag_given?(state) = %i[bag done].include?(state[:stage])

  # What a talk with Shira does.
  def self.talk_decide(state)
    { none: :intro, asked: :ask_again, seated: :reward, bag: :final, done: :after }.fetch(state[:stage])
  end

  # Eviatar's menu rows, and what SENT does.
  def self.eviatar_rows(state)
    state[:stage] == :done ? %i[mazaltov sent pass] : %i[sent pass]
  end

  def self.eviatar_decide(state, row)
    return :sent_done if row == :sent && state[:stage] == :done
    { sent: :summon, pass: :pass, mazaltov: :thanks }[row]
  end

  def self.reissue_due?(state, bag, inbar_done)
    bag_given?(state) && !!bag && !held?(bag) && !inbar_done
  end

  # QuestMarks (TG65), Playa only: Eviatar (always findable, summons her) and Shira's event,
  # which the overlay draws only while she is visibly crossing (blank page = no mark).
  MARK_MAP = 98
  MARK_EVIATAR = "shira_eviatar"
  MARK_SHIRA = "shira_wedding"

  def self.marks(state, map_id)
    return {} unless map_id == MARK_MAP
    case state[:stage]
    when :none then { giver: [MARK_EVIATAR] }
    when :asked, :seated, :bag then { next: [MARK_EVIATAR, MARK_SHIRA] }
    else {}
    end
  end

  # Mutators: state and item change together, before any message.
  def self.start!(state)
    return false unless state[:stage] == :none
    state[:stage] = :asked
    true
  end

  # The first solve moves :asked -> :seated; later solves only lower best.
  def self.seat!(state, swaps)
    return false unless swaps.is_a?(Integer) && swaps >= MIN_SWAPS
    return false if rank(state[:stage]) < rank(:asked)
    state[:stage] = :seated if state[:stage] == :asked
    state[:best] = [state[:best], swaps].compact.min
    true
  end

  def self.give_bag!(state, bag)
    return false unless state[:stage] == :seated && bag
    return false unless held?(bag) || bag.add(ITEM, 1)
    state[:stage] = :bag
    true
  end

  def self.finish!(state)
    return false unless state[:stage] == :bag
    state[:stage] = :done
    true
  end

  def self.reissue!(state, bag, inbar_done)
    return false unless reissue_due?(state, bag, inbar_done)
    !!bag.add(ITEM, 1)
  end

  # F9 only: that stage, holding one bag in :bag and :done, none before.
  def self.debug_set!(state, bag, stage)
    return false unless STAGES.include?(stage) && bag
    bag.remove(ITEM, bag.quantity(ITEM)) if held?(bag)
    bag.add(ITEM, 1) if bag_given?({ stage: stage })
    state[:stage] = stage
    true
  end

  #-----------------------------------------------------------------------------
  # Wandering scheduler (D3). Session clock only; nothing here is saved.
  #-----------------------------------------------------------------------------
  INTERVAL = 180.0
  CHANCE = 0.5
  GRACE = 5.0
  DT_CAP = 0.5
  SPEED = 4
  NOTICE_PAUSE = 1.5
  BLOCK_GIVEUP = 1.0
  FADE_FRAMES = 8
  SCREEN_W = 16
  SCREEN_H = 12
  PARK = [18, 5].freeze
  SUMMON_ENTRY = [26, 22].freeze
  SUMMON_STOP = [15, 22].freeze
  SUMMON_WAIT = 5.0

  def self.new_sched = { clock: 0.0, due: false, since_arrival: 0.0 }

  # ctx: { on_playa:, free:, crossing: }. Returns :none, :cross or :miss; one roll per interval.
  def self.tick(s, dt, ctx, rng)
    return :none if ctx[:crossing]
    dt = dt.to_f.clamp(0.0, DT_CAP)
    s[:clock] += dt
    s[:due] = true if s[:clock] >= INTERVAL
    s[:since_arrival] = ctx[:on_playa] ? s[:since_arrival] + dt : 0.0
    return :none unless s[:due] && ctx[:on_playa] && ctx[:free] && s[:since_arrival] >= GRACE
    s[:clock] = 0.0
    s[:due] = false
    rng.rand < CHANCE ? :cross : :miss
  end

  # v: { x0:, y0:, w:, h:, px:, py: } in tiles; ok.(x, y) = the tile is clear for her.
  # Returns { y:, dir:, start:, stop:, fade_in:, fade_out: } or nil (the roll is a miss).
  def self.pick_row(v, rng, ok)
    a = [v[:x0] - 1, 0].max
    b = [v[:x0] + SCREEN_W, v[:w] - 1].min
    rows = ((v[:y0] + 1)..(v[:y0] + 10)).select do |y|
      y.between?(0, v[:h] - 1) && y != v[:py] && (a..b).all? { |x| ok.call(x, y) }
    end
    return nil if rows.empty?
    near = rows.select { |y| (y - v[:py]).abs.between?(1, 3) }
    two = near.select { |y| (y - v[:py]).abs == 2 }
    pool = two.empty? ? (near.empty? ? rows : near) : two
    y = pool[(rng.rand * pool.length).floor.clamp(0, pool.length - 1)]
    ltr = rng.rand < 0.5
    edge_a = v[:x0] - 1 < 0
    edge_b = v[:x0] + SCREEN_W > v[:w] - 1
    if ltr
      { y: y, dir: 6, start: [a, y], stop: [b, y], fade_in: edge_a, fade_out: edge_b }
    else
      { y: y, dir: 4, start: [b, y], stop: [a, y], fade_in: edge_b, fade_out: edge_a }
    end
  end

  def self.summon_stop(player_xy)
    player_xy == SUMMON_STOP ? [SUMMON_STOP[0] + 1, SUMMON_STOP[1]] : SUMMON_STOP
  end

  def self.chebyshev(a, b) = [(a[0] - b[0]).abs, (a[1] - b[1]).abs].max

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
end
