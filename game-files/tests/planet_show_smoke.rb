# TG10 planetarium show smoke run with fake graphics, audio, input and clock (own
# process: its stubs would clash with plugin_rules_test.rb). Exit 0 = all checks passed.
# Every Graphics.update is one frame and moves the fake audio position, like the engine.
ROOT = File.expand_path("..", __dir__)
$fails = []
def check(ok, msg) = (puts "  #{ok ? 'PASS' : 'FAIL'}: #{msg}"; $fails << msg unless ok)
def echoln(msg) = ($echo << msg)
$echo = []

load File.join(ROOT, "Plugins/HebrewSupport/hebrew_support.rb")   # HebrewText + SimpleJSONParser, no hooks yet

$live = []      # every created graphic object
Color = Struct.new(:red, :green, :blue, :alpha) do
  def initialize(r, g, b, a = 255) = super(r, g, b, a)
end
Rect = Struct.new(:x, :y, :width, :height)
class Bitmap
  Font = Struct.new(:size, :color)
  Size = Struct.new(:width, :height)
  attr_reader :width, :height, :font, :blts
  def initialize(w, h) = (@width, @height, @font, @disposed, @blts = w, h, Font.new(20), false, []; $live << self)
  def fill_rect(*); end
  def draw_text(*); end
  def clear = (@blts = [])
  def blt(x, _y, _src, rect) = (@blts << [x, rect.width])
  # 0.45 em per character; good enough to wrap like the real font.
  def text_size(s) = Size.new((HebrewText.clusters(s.to_s).length * @font.size * 0.45).round, @font.size)
  def dispose = (@disposed = true)
  def disposed? = @disposed
end
class Viewport
  attr_accessor :z
  def initialize(*) = (@disposed = false; $live << self)
  def dispose = (@disposed = true)
  def disposed? = @disposed
end
class Sprite
  attr_accessor :bitmap, :x, :y, :z, :ox, :oy, :opacity, :angle, :zoom_x, :zoom_y
  def initialize(_vp) = (@disposed = false; @x = @y = @z = @ox = @oy = 0; @opacity = 255; $live << self)
  def dispose = (@disposed = true)
  def disposed? = @disposed
end
class Plane < Sprite; end
$frame_hook = nil
$frames = 0
$audio = { playing: nil, pos: 0.0, speed: 0.1, len: 558.141, loops: true }
module Graphics
  @frozen = false
  class << self; attr_accessor :frozen_log; end
  self.frozen_log = []
  def self.width = 512
  def self.height = 384
  def self.frame_rate = 60
  def self.update
    $frames += 1
    if $audio[:playing] && !$audio[:stalled]
      $audio[:pos] += $audio[:speed]
      $audio[:pos] -= $audio[:len] if $audio[:pos] >= $audio[:len] && $audio[:loops]
    end
    $frame_hook&.call
  end
  def self.freeze = frozen_log << :freeze
  def self.transition(n = 0) = frozen_log << [:transition, n]
end
module Input
  BACK = :back
  def self.update; end
  def self.trigger?(b) = $pressed.include?(b)
end
$pressed = []
module Audio
  def self.bgm_pos = $audio[:pos_override] || $audio[:pos]
  def self.bgm_play(path, _v, _p, pos = 0)
    raise ArgumentError, "no seek" if $audio[:no_seek]
    $audio_log << [:raw_play, path, pos]
    $audio[:playing] = path
    $audio[:pos] = pos.to_f
  end
end
module FileTest
  def self.audio_exist?(f) = !$missing.include?(:audio) || !f.include?("planetarium")
end
$missing = []
class File
  class << self
    alias planet_exist? exist?
    def exist?(f) = ($missing.include?(:timing) && f.to_s.include?("planetarium_timing")) ? false : planet_exist?(f)
  end
end
AF = Struct.new(:name, :volume, :pitch)
$audio_log = []
class FakeSystem
  attr_accessor :playing_bgm, :playing_bgs
  def bgm_play(b) = ($audio_log << [:bgm_play, b&.name]; @playing_bgm = b)
  def bgs_play(b) = ($audio_log << [:bgs_play, b&.name]; @playing_bgs = b)
end
class FakeMap
  def autoplay = $audio_log << [:autoplay]
end
def pbBGMPlay(name, *) = ($audio_log << [:play, name]; $audio[:playing] = name; $audio[:pos] = 0.0; $game_system.playing_bgm = AF.new(name))
def pbBGMFade(s) = ($audio_log << [:bgm_fade, s]; $game_system.playing_bgm = nil)
def pbBGSFade(s) = ($audio_log << [:bgs_fade, s]; $game_system.playing_bgs = nil)
def pbBGMStop = ($audio_log << [:bgm_stop]; $audio[:playing] = nil; $game_system.playing_bgm = nil)
def pbBGSStop = ($audio_log << [:bgs_stop]; $game_system.playing_bgs = nil)
def pbSetSystemFont(_b); end
$drawn = []
def pbDrawOutlineText(_b, _x, _y, _w, _h, s, *) = ($drawn << s)
def _INTL(m, *a) = a.empty? ? m : "#{m}|#{a.join(',')}"
$confirms = []
def pbMessage(m, choices = nil, cancel = 0) = ($audio_log << [:ask, m, $audio[:playing], choices, cancel]; $confirms.shift ? 0 : 1)
module DesertTalk
  def self.clear_speaker = ($cleared = true)
end

dir = File.join(ROOT, "Plugins/zPlanetarium")
%w[000_rules 002_sky 003_crawl 004_show].each { |f| load File.join(dir, "#{f}.rb") }
R = PlanetRules
Show = Planet::Show

def reset(bgm: "Deep Playa 3", bgs: "fire")
  $live.clear
  $drawn.clear
  $audio_log.clear
  $echo.clear
  $frames = 0
  $pressed = []
  $frame_hook = nil
  $audio.merge!(playing: bgm, pos: 0.0, stalled: false, pos_override: nil, no_seek: false, speed: 0.1)
  $game_system = FakeSystem.new
  $game_system.playing_bgm = bgm && AF.new(bgm)
  $game_system.playing_bgs = bgs && AF.new(bgs)
  $game_map = FakeMap.new
  Graphics.frozen_log = []
end

def live_count = $live.count { |o| (o.is_a?(Sprite)) && !o.disposed? }
def all_disposed? = $live.all?(&:disposed?)

#--- full run ------------------------------------------------------------------
reset
timing = Show.load_timing
check(timing && !timing[:placeholder] && timing[:source].include?("KA71"), "smoke: the shipped KA71 timing loads (no placeholder)")
show = Show.prepare
max_sprites = 0
early = []
digits_out = []
crawl = nil
seen_play = nil
$frame_hook = lambda do
  sh = show
  c = sh.instance_variable_get(:@crawl)
  clock = sh.instance_variable_get(:@clock)
  next unless c && clock
  crawl = c
  t = clock[:t]
  max_sprites = [max_sprites, live_count].max
  c.instance_variable_get(:@slots).each_key do |i|
    early << [i, t] if c.chunks[i][:start] > t + 0.11   # one frame of audio is 0.1 s here
  end
  sky = sh.instance_variable_get(:@sky)
  digit = sky.instance_variable_get(:@digit)
  digits_out << t if digit.opacity > 0 && R.countdown_at(t, sh.instance_variable_get(:@segs)).nil?
  seen_play ||= Show.running?
end
result = show.play
check(result == :done, "smoke: the show runs to the end of the audio (#{result.inspect})")
check(seen_play == true && !Show.running?, "smoke: running while it plays, not after")
check($audio_log.include?([:play, "planetarium"]) && $audio_log.index([:bgm_fade, 1.0]) < $audio_log.index([:play, "planetarium"]),
      "smoke: map music fades (1 s) before the recording starts")
check($audio_log.include?([:bgs_fade, 1.0]) && $audio_log.include?([:bgs_stop]), "smoke: the BGS fades and stops")
tail = $audio_log.drop_while { |e| e != [:play, "planetarium"] }
check(tail.include?([:bgm_play, "Deep Playa 3"]) && tail.include?([:bgs_play, "fire"]) && !tail.include?([:autoplay]),
      "smoke: the memorized map BGM and BGS come back at the end")
check(Graphics.frozen_log == [:freeze, [:transition, 16]], "smoke: the map fades back in (freeze, transition)")
check(all_disposed?, "smoke: every sprite, bitmap and the viewport are disposed")
check(max_sprites <= 120, "smoke: at most 120 sprites at once (#{max_sprites})")
check(early.empty?, "smoke: no row is on screen before its chunk's start (#{early.first(3).inspect})")
check(digits_out.empty?, "smoke: countdown digits only in the last 10 s of the gap (#{digits_out.first(3).inspect})")
check($frames.between?(5000, 6000), "smoke: frames follow the audio clock (#{$frames})")
check($cleared, "smoke: the name plate is cleared first")

# Every row the crawl draws, per line, rebuilds the line; together they are the narration.
rows = crawl.row_texts
by_line = rows.group_by(&:first).transform_values { |cs| cs.flat_map(&:last).join(" ") }
check(by_line.values == timing[:lines].map { |l| l[:text] }, "smoke: the crawl's rows rebuild every timing line exactly")
inside = false
spoken = File.read(File.join(ROOT, "..", "docs/design/planetarium-narration-spoken.md"), encoding: "utf-8").split("\n").filter_map do |raw|
  inside = raw.start_with?("## Lines") if raw.start_with?("## ")
  inside && raw.match?(/\A\| (\d+|P\d\d[a-z]) \|/) && raw[2..-3].split(" | ", -1)[4].strip
end
check(spoken.length == 54 && by_line.keys == (0...54).to_a && by_line.values.map(&:b) == spoken.map(&:b),
      "smoke: every on-screen line equals planetarium-narration-spoken.md byte for byte, 54 lines in order")
crawl_drawn = $drawn.uniq
check(crawl_drawn.all? { |s| rows.any? { |_, rs| rs.include?(s) } } && !crawl_drawn.join.match?(/\[|מבוטא|rotter/),
      "smoke: nothing else is drawn as text; no bracket, 'מבוטא' or 'rotter'")
mismatch = rows.flat_map(&:last).reject do |s|
  ch = HebrewText.clusters(s)
  Planet::Crawl.visual_order(s).map { |i| ch[i] }.join == HebrewText.visual_reverse(s)
end
check(mismatch.empty?, "smoke: the read-along mask uses the same bidi order as the drawn row (#{mismatch.first.inspect})")
flat = rows.flat_map(&:last)
runs = ["Nature Fictional Astrology", "Rotter.net", "Olympus Mons", "Mons Pubis", "1969", "1948"]
split = runs.reject { |r| (row = flat.find { |s| s.include?(r) }) && HebrewText.visual_reverse(row).include?(r) }
check(split.empty?, "smoke Q10: Latin and number runs stay on one row and draw in LTR order (#{split.inspect})")

#--- Back -> No, then Back -> Yes ------------------------------------------------
reset
show = Show.prepare
$confirms = [false, true]
asked = 0
$frame_hook = lambda do
  clock = show.instance_variable_get(:@clock)
  $pressed = clock && [200, 400].include?($frames) ? [Input::BACK] : []
  asked += 1 if $pressed.any?
end
result = show.play
asks = $audio_log.select { |e| e[0] == :ask }
check(result == :left && asks.length == 2 && asks.all? { |e| e[1] == "PLANET_SKIP_ASK" && e[2] == "planetarium" },
      "smoke Q4: Back asks; No keeps playing (audio never stopped), Yes leaves")
check(asks.all? { |e| e[3] == %w[PLANET_CHOICE_YES PLANET_CHOICE_NO] && e[4] == 2 },
      "smoke: the leave question shows the written Yes/No choices, Back = No")
leave = $audio_log.drop_while { |e| e[0] != :ask }.drop(1).drop_while { |e| e[0] != :ask }
check(leave.include?([:bgm_fade, 1.0]) && leave.index([:bgm_fade, 1.0]) < leave.index([:bgm_play, "Deep Playa 3"]),
      "smoke Q4: Yes fades the recording (1 s), then the map music returns")
check(all_disposed? && Graphics.frozen_log == [:freeze, [:transition, 16]], "smoke Q4: a clean exit")

#--- missing files -------------------------------------------------------------
reset(bgm: nil, bgs: nil)
$missing = [:audio]
show = Show.prepare
$audio[:speed] = 0.0
result = show.play
check(result == :done && !$audio_log.include?([:play, "planetarium"]) && $echo.any? { |e| e.include?("missing: silent") },
      "smoke Q7: no ogg: a silent show on the frame clock, then a normal end")
check($audio_log.include?([:autoplay]) && $frames > 33_000, "smoke Q7: nothing was playing before: the map autoplays after")
reset
$missing = [:timing]
show = Show.prepare
result = show.play
check(result == :done && show.instance_variable_get(:@crawl).nil? && $drawn.empty? && $echo.any? { |e| e.include?("stars only") },
      "smoke Q7: no timing: audio plus stars, no text, normal end")
$missing = [:audio, :timing]
check(Show.prepare.nil?, "smoke Q7: both missing: no show (Eyal says BROKEN)")
$missing = []

#--- stuck position, loop, error, re-entry, debug seek ---------------------------
reset
$audio[:pos_override] = 0.0
show = Show.prepare
$audio[:speed] = 0.0
result = show.play
check(result == :done && $echo.any? { |e| e.include?("stuck") }, "smoke: a position stuck at 0 falls back to the frame clock")
reset
show = Show.prepare
$audio[:speed] = 2.0   # jumps past the end and loops back between two frames
result = show.play
check(result == :done && $audio_log.include?([:bgm_stop]) && !$audio_log.drop_while { |e| e != [:play, "planetarium"] }.include?([:bgm_fade, 2.0]),
      "smoke: a looped recording ends the show and stops at once")
# Slow cabinet: the position reads 0 for 90 frames, then the recording moves.
reset
show = Show.prepare
$audio[:speed] = 1.0 / 60
$frame_hook = lambda do
  clock = show.instance_variable_get(:@clock)
  $audio[:pos_override] = clock && clock[:frames] < 90 ? 0.0 : nil
  $audio[:pos] = 0.0 if clock && clock[:frames] < 90
end
modes = []
hook = $frame_hook
$frame_hook = lambda do
  hook.call
  clock = show.instance_variable_get(:@clock)
  modes << clock[:mode] if clock && modes.last != clock[:mode]
end
result = show.play
plays = $audio_log.count { |e| e == [:play, "planetarium"] }
check(result == :done && modes == %i[audio frames audio] && $echo.any? { |e| e.include?("moving") },
      "smoke late audio: frames while stuck, back on the audio clock once it moves (#{modes.inspect})")
check(plays == 1 && $frames.between?(33_500 + 90, 33_500 + 300) && !$audio_log.include?([:bgm_fade, 2.0]) &&
      $audio_log.drop_while { |e| e != [:play, "planetarium"] }.include?([:bgm_stop]),
      "smoke late audio: the show ends with the recording (#{$frames} frames), which stops at its end, played once")
# Position lost mid-show: the recording loops while the clock is on frames.
reset
show = Show.prepare
$audio[:speed] = 2.0
$frame_hook = lambda do
  clock = show.instance_variable_get(:@clock)
  $audio[:pos_override] = clock && $audio[:pos] > 100 ? "?" : nil   # unreadable until it wraps
end
result = show.play
check(result == :done && show.instance_variable_get(:@clock)[:looped] && $audio_log.include?([:bgm_stop]) &&
      !$audio_log.drop_while { |e| e != [:play, "planetarium"] }.include?([:bgm_fade, 2.0]),
      "smoke loop on frames: a loop read after a lost position ends the show and stops the recording")
reset(bgm: nil, bgs: "fire")
show = Show.prepare
result = show.play
tail = $audio_log.drop_while { |e| e != [:play, "planetarium"] }
check(result == :done && tail.include?([:bgs_play, "fire"]) && !tail.include?([:autoplay]) && !tail.include?([:bgm_play, nil]),
      "smoke: a memorized BGS comes back with no BGM; no autoplay")
reset
show = Show.prepare
again = nil
boom = true
$frame_hook = lambda do
  next unless show.instance_variable_get(:@clock)
  again = Show.prepare.play if again.nil?
  raise "sky broke" if boom && $frames > 300
end
result = show.play
boom = false
check(again == false, "smoke: a second show cannot start while one runs")
check(result == :left && $echo.any? { |e| e.include?("show error") } && all_disposed? && !Show.running?,
      "smoke: an error mid-show is caught: :left, everything disposed")
check($audio_log.last(2) == [[:bgm_play, "Deep Playa 3"], [:bgs_play, "fire"]] && Graphics.frozen_log.empty?,
      "smoke: after an error the map music still comes back (no frozen screen)")
reset
show = Show.prepare(from: 470.0)
result = show.play
check(result == :done && $audio_log.include?([:raw_play, "Audio/BGM/planetarium", 470.0]) && $frames.between?(1000, 1100),
      "smoke: debug play-from seeks the recording")
reset
$audio[:no_seek] = true
show = Show.prepare(from: 550.0)
$audio[:speed] = 0.0
result = show.play
check(result == :done && $echo.any? { |e| e.include?("seek failed") } && $frames.between?(640, 700),
      "smoke: a failed seek runs silent on the frame clock from the offset")

if $fails.empty?
  puts "Planet show smoke passed."
  exit 0
end
warn "#{$fails.size} planet show smoke check(s) failed."
exit 1
