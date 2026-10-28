# TG48 Shira's wedding smoke run with fake graphics, input, clock, map and messages (own process:
# its stubs would clash with plugin_rules_test.rb). Exit 0 = all checks passed.
ROOT = File.expand_path("..", __dir__)
$fails = []
def check(ok, msg) = (puts "  #{ok ? 'PASS' : 'FAIL'}: #{msg}"; $fails << msg unless ok)

#--- graphics, input, clock ------------------------------------------------------------
$clock = 0.0
$all = []
Color = Struct.new(:r, :g, :b, :a)
class Rect
  attr_accessor :x, :y, :width, :height
  def initialize(x = 0, y = 0, w = 0, h = 0) = set(x, y, w, h)
  def set(x, y, w, h) = (@x, @y, @width, @height = x, y, w, h)
end
$sizes = {}      # fake PNG sizes by basename; empty = nothing installed
$loaded = []
class Bitmap
  Font = Struct.new(:size)
  Size = Struct.new(:width, :height)
  attr_reader :width, :height, :font
  def initialize(w, h = nil)
    if w.is_a?(String)
      $loaded << File.basename(w)
      w, h = $sizes.fetch(File.basename(w))
    end
    @width, @height, @font, @disposed = w, h, Font.new(20), false
    $all << self
  end
  def rect = Rect.new(0, 0, @width, @height)
  def text_size(s) = Size.new(s.to_s.length * 8, 16)
  def fill_rect(*); end
  def blt(*); end
  def stretch_blt(*); end
  def clear; end
  def dispose = (@disposed = true)
  def disposed? = @disposed
end
class Viewport
  attr_accessor :z
  def initialize(*) = ($all << self; @disposed = false)
  def dispose = (@disposed = true)
  def disposed? = @disposed
end
class Sprite
  attr_accessor :bitmap, :x, :y, :z, :visible, :color, :opacity
  attr_reader :src_rect
  def initialize(_vp = nil) = ($all << self; @disposed = false; @visible = true; @src_rect = Rect.new; @x = @y = 0)
  def dispose = (@disposed = true)
  def disposed? = @disposed
end
module Graphics
  def self.width = 512
  def self.height = 384
  def self.update = ($clock += 1 / 60.0; $frame_hook&.call)
end
module System
  def self.uptime = $clock
end
module Input
  USE = :use
  BACK = :back
  def self.update; end
  def self.trigger?(b) = $pressed.include?(b)
  def self.dir4 = $dir || 0
end
$pressed = []
$bgm = []
$me = []
$se = []
def pbDrawShadowText(*) = nil
def _INTL(m, *a) = a.empty? ? m : "#{m}|#{a.join(',')}"
%w[pbBGMPlay pbBGMStop pbBGMFade pbBGSPlay].each { |n| define_method(n) { |*a| $bgm << [n, a] } }
def pbMEPlay(*a) = $me << a
def pbSEPlay(n, *) = $se << n
def pbResolveBitmap(p) = $sizes.key?(File.basename(p)) ? p : nil
class PokemonGlobalMetadata
  attr_accessor :desert_player_charset
end
module EventHandlers
  @h = Hash.new { |h, k| h[k] = {} }
  def self.add(ev, id, pr) = (@h[ev][id] = pr)
  def self.trigger(ev, *a) = @h[ev].each_value { |pr| pr.call(*a) }
end
module MenuHandlers
  def self.add(*) = nil
end
module TempleStickers
  def self.player_charset = ($PokemonGlobal && $PokemonGlobal.desert_player_charset) || $game_player.character_name
end

dir = File.join(ROOT, "Plugins/zShiraWedding")
%w[000_rules 001_state 002_art 003_scene].each { |f| load File.join(dir, "#{f}.rb") }
R = ShiraWeddingRules
SEATS = R::SEATS

#--- the board by inputs ----------------------------------------------------------------
# A bot: a queue of [buttons, dir] frames; each input is followed by a released frame.
class Bot
  attr_reader :log
  def initialize = (@q = []; @log = [])
  def press(*b) = (@q << [b, 0] << [[], 0])
  def dir(d) = (@q << [[], d] << [[], 0])
  def step(scene)
    @tasks ||= []
    while @q.empty? && !@tasks.empty?
      @tasks.shift.call(scene, self)
    end
    @q.shift || [[], 0]
  end
  def task(&b) = ((@tasks ||= []) << b)
  DIRN = { down: 2, left: 4, right: 6, up: 8 }.freeze
  # Shortest joystick path between seats over NAV.
  def self.path(from, to)
    prev = { from => nil }
    q = [from]
    until q.empty?
      s = q.shift
      break if s == to
      R::NAV[s].each { |d, n| next if prev.key?(n); prev[n] = [s, d]; q << n }
    end
    out = []
    s = to
    while prev[s]
      s, d = prev[s]
      out.unshift(d)
    end
    out
  end
  def goto(scene, seat) = Bot.path(SEATS[scene.cursor], seat).each { |d| dir(DIRN[d]) }
end

def run_scene(limit: 20_000, &script)
  $all.clear
  $loaded.clear
  scene = ShiraWedding::Scene.new
  frames = 0
  $frame_hook = lambda do
    frames += 1
    raise "smoke: frame limit" if frames > limit
    $pressed, $dir = script.call(frames, scene)
    $pressed ||= []
  end
  [scene.run, scene]
ensure
  $frame_hook = nil
  $dir = 0
end

def all_disposed? = $all.all?(&:disposed?)
def bot_scene(bot) = run_scene { |_f, s| bot.step(s) }

res, = run_scene { |_f, s| s.phase == :title ? [[Input::BACK]] : [] }
check(res == { result: :quit } && all_disposed?, "T7 Blue on the title leaves and disposes everything")

# T7: every NAV edge by the joystick, select / deselect / swap, pause, leave; twice.
2.times do |round|
  bot = Bot.new
  edges = []
  bot.press(Input::USE)
  R::NAV.each do |seat, moves|
    moves.each do |d, to|
      bot.task { |s, b| b.goto(s, seat) }
      bot.task { |_s, b| b.dir(Bot::DIRN[d]) }
      bot.task { |s, _b| edges << [seat, d, SEATS[s.cursor] == to] }
    end
  end
  bot.task { |s, b| b.goto(s, :A1) }
  bot.task { |_s, b| b.press(Input::USE) }
  bot.task { |s, b| b.log << [:sel, s.sel]; b.press(Input::USE) }
  bot.task { |s, b| b.log << [:desel, s.sel]; b.press(Input::USE); b.goto(s, :K1) }
  bot.task { |s, b| b.goto(s, :K1); b.press(Input::USE) }
  bot.task { |s, b| b.log << [:swap, s.swaps, s.arr[0], s.arr[6]]; b.press(Input::USE); b.press(Input::BACK) }
  bot.task { |s, b| b.log << [:blue_drop, s.sel, s.phase]; b.press(Input::BACK) }
  bot.task { |s, b| b.log << [:pause, s.phase]; 3.times { b.dir(2) }; b.press(Input::USE) }
  $bgm.clear
  res, = bot_scene(bot)
  log = bot.log.to_h { |e| [e[0], e[1..]] }
  check(edges.length == R::NAV.values.sum(&:length) && edges.all? { |e| e[2] }, "T7 round #{round}: the cursor follows every NAV edge (#{edges.reject { |e| e[2] }.inspect})")
  check(log[:sel] == [0] && log[:desel] == [nil], "T7 round #{round}: Yellow selects, Yellow on the same seat deselects")
  check(log[:swap] == [1, :gavri, :angel], "T7 round #{round}: Yellow on another seat swaps and counts (#{log[:swap].inspect})")
  check(log[:blue_drop] == [nil, :play] && log[:pause] == [:pause], "T7 round #{round}: Blue drops a selection, then pauses")
  check(res == { result: :quit } && all_disposed? && $bgm.empty?, "T7 round #{round}: leave returns :quit, disposes everything, no BGM call")
end

# T8: the 6-swap solution by inputs, via the hint path.
def solve_bot(bot, arr)
  bot.press(Input::USE)
  a = arr
  hints = []
  while (h = R.hint(a))
    hints << h
    a = R.swap(a, *h)
  end
  hints.each do |i, j|   # a block per swap: each task keeps its own i, j
    bot.task { |s, b| b.goto(s, SEATS[i]) }
    bot.task { |_s, b| b.press(Input::USE) }
    bot.task { |s, b| b.goto(s, SEATS[j]) }
    bot.task { |_s, b| b.press(Input::USE) }
  end
  bot.task { |s, b| b.log << [:won, s.phase]; 90.times { b.dir(0) } }
  bot.task { |s, b| b.log << [:card, s.phase]; b.press(Input::USE) }
end
bot = Bot.new
solve_bot(bot, R::START)
$me.clear
res, scene = bot_scene(bot)
check(res == { result: :solved, swaps: 6 } && R.solved?(scene.arr), "T8 a 6-swap solve by inputs returns {solved, 6} (#{res.inspect})")
check(bot.log.assoc(:card) == [:card, :card] && $me.flatten.include?("Slots big win") && $se.include?("Mining found all"), "T8 the win plays SE and ME, then the card")
check(all_disposed? && $bgm.empty?, "T8 the solved board disposes everything; no BGM")

# T9: restart returns to START; T10 hint from the pause.
bot = Bot.new
bot.press(Input::USE)
bot.task { |_s, b| b.press(Input::USE); b.dir(2); b.press(Input::USE) }
bot.task { |s, b| b.log << [:moved, s.arr == R::START, s.swaps]; b.press(Input::BACK); b.dir(2); b.dir(2); b.press(Input::USE) }
bot.task { |s, b| b.log << [:restart, s.arr == R::START, s.swaps, s.phase]; b.press(Input::BACK); b.dir(2); b.press(Input::USE) }
bot.task { |s, b| b.log << [:hint, s.hint && s.hint[:seats]]; b.press(Input::BACK); 3.times { b.dir(2) }; b.press(Input::USE) }
res, = bot_scene(bot)
check(bot.log.assoc(:moved) == [:moved, false, 1] && bot.log.assoc(:restart) == [:restart, true, 0, :play], "T9 restart returns the board to START with 0 swaps")
check(bot.log.assoc(:hint) == [:hint, R.hint(R::START)], "T10 the pause hint marks the nearest solution's first misplaced guest")
check(res == { result: :quit }, "T9 leave after a restart is a quit")

# T17: a wrong-size PNG falls back; a missing charset draws a capsule; nothing raises.
$sizes = { "shira_poses" => [128, 192], "venue_props" => [10, 10], "dt_2f88eb7f" => [128, 192] }
run_scene { |_f, s| s.phase == :title ? [[Input::BACK]] : [] }
check($loaded.include?("shira_poses") && $loaded.include?("venue_props") && $loaded.include?("dt_2f88eb7f") && all_disposed?,
      "T17 installed PNGs load by name; a wrong-size one falls back and everything is disposed")
$sizes = {}
begin
  run_scene { |f, _s| raise "boom" if f == 5 }
rescue RuntimeError
  nil
end
check(all_disposed?, "T7 an error inside the loop still disposes everything (ensure)")

#--- the map: messages, bag, events --------------------------------------------------------
$msgs = []
$answers = []
def pbMessage(text, commands = nil, _cancel = 0, *) = ($msgs << text; commands ? ($answers.shift || commands.length - 1) : nil)
def pbShowCommands(_w, rows, _cancel) = ($msgs << [:menu, rows]; $answers.shift || rows.length - 1)
def pbFadeOutIn = yield
module DesertTalk
  class << self; attr_accessor :name_key; end
end
module GameData
  class Item
    Data = Struct.new(:portion_name, :pocket)
    def self.get(_id) = Data.new("Wedding Bag", 8)
  end
end
class PokemonBag
  def self.pocket_names = %w[1 2 3 4 5 6 7 8]
end
module DesertTownAutosave
  @saves = []
  class << self; attr_reader :saves; end
  def self.save_now(r) = (@saves << r; true)
end
class FakeBag
  def initialize = (@h = Hash.new(0))
  def quantity(i) = @h[i]
  def add(i, n = 1) = (@h[i] += n; true)
  def remove(i, n = 1) = (@h[i] >= n ? (@h[i] -= n; true) : false)
end

class Scene_Map
  Anim = Struct.new(:log)
  def spriteset = (@ss ||= SS.new)
  class SS
    def addUserAnimation(*a) = ($anims << a)
  end
end
$anims = []
class Spriteset_Map
  def self.viewport = :vp
end
module Settings
  EXCLAMATION_ANIMATION_ID = 3
end
module PBMoveRoute
  DOWN = 1
  LEFT = 2
  RIGHT = 3
  UP = 4
end
class Game_Map
  REAL_RES_X = 128
  REAL_RES_Y = 128
end
class FakeTable
  def initialize(over) = (@over = over)
  def [](x, y, z) = z == 2 && @over.include?([x, y]) ? 9 : 0
end
class FakeMap
  attr_accessor :display_x, :display_y, :events, :map_id, :blocked, :over
  def initialize = (@blocked = []; @over = []; @events = {}; @map_id = 98; @display_x = 12 * 128; @display_y = 16 * 128)
  def width = 42
  def height = 52
  def passable?(x, y, _d) = x.between?(0, 41) && y.between?(0, 51) && !@blocked.include?([x, y])
  def data = FakeTable.new(@over)
  def priorities = Hash.new(0).merge(9 => 1)
end
class FakeChar
  attr_accessor :x, :y, :character_name, :through, :move_speed, :opacity, :walk_anime, :direction, :name, :id
  def initialize(id, name, x, y, cs = "") = (@id, @name, @x, @y, @character_name, @through, @opacity = id, name, x, y, cs, true, 255; @mv = 0; @route = [])
  def moveto(x, y) = (@x, @y = x, y)
  def moving? = @mv > 0
  def move_route_forcing = !@route.empty? || moving?
  def route(cmds) = (@route += cmds)
  def update
    return @mv -= 1 if @mv > 0
    c = @route.shift
    return unless c
    @x += { PBMoveRoute::LEFT => -1, PBMoveRoute::RIGHT => 1 }.fetch(c, 0)
    @mv = 8
  end
  def passable?(x, y, d)
    nx = x + (d == 6 ? 1 : d == 4 ? -1 : 0)
    return false if [nx, y] == [$game_player.x, $game_player.y]
    $game_map.passable?(nx, y, 10 - d) && $game_map.events.values.none? { |e| !e.equal?(self) && [e.x, e.y] == [nx, y] }
  end
  def move_right = (@x += 1; @mv = 8; @direction = 6)
  def move_left = (@x -= 1; @mv = 8; @direction = 4)
  def turn_right = (@direction = 6)
  def turn_left = (@direction = 4)
  def turn_toward_player = (@direction = :player)
  def screen_x = 0
  def screen_y = 0
end
Temp = Struct.new(:message_window_showing, :in_menu, :player_transferring, :in_battle, :in_mini_update, :transition_processing)
$interp = false
def pbMapInterpreterRunning? = $interp
def pbMoveRoute(ev, cmds) = ev.route(cmds)
def map_frame
  $clock += 1 / 60.0
  $game_map.events.each_value(&:update)
  EventHandlers.trigger(:on_frame_update)
end
def pbWait(d)
  t0 = $clock
  map_frame while $clock - t0 < d
end

def fresh_world(stage: :none, player: [20, 26])
  $PokemonGlobal = PokemonGlobalMetadata.new
  $PokemonGlobal.shira_wedding = { stage: stage, best: nil }
  $bag = FakeBag.new
  $scene = Scene_Map.new
  $game_temp = Temp.new(false, false, false, false, false, false)
  $game_player = FakeChar.new(0, "player", *player, "dt_player")
  $game_map = FakeMap.new
  $game_map.events = { 16 => FakeChar.new(16, "shira_eviatar", 14, 22, "dt_f90d4de9"),
                       17 => FakeChar.new(17, "shira_wedding", 18, 5) }
  $msgs.clear
  $answers.clear
  $anims.clear
  ShiraWedding::Wander.reset_session!
end

%w[004_map 005_wander 006_debug].each { |f| load File.join(dir, "#{f}.rb") }
W = ShiraWedding::Wander
$play = { result: :solved, swaps: 7 }
module ShiraWedding
  def self.play = ($msgs << :BOARD; $play)
end
SH = $game_map ? nil : nil
def shira = $game_map.events[17]

# T6/T15: intro -> yes -> solved -> THANKS, item, BAG_JOKE, FINAL; then re-talks.
fresh_world
$answers = [0]
ShiraWedding.talk
seq = $msgs.reject { |m| m.is_a?(String) && m.start_with?("You ") || m.to_s.include?("\\me[") }
check(seq == %w[SHIRA_INTRO_1 SHIRA_INTRO_2 SHIRA_INTRO_3 SHIRA_HELP_PROMPT] + [:BOARD] + %w[SHIRA_THANKS SHIRA_BAG_JOKE SHIRA_FINAL],
      "T6/T15 intro, yes, solved: THANKS, bag, BAG_JOKE, FINAL (#{seq.inspect})")
key_msg = $msgs.index { |m| m.to_s.include?("\\me[Key item get]") }
check(key_msg && key_msg < $msgs.index("SHIRA_BAG_JOKE") && $msgs.index("SHIRA_BAG_JOKE") < $msgs.index("SHIRA_FINAL"), "T15 FINAL comes after the key-item message and BAG_JOKE")
check(ShiraWedding.state == { stage: :done, best: 7 } && $bag.quantity(:WEDDINGBAG) == 1 && DesertTownAutosave.saves.last == :shira_wedding,
      "T15 the stage is :done, one bag held, the game autosaves")
$msgs.clear
3.times { $answers = [1]; ShiraWedding.talk }
check($msgs.count("SHIRA_FINAL") == 0 && $msgs.count("SHIRA_AFTER") == 3 && $msgs.count("SHIRA_REPLAY_PROMPT") == 3, "T15 re-talk x3 shows AFTER, never FINAL again")
$msgs.clear
$answers = [0]
ShiraWedding.talk
check($msgs.include?(:BOARD) && ShiraWedding.state[:stage] == :done && $bag.quantity(:WEDDINGBAG) == 1, "T9/T12 a replay in :done changes nothing")

fresh_world
$answers = [1]
ShiraWedding.talk
check($msgs.last == "SHIRA_DECLINE" && ShiraWedding.state[:stage] == :asked, "T6 No -> DECLINE, the stage stays :asked")
$msgs.clear
$answers = [0]
$play = { result: :quit }
ShiraWedding.talk
check($msgs.first == "SHIRA_ASK_AGAIN" && $msgs.last == "SHIRA_QUIT_LINE" && ShiraWedding.state[:stage] == :asked, "T9 a quit board: QUIT_LINE, still :asked")
$play = { result: :solved, swaps: 7 }

fresh_world(stage: :bag)
$bag.add(:WEDDINGBAG)
ShiraWedding.talk
check($msgs == ["SHIRA_FINAL"] && ShiraWedding.state[:stage] == :done, "T15 an interrupted :bag shows FINAL once, then :done")
fresh_world(stage: :bag)
ShiraWedding.talk
check($msgs.first == "SHIRA_REISSUE" && $msgs.last == "SHIRA_FINAL" && $bag.quantity(:WEDDINGBAG) == 1, "T13 :bag without the bag: reissued, then FINAL")
fresh_world(stage: :seated)
ShiraWedding.talk
check($msgs.first == "SHIRA_THANKS" && $msgs.last == "SHIRA_FINAL" && $bag.quantity(:WEDDINGBAG) == 1, "T6 an interrupted :seated resumes the reward flow")
fresh_world(stage: :done)
$answers = [1]
ShiraWedding.talk
check($msgs.include?("SHIRA_REISSUE") && $bag.quantity(:WEDDINGBAG) == 1, "T13 :done, bag lost, Inbar not done: reissued")
module Bags
  def self.state = { inbar: :done }
end
fresh_world(stage: :done)
$answers = [1]
ShiraWedding.talk
check(!$msgs.include?("SHIRA_REISSUE") && $bag.quantity(:WEDDINGBAG) == 0, "T12 once Inbar is done the bag is never re-added")
Bags.singleton_class.send(:remove_method, :state)

# T20 mirror.
fresh_world
$PokemonGlobal.desert_player_charset = "dt_f90d4de9"
$answers = [1, 1]
ShiraWedding.talk
check($msgs.first(2) == %w[SHIRA_MIRROR SHIRA_INTRO_1], "T20 Shira's talk opens with SHIRA_MIRROR when the player is Eviatar")
$msgs.clear
pbShiraEviatar
check($msgs.first == "SHIRA_EV_MIRROR" && $msgs[1] == [:menu, %w[SHIRA_EV_SENT SHIRA_EV_PASS]] && $msgs.last == "MSG_F90D4DE9_LINE",
      "T20 Eviatar's mirror line comes before his menu; PASS is his own line")

# T6 summon: SENT -> calls, she walks in to (15,22) or (16,22), talks, walks out and parks.
[[[14, 23], [15, 22]], [[15, 22], [16, 22]]].each do |player, stop|
  fresh_world(player: player)
  $answers = [0, 1]
  stops = []
  ShiraWedding.singleton_class.alias_method(:talk_real, :talk) unless ShiraWedding.respond_to?(:talk_real)
  ShiraWedding.define_singleton_method(:talk) { stops << [shira.x, shira.y, shira.character_name]; talk_real }
  pbShiraEviatar
  ShiraWedding.singleton_class.send(:remove_method, :talk)
  ShiraWedding.singleton_class.alias_method(:talk, :talk_real)
  check($msgs.first(3) == [[:menu, %w[SHIRA_EV_SENT SHIRA_EV_PASS]], "SHIRA_EV_CALL_1", "SHIRA_EV_CALL_2"] && stops == [[*stop, "dt_50d0eeb7"]],
        "T6 SENT: Eviatar calls, Shira stops at #{stop.inspect} for a player at #{player.inspect} (#{stops.inspect})")
  check([shira.x, shira.y, shira.character_name, shira.through] == [18, 5, "", true], "T6 after the talk she walks out and parks")
end
fresh_world(stage: :done)
$answers = [1]
pbShiraEviatar
check($msgs.first == [:menu, %w[SHIRA_EV_MAZALTOV SHIRA_EV_SENT SHIRA_EV_PASS]] && $msgs.last == "SHIRA_EV_SENT_DONE" && shira.character_name == "",
      "T6 in :done SENT gives SENT_DONE and no summon")
fresh_world(stage: :done)
$answers = [0]
pbShiraEviatar
check($msgs.last(2) == %w[SHIRA_EV_THANKS_1 SHIRA_EV_THANKS_2], "D6 MAZALTOV thanks")

#--- T5/T22 the wander ------------------------------------------------------------------------
fresh_world
check(W.start_crossing && shira.move_speed == 4 && shira.through == false && shira.character_name == "dt_50d0eeb7", "T5 a crossing sets speed 4, collision on, her charset")
plan = W.cross
check(plan[:y] != 26 && (plan[:y] - 26).abs == 2, "T4 the row is 2 away from the player (#{plan[:y]})")
frames = 0
map_frame while W.crossing? && (frames += 1) < 2000
check(!W.crossing? && [shira.x, shira.y, shira.character_name, shira.through] == [18, 5, "", true], "T5 at the end she parks (blank, (18,5), through)")

fresh_world
W.start_crossing
x0 = shira.x
$game_temp.message_window_showing = true
60.times { map_frame }
check(shira.x == x0 && W.crossing?, "T5 a message window pauses her stepping")
$game_temp.message_window_showing = false
y = W.cross[:y]
$game_map.blocked << [shira.x + (W.cross[:dir] == 6 ? 3 : -3), y]
t0 = $clock
map_frame while W.crossing? && $clock - t0 < 5
check(!W.crossing? && shira.character_name == "" && $clock - t0 >= 1.0, "T5 a blocked step waits, then she fades out and parks (#{($clock - t0).round(2)} s)")

# No crossing starts while busy; at most one row scan per roll (T22).
scans = 0
R.singleton_class.alias_method(:pick_row_real, :pick_row)
R.define_singleton_method(:pick_row) { |*a| scans += 1; pick_row_real(*a) }
busy = { message: -> { $game_temp.message_window_showing = true }, interp: -> { $interp = true },
         transfer: -> { $game_temp.player_transferring = true }, song: -> { Bags.const_set(:Song, Module.new { def self.active? = true }) } }
busy.each do |what, on|
  fresh_world
  W.sched.merge!(clock: 0.0, due: true, since_arrival: 10.0)
  on.call
  120.times { map_frame }
  check(!W.crossing? && W.sched[:due] && W.picks.zero?, "T5 no crossing starts while #{what}")
  $interp = false
  Bags.send(:remove_const, :Song) if Bags.const_defined?(:Song, false)
end
fresh_world
scans = 0
W.rng = R::Lcg.new(48)
(1000 * 60).times { map_frame }
# Lcg(48) rolls m m m m c ... at 180 s steps: exactly one :cross in 1,000 s, so one scan.
check(scans == W.picks && scans == 1, "T22 the row scan runs only on a :cross roll (#{scans} scans in 1,000 s)")
R.singleton_class.send(:remove_method, :pick_row)
R.singleton_class.alias_method(:pick_row, :pick_row_real)

# Notice: '!' and a stop before :done; a heart and no stop in :done.
fresh_world(player: [20, 26])
$game_map.display_x = 12 * 128
W.rng = R::Lcg.new(5)
W.start_crossing
$game_player.moveto(19, W.cross[:y] + 1)
stopped = nil
200.times do
  map_frame
  if W.cross && W.cross[:notice_t] > 0
    stopped = shira.direction
    break
  end
end
check(stopped == :player && $anims.any? { |a| a[0] == 3 }, "T5 within 1 tile she stops, faces the player and shows '!'")

# T16: leaving the map resets the crossing; a stray visible Shira (a mid-crossing save) parks.
fresh_world
W.start_crossing
moved = [shira.x, shira.y] != [18, 5] && shira.character_name != ""
EventHandlers.trigger(:on_leave_map, 93, nil)
check(!W.crossing?, "T16 leaving the map resets the crossing")
check(moved && [shira.x, shira.y, shira.character_name, shira.through] == [18, 5, "", true],
      "T16 leaving the map (a walk-across keeps the Playa loaded) parks her: (18,5), blank, through")
fresh_world
shira.character_name = "dt_50d0eeb7"
shira.moveto(20, 30)
map_frame
check([shira.x, shira.y, shira.character_name] == [18, 5, ""], "T16 a visible Shira with no crossing (a mid-crossing save) is parked")
check(ShiraWedding.state[:stage] == :none, "T16 map changes never touch the quest state")
check(pbShiraWedding(nil) == true && $msgs.empty?, "a parked (blank) Shira never starts a talk")
check($bgm.empty?, "the plugin never touches the BGM (#{$bgm.inspect})")

puts($fails.empty? ? "ShiraWedding scene smoke passed." : "#{$fails.size} ShiraWedding scene smoke check(s) failed.")
exit($fails.empty? ? 0 : 1)
