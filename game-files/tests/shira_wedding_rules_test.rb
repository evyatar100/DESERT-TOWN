# TG48 Shira's wedding: loaded from plugin_rules_test.rb (shares check/$failures and ROOT).
# ShiraWeddingRules is pure; the scene and map flow run in their own process (shira_wedding_scene_smoke.rb).
require "json"
require "rbconfig"
%w[000_rules].each { |f| require File.join(ROOT, "Plugins/zShiraWedding", "#{f}.rb") }

module ShiraWeddingTest
  R = ShiraWeddingRules
  DIR = File.join(ROOT, "Plugins/zShiraWedding")
  FIRST20 = "mmmmcmmcmmcmcmmmcmmc"   # Lcg(48), dt 1/60, always free on the Playa (same literal in Python)

  class Bag
    attr_reader :items
    def initialize(items = {}) = (@items = Hash.new(0).merge(items))
    def quantity(i) = @items[i]
    def add(i, n = 1) = (@items[i] += n; true)
    def remove(i, n = 1)
      return false if @items[i] < n
      @items[i] -= n
      true
    end
  end

  #--- T8 board: brute force over all 9! arrangements ----------------------------------
  all = R::SEATS.permutation.map { |seats| R::SEATS.map { |s| R::GUESTS.keys[seats.index(s)] } }
  sets = all.map { |arr| R.broken(arr) }
  sols = all.each_index.select { |i| sets[i].empty? }.map { |i| all[i] }
  tables = sols.map { |a| a.each_with_index.map { |g, i| [g, R.table(R::SEATS[i])] }.sort }.uniq
  check(all.length == 362_880 && sols.length == 8 && tables.length == 1, "shira board T8: brute force gives 8 seat-level solutions, 1 table arrangement (#{sols.length}/#{tables.length})")
  check(sols.sort == R::SOLUTIONS.sort, "shira board T8: SOLUTIONS equals the brute force")
  want = { angel_kids: 96, yaarul_kids: 184, torli_lamp: 544, kids_apart: 16, johnny_bar: 32, dj_not_dj: 16, food_fight: 24, gavri_dj: 16, chen_toga: 88 }
  got = R::RULES.keys.to_h { |r| [r, sets.count { |b| (b - [r]).empty? }] }
  check(got == want, "shira board T8: every rule is necessary (the D7 table) #{got.inspect}")
  check(R.broken(R::START).length == 8 && !R.broken(R::START).include?(:gavri_dj), "shira board T8: START breaks 8 rules, all but gavri_dj")
  check(R::SOLUTIONS.map { |s| R.swap_distance(R::START, s) }.min == R::MIN_SWAPS, "shira board T8: the minimum from START is 6 swaps")
  check(all.first(5000).all? { |a| R.solved?(a) == (R.complaints(a) == 0) }, "shira board T8: solved? exactly when complaints == 0")
  check(R::GUESTS.keys.include?(:angel) && !R::GUESTS.key?(:boss) && R::GUESTS[:angel] == "2f88eb7f", "shira board: Angel Eyes Junior replaced the Boss")
  sol = R::SOLUTIONS.first
  check(R.table(R::SEATS[sol.index(:chen)]) == "A" && sol.index(:torli) == 8 && sol.index(:angel) == 7 && sol.index(:yaarul) == 6,
        "shira board: the table arrangement is A Chen+Toga, K1 Yaarul, K2 Angel, K3 Tor Li Or")

  #--- T10 hint -------------------------------------------------------------------------
  def self.follow(arr)
    n = 0
    while (h = R.hint(arr))
      arr = R.swap(arr, *h)
      n += 1
      return nil if n > 20
    end
    [arr, n]
  end
  fin, n = follow(R::START)
  check(R.solved?(fin) && n == 6, "shira hint T10: from START the hints solve in exactly 6 swaps (#{n})")
  rng = Random.new(48)
  ok = 1000.times.all? do
    arr = R::GUESTS.keys.shuffle(random: rng)
    d = R::SOLUTIONS.map { |s| R.swap_distance(arr, s) }.min
    f, k = follow(arr)
    f && R.solved?(f) && k == d
  end
  check(ok, "shira hint T10: from 1,000 random boards the hints always solve within the swap distance")

  #--- NAV ------------------------------------------------------------------------------
  nav_ok = R::NAV[:A1][:down] == :K1 && R::NAV[:B2][:down] == :K2 && R::NAV[:C2][:down] == :K3 &&
           R::NAV[:K1][:up] == :B1 && R::NAV[:K2][:up] == :B1 && R::NAV[:K3][:up] == :B2 &&
           R::NAV[:A1][:left].nil? && R::NAV[:C2][:right].nil? && R::NAV[:K3][:right].nil? &&
           R::NAV.values.flat_map(&:values).all? { |s| R::SEATS.include?(s) } && R::NAV.keys == R::SEATS
  check(nav_ok, "shira board: NAV matches D7 (no wrap)")
  mood = R.react(R::START, R.swap(R::START, 0, 6), 0, 6)
  check(mood == [:angel, :happy], "shira board: a swap that fixes Angel gives a happy bubble (#{mood.inspect})")

  #--- T2/T3 scheduler ------------------------------------------------------------------
  free = { on_playa: true, free: true, crossing: false }
  s = R.new_sched
  g = R::Lcg.new(48)
  out = []
  first_at = nil
  216_000.times do |f|
    o = R.tick(s, 1.0 / 60, free, g)
    next if o == :none
    first_at ||= (f + 1) / 60.0
    out << o
  end
  check(out.length == 20 && first_at >= 180.0 && first_at < 180.1, "shira sched T2: no roll before 180 s, exactly 20 rolls in 3,600 s (#{out.length}, first #{first_at})")
  check(out.map { |o| o == :cross ? "c" : "m" }.join == FIRST20, "shira sched T2: the first 20 outcomes match the Python mirror")
  g = R::Lcg.new(48)
  share = 10_000.times.count { R.tick({ clock: 0.0, due: true, since_arrival: 9.0 }, 0.0, free, g) == :cross } / 10_000.0
  check(share.between?(0.48, 0.52), "shira sched T2: the cross share over 10,000 rolls is 0.48-0.52 (#{share})")
  s = { clock: 179.9, due: false, since_arrival: 0.0 }
  away = 60.times.map { R.tick(s, 0.1, free.merge(on_playa: false), g) }
  check(away.all?(:none) && s[:due] && s[:since_arrival] == 0.0, "shira sched T3: a due check off the Playa never fires and stays due")
  arrive = (1..400).find { |k| R.tick(s, 1.0 / 60, free, g) != :none }
  check(arrive && arrive >= 300 && arrive <= 301, "shira sched T3: it fires 5 s after arriving on the Playa (frame #{arrive})")
  s = { clock: 179.9, due: false, since_arrival: 10.0 }
  busy = 30.times.map { R.tick(s, 0.1, free.merge(free: false), g) }
  check(busy.all?(:none) && s[:due], "shira sched T3: busy frames never fire and keep the due flag")
  check(R.tick(s, 0.1, free, g) != :none, "shira sched T3: the first free frame fires")
  s = R.new_sched
  R.tick(s, 1.0, free.merge(crossing: true), g)
  check(s[:clock] == 0.0, "shira sched T3: a crossing freezes the clock")
  R.tick(s, 30.0, free, g)
  check(s[:clock] == 0.5, "shira sched T3: a 30 s frame adds only 0.5 s")

  #--- pick_row (pure part; the Map098 coverage is in test_shira_wedding.py) ----------------
  v = { x0: 10, y0: 10, w: 42, h: 52, px: 18, py: 16 }
  plan = R.pick_row(v, R::Lcg.new(1), ->(_x, _y) { true })
  check(plan && (plan[:y] - 16).abs == 2 && [plan[:start][0], plan[:stop][0]].sort == [9, 26], "shira sched: an open screen picks a row 2 away, edge to edge (#{plan.inspect})")
  check(R.pick_row(v, R::Lcg.new(1), ->(_x, y) { y == 16 }).nil?, "shira sched: only the player's row clear = a miss")
  far = R.pick_row(v, R::Lcg.new(1), ->(_x, y) { y == 20 })
  check(far && far[:y] == 20, "shira sched: with no row 1-3 away another row is used")
  edge = R.pick_row({ x0: 0, y0: 0, w: 42, h: 52, px: 5, py: 5 }, R::Lcg.new(3), ->(_x, _y) { true })
  check(edge && (edge[:dir] == 6 ? edge[:fade_in] && edge[:start][0] == 0 : edge[:fade_out] && edge[:stop][0] == 0),
        "shira sched: at the map edge the edge tile is used, with a fade")
  check(R.summon_stop([15, 22]) == [16, 22] && R.summon_stop([14, 23]) == [15, 22], "shira T6: the summon stop is (16,22) only when the player stands on (15,22)")

  #--- T6/T9/T12/T13/T16 quest ------------------------------------------------------------
  st = R.new_state
  check(R.talk_decide(st) == :intro && R.start!(st) && st[:stage] == :asked && !R.start!(st), "shira T6: :none talk = intro; start! -> :asked once")
  check(R.talk_decide(st) == :ask_again && R.eviatar_decide(st, :sent) == :summon && R.eviatar_rows(st) == %i[sent pass], "shira T6: :asked = ask again; Eviatar SENT summons")
  bag = Bag.new
  check(!R.give_bag!(st, bag) && bag.quantity(:WEDDINGBAG) == 0, "shira T12: give_bag! outside :seated is a no-op")
  check(!R.seat!(st, 5) && st[:stage] == :asked, "shira: seat! refuses fewer than 6 swaps")
  check(R.seat!(st, 9) && st == { stage: :seated, best: 9 } && R.talk_decide(st) == :reward, "shira: the first solve seats and records best")
  check(R.give_bag!(st, bag) && !R.give_bag!(st, bag) && bag.quantity(:WEDDINGBAG) == 1 && st[:stage] == :bag, "shira T12: give_bag! twice gives 1")
  check(R.bag_given?(st) && R.talk_decide(st) == :final, "shira: :bag counts as given and resumes at FINAL")
  check(!R.reissue!(st, bag, false) && bag.quantity(:WEDDINGBAG) == 1, "shira T12: reissue! while held is a no-op")
  check(R.finish!(st) && !R.finish!(st) && st[:stage] == :done, "shira T15: finish! is the single :bag -> :done step")
  check(R.seat!(st, 6) && st == { stage: :done, best: 6 } && bag.quantity(:WEDDINGBAG) == 1, "shira T9: a replay in :done changes only best, never the stage or the item")
  check(R.eviatar_rows(st) == %i[mazaltov sent pass] && R.eviatar_decide(st, :sent) == :sent_done && R.eviatar_decide(st, :mazaltov) == :thanks,
        "shira T6: Eviatar in :done offers mazal tov and does not summon")
  bag.remove(:WEDDINGBAG, 1)
  check(R.reissue_due?(st, bag, false) && R.reissue!(st, bag, false) && bag.quantity(:WEDDINGBAG) == 1, "shira T13: :done, bag lost, Inbar not done -> reissued, 1 held")
  bag.remove(:WEDDINGBAG, 1)
  check(!R.reissue!(st, bag, true) && bag.quantity(:WEDDINGBAG) == 0, "shira T12: never reissued once Inbar is done")
  bst = { stage: :bag, best: 7 }
  b2 = Bag.new
  check(R.reissue!(bst, b2, false) && b2.quantity(:WEDDINGBAG) == 1, "shira T13: :bag, bag lost -> reissued")
  maxq = 0
  walk = R.new_state
  wb = Bag.new
  [-> { R.start!(walk) }, -> { R.seat!(walk, 8) }, -> { R.give_bag!(walk, wb) }, -> { R.give_bag!(walk, wb) }, -> { R.reissue!(walk, wb, false) },
   -> { R.finish!(walk) }, -> { R.reissue!(walk, wb, false) }, -> { R.seat!(walk, 6) }].each { |f| f.call; maxq = [maxq, wb.quantity(:WEDDINGBAG)].max }
  check(maxq == 1, "shira T12: a walk through every stage never holds more than 1 Wedding Bag")
  junk = { stage: :party, best: 3, extra: 1 }
  check(R.normalize(junk).equal?(junk) && junk == { stage: :none, best: nil }, "shira T16: normalize repairs junk in place")
  check(R.normalize(nil) == R.new_state && R.normalize({ stage: :bag, best: 8 }) == { stage: :bag, best: 8 }, "shira T16: an old save loads fresh; a valid state is kept")
  dbg = Bag.new(WEDDINGBAG: 2)
  f9 = R::STAGES.map { |stg| b = Bag.new(WEDDINGBAG: 2); R.debug_set!(R.new_state, b, stg); b.quantity(:WEDDINGBAG) }
  check(f9 == [0, 0, 0, 1, 1] && dbg, "shira F9: set stage holds one bag in :bag and :done, none before (#{f9.inspect})")

  #--- copy and files -----------------------------------------------------------------------
  meta = File.read(File.join(DIR, "meta.txt"))
  check(meta.include?("Name       = ShiraWedding") && %w[HebrewSupport DesertTalk DesertTownArcade].all? { |r| meta.include?("Requires   = #{r}") },
        "shira_wedding: meta.txt names ShiraWedding and its 3 requirements")
  tr_data = JSON.parse(File.read(File.join(ROOT, "PBS/translations.json"), encoding: "utf-8"))["translations"]
  # Every SHIRA_ key in quotes or %w lists (not the Ruby constant SHIRA_EVENT), plus the built rule/bubble keys.
  keys = Dir.glob(File.join(DIR, "*.rb")).flat_map { |f| File.read(f, encoding: "utf-8").scan(/(?<![A-Za-z0-9_])SHIRA_[A-Z0-9_]*[A-Z0-9](?![A-Za-z0-9_#])/) }.uniq - %w[SHIRA_EVENT]
  keys += R::RULES.keys.map { |r| "SHIRA_RULE_#{r.upcase}" } + %w[SHIRA_R_HAPPY_1 SHIRA_R_HAPPY_2 SHIRA_R_HAPPY_3 SHIRA_R_ANGRY_1 SHIRA_R_ANGRY_2 SHIRA_R_ANGRY_3]
  missing = keys.uniq.reject { |k| tr_data[k] && !tr_data[k]["en"].to_s.strip.empty? && !tr_data[k]["he"].to_s.strip.empty? }
  check(!keys.empty? && missing.empty?, "shira_wedding copy: every SHIRA_* key the code uses has en and he (missing #{missing.inspect})")

  smoke = IO.popen([RbConfig.ruby, File.join(__dir__, "shira_wedding_scene_smoke.rb")], err: [:child, :out], &:read)
  smoke_fails = smoke.lines.grep(/FAIL|Error/).map(&:strip)
  check($?.success? && smoke_fails.empty?, "shira_wedding: scene smoke run passes (#{smoke_fails.first(3).inspect})")
end
