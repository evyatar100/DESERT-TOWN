# TG65 QuestMarks overlay smoke (T5, T6, Lily T22) on a stub engine: sprites per target, hidden
# while busy, rebuilt on the busy->free edge, disposed on map change and Scene_Map#dispose.
# Exit 0 = all checks passed.
ROOT = File.expand_path("..", __dir__)
$fails = []
def check(ok, msg) = (puts "  #{ok ? 'PASS' : 'FAIL'}: #{msg}"; $fails << msg unless ok)

$all = []
Color = Struct.new(:r, :g, :b, :a) do
  def initialize(r, g, b, a = 255) = super
end
class Bitmap
  attr_reader :width, :height, :fills
  def initialize(w, h) = (@width, @height, @fills, @disposed = w, h, [], false; $all << self)
  def fill_rect(*a) = @fills << a
  def dispose = (@disposed = true)
  def disposed? = @disposed
end
class AnimatedBitmap
  SIZES = { "dt_tuta" => [192, 320] }.freeze
  attr_reader :height
  def initialize(path) = (@height = SIZES.fetch(File.basename(path), [128, 192])[1])
  def dispose; end
end
class Viewport
  attr_accessor :z
  def initialize(*) = (@disposed = false; $all << self)
  def dispose = (@disposed = true)
  def disposed? = @disposed
end
class Sprite
  attr_accessor :bitmap, :x, :y, :visible
  def initialize(vp) = (@vp, @disposed, @visible = vp, false, true; $all << self)
  def viewport = @vp
  def dispose = (@disposed = true)
  def disposed? = @disposed
end
module Graphics
  def self.width = 512
  def self.height = 384
end
module MenuHandlers
  def self.add(*); end
end
GameTemp = Struct.new(:message_window_showing, :in_menu, :in_battle, :player_transferring)
$game_temp = GameTemp.new(false, false, false, false)
GamePlayer = Struct.new(:move_route_forcing)
$game_player = GamePlayer.new(false)
$interp = false
def pbMapInterpreterRunning? = $interp

class Ev
  attr_accessor :name, :x, :y, :transparent, :opacity, :character_name
  def initialize(name, x, y) = (@name, @x, @y, @transparent, @opacity, @character_name = name, x, y, false, 255, name)
  def screen_x = @x * 32 + 16
  def screen_y = @y * 32 + 32
  def erase! = (@erased = true; @character_name = "")
end
class GameMap
  attr_reader :map_id, :events
  def initialize(id, events) = (@map_id, @events = id, events)
end
def map91 = GameMap.new(91, { 4 => Ev.new("dt_648b924a", 6, 5), 5 => Ev.new("dt_f9348fd0", 4, 4), 9 => Ev.new("dt_00000000", 8, 8) })
def map98 = GameMap.new(98, { 2 => Ev.new("dt_648b924a", 5, 3), 7 => Ev.new("dt_6b53f14c", 3, 6), 11 => Ev.new("dt_6b53f14c", 9, 8),
                              12 => Ev.new("dt_f9348fd0", 8, 9) })

# The engine's Scene_Map: update runs $on_update (the interpreter), miniupdate does nothing.
class Scene_Map
  def update = $on_update&.call(self)
  def miniupdate; end
  def dispose = ($disposed_scene = true)
end
class PokemonGlobalMetadata; end
$PokemonGlobal = PokemonGlobalMetadata.new

LILY = File.join(ROOT, "Plugins/zLilyHappy")
QM = File.join(ROOT, "Plugins/QuestMarks")

# --- T6: a quest without QuestMarks, then QuestMarks with no quests -------------------------
begin
  %w[000_rules 001_state 008_marks].each { |f| load File.join(LILY, "#{f}.rb") }
  check(!defined?(QuestMarks), "T6: Lily's adapter loads and does nothing without QuestMarks")
rescue StandardError => e
  check(false, "T6: Lily's adapter raised without QuestMarks: #{e.message}")
end
%w[000_rules 001_registry 002_overlay 003_debug].each { |f| load File.join(QM, "#{f}.rb") }
O = QuestMarks::Overlay
$scene = Scene_Map.new
$game_map = map91
def frames(n, scene = $scene) = n.times { scene.update }
def live = O.sprites.values.reject(&:disposed?)
def shown = live.select(&:visible)
begin
  frames(5)
  check(QuestMarks.clients.empty? && O.sprites.empty?, "T6: QuestMarks with no clients draws nothing and raises nothing")
rescue StandardError => e
  check(false, "T6: QuestMarks alone raised: #{e.message}")
end

# --- Lily registers; count predicate runs -----------------------------------------------
LilyHappy.send(:remove_const, :MARKS)
load File.join(LILY, "008_marks.rb")
$calls = 0
blk = QuestMarks.instance_variable_get(:@clients)[:lily]
QuestMarks.register(:lily) { |m| $calls += 1; blk.call(m) }
st = $PokemonGlobal.lily_happy
frames(3)
check(O.sprites.empty?, "D1: :none -> no mark (givers off)")
LilyHappyRules.start!(st)
$game_temp.message_window_showing = true   # Lily's GO lines, then the talk ends
frames(1)
$game_temp.message_window_showing = false
frames(1)
check(O.ids == [5] && shown.size == 1, "T22: :asked on 91 -> one mark, over Shorty (#{O.ids.inspect})")
spr = O.sprites[5]
check(spr.viewport.z == 99_990 && spr.bitmap.width == 12 && spr.bitmap.height == 16, "D2/D3: 12x16 balloon on its own z 99_990 viewport")
ev = $game_map.events[5]
check(spr.x == ev.screen_x - 6 && (ev.screen_y - 48 - 18 - spr.y).abs <= 2, "D2: x = screen_x - 6, y = screen_y - 48 - 18 +- bob (#{spr.x},#{spr.y})")
ys = Array.new(40) { frames(1); spr.y }
check(ys.max - ys.min == 4, "D2: the mark bobs +-2 px over 40 frames")

# --- hidden while busy, including a message started inside update -----------------------
$game_temp.message_window_showing = true
frames(1)
check(shown.empty? && live.size == 1, "T5: hidden while a message shows (sprite kept)")
$game_temp.message_window_showing = false
%i[in_menu in_battle player_transferring].each do |f|
  $game_temp[f] = true
  frames(1)
  check(shown.empty?, "T2/T5: hidden while #{f}")
  $game_temp[f] = false
end
$game_player.move_route_forcing = true
frames(1)
check(shown.empty?, "T5: hidden during a forced route")
$game_player.move_route_forcing = false
frames(1)
seen = nil
$on_update = lambda do |scene|   # a talk: the interpreter opens a message inside update
  $interp = true
  $game_temp.message_window_showing = true
  scene.miniupdate
  seen = shown.size
  LilyHappyRules.hear!(st, :shorty)
  $game_temp.message_window_showing = false
  $interp = false
end
frames(1)
$on_update = nil
check(seen == 0, "D4: a message opened inside update never shows the mark (miniupdate sync)")
check(O.ids.empty? && live.empty?, "T22: the talk ends -> Shorty's mark is gone on the busy->free edge")

# --- map change ------------------------------------------------------------------------
old = $all.grep(Sprite).size
$game_map = map98
frames(1)
check(O.ids == [7, 11], "T22: the Playa marks both Loooo spots, not Shorty (heard) (#{O.ids.inspect})")
LilyHappyRules.hear!(st, :loooo)   # an F9-style change with no busy edge
$calls = 0
frames(600)
check(O.ids.empty?, "D6: the 60-frame poll catches a change made without a busy edge")
check($calls <= 600 / QuestMarksRules::POLL + 1, "T5: predicates run at most once per POLL frames when idle (#{$calls})")
%i[gufak turtle].each { |e| LilyHappyRules.hear!(st, e) }
$game_temp.in_menu = true
frames(1)
$game_temp.in_menu = false
frames(1)
check(O.ids == [2] && shown.size == 1, "TG65 D8: ready -> Lily herself is marked on the Playa")
n = $all.grep(Sprite).size
frames(600)
check($all.grep(Sprite).size == n && live.size == 1, "T5: the sprite count stays stable over 600 idle frames")
check($all.grep(Sprite).first(old).all?(&:disposed?), "T5: the map change disposed the old map's sprites")

# --- drawability and off-screen -------------------------------------------------------------
$game_map.events[2].x = 40
frames(1)
check(shown.empty? && live.size == 1, "D2: a mark whose box is off screen is hidden")
$game_map.events[2].x = 5
$game_map.events[2].erase!
frames(1)
check(shown.empty?, "D2: an erased event shows no mark")

# --- :wheeled, MARKS off, ENABLED off, dispose ------------------------------------------------
$game_map = map91
LilyHappyRules.wheel_done!(st, 3, 1)
frames(1)
check(O.ids == [4], "T22: :wheeled -> no complainer marks, Lily marked (#{O.ids.inspect})")
LilyHappy.send(:remove_const, :MARKS)
LilyHappy.const_set(:MARKS, false)
$game_temp.message_window_showing = true
frames(1)
$game_temp.message_window_showing = false
frames(1)
check(O.ids.empty? && live.empty?, "T22: LilyHappy::MARKS = false -> no Lily marks")
LilyHappy.send(:remove_const, :MARKS)
LilyHappy.const_set(:MARKS, true)
QuestMarks.send(:remove_const, :ENABLED)
QuestMarks.const_set(:ENABLED, false)
frames(1)
check(O.sprites.empty? && O.viewport.nil?, "T1/D7: ENABLED = false -> no sprites, viewport gone")
QuestMarks.send(:remove_const, :ENABLED)
QuestMarks.const_set(:ENABLED, true)
frames(1)
check(O.ids == [4], "marks come back when ENABLED is true again")
$scene.dispose
check($disposed_scene && $all.grep(Sprite).all?(&:disposed?) && $all.grep(Viewport).all?(&:disposed?),
      "T5/D7: Scene_Map#dispose disposes every mark sprite and the viewport")
$scene = Scene_Map.new
frames(1)
check(O.ids == [4] && live.size == 1, "a new Scene_Map (title -> Continue) rebuilds on its first frame")

# --- frame height from the charset (Tuta-size) ------------------------------------------------
check(O.frame_h("dt_tuta") == 80 && O.frame_h("dt_648b924a") == 48, "D2: frame_h = charset height / 4, cached per name")

# --- a broken client never breaks the map -----------------------------------------------------
QuestMarks.register(:broken) { |_m| raise "boom" }
begin
  frames(61)
  check(QuestMarks.disabled?(:broken) && O.ids == [4], "D5: a raising client is disabled; the others still mark")
rescue StandardError => e
  check(false, "D5: a raising client broke the map: #{e.message}")
end

check(!defined?(PokemonGlobalMetadata.new.quest_marks), "D7: nothing is added to the save")
puts($fails.empty? ? "QuestMarks smoke passed." : "#{$fails.size} QuestMarks smoke check(s) failed.")
exit($fails.empty? ? 0 : 1)
