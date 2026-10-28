# TG31 Tuta maze: loaded from plugin_rules_test.rb (shares check/$failures).
# TutaMazeRules is pure; the scene runs in its own process (tuta_scene_smoke.rb).
require "json"
%w[000_rules 001_state].each { |f| require File.join(ROOT, "Plugins/zTutaMaze", "#{f}.rb") }

module TutaTest
extend self
TDIR = File.join(ROOT, "Plugins/zTutaMaze")
TR = TutaMazeRules
DT = TR::DT

def floor_cells
  cells = []
  TR::H.times { |y| TR::W.times { |x| cells << [x, y] if TR.open?(x, y) } }
  cells
end

def exits(x, y)
  TR::ORDER.count { |d| TR.open?(x + TR::DIRS[d][0], y + TR::DIRS[d][1]) }
end

def reach(from)
  seen = { from => true }
  q = [from]
  until q.empty?
    x, y = q.shift
    TR::ORDER.each do |d|
      n = [(x + TR::DIRS[d][0]) % TR::W, y + TR::DIRS[d][1]]
      next if seen[n] || !TR.open?(*n)
      seen[n] = true
      q << n
    end
  end
  seen
end

# A game in play with the owners parked out of the way (they never move or catch).
def parked(eaten: [])
  g = TR.new_game(eaten: eaten)
  g[:mode] = :play
  g[:started] = true
  g[:owners].each { |o| o[:state] = :parked }
  g
end

def put(o, x, y, dir, state = :active)
  o.merge!(x: x.to_f, y: y.to_f, dir: dir, state: state, melted: false)
end

# T15 / T4: maze shape, counts, reachability, fairness geometry.
check(TR::ROWS.length == 15 && TR::ROWS.all? { |r| r.length == 21 }, "tuta maze: 21x15, every row the same width")
check(TR.berries.length == TR::TOTAL && TR.goldens.length == 4, "tuta maze: 136 strawberries + 4 golden = 140")
check(TR.goldens.sort == [[1, 1], [1, 12], [19, 1], [19, 12]], "tuta maze: the golden strawberries sit in the 4 corners")
check(TR.spawn == [10, 10] && !TR.berries.include?([10, 10]), "tuta maze: Tuta spawns at (10,10) with no strawberry there")
dead = floor_cells.select { |x, y| exits(x, y) < 2 }
check(dead.empty?, "tuta maze: 0 dead ends, counting the wrap (#{dead.inspect})")
seen = reach(TR.spawn)
check(TR.berries.all? { |c| seen[c] }, "tuta maze: BFS from T reaches all 140 (T4)")
check(TR.home_dist[TR.spawn] == 10, "tuta fair: the couch exit (10,6) is 10 steps from T (#{TR.home_dist[TR.spawn]})")
check(exits(*TR.spawn) == 2 && TR.open?(9, 10) && TR.open?(11, 10), "tuta fair: T has 2 exits (left, right)")
check(TR.open?(-1, 7) && TR.open?(21, 7) && TR.cell(-1, 7) == "=" && !TR.open?(10, 7) && !TR.open?(10, 8),
      "tuta maze: the tunnel wraps both ways; door and couch are not floor")

# T15: wrap tunnel both ways for Tuta.
g = parked
g[:tuta].merge!(x: 0.0, y: 7.0, dir: :left)
30.times { TR.tick(g) }
check(g[:tuta][:x] > 15.0 && g[:tuta][:y] == 7.0, "tuta tunnel: leaving x 0 heading left enters at x 20 (#{g[:tuta][:x].round(2)})")
g[:tuta].merge!(x: 20.0, y: 7.0, dir: :right)
30.times { TR.tick(g) }
check(g[:tuta][:x] < 5.0, "tuta tunnel: leaving x 20 heading right enters at x 0 (#{g[:tuta][:x].round(2)})")

# T3: a long random drive never puts Tuta on a wall, door or couch.
rng = TR::Lcg.new(7)
g = parked
bad = nil
20_000.times do |i|
  press = (i % 23).zero? ? TR::ORDER[(rng.rand * 4).floor] : nil
  TR.tick(g, press)
  c = TR.tile(g[:tuta])
  bad ||= c unless TR.open?(*c)
end
check(bad.nil?, "tuta collision: 20,000 random ticks never enter # H or - (#{bad.inspect})")

# T3: owners: # never; door/couch only while leaving, entering, sitting or in the couch.
bad = nil
3.times do |seed|
  g = TR.new_game(seed: seed + 1)
  rng = TR::Lcg.new(seed + 11)
  60.times do
    break if TR.over?(g)
    press = TR::ORDER[(rng.rand * 4).floor]
    60.times do
      TR.tick(g, press)
      g[:owners].each do |o|
        c = TR.tile(o)
        ch = TR.cell(*c)
        ok = ch != "#" && ("H-".include?(ch) ? [:leaving, :entering, :sitting, :couch].include?(o[:state]) : true)
        bad ||= [o[:id], o[:state], c] unless ok
      end
    end
  end
end
check(bad.nil?, "tuta collision: owners never enter walls; door and couch only on the way out or home (#{bad.inspect})")

# T3 + T19: a buffered turn into a wall stays buffered and applies at the next opening.
g = parked
g[:tuta].merge!(dir: :left)
TR.tick(g, :up)
check(g[:tuta][:want] == :up && g[:tuta][:dir] == :left, "tuta turn: up into the wall above T stays buffered")
TR.tick(g) until g[:tuta][:dir] == :up || g[:mode_t] > 2
check(g[:tuta][:dir] == :up && (g[:tuta][:x] - 7.0).abs <= TR::TURN_WINDOW, "tuta turn: the buffered up applies at the opening (7,10) (#{g[:tuta][:x]})")
3.times { TR.tick(g) }
check(g[:tuta][:x] == 7.0 && g[:tuta][:snap].nil?, "tuta turn: ...and she is on the column-7 centre line within 3 ticks")
g = parked
g[:tuta].merge!(x: 7.25, y: 10.0, dir: :left)
TR.tick(g, :up)
step = TR::TUTA_SPEED * DT
check(g[:tuta][:dir] == :up && (g[:tuta][:x] - (7.25 - step)).abs < 1e-9 && (g[:tuta][:y] - (10.0 - step)).abs < 1e-9,
      "tuta turn: pressed 0.25 before the junction, it turns there; the corner slide is one tick's travel, not a jump")
xs = [g[:tuta][:x]]
3.times { TR.tick(g); xs << g[:tuta][:x] }
check(xs.last == 7.0 && xs.each_cons(2).all? { |a, b| (a - b).abs <= step + 1e-9 }, "tuta turn: the off-axis slide eases over at most 3 ticks (#{xs.map { |v| v.round(3) }})")
g = parked
g[:tuta].merge!(x: 7.40, y: 10.0, dir: :left)
TR.tick(g, :up)
check(g[:tuta][:dir] == :left && g[:tuta][:want] == :up, "tuta turn: pressed 0.40 before, not yet, but it stays buffered")
TR.tick(g)
check(g[:tuta][:dir] == :up && g[:tuta][:want].nil?, "tuta turn: ...and applies once inside the 0.30 window")
g = parked
g[:tuta].merge!(x: 3.5, y: 10.0, dir: :left)
TR.tick(g, :right)
check(g[:tuta][:dir] == :right && g[:tuta][:x] > 3.5, "tuta turn: reverse applies instantly between centres")
g = parked
g[:tuta].merge!(x: 1.0, y: 10.0, dir: :left)
TR.tick(g)
check(g[:tuta][:x] == 1.0, "tuta turn: Tuta stops flush at the last open tile before a wall")

# T5 / T8: a BFS bot with the owners frozen eats each cell once, the counter +1 at a time, and wins.
def bfs_dir(from, goals)
  prev = { from => nil }
  q = [from]
  until q.empty?
    c = q.shift
    if goals[c] && c != from
      c = prev[c][1] while prev[c][1] != from
      return prev[c][0]
    end
    TR::ORDER.each do |d|
      n = [(c[0] + TR::DIRS[d][0]) % TR::W, c[1] + TR::DIRS[d][1]]
      next if prev.key?(n) || !TR.open?(*n)
      prev[n] = [d, c]
      q << n
    end
  end
  nil
end

g = TR.new_game
g[:owners].each { |o| o[:state] = :parked }
counts = [0]
eats = []
20_000.times do
  break if TR.over?(g)
  press = nil
  if g[:mode] == :play
    t = g[:tuta]
    off = (t[:x] - (t[:x] + 0.5).floor).abs + (t[:y] - (t[:y] + 0.5).floor).abs
    here = TR.tile(t)
    if off > TR::TURN_WINDOW
      dx, dy = TR::DIRS[t[:dir]]
      here = [((dx > 0 ? t[:x].ceil : dx < 0 ? t[:x].floor : here[0])) % TR::W, dy > 0 ? t[:y].ceil : dy < 0 ? t[:y].floor : here[1]]
    end
    left = {}
    TR.berries.each { |c| left[c] = true unless g[:eaten][c] }
    press = left[here] && here != TR.tile(t) ? t[:dir] : bfs_dir(here, left)   # still heading into a berry
  end
  TR.tick(g, press).each { |e| eats << [e[1], e[2]] if e[0] == :eat }
  counts << TR.eaten_count(g) if counts.last != TR.eaten_count(g)
end
check(g[:mode] == :won && g[:win_time] > 0, "tuta win: a BFS bot with frozen owners eats all 140 and wins (#{g[:mode]}, #{g[:win_time]&.round(1)} s)")
check(counts == (0..140).to_a && eats.uniq.length == 140 && eats.length == 140, "tuta counter: 0 -> 140 by +1, each cell eaten once")

# T6: an idle Tuta is caught by the man within 15 s at diff 0.
g = TR.new_game
go = nil
catcher = nil
(60 * 30).times do
  ev = TR.tick(g)
  go ||= g[:time] if ev.include?([:go])
  if (c = ev.find { |e| e[0] == :catch })
    catcher = [c[1], g[:time] - go]
    break
  end
end
check(catcher && catcher[0] == :man && catcher[1] <= 15, "tuta catch: an idle Tuta is caught by the man within 15 s (#{catcher.inspect})")
check(TR::CATCH_R == 0.55, "tuta catch: radius 0.55")
g = parked
g[:life_t] = 5.0
put(TR.owner(g, :man), 4.0, 3.0, :right)
g[:tuta].merge!(x: 5.0, y: 3.0, dir: :left)
g[:diff] = 0.6
hit = false
10.times { hit ||= TR.tick(g).any? { |e| e[0] == :catch } if g[:mode] == :play }
check(hit, "tuta catch: a head-on swap at max speed is detected")

# T7: 3 catches lose; a retry is a fresh game; the loss streak eases the diff.
g = TR.new_game
lost = false
(60 * 200).times { lost ||= TR.tick(g).include?([:lost]); break if TR.over?(g) }
check(lost && g[:mode] == :lost && g[:lives] == 0, "tuta lose: 3 catches end the game :lost")
st = TR.new_state
TR.record!(st, :lost)
fresh = TR.new_game(diff: TR.diff(st))
check(st[:losses_streak] == 1 && TR.diff(st) == -0.3 && fresh[:lives] == 3 && TR.eaten_count(fresh) == 0 &&
      fresh[:phase_i] == 0 && fresh[:phase_t] == 0.0 && fresh[:tuta][:x] == 10.0 && TR.owner(fresh, :man)[:state] == :couch,
      "tuta lose: retry restores 140, 3 lives, positions and the phase timer; diff -0.3")
g = TR.new_game(eaten: TR.berries.first(30))
g[:mode] = :caught
g[:mode_t] = TR::CATCH_FREEZE
TR.tick(g)
check(g[:lives] == 2 && TR.eaten_count(g) == 30 && g[:mode] == :ready && g[:tuta][:x] == 10.0 && g[:phase_t] == 0.0,
      "tuta lose: a lost life resets positions and keeps the eaten strawberries")

# T9: never an early win; a same-tick eat + catch of the last one is a win.
all_but_one = TR.berries - [TR::LAST_BERRY]
g = TR.new_game(eaten: all_but_one)
g[:owners].each { |o| o[:state] = :parked }
early = false
600.times { early ||= TR.tick(g).any? { |e| e[0] == :won || e[0] == :clear } }
check(!early && g[:mode] == :play, "tuta win: 139 eaten and an idle Tuta never wins")
g = TR.new_game(eaten: TR.berries - [TR.goldens.first])
lost = false
won = false
(60 * 200).times { ev = TR.tick(g); won ||= ev.include?([:won]); break if TR.over?(g) }
check(!won && g[:mode] == :lost, "tuta win: all but one golden eaten is still not a win")
g = parked(eaten: all_but_one)
g[:life_t] = 5.0
g[:tuta].merge!(x: 9.6, y: 10.0, dir: :left)
put(TR.owner(g, :man), 8.9, 10.0, :right)
ev = TR.tick(g)
check(ev.include?([:clear]) && g[:mode] == :hop, "tuta win: eating the last one on the tick a catch would land is a win (#{ev.inspect})")
TR.tick(g) until TR.over?(g)
check(g[:mode] == :won && g[:win_time] > 0, "tuta win: the happy hop ends in :won")

# T10: a win resets the streak and raises the diff, capped at +0.6.
st = TR.new_state
TR.record!(st, :lost)
TR.record!(st, :lost)
check(TR.diff(st) == -0.6, "tuta diff: 2 losses in a row -0.6")
check(TR.record!(st, :won, 80.0) && st[:losses_streak] == 0 && TR.diff(st) == 0.3, "tuta diff: a win resets the streak, +0.3, first time is a record")
TR.record!(st, :won, 90.0)
TR.record!(st, :won, 70.0)
check(TR.diff(st) == 0.6 && st[:best_time] == 70.0 && st[:wins] == 3 && st[:plays] == 5, "tuta diff: capped at +0.6; best time kept")
5.times { TR.record!(st, :lost) }
check(TR.diff(st) == -0.9, "tuta diff: floor -0.9")
before = st.dup
TR.record!(st, :quit, 5.0)
check(st == before, "tuta state: a quit records nothing")

# T14: fairness at the hardest diff.
g = TR.new_game(diff: 0.6)
g[:phase_i] = 5   # chase from GO: the worst case
go = nil
first = nil
(60 * 10).times do
  ev = TR.tick(g)
  go ||= g[:time] if ev.include?([:go])
  next unless go
  first ||= g[:time] - go if g[:owners].any? { |o| TR.gap(g[:tuta], o) < TR::CATCH_R }
end
check(first && first > 3.0, "tuta fair: at diff +0.6 in chase, no owner reaches an idle Tuta before 3.0 s after GO (#{first&.round(2)})")
g = parked
g[:life_t] = 0.5
put(TR.owner(g, :man), 10.0, 10.0, :left)
ev = TR.tick(g)
check(ev.none? { |e| e[0] == :catch }, "tuta fair: no catch inside the 1.0 s grace")
g[:life_t] = 1.0
put(TR.owner(g, :man), 10.0, 10.0, :left)
check(TR.tick(g).any? { |e| e[0] == :catch }, "tuta fair: a catch right after the grace")
g = TR.new_game
TR.tick(g) until g[:mode] == :play
check(g[:owners].all? { |o| o[:state] == :couch } && (g[:mode_t]).zero?, "tuta fair: READY 1.5 s with everyone frozen in the couch, then GO")

# T16: AI targets, no reversal, tie order.
g = parked
g[:phase_i] = 1
g[:tuta].merge!(x: 19.0, y: 10.0, face: :right)
man = TR.owner(g, :man)
woman = TR.owner(g, :woman)
man[:state] = woman[:state] = :active
check(TR.target(g, man) == [19, 10] && TR.target(g, woman) == [20, 10], "tuta AI: man -> Tuta's tile, woman -> 4 ahead clamped")
g[:tuta].merge!(x: 1.0, y: 3.0, face: :up)
check(TR.target(g, woman) == [1, 0], "tuta AI: 4 ahead going up clamps at row 0")
g[:phase_i] = 0
check(TR.target(g, man) == [19, 14] && TR.target(g, woman) == [1, 0], "tuta AI: scatter corners bottom-right / top-left")
put(man, 5.0, 3.0, nil)
g[:phase_i] = 1
g[:tuta].merge!(x: 4.0, y: 4.0)
TR.choose(g, man, 5, 3)
check(man[:dir] == :left, "tuta AI: a tie between left and down goes left (up > left > down > right)")
g[:tuta].merge!(x: 5.0, y: 3.0)
man[:dir] = nil
TR.choose(g, man, 5, 3)
check(man[:dir] == :up, "tuta AI: a 4-way tie goes up")
man[:dir] = :left
g[:tuta].merge!(x: 19.0, y: 3.0)
TR.choose(g, man, 5, 3)
check(man[:dir] != :right, "tuta AI: never reverses at a junction, even toward the target")
g = TR.new_game
g[:mode] = :play
g[:started] = true
put(TR.owner(g, :man), 5.5, 3.0, :left)
g[:phase_t] = 6.0 - DT
ev = TR.tick(g)
check(ev.include?([:phase, :chase]) && TR.owner(g, :man)[:dir] == :right, "tuta AI: a phase switch reverses the owners at once")

# T17: speeds.
g = TR.new_game
check(TR.owner_speed(g) == 5.0, "tuta speed: 5.0 at 0 eaten, diff 0")
g = TR.new_game(eaten: TR.berries, diff: 0.6)
check(TR.owner_speed(g) == 6.4 && TR::OWNER_MAX < TR::TUTA_SPEED, "tuta speed: clamped at 6.4 < Tuta's 6.6")
g = TR.new_game(diff: -0.9)
check(TR.owner_speed(g) == 4.1 && TR.new_game(diff: -2.0).then { |x| TR.owner_speed(x) } == 4.0, "tuta speed: floor 4.0")
g = TR.new_game(eaten: TR.berries.first(70))
check((TR.owner_speed(g) - 5.6).abs < 1e-9, "tuta speed: +1.2 x eaten/140")
o = put(TR.owner(g, :man), 2.0, 7.0, :left)
check(TR.speed_of(g, o) == 2.5, "tuta speed: 2.5 in the tunnel")
put(o, 2.0, 3.0, :left)
o[:melted] = true
check((TR.speed_of(g, o) - 5.6 * 0.55).abs < 1e-9, "tuta speed: melted 0.55x")
o[:state] = :returning
check(TR.speed_of(g, o) == 9.0, "tuta speed: going home 9.0")

# T18: golden, lick, return, restart, phase pause.
g = parked
man = TR.owner(g, :man)
put(man, 5.5, 3.0, :left)
woman = TR.owner(g, :woman)
woman.merge!(state: :couch)
g[:tuta].merge!(x: 1.0, y: 1.5, dir: :up)
g[:phase_t] = 2.0
ev = TR.tick(g)
check(ev.include?([:golden]) && man[:melted] && man[:dir] == :right && !woman[:melted] && g[:melt_t] == TR::MELT_TIME - DT,
      "tuta golden: owners outside the couch melt and reverse; the couch one does not")
pt = g[:phase_t]
30.times { TR.tick(g) }
check(g[:phase_t] == pt, "tuta golden: the phase timer pauses while melted")
g[:melt_t] = 2.0
g[:eaten].delete([1, 1])
g[:tuta].merge!(x: 1.0, y: 1.5, dir: :up)
TR.tick(g)
check(g[:melt_t] == TR::MELT_TIME - DT, "tuta golden: a second golden restarts the 6 s timer")
g[:life_t] = 5.0
put(man, g[:tuta][:x], g[:tuta][:y] + 0.3, :up)
man[:melted] = true
ev = TR.tick(g)
check(ev.include?([:lick, :man]) && man[:state] == :returning && g[:mode] == :play, "tuta lick: touching a melted owner is a lick, never a catch")
states = []
(60 * 15).times { TR.tick(g); states << man[:state] if states.last != man[:state] }
check(states.first(4) == [:returning, :entering, :sitting, :leaving] && states.include?(:active),
      "tuta lick: home to the couch, sit, then out again (#{states.inspect})")
bad = []
TR.home_dist.each_key do |c|
  TR::ORDER.each do |d|
    h = TR.new_game
    o = put(TR.owner(h, :man), c[0], c[1], d, :returning)
    600.times { TR.move_owner(h, o, TR::RETURN_SPEED * DT); break if o[:state] == :sitting }
    bad << [c, d] unless o[:state] == :sitting
  end
end
check(bad.empty?, "tuta lick: a licked owner gets home from every tile and heading (#{bad.first(3).inspect})")

# State, debug preset, copy keys, meta.
check(TR.normalize(nil) == TR.new_state && TR.normalize("x") == TR.new_state, "tuta state: garbage loads as fresh")
check(TR.normalize({ wins: -1, losses_streak: "a", best_time: 0, plays: 2, junk: 1 }) == { wins: 0, losses_streak: 0, best_time: nil, plays: 2 },
      "tuta state: bad fields reset one by one, unknown keys dropped")
check(TR.clock(75.9) == "1:15" && TR.clock(5) == "0:05", "tuta state: the time shows as m:ss")
TutaMaze.leave_one = true
pre = TutaMaze.preset_eaten
check(pre.length == 139 && !pre.include?(TR::LAST_BERRY) && TutaMaze.preset_eaten.empty?, "tuta debug: leave-1 presets 139 eaten, once")
tr_data = JSON.parse(File.read(File.join(ROOT, "PBS/translations.json"), encoding: "utf-8"))["translations"]
keys = %w[003_scene 004_statue].flat_map { |f| File.read(File.join(TDIR, "#{f}.rb")).scan(/(?<![A-Z0-9_])(TUTA_[A-Z0-9_]*[A-Z0-9])(?![A-Z0-9_])/).flatten } - ["TUTA_CATCH"] +
       %w[TUTA_CATCH_MAN_1 TUTA_CATCH_MAN_2 TUTA_CATCH_MAN_3 TUTA_CATCH_WOMAN_1 TUTA_CATCH_WOMAN_2 TUTA_CATCH_WOMAN_3]
missing = keys.uniq.reject { |k| tr_data[k] && !tr_data[k]["en"].to_s.strip.empty? && !tr_data[k]["he"].to_s.strip.empty? }
check(keys.include?("TUTA_INTRO_3") && missing.empty?, "tuta copy: every TUTA_* key the code uses has en and he (#{missing.inspect})")
check(tr_data["TUTA_TITLE"]["he"] == "הטוט שאהב תות", "tuta copy: TUTA_TITLE he is byte-exact")
meta = File.read(File.join(TDIR, "meta.txt"))
check(meta.include?("Name       = TutaMaze") && %w[HebrewSupport DesertTalk DesertTownArcade].all? { |r| meta.include?("Requires   = #{r}") },
      "tuta: meta.txt names TutaMaze and its 3 requirements")
end

require "rbconfig"
smoke = IO.popen([RbConfig.ruby, File.join(__dir__, "tuta_scene_smoke.rb")], err: [:child, :out], &:read)
smoke_fails = smoke.lines.grep(/FAIL|Error/).map(&:strip)
check($?.success? && smoke_fails.empty?, "tuta: scene smoke run passes (#{smoke_fails.first(3).inspect})")
