# TG23 Hot-Dog Rush smoke runs with fake graphics, input and clock (own process: its stubs
# would clash with plugin_rules_test.rb). Exit 0 = all checks passed.
ROOT = File.expand_path("..", __dir__)
$fails = []
def check(ok, msg) = (puts "  #{ok ? 'PASS' : 'FAIL'}: #{msg}"; $fails << msg unless ok)

$clock = 0.0
$all = []
Color = Struct.new(:r, :g, :b, :a)
Tone = Struct.new(:r, :g, :b, :gray)
class Rect
  attr_accessor :x, :y, :width, :height
  def initialize(x = 0, y = 0, w = 0, h = 0) = (@x, @y, @width, @height = x, y, w, h)
  def set(x, y, w, h) = (@x, @y, @width, @height = x, y, w, h)
end
class Bitmap
  Font = Struct.new(:size)
  attr_reader :width, :height, :font
  def initialize(w, h = nil)
    w, h = 128, 192 if w.is_a?(String)
    @width, @height, @font, @disposed = w, h, Font.new(20), false
    $all << self
  end
  def rect = Rect.new(0, 0, @width, @height)
  def text_size(s) = Rect.new(0, 0, s.to_s.length * @font.size / 2, @font.size)
  def fill_rect(*); end
  def blt(*); end
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
  attr_accessor :bitmap, :x, :y, :z, :ox, :oy, :zoom_x, :zoom_y, :visible, :color, :tone
  attr_reader :src_rect
  def initialize(_vp)
    $all << self
    @src_rect = Rect.new
    @disposed = false
    @x = @y = @z = @ox = @oy = 0
    @zoom_x = @zoom_y = 1
    @visible = true
  end
  def bitmap=(b)
    @bitmap = b
    @src_rect = Rect.new(0, 0, b.width, b.height) if b
  end
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
  UP = :up
  DOWN = :down
  LEFT = :left
  RIGHT = :right
  def self.update; end
  def self.trigger?(b) = $pressed.include?(b)
  def self.repeat?(b) = $pressed.include?(b)
end
$pressed = []
$se = []
$drawn = []
def pbSEPlay(name, *) = ($se << name)
def pbDrawShadowText(_b, _x, _y, _w, _h, s, *) = ($drawn << s)
def _INTL(m, *a) = a.empty? ? m : "#{m}|#{a.join(',')}"
$pictures = true
def pbResolveBitmap(p) = $pictures ? p : nil

dir = File.join(ROOT, "Plugins/zAllaStand")
%w[001_rules_rush 004_rush].each { |f| load File.join(dir, "#{f}.rb") }
R = AllaRushRules
BTN = { ketchup: Input::UP, mustard: Input::RIGHT, onion: Input::DOWN, kraut: Input::LEFT }.freeze

# mode: :law serves the decree, :wobble toggles a wrong topping on and off first, :ordered ignores the law,
# :idle never presses, :spam presses Red every frame.
def rush(mode, losses: 0, seed: 5)
  $se.clear
  $drawn.clear
  $all.clear
  scene = AllaStand::RushScene.new(losses, seed)
  iv = ->(n) { scene.instance_variable_get(n) }
  info = { decide: [], tint: 0, banner: [], slide: [], serve_at: [] }
  wobbled = Hash.new(0)
  $frame_hook = lambda do
    $pressed = []
    phase = iv.call(:@phase)
    idx = iv.call(:@index)
    bs = iv.call(:@bun_sprite)
    info[:tint] += 1 if bs && bs.color && bs.color.a.to_i > 0
    info[:banner] << $clock if phase == :banner && info[:banner_idx] != idx && (info[:banner_idx] = idx)
    info[:slide] << [idx, $clock] if phase == :slide_in && info[:slide].last&.first != idx
    info[:decide] << [idx, $clock] if phase == :decide && info[:decide].last&.first != idx
    next $pressed = [Input::USE] if phase == :card
    next unless phase == :decide
    ord = scene.order
    want = mode == :ordered ? R.as_ordered(ord) : R.apply_law(ord[:law], ord)
    bun = iv.call(:@bun)
    locked = $clock - iv.call(:@at) < R::INPUT_LOCK
    case mode
    when :spam then $pressed = [Input::USE]
    when :idle then nil
    else
      next if locked
      if mode == :wobble && wobbled[idx] < 2 && (extra = R::TOPPINGS - want).first
        wobbled[idx] += 1
        $pressed = [BTN[extra.first]]
      elsif (diff = (want - bun) + (bun - want)).any?
        $pressed = [BTN[diff.first]]
      else
        $pressed = [Input::USE]
      end
    end
  end
  start = $clock = 100.0
  result = scene.run
  info.merge(result: result, time: $clock - start, disposed: $all.all?(&:disposed?), scene: scene)
end

out = rush(:law)
check(out[:result] == { passed: true, correct: 9, shown: 9 }, "rush: applying the decree passes 9/9 (#{out[:result].inspect})")
check($se.count("Mining hammer") == 9 && $se.count("GUI summary change page") == 6 && !$se.include?("GUI sel buzzer"),
      "rush: a hammer per order, 3-2-1 SE twice (6), no buzzer")
check(out[:time] < 90, "rush: a fast player finishes in under 90 s (#{out[:time].round(1)} s)")
check(out[:banner].length == 2 && out[:slide].length == 9, "rush: two law banners and nine tickets (#{out[:banner].length}, #{out[:slide].length})")
gap = out[:slide].find { |i, _| i == 3 }[1] - out[:banner].first
check((gap - R::BANNER_TIME).abs < 0.1, "rush: the new-law beat lasts 3.0 s (#{gap.round(3)})")
check(%w[ALLA_RUSH_RESULT|9,9 ALLA_RUSH_PASS ALLA_LAW_BANNER ALLA_RUSH_HINT ALLA_RUSH_OK ALLA_RUSH_VOTED ALLA_RUSH_COUNT|9,9 ALLA_LAW_NUM|3 ALLA_TOP_KETCHUP].all? { |k| $drawn.include?(k) } &&
      %w[3 2 1].all? { |d| $drawn.include?(d) } && (0..5).any? { |n| $drawn.include?("ALLA_LAW_#{n}") },
      "rush: result card, banner with digits, hint, feedback, ballot badge, count and law numbers are drawn")
check(out[:disposed], "rush: every bitmap, sprite and the viewport are disposed")

out = rush(:wobble)
check(out[:result] == { passed: true, correct: 9, shown: 9 }, "rush: toggling a topping on and off again leaves the bun right (#{out[:result].inspect})")

out = rush(:ordered)
wrong = out[:result][:shown] - out[:result][:correct]
check(!out[:result][:passed] && out[:result][:shown] < 9 && wrong == 3, "rush: serving as ordered fails early at the third wrong (#{out[:result].inspect})")
check(out[:tint] == 6 * wrong && $se.count("GUI sel buzzer") == wrong && $drawn.include?("ALLA_RUSH_ILLEGAL") && $drawn.include?("ALLA_RUSH_FAIL"),
      "rush: a wrong serve tints the bun for exactly 6 frames and buzzes (#{out[:tint]} tinted, #{wrong} wrong)")

out = rush(:idle)
expect = 3 * (R::SLIDE_TIME + R.window(0) + R::RESULT_TIME) + R::CARD_LOCK
check(out[:result] == { passed: false, correct: 0, shown: 3 } && $se.count("GUI sel buzzer") == 3 && $drawn.include?("ALLA_RUSH_LATE") && (out[:time] - expect).abs < 0.5,
      "rush: three timeouts end the rush at P=7 (#{out[:result].inspect}, #{out[:time].round(2)} vs #{expect.round(2)})")
out = rush(:idle, losses: 2)
check(out[:result][:shown] == 5 && out[:disposed], "rush: at losses 2 (P=5) it ends after 5 timeouts (#{out[:result].inspect})")
out = rush(:idle, losses: 3)
gap = out[:decide][1][1] - out[:decide][0][1]
check((gap - (R.window(3) + R::RESULT_TIME + R::SLIDE_TIME)).abs < 0.1, "rush: the window eases to 11 s (#{gap.round(2)})")

out = rush(:spam)
check(out[:result][:shown] >= 3 && out[:result][:correct] <= out[:result][:shown], "rush: spamming Red serves wrongly and the rush ends (#{out[:result].inspect})")
$all.clear

# Red held through an order is ignored for the first 0.15 s of the window.
decide_frames = nil
lock_scene = AllaStand::RushScene.new(0, 5)
decide_frames = 0
$frame_hook = lambda do
  ph = lock_scene.instance_variable_get(:@phase)
  idx = lock_scene.instance_variable_get(:@index)
  $pressed = ph == :decide || ph == :card ? [Input::USE] : []
  decide_frames += 1 if ph == :decide && idx == 0
end
$clock = 400.0
lock_scene.run
check(decide_frames >= (R::INPUT_LOCK * 60).floor, "rush: the first order's decision waits out the 0.15 s lock (#{decide_frames} frames)")

exit($fails.empty? ? 0 : 1)
