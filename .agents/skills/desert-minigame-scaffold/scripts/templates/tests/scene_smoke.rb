# __TICKET__ __NAME__ scene smoke run with fake graphics, input and clock (own process: its
# stubs would clash with plugin_rules_test.rb). Exit 0 = all checks passed.
ROOT = File.expand_path("..", __dir__)
$fails = []
def check(ok, msg) = (puts "  #{ok ? 'PASS' : 'FAIL'}: #{msg}"; $fails << msg unless ok)

$clock = 0.0
$all = []
Color = Struct.new(:r, :g, :b, :a)
class Rect
  attr_accessor :x, :y, :width, :height
  def initialize(x = 0, y = 0, w = 0, h = 0) = (@x, @y, @width, @height = x, y, w, h)
end
$sizes = {}      # fake PNG sizes by name; empty = no PNGs installed
$loaded = []
class Bitmap
  Font = Struct.new(:size)
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
  attr_accessor :bitmap, :x, :y, :z, :visible
  def initialize(_vp) = ($all << self; @disposed = false; @visible = true)
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
$bgm = []
def pbDrawShadowText(*) = nil
def _INTL(m, *a) = a.empty? ? m : "#{m}|#{a.join(',')}"
%w[pbBGMPlay pbBGMStop pbBGMFade pbBGSPlay pbMEPlay].each { |n| define_method(n) { |*a| $bgm << [n, a] } }
def pbResolveBitmap(p) = $sizes.key?(File.basename(p)) ? p : nil
class PokemonGlobalMetadata; end

dir = File.join(ROOT, "Plugins/z__NAME__")
%w[000_rules 001_state 002_art 003_scene].each { |f| load File.join(dir, "#{f}.rb") }
R = __NAME__Rules

# script: phase -> lambda(frame, scene) returning the buttons pressed this frame.
def run_scene(state, record: true, limit: 3000, &script)
  $all.clear
  $loaded.clear
  scene = __NAME__::Scene.new(state, record: record)
  frames = 0
  $frame_hook = lambda do
    frames += 1
    raise "smoke: frame limit" if frames > limit
    $pressed = script.call(frames, scene) || []
  end
  [scene.run, scene]
ensure
  $frame_hook = nil
end

def all_disposed? = $all.all?(&:disposed?)

presser = lambda do |f, s|
  case s.phase
  when :title then [Input::USE]
  when :play then f.even? ? [Input::USE] : []
  when :card then [Input::BACK]
  end
end

st = R.new_state
res, = run_scene(st) { |_f, s| s.phase == :title ? [Input::BACK] : [] }
check(res[:result].nil? && st == R.new_state, "Blue on the title leaves and records nothing")
check(all_disposed?, "every sprite, bitmap and the viewport are disposed on leaving")

res, scene = run_scene(st, &presser)
vp = $all.find { |o| o.is_a?(Viewport) }
check(res[:result] == :won && st[:wins] == 1 && st[:plays] == 1, "a steady presser wins and the win is recorded once (#{st.inspect})")
check(vp && vp.z == 99_999, "the viewport sits at z 99_999, above pbFadeOutIn")
check(scene.game[:taps] == R::TARGET, "the game stops at the target")

st2 = R.new_state
res, = run_scene(st2, record: false, &presser)
check(res[:result] == :won && st2 == R.new_state, "an F9 game (record: false) never writes the state")

st3 = R.new_state
log = {}
res, = run_scene(st3) do |f, s|
  case s.phase
  when :title then [Input::USE]
  when :play
    log[:paused_at] ? (log[:resumed] = true; f > log[:pause_frame] + 70 ? [Input::BACK] : []) : (f > 30 ? [Input::BACK] : [])
  when :pause
    log[:pause_frame] ||= f
    log[:paused_at] ||= s.game[:time]
    log[:pause_time] = s.game[:time] unless log[:resumed]
    if log[:resumed] then [Input::BACK]
    elsif f > log[:pause_frame] + 60 then [Input::USE]
    end
  end
end
check(log[:paused_at] && log[:pause_time] == log[:paused_at], "the game clock is frozen during the pause")
check(log[:resumed] && res[:result].nil? && st3 == R.new_state, "Yellow resumes; Blue in the pause quits and records nothing")

st4 = R.new_state
res, = run_scene(st4) { |_f, s| { title: [Input::USE], card: [Input::BACK] }[s.phase] }
check(res[:result] == :lost && st4[:plays] == 1 && st4[:wins] == 0, "an idle game is lost and counted as a play")

$sizes = { "title" => [256, 96], "card_win" => [10, 10], "card_lose" => [256, 192] }
run_scene(R.new_state) { |_f, s| s.phase == :title ? [Input::BACK] : [] }
check($loaded.sort == %w[card_lose card_win title], "installed PNGs are loaded by name")
check(all_disposed?, "a wrong-size PNG falls back and is disposed")
$sizes = {}

begin
  run_scene(R.new_state) { |f, _s| raise "boom" if f == 5 }
rescue RuntimeError
  nil
end
check(all_disposed?, "an error inside the loop still disposes everything (ensure)")
check($bgm.empty?, "the scene never touches the BGM (#{$bgm.inspect})")

puts($fails.empty? ? "__NAME__ scene smoke passed." : "#{$fails.size} __NAME__ scene smoke check(s) failed.")
exit($fails.empty? ? 0 : 1)
