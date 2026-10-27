# TG11 hoop scene smoke run with fake graphics, input and clock (own process:
# its stubs would clash with plugin_rules_test.rb). Exit 0 = all checks passed.
ROOT = File.expand_path("..", __dir__)
$fails = []
def check(ok, msg) = (puts "  #{ok ? 'PASS' : 'FAIL'}: #{msg}"; $fails << msg unless ok)

$clock = 0.0
$all = []
Color = Struct.new(:r, :g, :b, :a)
class Rect
  attr_accessor :x, :y, :width, :height
  def set(x, y, w, h) = (@x, @y, @width, @height = x, y, w, h)
end
class Bitmap
  Font = Struct.new(:size)
  attr_reader :width, :height, :font
  def initialize(w, h = nil)
    w, h = 144, 336 if w.is_a?(String)
    @width, @height, @font, @disposed = w, h, Font.new(20), false
    $all << self
  end
  def fill_rect(*); end
  def set_pixel(*); end
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
  attr_accessor :bitmap, :x, :y, :z, :ox, :oy
  attr_reader :src_rect
  def initialize(_vp) = ($all << self; @src_rect = Rect.new; @disposed = false; @x = @y = @z = @ox = @oy = 0)
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
end
$pressed = []
$se = []
$drawn = []
def pbSEPlay(name, *) = ($se << name)
def pbDrawShadowText(_b, _x, _y, _w, _h, s, *) = ($drawn << s)
def _INTL(m, *a) = a.empty? ? m : "#{m}|#{a.join(',')}"
$pictures = false
def pbResolveBitmap(p) = $pictures ? p : nil

dir = File.join(ROOT, "Plugins/zTempleHoop")
%w[000_rules 002_art 003_scene].each { |f| load File.join(dir, "#{f}.rb") }
R = TempleHoopRules

# targets: the marker value to shoot at per shot; :blue quits at the first aim.
def play(targets, state = R.new_state, card_press: true)
  $se.clear
  $drawn.clear
  $all.clear
  scene = TempleHoop::Scene.new(state)
  zs = []
  $frame_hook = lambda do
    $pressed = []
    phase = scene.instance_variable_get(:@phase)
    zs << scene.instance_variable_get(:@ball).z if phase == :flight
    if phase == :aim && targets.first == :blue
      $pressed = [Input::BACK]
    elsif phase == :aim && targets.any?
      shot = scene.instance_variable_get(:@shot)
      v = scene.marker_value
      if (v - targets[shot]).abs < 3
        $pressed = [Input::USE]
      end
    elsif phase == :card && card_press
      $pressed = [Input::USE]
    end
  end
  $clock = 100.0
  result = scene.run
  card_at = scene.instance_variable_get(:@card_at)
  { result: result, zs: zs, card_for: card_at && $clock - card_at, disposed: $all.all?(&:disposed?) }
end

# The marker sits exactly on bar_y(value) from the first frame of each aim.
class TempleHoop::Scene
  alias_method :orig_start_aim, :start_aim
  def start_aim = (orig_start_aim; ($first_y ||= []) << [@marker.y, bar_y(marker_value)])
end
$marker_bad = []
class TempleHoop::Scene
  alias_method :orig_update_aim, :update_aim
  def update_aim
    r = orig_update_aim
    $marker_bad << [@marker.y, bar_y(marker_value)] if @phase == :aim && @marker.y != bar_y(marker_value)
    r
  end
end

out = play([72, 64, 40, 95, 80])
check($first_y.length == 5 && $first_y.all? { |a, b| a == b }, "smoke: the marker is placed in start_aim, not left at the top (#{$first_y.inspect})")
check($marker_bad.empty?, "smoke: the marker y equals bar_y(value) every aim frame (#{$marker_bad.first(2).inspect})")

# Colour edges follow the rules' bands.
bands = R::BANDS.map(&:dup)
bands[2][0] = 70
shifted = TempleHoop::Scene.band_colors(bands)
check(TempleHoop::Scene.band_colors.map(&:first) == R::BANDS.map(&:first) + [100] && shifted.map(&:first)[2] == 70 &&
      shifted[2][1] == TempleHoop::Scene::PATH_COLORS[:rim_in], "smoke: a changed band edge moves the colour edge with it")

check(out[:result] == { finished: true, made: 3 }, "smoke: swish, in, short, long, in is 3 of 5 (#{out[:result].inspect})")
check($se.count("Battle throw") == 5 && $se.include?("Voltorb Flip point") && $se.include?("Battle ball drop") &&
      $se.last == "GUI sel decision", "smoke: release SE per shot, outcome SEs, plain end SE")
check(out[:card_for] && out[:card_for] >= R::CARD_LOCK, "smoke: Red held on the card is ignored for 0.5 s (#{out[:card_for]&.round(2)})")
check($drawn.include?("HOOP_RESULT|3,5") && $drawn.none? { |s| s.start_with?("HOOP_BEST") }, "smoke: the first card shows the score, no best")
check(%w[HOOP_SWISH HOOP_MADE HOOP_MISSED HOOP_HINT].all? { |k| $drawn.include?(k) } && $drawn.include?("HOOP_SHOT|5,5"),
      "smoke: pop words, hint and shot label are drawn")
check(out[:zs].include?(5) && !out[:zs].include?(20), "smoke: without hoop_front.png a made ball drops under the hoop")
check(out[:disposed], "smoke: every bitmap, sprite and the viewport are disposed")

$pictures = true
out = play([72] * 5, { evyatar_seen: true, plays: 2, best: 4 })
check(out[:result] == { finished: true, made: 5 } && $se.last == "Mining found all", "smoke: 5 of 5 plays the big end SE")
check($drawn.include?("HOOP_BEST|5"), "smoke: a later round's card shows the best this run")
check(out[:zs].include?(20) && out[:zs].include?(40), "smoke: with hoop_front.png a make drops between the rim layers")

out = play([:blue])
check(out[:result] == { finished: false, made: 0 } && out[:disposed], "smoke: Blue at the first shot quits without a score")
exit($fails.empty? ? 0 : 1)
