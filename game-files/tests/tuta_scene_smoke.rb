# TG31 Tuta maze scene smoke run with fake graphics, input and clock (own process: its
# stubs would clash with plugin_rules_test.rb). Exit 0 = all checks passed.
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
  def to_a = [@x, @y, @width, @height]
end
# Sizes the fake "files" have; a case may change one to a wrong size.
$sizes = {
  "tuta_run" => [128, 128], "tuta_poses" => [128, 128], "owner_man_run" => [128, 160],
  "owner_woman_run" => [128, 160], "owner_poses" => [96, 80], "berries" => [64, 16],
  "tuta_win" => [256, 192], "tuta_lose" => [256, 192]
}
$loaded = []
class Bitmap
  Font = Struct.new(:size)
  attr_reader :width, :height, :font, :path
  def initialize(w, h = nil)
    if w.is_a?(String)
      @path = w
      w, h = $sizes.fetch(File.basename(w))
      $loaded << File.basename(@path)
    end
    @width, @height, @font, @disposed = w, h, Font.new(20), false
    $all << self
  end
  def rect = Rect.new(0, 0, @width, @height)
  def text_size(s) = Rect.new(0, 0, s.to_s.length * 10, 20)
  def fill_rect(*); end
  def set_pixel(*); end
  def blt(*); end
  def stretch_blt(*); end
  def clear; end
  def dispose = (@disposed = true)
  def disposed? = @disposed
end
class Viewport
  attr_accessor :z, :ox, :oy
  def initialize(*) = ($all << self; @disposed = false; @ox = @oy = 0)
  def dispose = (@disposed = true)
  def disposed? = @disposed
end
class Sprite
  attr_accessor :bitmap, :x, :y, :z, :ox, :oy, :zoom_x, :zoom_y, :angle, :opacity, :visible
  attr_reader :src_rect
  def initialize(_vp)
    $all << self
    @src_rect = Rect.new
    @disposed = false
    @x = @y = @z = @ox = @oy = @angle = 0
    @zoom_x = @zoom_y = 1
    @opacity = 255
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
  def self.update; end
  def self.trigger?(b) = $pressed.include?(b)
  def self.dir4 = $dir4
end
$pressed = []
$dir4 = 0
$se = []
$drawn = []
$bgm = []
$messages = []
def pbSEPlay(name, *) = ($se << name)
def pbDrawShadowText(_b, _x, _y, _w, _h, s, *) = ($drawn << s)
def _INTL(m, *a) = a.empty? ? m : "#{m}|#{a.join(',')}"
%w[pbBGMPlay pbBGMStop pbBGMFade pbBGSPlay pbMEPlay].each { |n| define_method(n) { |*a| $bgm << [n, a] } }
$pictures = false
def pbResolveBitmap(p) = $pictures ? p : nil

class PokemonGlobalMetadata; end
dir = File.join(ROOT, "Plugins/zTutaMaze")
%w[000_rules 001_state 002_art 003_scene 004_statue].each { |f| load File.join(dir, "#{f}.rb") }
R = TutaMazeRules

# policy: :back_title, :leave_one (steer left onto the last berry), :idle, :pause_resume,
# :pause_ready (pause during READY for 2 s), :blue_in_catch (one Blue tap during the catch freeze).
# card: what to press on the end card (:back or :again, then the next game is quit from pause).
def play(state, policy, card: :back, diff: 0.0, seed: 5)
  $se.clear
  $drawn.clear
  $all.clear
  $loaded.clear
  scene = TutaMaze::Scene.new(state, diff, seed)
  frames = 0
  log = { games: 0, cards: [], max_ticks: 0, pause_frames: 0, card_hold: 0 }
  $frame_hook = lambda do
    frames += 1
    $pressed = []
    $dir4 = 0
    g = scene.game
    case scene.phase
    when :title
      next unless frames > 200
      $pressed = [policy == :back_title ? Input::BACK : Input::USE]
    when :play
      log[:pause_frames] = 0
      $dir4 = 4 if [:leave_one, :pause_resume].include?(policy)
      log[:play_cells] = (log[:play_cells] || []) << scene.instance_variable_get(:@tuta).src_rect.to_a if policy == :pause_resume
      want_pause = (policy == :pause_resume && g[:mode] == :play && g[:life_t] > (log[:resumed] ? 1.2 : 0.5)) ||
                   (policy == :pause_ready && (log[:resumed] ? g[:mode] == :play && g[:life_t] > 0.5 : g[:mode] == :ready && frames > 210)) ||
                   (log[:cards].length > 0 && g[:mode] == :play)   # the next game: leave through the pause
      if policy == :blue_in_catch && g[:mode] == :caught && !log[:blue_sent]
        want_pause = log[:blue_sent] = true
      end
      $pressed = [Input::BACK] if want_pause
    when :pause
      log[:pause_frames] += 1
      log[:paused_seen] = true
      log[:paused_at] ||= [g[:mode], g[:lives]]
      if policy == :pause_resume && !log[:resumed]
        log[:pause_cells] = (log[:pause_cells] || []) << scene.instance_variable_get(:@tuta).src_rect.to_a
      end
      if policy == :pause_ready && !log[:resumed]
        word = scene.instance_variable_get(:@word)
        log[:pause_fx] = (log[:pause_fx] || []) << [word.visible, scene.instance_variable_get(:@word_t),
                                                    scene.instance_variable_get(:@tuta).src_rect.to_a, g[:mode_t]]
      end
      if log[:pause_frames] >= (policy == :pause_ready ? 120 : 10)
        resume = [:pause_resume, :pause_ready].include?(policy) && !log[:resumed]
        log[:resumed] = true if resume
        $pressed = [resume ? Input::BACK : Input::USE]
      end
    when :card
      log[:cards] << g[:mode] if log[:cards].last != g[:mode] || log[:card_hold].zero?
      log[:card_hold] += 1
      if log[:card_hold] < 10
        $pressed = [Input::USE]                         # held Yellow during the lock is ignored
      elsif log[:card_hold] > 40
        $pressed = [card == :back ? Input::BACK : Input::USE]
        log[:card_hold] = 0 if card == :again
      end
    end
  end
  $clock = 100.0
  result = scene.run
  log.merge(result: result, scene: scene, game: scene.game, disposed: $all.all?(&:disposed?),
            se: $se.dup, drawn: $drawn.dup, loaded: $loaded.dup)
end

#--- title, then back -------------------------------------------------------------------
st = R.new_state
out = play(st, :back_title)
check(out[:result] == { result: :quit, time: 0.0 }, "smoke: Blue on the title card leaves with :quit (#{out[:result].inspect})")
check(%w[TUTA_TITLE TUTA_INTRO_1 TUTA_INTRO_2 TUTA_INTRO_3 TUTA_HOWTO TUTA_START].all? { |k| out[:drawn].include?(k) },
      "smoke: the title card draws the title, all 3 intro lines (TUTA_INTRO_3 last), how-to and start")
check(out[:drawn].index("TUTA_INTRO_3") > out[:drawn].index("TUTA_INTRO_2"), "smoke: TUTA_INTRO_3 shows after TUTA_INTRO_2")
check(out[:disposed], "smoke: every bitmap, sprite and the viewport are disposed after the title")
check(st == R.new_state, "smoke: leaving from the title records nothing")
out2 = play(st, :back_title)
check(out2[:result][:result] == :quit && out2[:disposed], "smoke: a second run in a row works and disposes again")
check($bgm.empty?, "smoke: no BGM/BGS/ME call")

#--- the F9 'leave 1' start, steer left, win -------------------------------------------
TutaMaze.leave_one = true
out = play(st, :leave_one)
check(out[:result][:result] == :won && out[:result][:time] > 0, "smoke: eating the last strawberry wins (#{out[:result].inspect})")
check(out[:drawn].include?("TUTA_COUNTER|139,140") && out[:drawn].include?("TUTA_COUNTER|140,140"),
      "smoke: the counter shows 139/140, then 140/140")
check(%w[TUTA_READY TUTA_GO TUTA_WIN_TITLE TUTA_WIN_LINE TUTA_AGAIN].all? { |k| out[:drawn].include?(k) },
      "smoke: READY, GO, the win card and the again hint are drawn")
check(!out[:drawn].include?("TUTA_NEW_BEST") && out[:drawn].any? { |d| d.start_with?("TUTA_BEST|") },
      "smoke: an F9 preset win shows no new-record line")
check(out[:se].include?("Voltorb Flip tile") && out[:se].include?("Mining found all") && out[:se].include?("Vs flash"),
      "smoke: berry, win and GO sounds play")
check(st[:wins] == 1 && st[:plays] == 1 && st[:best_time].nil?, "smoke: the preset win counts but sets no best time (#{st.inspect})")
check(TutaMaze.leave_one == false, "smoke: the F9 flag is used up by one game")
check(out[:disposed], "smoke: disposed after a win")
check(TutaMaze.prompt_key(st) == "TUTA_STATUE_PROMPT_WON", "smoke: after a win the statue prompt is the _WON variant")

#--- idle: 3 catches, lose card, retry, leave through the pause ---------------------------
out = play(st, :idle, card: :again)
check(out[:cards].first == :lost, "smoke: an idle Tuta is caught 3 times and gets the lose card (#{out[:cards].inspect})")
check(out[:drawn].any? { |s| s.start_with?("TUTA_CATCH_") } && out[:drawn].include?("TUTA_LOSE_TITLE"),
      "smoke: a catch bubble and the lose card are drawn")
check(out[:se].count("Exclaim") == 3 && out[:se].include?("Pkmn faint") && out[:se].count("Battle damage weak") == 3,
      "smoke: 3 catches, 3 hearts lost, the game-over sound")
check(out[:result][:result] == :quit && out[:game][:lives] == 3 && R.eaten_count(out[:game]) < 140,
      "smoke: Yellow on the lose card starts a fresh game; Blue+Yellow from it quits (#{out[:result].inspect})")
check(st[:losses_streak] == 1 && st[:plays] == 2 && st[:wins] == 1, "smoke: the loss is recorded, the quit is not (#{st.inspect})")
check(out[:disposed], "smoke: disposed after lose, retry and quit")

#--- pause, resume, then quit -------------------------------------------------------------
before = st.dup
out = play(st, :pause_resume)
check(out[:result][:result] == :quit && out[:resumed] && out[:game][:life_t] > 1.2, "smoke: Blue pauses, Blue resumes play, and a later pause + Yellow leaves")
check(st == before, "smoke: leaving mid-game counts as neither a win nor a loss")
check(out[:play_cells].uniq.length > 1 && out[:pause_cells].length >= 9 && out[:pause_cells].uniq.length == 1,
      "smoke: Tuta's run cycle animates in play and freezes in the pause")

#--- pause during READY freezes the word and the animation -------------------------------
out = play(st, :pause_ready)
fx = out[:pause_fx] || []
check(fx.length >= 100 && fx.map { |v, t, _, _| [v, t] }.uniq.length == 1 && fx[0][0],
      "smoke: paused during READY, the READY word stays up and its timer stands still (#{fx.length} frames)")
check(fx.map { |_, _, r, m| [r, m] }.uniq.length == 1, "smoke: the run cell and the rules READY clock stand still in the pause")
check(out[:result][:result] == :quit && out[:resumed], "smoke: resume after the READY pause, then leave")

#--- Blue during the catch freeze is held until play can pause -------------------------------
out = play(R.new_state, :blue_in_catch)
check(out[:paused_at] && out[:paused_at][0] == :ready && out[:paused_at][1] == 2,
      "smoke: a Blue tap in the catch freeze opens the pause at the next READY (#{out[:paused_at].inspect})")
check(out[:result][:result] == :quit, "smoke: ...and Yellow there leaves")

#--- PNGs present / wrong size --------------------------------------------------------------
$pictures = true
out = play(R.new_state, :back_title)
check(out[:loaded].sort == $sizes.keys.sort && out[:disposed], "smoke: all 8 scene PNGs load at their exact sizes")
$sizes["owner_man_run"] = [100, 100]
out = play(R.new_state, :back_title)
check(out[:result][:result] == :quit && out[:disposed], "smoke: a wrong-size PNG falls back without an exception")
check(out[:scene].instance_variable_get(:@owner_runs)[0].path.nil?, "smoke: the wrong-size man sheet is the drawn fallback")
$sizes["owner_man_run"] = [128, 160]
$pictures = false

#--- the statue event -------------------------------------------------------------------------
$confirm = false
def pbConfirmMessage(m) = ($messages << m; $confirm)
def pbMessage(m) = ($messages << m)
def pbFadeOutIn = yield
$PokemonGlobal = PokemonGlobalMetadata.new
$messages.clear
check(pbTutaStatue(:ev) == true && $messages == %w[TUTA_STATUE_PROMPT TUTA_STATUE_LATER], "statue: No shows the 'later' line")
$confirm = true
$messages.clear
$frame_hook = lambda do
  $pressed = $clock > 104 ? [Input::BACK] : []
end
$clock = 100.0
$all.clear
check(pbTutaStatue(:ev) == true && $messages == %w[TUTA_STATUE_PROMPT] && $all.all?(&:disposed?),
      "statue: Yes runs the scene to the title card and back, everything disposed")
check($PokemonGlobal.tuta_maze == R.new_state, "statue: an old save without tuta_maze loads the default")
check($bgm.empty?, "statue: no BGM call anywhere")
src = Dir[File.join(dir, "00[0-4]_*.rb")].map { |f| File.read(f) }.join
check(!src.match?(/\$game_player|pbBGM|transfer_player|moveto/), "statue: the game code never moves the player or touches music")
exit($fails.empty? ? 0 : 1)
