# TG14 arm wrestling: loaded from plugin_rules_test.rb (shares check/$failures).
# ArmWrestleRules is pure; the cowboy flow runs through the real pbDesertTalk chain with stubs.
require "json"
arm_dir = File.join(ROOT, "Plugins/zArmWrestle")
%w[000_rules 001_state 004_offer].each { |f| require File.join(arm_dir, "#{f}.rb") }
AR = ArmWrestleRules
AW_DT = 1.0 / 60

# 1: tier
st = ->(h) { AR.normalize(AR.new_state.merge(h)) }
check(AR.tier(AR.new_state) == 1 && AR.tier(st.(wins: 1)) == 2 && AR.tier(st.(wins: 2)) == 3 && AR.tier(st.(wins: 5)) == 3,
      "arm tier: fresh 1, one win 2, from the 3rd bout after wins 3")
check(AR.tier(st.(wins: 1, loss_streak: 2)) == 1 && AR.tier(st.(wins: 5, loss_streak: 4)) == 1 && AR.tier(st.(wins: 5, loss_streak: 3)) == 2,
      "arm tier: 2 losses in a row -1, 4 in a row -2")
check(AR.tier(st.(loss_streak: 2)) == 0 && AR.tier(st.(loss_streak: 9)) == 0, "arm tier: floor at the assist tier 0")

# A bout parked just before time t (no surge, no pull) so a press lands at exactly t.
def aw_at(tier, t, edge: false)
  b = AR.new_bout(tier, AR::Lcg.new(1))
  b[:next_surge] = 999.0
  b[:edge] = edge
  b[:b] = edge ? -70.0 : 0.0
  b[:t] = t - 1e-12
  b
end

def aw_press(bout, red: false, blue: false)
  before = bout[:b]
  ev = AR.step(bout, 1e-12, red: red, blue: blue)
  [ev - [:beat], (bout[:b] - before).round(6)]
end

# 2: beat judging at every window edge
edge_ok = AR::TIERS.each_index.all? do |ti|
  c = AR::TIERS[ti]
  p, g, per = c[:perfect], c[:good], c[:period]
  [[per, [:perfect], 10], [per + p, [:perfect], 10], [per - p, [:perfect], 10], [per + p + 1e-6, [:good], 6],
   [per + g, [:good], 6], [per - g, [:good], 6], [per + g + 1e-6, [:slip], -3], [per - g - 1e-6, [:slip], -3],
   [0.05, [:slip], -3]].all? { |t, evs, db| aw_press(aw_at(ti, t), red: true) == [evs, db] }
end
check(edge_ok, "arm beat: PERFECT, GOOD and slip at every window edge, all tiers")
b2 = aw_at(1, 0.75)
first = aw_press(b2, red: true)
second = aw_press(b2, red: true)
b2[:t] = 1.5 - 1e-12
third = aw_press(b2, red: true)
check(first == [[:perfect], 10] && second == [[:slip], -3] && third == [[:perfect], 10],
      "arm beat: one judged press per beat; a second press in the window slips, the next beat judges again")
missed = aw_at(1, 0.75)
check(AR.step(missed, 0.5).none? { |e| %i[perfect good slip].include?(e) }, "arm beat: a missed beat costs only the pull")
masher = AR.new_bout(1, AR::Lcg.new(4))
mash_ev = (1..120).flat_map { |f| AR.step(masher, AW_DT, red: (f % 6).zero?) }
check(mash_ev.count(:slip) > 3 * (mash_ev.count(:perfect) + mash_ev.count(:good)), "arm beat: pressing 10x a second earns far more slips than pushes")

# 3: surge, brace window edges, flinch
surge_ok = AR::TIERS.each_index.all? do |ti|
  c = AR::TIERS[ti]
  land = 20.0
  res = [[land - c[:brace], [:block], 12], [land + AR::BRACE_AFTER, [:block], 12],
         [land - c[:brace] - 1e-6, [:flinch], -4]].map do |t, evs, db|
    bo = aw_at(ti, t)
    bo[:surge] = land
    aw_press(bo, blue: true) == [evs, db]
  end
  late = aw_at(ti, land + AR::BRACE_AFTER + 1e-6)
  late[:surge] = land
  hit_ev = aw_press(late, blue: true)[0]
  drained = 0.0
  ev = AR.step(late, 0.0)
  before = late[:b]
  30.times { AR.step(late, AW_DT) }
  pull = c[:pull] * 30 * AW_DT
  res.all? && hit_ev == [:flinch, :hit] && ev == [] && ((before - late[:b]) - pull - c[:hit]).abs < 1e-6
end
check(surge_ok, "arm surge: Blue at the brace-window edges blocks, earlier flinches, no Blue hits for the tier's amount over 0.4 s")
bl = aw_at(1, 20.0)
bl[:surge] = 20.0
aw_press(bl, blue: true)
check(bl[:surge].nil? && AR.face(bl) == :strain && aw_press(bl, blue: true) == [[:flinch], -4], "arm surge: a block ends the surge, shows :strain; Blue again flinches")
tell = aw_at(1, 10.0)
tell[:next_surge] = 10.0
ev = AR.step(tell, 1e-9)
check(ev.include?(:tell) && (tell[:surge] - 10.0 - AR::TIERS[1][:tell]).abs < 1e-6 && AR.face(tell) == :tell,
      "arm surge: the tell starts when due and lands after the tier's tell length")
on_edge = aw_at(1, 10.0, edge: true)
on_edge[:next_surge] = 5.0
check(AR.step(on_edge, AW_DT).none? { |e| e == :tell } && on_edge[:surge].nil?, "arm surge: no new surge starts on the edge")

# 4: the edge
e = AR.new_bout(1, AR::Lcg.new(2))
e[:next_surge] = 999.0
e[:b] = -64.9
AR.step(e, 0.0)
not_yet = e[:edge]
e[:b] = -65.0
in_ev = AR.step(e, 0.0)
e[:b] = -40.0
stay = AR.step(e, 0.0)
e[:b] = -39.9
out_ev = AR.step(e, 0.0)
check(!not_yet && in_ev == [:edge_in] && stay == [] && out_ev == [:edge_out] && !e[:edge], "arm edge: in at <= -65, out only above -40")
check(AR.face(e) == :strain && e[:next_surge] > e[:t], "arm edge: leaving it shows :strain and schedules the next surge later")
w = aw_at(1, 0.75 + 0.18 * 1.5, edge: true)
check(AR.windows(w) == [0.09 * 1.5, 0.18 * 1.5] && aw_press(w, red: true) == [[:good], 6], "arm edge: windows widen x1.5")
check(aw_press(aw_at(1, 0.75 + 0.13, edge: true), red: true) == [[:perfect], 14], "arm edge: PERFECT pushes +14")
pull = aw_at(2, 5.0, edge: true)
b0 = pull[:b]
AR.step(pull, 1.0)
check((b0 - pull[:b] - AR::TIERS[2][:pull] * 0.5).abs < 1e-6, "arm edge: her pull halves")

# 5: end
pw = aw_at(1, 0.75)
pw[:b] = 95.0
check(aw_press(pw, red: true)[0] == [:perfect, :pin_win] && AR.outcome(pw) == :win && pw[:reason] == :pin && pw[:b] == 100, "arm end: +100 pins her")
pl = aw_at(1, 3.0)
pl[:b] = -99.0
pl[:edge] = true
check(AR.step(pl, 1.0).include?(:pin_loss) && AR.outcome(pl) == :loss, "arm end: -100 pins the player")
[[0.0, :win], [12.0, :win], [-0.01, :loss]].each do |bal, want|
  cap = aw_at(1, AR::CAP)
  cap[:b] = bal + AR::TIERS[1][:pull] * 1e-12
  ev = AR.step(cap, 1e-12)
  check(ev.include?(:timeup) && AR.outcome(cap) == want && cap[:reason] == :timeup, "arm end: the cap with b = #{bal} is a #{want}")
end
check(AR.step(pw, 1.0) == [] && AR.over?(pw), "arm end: a finished bout does not move")

# 6: winnability bots at 60 fps, 20 seeds each
def aw_bot(tier, seed, kind)
  bout = AR.new_bout(tier, AR::Lcg.new(seed * 7919 + 13))
  frame = 0
  beat = 1
  tells = 0
  braced = nil
  until AR.over?(bout)
    c = bout[:cfg]
    t = bout[:t] + AW_DT
    red = blue = false
    case kind
    when :masher then red = (frame % 4).zero?
    when :steady, :sloppy, :perfect
      off = { steady: 0.10, perfect: -0.5 / 60, sloppy: (c[:perfect] + c[:good]) / 2.0 }[kind]
      if t >= beat * c[:period] + off
        red = kind != :sloppy || beat % 4 != 0
        beat += 1
      end
      if bout[:surge] && braced != bout[:surge] && (kind == :perfect || (kind == :steady && tells.odd?)) &&
         t >= bout[:surge] - c[:brace] / 2.0
        blue = true
        braced = bout[:surge]
      end
    end
    tells += 1 if AR.step(bout, AW_DT, red: red, blue: blue).include?(:tell)
    frame += 1
  end
  bout
end
SEEDS = (1..20).to_a
runs = ->(kind, tier) { SEEDS.map { |s| aw_bot(tier, s, kind) } }
check((0..3).all? { |ti| runs.(:idle, ti).all? { |b| AR.outcome(b) == :loss } }, "arm bots: an idle player loses at every tier")
check((1..3).all? { |ti| runs.(:masher, ti).all? { |b| AR.outcome(b) == :loss } }, "arm bots: mashing Red (every 4 frames) loses at T1, T2, T3")
check((0..3).all? { |ti| runs.(:steady, ti).all? { |b| AR.outcome(b) == :win && b[:reason] == :pin } },
      "arm bots: steady (0.10 s off the beat, every other surge blocked) pins her before the cap at every tier")
check((0..1).all? { |ti| runs.(:sloppy, ti).all? { |b| AR.outcome(b) == :win } }, "arm bots: sloppy (GOOD on 75% of beats, no blocks) wins at T0 and T1")
p1 = runs.(:perfect, 1)
p3 = runs.(:perfect, 3)
check(p1.all? { |b| AR.outcome(b) == :win && b[:t] <= 15 } && p3.all? { |b| AR.outcome(b) == :win && b[:t] <= 30 },
      "arm bots: perfect wins at T1 within 15 s and at T3 within 30 s (#{p1.map { |b| b[:t] }.max.round(1)}, #{p3.map { |b| b[:t] }.max.round(1)})")
check(runs.(:steady, 1).map { |b| b[:t] }.minmax.all? { |t| t.between?(10, 40) }, "arm bots: a steady bout lasts 10-40 s at T1")
# Tier drop: a sloppy player at 2 wins (T3) loses until 2 losses drop the tier, then wins.
drop_ok = SEEDS.all? do |s|
  state = st.(wins: 2)
  tiers = []
  5.times do |n|
    tiers << AR.tier(state)
    out = AR.outcome(aw_bot(tiers.last, s + n * 100, :sloppy))
    AR.record!(state, out)
    break if out == :win
  end
  tiers == [3, 3, 2] && state[:wins] == 3 && state[:loss_streak] == 0
end
check(drop_ok, "arm bots: after 2 losses the tier drops and the sloppy player wins (T3, T3, T2)")
check(AR.tier(st.(loss_streak: 2)) == 0 && runs.(:sloppy, 0).all? { |b| AR.outcome(b) == :win },
      "arm bots: a first-timer who lost twice plays T0, which sloppy play wins")
la = AR::Lcg.new(42)
check([la.rand, la.rand].map { |x| x.round(12) } == [0.568230326644, 0.225463428948], "arm rng: the seeded LCG matches the Python mirror")

# 7: record!, normalize, line rotation
s7 = AR.new_state
AR.record!(s7, :loss)
AR.record!(s7, :loss)
check(s7 == { wins: 0, losses: 2, loss_streak: 2, plays: 2 }, "arm record: a loss counts losses and the streak")
AR.record!(s7, :win)
check(s7 == { wins: 1, losses: 2, loss_streak: 0, plays: 3 }, "arm record: a win counts and resets the streak")
AR.record!(s7, :back)
AR.record!(s7, nil)
check(s7 == { wins: 1, losses: 2, loss_streak: 0, plays: 3 }, "arm record: :back changes nothing")
check(AR.normalize(nil) == AR.new_state && AR.normalize("x") == AR.new_state && AR.normalize([1]) == AR.new_state,
      "arm state: nil or garbage loads fresh")
check(AR.normalize({ wins: -1, losses: "2", loss_streak: 1.5, junk: 3 }) == AR.new_state, "arm state: garbage values are repaired, junk keys dropped")
kept = { wins: 4, losses: 1, loss_streak: 1, plays: 5 }
check(AR.normalize(kept).equal?(kept) && kept[:wins] == 4, "arm state: a valid state is kept as the same object")
check((1..4).map { |n| AR.win_line({ wins: n }) } == %w[1 2 3 1].map { |n| "BAGS_SHIRPAZ_COWBOY_GIFT_#{n}" } &&
      (1..4).map { |n| AR.lose_line({ losses: n }) } == %w[AW_LOSE_1 AW_LOSE_2 AW_LOSE_3 AW_LOSE_1], "arm lines: win and loss lines rotate 1, 2, 3")

# 8: angle and frame
check(AR.angle(100) == -72 && AR.angle(-100) == 72 && AR.angle(0) == 0 && AR.angle(250) == -72, "arm angle: +-100 is -+72 deg")
check(AR.frame(100) == 0 && AR.frame(-100) == 48 && AR.frame(0) == 24 && (-120..120).all? { |b| AR.frame(b).between?(0, 48) },
      "arm angle: frame index 0..48, upright is 24")
fb = aw_at(1, 1.0)
faces = [[0, :steady], [40, :steady], [41, :strain], [-30, :steady], [-31, :taunt]].map { |bal, _| fb[:b] = bal.to_f; AR.face(fb) }
check(faces == %i[steady steady strain steady taunt], "arm face: follows the balance (#{faces.inspect})")

#-------------------------------------------------------------------------------
# Static: state writers, music, keys, no zBags names, parses
#-------------------------------------------------------------------------------
arm_src = Dir.glob(File.join(arm_dir, "*.rb")).sort.to_h { |f| [File.basename(f), File.read(f, encoding: "utf-8")] }
writers = arm_src.reject { |n, _| n == "000_rules.rb" }.select { |_, s| s.match?(/\[:(wins|losses|loss_streak|plays)\]\s*(\+|-)?=(?!=)/) }.keys
check(writers.empty?, "arm: only ArmWrestleRules writes the run state (#{writers.inspect})")
check(arm_src.values.none? { |s| s.match?(/pb(BGM|BGS|ME)\w*|bags_quest|\bBags[.:]/) }, "arm: no music calls, and nothing from zBags (one-way dependency)")
tr = JSON.parse(File.read(File.join(ROOT, "PBS/translations.json"), encoding: "utf-8"))["translations"]
aw_keys = (arm_src.values.join.scan(/"(AW_[A-Z0-9_]+)"/).flatten + %w[AW_CHOICE_PLAY AW_CHOICE_LATER AW_LOSE_1 AW_LOSE_2 AW_LOSE_3] +
           %w[1 2 3].map { |n| "BAGS_SHIRPAZ_COWBOY_GIFT_#{n}" }).uniq
check(aw_keys.length == 25 && aw_keys.all? { |k| tr.dig(k, "he").to_s != "" && tr.dig(k, "en").to_s != "" },
      "arm: every AW_ key the plugin shows is in translations.json (missing #{aw_keys.reject { |k| tr[k] }.inspect})")
%w[002_art.rb 003_scene.rb 005_debug.rb].each do |f|
  ok = begin
    RubyVM::InstructionSequence.compile(arm_src[f], f) && true
  rescue SyntaxError
    false
  end
  check(ok, "arm: #{f} parses")
end
check(arm_src["005_debug.rb"].match?(/WARP = \[14, 9, 8\]/) && arm_src["005_debug.rb"].scan(/MenuHandlers\.add\(:debug_menu, :dt_arm_/).length == 3 &&
      arm_src["005_debug.rb"].scan(/"parent"\s*=> :desert_town_menu/).length == 3, "arm debug: 3 entries under Desert Town, warp to (14,9) facing up")
meta = File.read(File.join(arm_dir, "meta.txt"))
check(meta.include?("Name       = ArmWrestle") && %w[HebrewSupport DesertTalk DesertTownArcade].all? { |r| meta.include?("Requires   = #{r}") },
      "arm: meta.txt names ArmWrestle and its 3 requirements")

#-------------------------------------------------------------------------------
# The cowboy talk through the real pbDesertTalk chain; waits and fades run map frames
#-------------------------------------------------------------------------------
class ArmFakeBag
  attr_reader :items
  def initialize = (@items = Hash.new(0))
  def quantity(i) = @items[i]
  def add(i, n = 1) = (@items[i] += n; true)
  def remove(i, n = 1) = (@items[i] >= n ? (@items[i] -= n; true) : false)
end
ArmFakeMap = Struct.new(:map_id, :events) do
  def need_refresh=(_); end
end
$arm_log = []
$arm_picks = []
$arm_frames = 0
def arm_frame
  $arm_frames += 1
  %i[desert_talk_clear_speaker bags_song].each { |h| $event_handlers[h]&.call }
end
def pbMessage(msg, commands = nil, _cancel = 0)
  $arm_log << [msg.split("|")[0], DesertTalk.name_key]
  return nil unless commands
  raise "arm test: no scripted choice for #{msg}" if $arm_picks.empty?
  $arm_picks.shift
end
def _INTL(m, *a) = a.empty? ? m : "#{m}|#{a.join(',')}"
def pbReceiveItem(i, n = 1) = (arm_frame; $arm_log << [:got, i, DesertTalk.name_key]; $bag.add(i, n))
def pbUpdateSceneMap = arm_frame
def pbWait(_s) = 3.times { arm_frame }
def pbFadeOutIn = (3.times { arm_frame }; $arm_log << :fade; r = yield; 3.times { arm_frame }; r)

module ArmWrestle
  class Scene
    @results = []
    class << self; attr_accessor :results, :tiers; end
    def initialize(tier) = ((self.class.tiers ||= []) << tier)
    def run = ($arm_log << :scene; self.class.results.shift)
  end
end
saves = []
save_view = nil
autosave_was = DesertTownAutosave.method(:save_now)
DesertTownAutosave.define_singleton_method(:save_now) do |reason|
  saves << reason
  save_view = [ArmWrestle.state[:wins], $bag.quantity(:SURPRISEBAG)]
  true
end
saved = [$game_map, $bag, $PokemonGlobal, $map_interpreter_running]
$game_map = ArmFakeMap.new(95, {})
$bag = ArmFakeBag.new
$PokemonGlobal = PokemonGlobalMetadata.new
$map_interpreter_running = true
song_on = false
Bags::Song.singleton_class.send(:alias_method, :arm_active_was, :active?)
Bags::Song.define_singleton_method(:active?) { song_on }
arm_talk = lambda do |picks, results = []|
  $arm_log = []
  $arm_picks = picks.dup
  ArmWrestle::Scene.results = results.dup
  DesertTalk.start_speaker("670f79e3")
  pbDesertTalk("670f79e3")
  $arm_log.map { |m| m.is_a?(Array) && m[0].is_a?(String) ? m[0] : m }
end
bags_state = -> { $PokemonGlobal.bags_quest }

pre = arm_talk.call([1])
check(pre == %w[MSG_670F79E3_LINE AW_CHALLENGE AW_LATER] && $bag.quantity(:SURPRISEBAG) == 0 && $PokemonGlobal.arm_wrestle == AR.new_state,
      "arm flow: before the party her line, the challenge; not now changes nothing (#{pre.inspect})")
check($arm_log[1][1] == "NAME_670F79E3" && $arm_log[2][1] == "NAME_670F79E3", "arm flow: the challenge and the reply carry her name plate")
back = arm_talk.call([0], [{ outcome: :back }])
check(back == ["MSG_670F79E3_LINE", "AW_CHALLENGE", :fade, :scene, "AW_LATER"] && $bag.quantity(:SURPRISEBAG) == 0 &&
      $PokemonGlobal.arm_wrestle == AR.new_state && saves.empty?, "arm flow: Blue on the how-to card records nothing, gives nothing")
bags_state.call[:inbar] = :done
before_bags = Marshal.load(Marshal.dump(bags_state.call))
frames0 = $arm_frames
win = arm_talk.call([0], [{ outcome: :win }])
check(win == ["MSG_670F79E3_LINE", "BAGS_SHIRPAZ_COWBOY_CLASH", "AW_CHALLENGE", :fade, :scene, "BAGS_SHIRPAZ_COWBOY_GIFT_1", [:got, :SURPRISEBAG, nil]],
      "arm flow: after the party CLASH comes before the challenge; a win line, then the bag (#{win.inspect})")
check($bag.quantity(:SURPRISEBAG) == 1 && saves == [:arm_wrestle] && save_view == [1, 1], "arm flow: a win gives exactly 1 Surprise Bag, then 1 autosave that holds it")
got = $arm_log.find { |m| m.is_a?(Array) && m[0] == :got }
check(got && got[2].nil? && $arm_frames > frames0, "arm flow: the name plate is cleared for the item box; fades and the item ran map frames")
check(ArmWrestle::Scene.tiers.last == 1 && bags_state.call == before_bags, "arm flow: the first bout is tier 1 and the bags quest state is untouched")
loss = arm_talk.call([0], [{ outcome: :loss }])
check(loss.last == "AW_LOSE_1" && $bag.quantity(:SURPRISEBAG) == 1 && saves == [:arm_wrestle] &&
      $PokemonGlobal.arm_wrestle == { wins: 1, losses: 1, loss_streak: 1, plays: 2 }, "arm flow: a loss gives no bag, no save, only the counters")
check(ArmWrestle::Scene.tiers.last == 2, "arm flow: after one win the next bout is tier 2")
win_lines = [win] + 2.times.map { arm_talk.call([0], [{ outcome: :win }]) }
win_lines = win_lines.map { |t| t.grep(/\ABAGS_SHIRPAZ_COWBOY_GIFT_/) }
check($bag.quantity(:SURPRISEBAG) == 3 && saves.length == 3 && $PokemonGlobal.arm_wrestle[:wins] == 3, "arm flow: three wins give 3 bags and 3 saves")
check(win_lines == [1, 2, 3].map { |n| ["BAGS_SHIRPAZ_COWBOY_GIFT_#{n}"] }, "arm flow: the three wins show win lines 1, 2, 3 (#{win_lines.inspect})")
song_on = true
busy = arm_talk.call([], [{ outcome: :win }])
check(busy == %w[MSG_670F79E3_LINE BAGS_SHIRPAZ_COWBOY_CLASH AW_BUSY] && ArmWrestle::Scene.results == [{ outcome: :win }] &&
      $bag.quantity(:SURPRISEBAG) == 3, "arm flow: during the unicorn song AW_BUSY, no challenge, no scene (#{busy.inspect})")
song_on = false
$arm_picks = [1]
check(ArmWrestle.offer == :later && ArmWrestle.offer(busy: true) == :busy, "arm flow: offer returns what happened (:later, :busy)")

# Debug: a bout gives no bag and records nothing; reset loads fresh.
module MenuHandlers
  def self.add(_menu, id, _h) = (($arm_menu ||= []) << id)
end unless defined?(MenuHandlers)
load File.join(arm_dir, "005_debug.rb")
before_dbg = Marshal.load(Marshal.dump($PokemonGlobal.arm_wrestle))
ArmWrestle::Scene.results = [{ outcome: :win }]
ArmWrestle.debug_play(2)
check($bag.quantity(:SURPRISEBAG) == 3 && $PokemonGlobal.arm_wrestle == before_dbg && ArmWrestle::Scene.tiers.last == 2,
      "arm debug: a debug bout at the picked tier gives nothing and records nothing")
ArmWrestle.debug_reset
check($PokemonGlobal.arm_wrestle == AR.new_state, "arm debug: reset loads a fresh run state")
$PokemonGlobal.arm_wrestle = { wins: "x" }
check($PokemonGlobal.arm_wrestle == AR.new_state, "arm state: a broken saved value loads fresh through the accessor")

Bags::Song.singleton_class.send(:alias_method, :active?, :arm_active_was)
DesertTownAutosave.define_singleton_method(:save_now, autosave_was)
DesertTalk.clear_speaker if DesertTalk.respond_to?(:clear_speaker)
$game_map, $bag, $PokemonGlobal, $map_interpreter_running = saved

# The scene runs in its own process (fake Bitmap/Sprite/Input/clock), with and without the PNGs.
require "rbconfig"
smoke = IO.popen([RbConfig.ruby, File.join(__dir__, "arm_scene_smoke.rb")], err: [:child, :out], &:read)
smoke_fails = smoke.lines.grep(/FAIL|Error/).map(&:strip)
check($?.success? && smoke_fails.empty?, "arm: scene smoke run passes (#{smoke_fails.first(3).inspect})")
