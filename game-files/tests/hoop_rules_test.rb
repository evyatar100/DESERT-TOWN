# TG11 temple hoop: loaded from plugin_rules_test.rb (shares check/$failures).
# TempleHoopRules is pure; pbTempleHoop runs against stubs whose waits run frames.
require "json"
hoop_dir = File.join(ROOT, "Plugins/zTempleHoop")
load File.join(hoop_dir, "000_rules.rb")
HR = TempleHoopRules
HOOP_LINE = "איך אמר יותם פעם? תעשה חיים בחיים. כי בחיים לא תצא בחיים."

# 1: meter
[1.8, 1.2].each do |p|
  check(HR.meter(0, p) == 0 && HR.meter(p / 2.0, p) == 100 && HR.meter(p, p).abs < 1e-9,
        "hoop: meter is 0 at t=0, 100 at P/2, 0 at P (P=#{p})")
  samples = (0..400).map { |i| i * p / 97.0 }
  check(samples.all? { |t| HR.meter(t, p).between?(0, 100) }, "hoop: meter stays within 0..100 (P=#{p})")
  check(samples.all? { |t| (HR.meter(t, p) - HR.meter(t + 2 * p, p)).abs < 1e-6 }, "hoop: meter is periodic (P=#{p})")
end

# 2: outcome at every band edge
edges = { 53.99 => :short, 54 => :rim_out, 59.99 => :rim_out, 60 => :in, 67.99 => :in, 68 => :swish,
          76 => :swish, 76.01 => :in, 84 => :in, 84.01 => :rim_out, 90 => :rim_out, 90.01 => :long,
          0 => :short, 100 => :long }
bad = edges.reject { |v, o| HR.outcome(v) == o }
check(bad.empty?, "hoop: outcome at every band edge (wrong at #{bad.keys.inspect})")
check(HR.shot(55) == :rim_front && HR.shot(85) == :rim_back && HR.shot(65) == :rim_in && HR.shot(80) == :board_in,
      "hoop: front/back rim and rim/backboard makes take their own paths")

check(HR.net_jiggle?(:swish) && %i[rim_in board_in short long rim_front rim_back].none? { |p| HR.net_jiggle?(p) },
      "hoop: only a swish shakes the net")
check(HR::RIM_ART == [104, 139], "hoop: the art-space rim spot is derived from RIM and HOOP_ORIGIN")

# 3: made?
check(HR.made?(:in) && HR.made?(:swish) && %i[short rim_out long].none? { |o| HR.made?(o) }, "hoop: only :in and :swish are makes")
check(HR.word_key(:swish) == "HOOP_SWISH" && HR.word_key(:in) == "HOOP_MADE" && HR.word_key(:long) == "HOOP_MISSED",
      "hoop: pop word per outcome")

# 4: periods
check(HR::PERIODS.length == HR::SHOTS && HR::PERIODS.each_cons(2).all? { |a, b| b <= a },
      "hoop: one period per shot, never slower than the last")

# 5: normalize
check(HR.normalize(nil) == HR.new_state && HR.normalize("x") == HR.new_state && HR.normalize([1]) == HR.new_state,
      "hoop: nil or garbage state becomes fresh")
check(HR.normalize({ evyatar_seen: "yes", plays: -1, best: 9, junk: 1 }) == HR.new_state, "hoop: garbage values are repaired")
kept = { evyatar_seen: true, plays: 4, best: 5 }
check(HR.normalize(kept).equal?(kept) && kept == { evyatar_seen: true, plays: 4, best: 5 }, "hoop: a valid state is unchanged")

# 6: finish! / mark_toga! (the old :evyatar_seen key and method names still work)
st = HR.new_state
check(HR.card(st, 2)[:best].nil?, "hoop: no best on the run's first card")
check(HR.finish!(st, 2) && st[:plays] == 1 && st[:best] == 2, "hoop: the first finish is due and counts")
check(HR.finish!(st, 1) && st[:best] == 2 && !HR.toga_seen?(st), "hoop: still due until the visitor is marked; best keeps the max")
HR.mark_toga!(st)
check(HR.toga_seen?(st) && st[:evyatar_seen] == true, "hoop: mark_toga! writes the kept evyatar_seen key")
check(!HR.finish!(st, 4) && st[:plays] == 3 && st[:best] == 4, "hoop: after mark_toga! no longer due; plays +1, best = max")
old_save = HR.normalize({ evyatar_seen: true, plays: 1, best: 2 })
check(HR.toga_seen?(old_save) && !HR.finish!(old_save, 3), "hoop: a save with evyatar_seen = true counts as the visitor seen")
alias_st = HR.new_state
HR.mark_evyatar!(alias_st)
check(HR.toga_seen?(alias_st) && (HR.reset_evyatar!(alias_st); !HR.toga_seen?(alias_st)), "hoop: the old evyatar method names still work")
check(HR.card(st, 1) == { made: 1, of: 5, best: 4 } && HR.card(st, 5)[:best] == 5, "hoop: later cards show the best this run")
HR.finish!(st, 99)
check(st[:best] == 5, "hoop: a score is clamped to 0..5")

# Paths: on screen, makes drop behind the front rim, misses never do.
on_screen = HR::PATHS.keys.all? do |p|
  (0..(HR.duration(p) * 100).ceil).all? do |c|
    x, y, = HR.ball_at(p, c / 100.0)
    x.between?(HR::BALL_R, HR::SCREEN_W - HR::BALL_R) && y.between?(HR::BALL_R, HR::SCREEN_H - HR::BALL_R)
  end
end
check(on_screen, "hoop: every ball path stays on screen")
check(HR::PATHS.keys.all? { |p| HR.ball_at(p, 0)[0, 2] == HR::BALL_START && HR::PATHS[p][0][3] == HR::ARC_TIME },
      "hoop: every shot starts at the ball spot and its arc takes 0.9 s")
behind = HR::PATHS.keys.select { |p| (0..200).any? { |c| HR.behind_front?(p, c / 100.0) } }
check(behind.sort == %i[board_in rim_in swish], "hoop: only makes drop behind the front rim (#{behind.inspect})")
check(%i[rim_in swish board_in].all? { |p| (0..200).any? { |c| x, y, = HR.ball_at(p, c / 100.0); (x - HR::RIM[0]).abs < 2 && (y - HR::RIM[1]).abs < 4 } },
      "hoop: every make passes through the rim centre")
se = HR::PATHS.keys.to_h { |p| [p, HR.sounds(p).map(&:last)] }
check(se[:swish] == ["Voltorb Flip point"] && se[:rim_in] == ["Mining iron", "Mining ping"] &&
      se[:board_in] == ["Player bump", "Mining ping"] && se[:short] == ["Battle ball drop"] &&
      se[:rim_front][0] == "Mining iron" && se[:long][0] == "Player bump", "hoop: sound per outcome")

#-------------------------------------------------------------------------------
# Static: state writers, no music, TG5 only through walk, keys and the line
#-------------------------------------------------------------------------------
hoop_files = Dir.glob(File.join(hoop_dir, "*.rb")).sort
hoop_src = hoop_files.to_h { |f| [File.basename(f), File.read(f, encoding: "utf-8")] }
writers = hoop_src.reject { |n, _| n == "000_rules.rb" }.select { |_, s| s.match?(/st(ate)?\[:\w+\]\s*=(?!=)/) }.keys
check(writers.empty?, "hoop: only TempleHoopRules writes the state (#{writers.inspect})")
check(hoop_src.values.none? { |s| s.match?(/pb(BGM|BGS|ME)\w*/) }, "hoop: the plugin never touches music")
ts_calls = hoop_src.values.flat_map { |s| s.scan(/TempleStickers\.(\w+)/).flatten }.uniq
check(ts_calls == ["walk"], "hoop: TG5 is used only through TempleStickers.walk (#{ts_calls.inspect})")
tr = JSON.parse(File.read(File.join(ROOT, "PBS/translations.json"), encoding: "utf-8"))["translations"]
hoop_keys = hoop_src.values.join.scan(/"(HOOP_[A-Z_]+)"/).flatten.uniq
check(hoop_keys.length >= 9 && hoop_keys.all? { |k| tr.dig(k, "he").to_s != "" && tr.dig(k, "en").to_s != "" },
      "hoop: every HOOP_ key used is in translations.json (#{hoop_keys.reject { |k| tr[k] }.inspect})")
line = tr["HOOP_EVYATAR_LINE"] || {}
check(line["he"] == HOOP_LINE && line["en"] == HOOP_LINE && !HOOP_LINE.match?(/[\n״"]/),
      "hoop: HOOP_EVYATAR_LINE is the founder's line byte for byte in he and en")
check(tr.dig("NAME_F90D4DE9", "he") == "אביתר" && DesertTalk::CHARACTERS["f90d4de9"][:name_key] == "NAME_F90D4DE9",
      "hoop: Evyatar's name plate reads אביתר")
%w[002_art.rb 003_scene.rb 005_debug.rb].each do |f|
  ok = begin
    RubyVM::InstructionSequence.compile(hoop_src[f], f) && true
  rescue SyntaxError
    false
  end
  check(ok, "hoop: #{f} parses")
end

#-------------------------------------------------------------------------------
# pbTempleHoop + the visitor with stubs: a wait runs map frames, each frame steps routes
#-------------------------------------------------------------------------------
module PBMoveRoute
  DOWN = 1; LEFT = 2; RIGHT = 3; UP = 4
  TURN_DOWN = 16; TURN_LEFT = 17; TURN_RIGHT = 18; TURN_UP = 19
end unless defined?(PBMoveRoute)

class HoopFakeChar
  STEP = { PBMoveRoute::DOWN => [0, 1, 2], PBMoveRoute::LEFT => [-1, 0, 4],
           PBMoveRoute::RIGHT => [1, 0, 6], PBMoveRoute::UP => [0, -1, 8] }.freeze
  TURN = { PBMoveRoute::TURN_DOWN => 2, PBMoveRoute::TURN_LEFT => 4,
           PBMoveRoute::TURN_RIGHT => 6, PBMoveRoute::TURN_UP => 8 }.freeze
  attr_accessor :x, :y, :through, :move_speed, :character_name, :direction
  attr_reader :name, :walked
  def initialize(name, x, y, charset = "")
    @name, @x, @y, @character_name = name, x, y, charset
    @through, @move_speed, @direction, @route, @walked = false, 3, 2, [], []
  end
  def moveto(x, y) = (@x, @y = x, y)
  def turn_left = (@direction = 4)
  def turn_right = (@direction = 6)
  def turn_up = (@direction = 8)
  def force_route(cmds) = (@route = cmds.dup)
  def move_route_forcing = !@route.empty?
  # One command per frame, like a forced route.
  def frame
    c = @route.shift or return
    if (s = STEP[c])
      @x += s[0]
      @y += s[1]
      @direction = s[2]
      @walked << [@x, @y, @through, @move_speed]
    elsif TURN[c]
      @direction = TURN[c]
    end
  end
end

class HoopFakeMap
  attr_reader :events
  def initialize(events) = (@events = events)
end

$hoop_frames = 0
$hoop_log = []
$hoop_confirm = []
def pbMoveRoute(event, cmds) = event.force_route(cmds)
def pbUpdateSceneMap = ($hoop_frames += 1; $game_map.events.each_value(&:frame))
def pbWait(_s) = 3.times { pbUpdateSceneMap }
def pbSEPlay(name, *) = ($hoop_log << [:se, name])
def pbFadeOutIn = ($hoop_log << :fade; yield)
def pbConfirmMessage(m) = ($hoop_log << [:ask, m]; $hoop_confirm.shift)
def pbMessage(m, *)
  ev = $game_map.events[13]
  $hoop_log << [:msg, m, DesertTalk.name_key, [ev.x, ev.y, ev.direction, ev.character_name],
                [$game_player.x, $game_player.y, $game_player.direction], TempleHoop.state[:evyatar_seen]]
end

# Stands in for the modal: records where the player stood and returns a scripted result.
module TempleHoop
  class Scene
    @results = []
    class << self; attr_accessor :results; end
    def initialize(state) = (@state = state)
    def run
      $hoop_log << [:scene, [$game_player.x, $game_player.y, $game_player.direction]]
      self.class.results.shift
    end
  end
end
load File.join(hoop_dir, "001_state.rb")
load File.join(hoop_dir, "004_event.rb")

saved_map, saved_player = $game_map, $game_player
saves = []
autosave_was = DesertTownAutosave.method(:save_now)
save_view = nil
DesertTownAutosave.define_singleton_method(:save_now) do |reason|
  saves << reason
  save_view = [TempleHoop.state[:evyatar_seen], $game_map.events[13].walked.length]
  true
end
hoop_ev = HoopFakeChar.new("temple_hoop", 5, 13, "temple_hoop")
evy = HoopFakeChar.new("temple_hoop_evyatar", 0, 23)
$game_map = HoopFakeMap.new({ 12 => hoop_ev, 13 => evy })
$game_player = HoopFakeChar.new("player", 5, 14, "player")
$PokemonGlobal = PokemonGlobalMetadata.new
class HoopFakeFollowers
  attr_reader :put
  def put_followers_on_player = ($hoop_log << [:followers, $game_player.x, $game_player.y]; @put = true)
end
saved_temp = $game_temp
$game_temp = Struct.new(:followers).new(HoopFakeFollowers.new)
hoop_play = lambda do |confirm, result|
  $hoop_log.clear
  $hoop_confirm = [confirm]
  TempleHoop::Scene.results = [result]
  pbTempleHoop(hoop_ev)
end

check(hoop_play.call(false, nil) && $hoop_log == [[:ask, "HOOP_APPROACH"]] && $PokemonGlobal.temple_hoop[:plays] == 0,
      "hoop: No closes the prompt and starts nothing")
hoop_play.call(true, { finished: false, made: 3 })
check($hoop_log.include?([:scene, [6, 13, 4]]), "hoop: under the fade the player stands at (6,13) facing left")
check($hoop_log.index([:followers, 6, 13]) && $hoop_log.index([:followers, 6, 13]) < $hoop_log.index { |e| e.is_a?(Array) && e[0] == :scene },
      "hoop: followers are put on the player after the teleport, before the scene")
check($PokemonGlobal.temple_hoop == HR.new_state && $hoop_log.none? { |e| e.is_a?(Array) && e[0] == :msg } && saves.empty?,
      "hoop: a Blue quit counts nothing and brings no Evyatar")

$game_player.moveto(4, 13)
DesertTalk.name_key = "NAME_STALE" if DesertTalk.respond_to?(:name_key=)
frames_before = $hoop_frames
hoop_play.call(true, { finished: true, made: 3 })
msgs = $hoop_log.select { |e| e.is_a?(Array) && e[0] == :msg }
check(msgs.length == 1 && msgs[0][1] == "HOOP_EVYATAR_LINE", "hoop: the first finished round shows exactly one box, the line")
check(msgs[0][2] == "NAME_F90D4DE9", "hoop: Evyatar's line shows his name plate (#{msgs[0][2].inspect})")
check(msgs[0][3] == [7, 13, 4, "dt_f90d4de9"] && msgs[0][4] == [6, 13, 6],
      "hoop: Evyatar stands at (7,13) facing left, the player faces him")
check(msgs[0][5] == false && $PokemonGlobal.temple_hoop[:evyatar_seen], "hoop: the seen flag is set right after the box")
route_in = evy.walked.first(9).map { |x, y, _, _| [x, y] }
check(route_in == [[6, 20], [6, 19]] + (13..19).to_a.reverse.map { |y| [7, y] },
      "hoop: Evyatar walks up 2 from the arch, right 1, up 6 to (7,13) (#{route_in.inspect})")
route_out = evy.walked.last(9).map { |x, y, _, _| [x, y] }
check(route_out == (14..19).map { |y| [7, y] } + [[6, 19], [6, 20], [6, 21]], "hoop: he walks out the same way (#{route_out.inspect})")
check(evy.walked.length == 18 && evy.walked.all? { |_, _, th, sp| th && sp == 2 } && evy.walked.last[0, 2] == [6, 21],
      "hoop: he walks in and back out through the arch at speed 2 (below walking) with through on")
check([evy.x, evy.y, evy.character_name, evy.through] == [0, 23, "", false], "hoop: afterwards he is blank at (0,23), through off")
check($hoop_frames - frames_before > 18, "hoop: the walk advanced on map frames (#{$hoop_frames - frames_before})")
check(saves == [:temple_hoop], "hoop: autosave once during his visit")
check(save_view == [true, 9], "hoop: the autosave holds the seen flag and comes before he walks out (#{save_view.inspect})")
ses = $hoop_log.select { |e| e.is_a?(Array) && e[0] == :se }.map(&:last)
check(ses == ["Door enter", "Door exit"], "hoop: door sounds on his way in and out")

hoop_play.call(true, { finished: true, made: 5 })
check($hoop_log.none? { |e| e.is_a?(Array) && e[0] == :msg } && saves == [:temple_hoop] &&
      $PokemonGlobal.temple_hoop == { evyatar_seen: true, plays: 2, best: 5 }, "hoop: the second round is only the game")
$PokemonGlobal = PokemonGlobalMetadata.new
hoop_play.call(true, { finished: true, made: 0 })
check($hoop_log.count { |e| e.is_a?(Array) && e[0] == :msg } == 1, "hoop: a new game brings Evyatar again, at any score")
$PokemonGlobal = PokemonGlobalMetadata.new
$PokemonGlobal.temple_hoop = { evyatar_seen: true, plays: 1, best: 2 }
hoop_play.call(true, { finished: true, made: 4 })
check($hoop_log.none? { |e| e.is_a?(Array) && e[0] == :msg } && $PokemonGlobal.temple_hoop[:plays] == 2,
      "hoop: an old save with evyatar_seen = true brings no visit")
evy.instance_variable_set(:@name, "temple_hoop_toga")
check(TempleHoop.toga_event.equal?(evy), "hoop: event 13 is found by its new name too")
evy.instance_variable_set(:@name, "temple_hoop_evyatar")
$PokemonGlobal.temple_hoop = { plays: "x" }
check($PokemonGlobal.temple_hoop == HR.new_state, "hoop: a broken saved value loads as a fresh state")

$game_temp = saved_temp
DesertTownAutosave.define_singleton_method(:save_now, autosave_was)
DesertTalk.clear_speaker if DesertTalk.respond_to?(:clear_speaker)
$game_map, $game_player, $PokemonGlobal = saved_map, saved_player, nil

# The scene itself runs in its own process (fake Bitmap/Sprite/Input/clock).
require "rbconfig"
smoke = IO.popen([RbConfig.ruby, File.join(__dir__, "hoop_scene_smoke.rb")], err: [:child, :out], &:read)
smoke_fails = smoke.lines.grep(/FAIL|Error/).map(&:strip)
check($?.success? && smoke_fails.empty?, "hoop: scene smoke run passes (#{smoke_fails.first(3).inspect})")
