# Kusomo TV poster countdown through the real HebrewSupport hooks (own process). Exit 0 = all passed.
# The poster draws through the same _INTL + pbDrawShadowText path as the DJ Rush and Tuta HUDs.
ROOT = File.expand_path("..", __dir__)
Dir.chdir(ROOT)
$fails = []
def check(ok, msg) = (puts "  #{ok ? 'PASS' : 'FAIL'}: #{msg}"; $fails << msg unless ok)

Color = Struct.new(:r, :g, :b, :a) do
  def initialize(r, g, b, a = 255) = super(r, g, b, a)
end
class Bitmap
  Font = Struct.new(:size, :color)
  attr_reader :font
  def initialize(*) = (@font = Font.new(20))
  def fill_rect(*); end
  def clear; end
end
# Engine-level stand-ins defined BEFORE HebrewSupport loads, so its hooks wrap them as in the game.
$drawn = []
def pbDrawShadowText(_b, _x, _y, w, _h, s, _base, _shadow = nil, align = 0) = ($drawn << [s, align, w])
def _INTL(*arg)
  s = arg[0].dup
  (1...arg.length).each { |i| s.gsub!(/\{#{i}\}/, arg[i].to_s) }
  s
end
load File.join(ROOT, "Plugins/HebrewSupport/hebrew_support.rb")
HebrewText.language = :he
%w[000_rules 002_poster 003_trace].each { |f| load File.join(ROOT, "Plugins/zKusomoTV/#{f}.rb") }

# What DJ Rush's text() hands the same hook for a centred HUD label.
def hud_visual(str)
  $drawn.clear
  pbDrawShadowText(Bitmap.new, 0, 0, 98, 24, str, nil, nil, 1)
  $drawn.first[0]
end

[10, 3, 1].each do |n|
  $drawn.clear
  KusomoTV.draw_countdown(Bitmap.new, n)
  top, bottom = $drawn.map(&:first)
  aligns = $drawn.map { |d| d[1] }
  check(top == "ךישממ קחשמה", "he #{n}: top line reads 'המשחק ממשיך' right to left (#{top.inspect})")
  check(bottom == "#{n} דועב", "he #{n}: bottom line reads 'בעוד #{n}' with the digits left to right (#{bottom.inspect})")
  check(aligns == [1, 1], "he #{n}: both lines centred (#{aligns.inspect})")
  check(top == hud_visual("המשחק ממשיך") && bottom == hud_visual("בעוד #{n}"),
        "he #{n}: same visual string the DJ Rush/Tuta HUD path draws for that text")
end

HebrewText.language = :en
$drawn.clear
KusomoTV.draw_countdown(Bitmap.new, 7)
check($drawn.map(&:first) == ["The game resumes", "in 7"], "en: 'The game resumes' / 'in 7' (#{$drawn.map(&:first).inspect})")
exit($fails.empty? ? 0 : 1)
