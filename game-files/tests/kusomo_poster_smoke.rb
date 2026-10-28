# Kusomo TV poster smoke run with fake graphics, input, clock and movie player (own process).
# Exit 0 = all checks passed.
ROOT = File.expand_path("..", __dir__)
$fails = []
def check(ok, msg) = (puts "  #{ok ? 'PASS' : 'FAIL'}: #{msg}"; $fails << msg unless ok)

$clock = 0.0
$frames = 0
$all = []
Color = Struct.new(:r, :g, :b, :a)
class Bitmap
  Font = Struct.new(:size)
  attr_reader :width, :height, :font
  def initialize(w, h = nil)
    w, h = 307, 384 if w.is_a?(String)
    @width, @height, @font, @disposed = w, h, Font.new(20), false
    $all << self
  end
  def fill_rect(*); end
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
  attr_accessor :bitmap, :z
  def initialize(_vp) = ($all << self; @disposed = false)
  def dispose = (@disposed = true)
  def disposed? = @disposed
end
module Graphics
  def self.width = 512
  def self.height = 384
  def self.update = ($clock += 1 / 60.0; $frames += 1; $frame_hook&.call)
  def self.play_movie(*) = ($movie_calls += 1; raise "boom" if $movie_fails)
end
module System
  def self.uptime = $clock
end
module Input
  $queue = []
  $reads = 0
  def self.update = ($queue.clear; $input_updates += 1)
  def self.trigger?(_b) = ($reads += 1; false)
  def self.press?(_b) = ($reads += 1; false)
end
module Audio
  def self.bgm_pos = 12
end
class FakeSystem
  def playing_bgm = :bgm
  def bgm_stop = ($events << :bgm_stop)
  def bgm_play_internal(b, pos) = ($events << [:bgm_play, b, pos, $all.count { |o| !o.disposed? }])
end
$game_system = FakeSystem.new
$drawn = []
def pbDrawShadowText(_b, _x, _y, _w, _h, s, *) = ($drawn << s)
def _INTL(m, *a) = a.empty? ? m : "#{m}|#{a.join(',')}"
def echoln(*); end
$pictures = true
def pbResolveBitmap(p) = $pictures ? p : nil
$movie_calls = 0
$movie_fails = false
$input_updates = 0
$events = []

$handlers = {}
module EventHandlers; def self.add(ev, key, prc) = ($handlers[[ev, key]] = prc); end
module MenuHandlers; def self.add(menu, key, h) = ($handlers[[menu, key]] = h); end
class Scene_Map; end
GameTemp = Struct.new(:in_mini_update, :message_window_showing)
$game_temp = GameTemp.new(false, false)
$interp_running = false
def pbMapInterpreterRunning? = $interp_running
$messages = []
def pbMessage(m) = ($messages << m)

dir = File.join(ROOT, "Plugins/zKusomoTV")
%w[000_rules 001_player 002_poster 003_trace 004_debug].each { |f| load File.join(dir, "#{f}.rb") }
$trace = []
module KusomoTV; def self.write_trace(m) = ($trace << m); end

def run_play
  $clock = 100.0
  $frames = 0
  $drawn.clear
  $all.clear
  $events.clear
  $input_updates = 0
  $reads = 0
  $queue = [:use, :back]
  KusomoTV.play(:mohel)
end
module FileTest; def self.exist?(_p) = true; end

# Poster time and countdown, with button mashing on every frame.
$frame_hook = -> { $queue.push(:use) }
ok = run_play
elapsed = $clock - 100.0
counts = $drawn.grep(/\AKUSOMO_TV_RESUME\|\d+\z/).map { |s| s.split("|").last.to_i }
check(ok == true && $movie_calls == 1, "smoke: play returns true after the movie")
check(($frames - 600).abs <= 1 && (elapsed - 10.0).abs < 0.05, "smoke: the poster holds for 10 s (#{$frames} frames, #{elapsed.round(3)} s)")
check(counts == (1..10).to_a.reverse, "smoke: countdown draws 10 down to 1 (#{counts.inspect})")
check($reads == 0 && $queue.empty?, "smoke: button presses are never read and the queue is empty afterwards")
check($input_updates >= 600, "smoke: Input.update runs every frame, swallowing presses (#{$input_updates})")
check($all.all?(&:disposed?), "smoke: viewport, sprites and bitmaps are all disposed")
check($events.first == :bgm_stop && $events.last[0] == :bgm_play && $events.last[1] == :bgm && $events.last[2] == 12 && $events.last[3] == 0,
      "smoke: BGM comes back only after the poster is gone (#{$events.last.inspect})")

# Movie raises: no poster, BGM still restored.
$movie_fails = true
ok = run_play
check(ok == false && $frames == 0 && $all.empty? && $drawn.empty?, "smoke: a failed movie shows no poster (#{$frames} frames)")
check($events.last[0] == :bgm_play, "smoke: a failed movie still restores the BGM")
$movie_fails = false

# Movie id unknown: nothing at all.
check(KusomoTV.play(:nope) == false && $all.empty?, "smoke: an unknown video id shows no poster")

# Poster PNG missing: skipped gracefully, movie result unchanged.
$pictures = false
ok = run_play
check(ok == true && $frames == 0 && $all.empty? && $events.last[0] == :bgm_play, "smoke: a missing poster PNG is skipped and the BGM returns")
$pictures = true

# Trace: a session header, then every step in order, ending with the poster and play done.
$trace.clear
KusomoTV.instance_variable_set(:@trace_started, false)
run_play
order = ["=== session:", "play mohel movie", "play: path", "play: before play_movie", "play: after play_movie",
         "poster: resolved", "poster: bitmap", "poster: loop done after", "poster: disposed", "play: restoring bgm", "play: done ok"]
idx = order.map { |o| $trace.index { |l| l.start_with?(o) } }
check(idx.none?(&:nil?) && idx == idx.sort, "trace: header and every play/poster step logged in order (#{idx.inspect})")
check($trace.count { |l| l.start_with?("poster: countdown") } == 10, "trace: one line per countdown number")
KusomoTV.trace_exit(SystemExit.new("bye"))
check($trace.last.start_with?("at_exit: SystemExit: bye"), "trace: at_exit names SystemExit (#{$trace.last})")
KusomoTV.trace_exit(nil)
check($trace.last == "at_exit: normal end (no exception)", "trace: at_exit with no exception says so")

# A poster error is traced and never ends the game: play still returns true and the BGM comes back.
$trace.clear
def pbResolveBitmap(_p) = raise(TypeError, "kaput")
ok = begin; run_play; rescue TypeError; :raised; end
check(ok == true && $trace.any? { |l| l.start_with?("poster: TypeError: kaput") } && $events.last[0] == :bgm_play,
      "poster: an error in the poster is traced, play returns true and the BGM returns (#{ok.inspect})")
def pbResolveBitmap(p) = $pictures ? p : nil

# SystemExit (window closed) mid-poster is traced as escaping and re-raised, with everything disposed.
$trace.clear
$frame_hook = -> { raise SystemExit, "closed" if $frames == 30 }
raised = begin; run_play; false; rescue SystemExit; true; end
check(raised && $trace.any? { |l| l.start_with?("play: SystemExit escaped: closed") } && $all.all?(&:disposed?),
      "trace: SystemExit during the poster is logged, re-raised, and the poster is disposed")
$frame_hook = nil

# F9 entries: queued, then run on the map only once the menu, messages and events are idle.
job = $handlers[[:on_frame_update, :kusomo_tv_debug_job]]
check(job && $handlers[[:debug_menu, :dt_kusomo_poster_only]] && $handlers[[:debug_menu, :dt_kusomo_movie_only]], "f9: both entries and the frame hook are registered")
$scene = Scene_Map.new
$frames = 0
$movie_calls = 0
$handlers[[:debug_menu, :dt_kusomo_poster_only]]["effect"].call
$game_temp.in_mini_update = true
job.call
check($frames == 0, "f9: nothing runs while the debug menu's mini-update is active")
$game_temp.in_mini_update = false
job.call
check($frames >= 599 && $movie_calls == 0, "f9: poster only shows the poster with no movie (#{$frames} frames)")
$frames = 0
job.call
check($frames == 0, "f9: a job runs once")
def pbShowCommands(*) = 2
$handlers[[:debug_menu, :dt_kusomo_movie_only]]["effect"].call
$interp_running = true
job.call
check($movie_calls == 0, "f9: waits while an event is running")
$interp_running = false
job.call
check($movie_calls == 1 && $frames == 0 && $trace.any? { |l| l.include?("play grandma movie=true poster=false") },
      "f9: movie only plays the picked video with no poster")
exit($fails.empty? ? 0 : 1)
