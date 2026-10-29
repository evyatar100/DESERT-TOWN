# TG64 LilyHappy: fake graphics, input, clock and messages shared by the two smoke runs
# (each runs in its own process, so these stubs never meet plugin_rules_test.rb).
ROOT = File.expand_path("..", __dir__)
$fails = []
def check(ok, msg) = (puts "  #{ok ? 'PASS' : 'FAIL'}: #{msg}"; $fails << msg unless ok)

$clock = 0.0
$all = []
Color = Struct.new(:r, :g, :b, :a)
class Rect
  attr_accessor :x, :y, :width, :height
  def initialize(x = 0, y = 0, w = 0, h = 0) = set(x, y, w, h)
  def set(x, y, w, h) = (@x, @y, @width, @height = x, y, w, h)
end
$sizes = {}      # fake PNG sizes by basename; dt_ charsets are always 128x192
$loaded = []
class Bitmap
  Font = Struct.new(:size)
  attr_reader :width, :height, :font
  def initialize(w, h = nil)
    if w.is_a?(String)
      base = File.basename(w)
      $loaded << base
      w, h = base.start_with?("dt_") ? [128, 192] : $sizes.fetch(base)
    end
    @width, @height, @font, @disposed = w, h, Font.new(20), false
    $all << self
  end
  def rect = Rect.new(0, 0, @width, @height)
  def text_size(s) = Rect.new(0, 0, s.to_s.length * 10, 20)
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
  attr_accessor :bitmap, :x, :y, :z, :ox, :oy, :zoom_x, :zoom_y, :visible, :src_rect
  def initialize(_vp)
    $all << self
    @src_rect = Rect.new
    @disposed = false
    @x = @y = @z = @ox = @oy = 0
    @zoom_x = @zoom_y = 1
    @visible = true
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
  LEFT = :left
  RIGHT = :right
  UP = :up
  DOWN = :down
  def self.update; end
  def self.trigger?(b) = $pressed.include?(b)
end
$pressed = []
$bgm = []
$se = []
def pbDrawShadowText(*) = nil
def _INTL(m, *a) = a.empty? ? m : "#{m}|#{a.join(',')}"
def pbSEPlay(*a) = $se << a
%w[pbBGMPlay pbBGMStop pbBGMFade pbBGSPlay].each { |n| define_method(n) { |*a| $bgm << [n, a] } }
def pbResolveBitmap(p) = (File.basename(p).start_with?("dt_") || $sizes.key?(File.basename(p))) ? p : nil
class PokemonGlobalMetadata; end

DIR = File.join(ROOT, "Plugins/zLilyHappy")
%w[000_rules 000_wheel_rules 001_state 002_art 003_scene].each { |f| load File.join(DIR, "#{f}.rb") }
R = LilyHappyRules
BOT_KEYS = { fix: Input::USE, left: Input::LEFT, right: Input::RIGHT, comp: Input::UP, moop: Input::DOWN }.freeze

def all_disposed? = $all.all?(&:disposed?)

# Plays the real game by inputs: Yellow on the title and card, the rules bot in play.
BOT = lambda do |_f, s|
  case s.phase
  when :title, :card then [Input::USE]
  when :play
    act = R.bot_input(s.game)
    act ? [BOT_KEYS[act]] : []
  end
end
