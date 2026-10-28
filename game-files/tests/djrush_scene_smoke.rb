# TG40 DJ Rush Hour scene smoke run with fake graphics, input and clock (own process: its
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
end
$sizes = { "dj_poses" => [128, 192], "car_piece" => [96, 48], "djrush_car" => [384, 384] }
$loaded = []
class Bitmap
  Font = Struct.new(:size)
  attr_reader :width, :height, :font, :path
  def initialize(w, h = nil)
    if w.is_a?(String)
      @path = w
      base = File.basename(w)
      w, h = base.start_with?("dt_") ? [128, 192] : $sizes.fetch(base)
      $loaded << base
    end
    @width, @height, @font, @disposed = w, h, Font.new(20), false
    $all << self
  end
  def text_size(s) = Rect.new(0, 0, s.to_s.length * 10, 20)
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
  def self.press?(b) = $held.include?(b)
  def self.dir4 = $dir4
end
$pressed = []
$held = []
$dir4 = 0
$se = []
$me = []
$drawn = []
$bgm = []
def pbSEPlay(name, *) = ($se << name)
def pbMEPlay(name, *) = ($me << name)
def pbDrawShadowText(_b, _x, _y, _w, _h, s, *) = ($drawn << s)
def _INTL(m, *a) = a.empty? ? m : "#{m}|#{a.join(',')}"
%w[pbBGMPlay pbBGMStop pbBGMFade pbBGSPlay].each { |n| define_method(n) { |*a| $bgm << [n, a] } }
$pictures = false
def pbResolveBitmap(p) = $pictures ? p : nil
def echoln(*); end

class PokemonGlobalMetadata; end
dir = File.join(ROOT, "Plugins/zDJRush")
%w[000_rules 001_state 002_art 003_scene].each { |f| load File.join(dir, "#{f}.rb") }
R = DJRushRules
DIR_CODE = { left: 4, right: 6, up: 8, down: 2 }.freeze

def dir_of(p, delta) = p[:horiz] ? (delta < 0 ? :left : :right) : (delta < 0 ? :up : :down)

# The solving bot: walks the cursor onto the next shortest-path piece, grabs, slides, releases.
# Directions are pressed on alternate frames so every press is fresh (no repeat).
def solve_frame(scene, mem)
  b = scene.board
  if (id = b[:grab])
    p = b[:pieces][id]
    pos = p[:horiz] ? p[:x] : p[:y]
    if pos == mem[:target]
      $pressed = [Input::USE]
    elsif mem[:tick].even?
      $dir4 = DIR_CODE[dir_of(p, mem[:target] - pos)]
    end
    return
  end
  id, delta = R.hint(b)
  p = b[:pieces][id]
  cells = R.cells(p)
  if cells.include?(scene.cursor)
    mem[:target] = (p[:horiz] ? p[:x] : p[:y]) + delta
    $pressed = [Input::USE]
  elsif mem[:tick].even?
    cx, cy = scene.cursor
    tx, ty = cells.first
    $dir4 = tx != cx ? DIR_CODE[tx < cx ? :left : :right] : DIR_CODE[ty < cy ? :up : :down]
  end
end

# policy: :solve, :back_title, :pause_leave, :hold_restart, :hint, :bump, :blue_release, :pause_restart
def play(state, levels, policy, replay: false, record: true)
  $se.clear
  $me.clear
  $drawn.clear
  $all.clear
  $loaded.clear
  scene = DJRush::Scene.new(state, levels, replay: replay, record: record, seed: 3)
  mem = { tick: 0, card: 0, log: {} }
  $frame_hook = lambda do
    mem[:tick] += 1
    raise "smoke: #{policy} stuck in #{scene.phase} after 20000 frames" if mem[:tick] > 20_000
    $pressed = []
    $held = []
    $dir4 = 0
    lg = mem[:log]
    case scene.phase
    when :title
      next unless mem[:tick] > 30
      $pressed = [policy == :back_title ? Input::BACK : Input::USE]
    when :play
      b = scene.board
      case policy
      when :solve then solve_frame(scene, mem)
      when :pause_leave, :pause_restart, :hint
        if lg[:done]
          lg[:hint] ||= scene.instance_variable_get(:@hint)&.dup if policy == :hint
          $pressed = [Input::BACK] if (mem[:tick] % 4).zero?   # a tap: pause again, then leave
        elsif mem[:tick] > 50 && !lg[:tapped]
          lg[:tapped] = mem[:tick]
          $pressed = [Input::BACK]
          $held = [Input::BACK]
        end
      when :hold_restart
        lg[:moves_before] ||= b[:moves] if lg[:grabbed] && !b[:grab]
        if !lg[:grabbed]
          lg[:grabbed] = true
          scene.instance_variable_set(:@cursor, [3, 1])            # on sleeper b (L1)
          $pressed = [Input::USE]
        elsif b[:grab] && !lg[:slid]
          lg[:slid] = true
          $dir4 = 8
        elsif b[:grab]
          $pressed = [Input::USE]
        elsif !lg[:hold_from]
          lg[:hold_from] = mem[:tick]
          lg[:moved] = b[:moves]
          $pressed = [Input::BACK]
          $held = [Input::BACK]
        elsif mem[:tick] - lg[:hold_from] < 70
          $held = [Input::BACK]
          lg[:mid] ||= [b[:moves], scene.phase] if mem[:tick] - lg[:hold_from] == 66
        elsif !lg[:after]
          lg[:after] = [b[:moves], b == R.new_board(0), scene.phase]
        elsif mem[:tick] - lg[:hold_from] > 80 && !lg[:tapped]
          lg[:tapped] = true
          $pressed = [Input::BACK]
        end
      when :bump
        if !b[:grab] && !lg[:grabbed]
          lg[:grabbed] = true
          scene.instance_variable_set(:@cursor, [0, 4])            # conga e at the left edge (L1)
          $pressed = [Input::USE]
        elsif b[:grab] && (lg[:pushes] || 0) < 6
          lg[:pushes] = (lg[:pushes] || 0) + 1
          $dir4 = 4 if mem[:tick].even?
          lg[:pushes] -= 1 if mem[:tick].odd?
        elsif b[:grab]
          $pressed = [Input::USE]
        else
          lg[:released] ||= b[:moves]
          $pressed = [Input::BACK] if mem[:tick] % 3 == 0
          $held = $pressed.dup
        end
      when :blue_release
        if !lg[:grabbed]
          lg[:grabbed] = true
          scene.instance_variable_set(:@cursor, [3, 1])
          $pressed = [Input::USE]
        elsif b[:grab]
          lg[:release_at] = mem[:tick]
          $pressed = [Input::BACK]
          $held = [Input::BACK]
        elsif mem[:tick] - lg[:release_at] < 90
          $held = [Input::BACK]
          lg[:still] = [b[:moves], scene.phase, $se.include?("Mining collapse")]
        elsif !lg[:tapped]
          $pressed = [Input::BACK]
          lg[:tapped] = true
        end
      end
    when :pause
      lg[:paused] ||= mem[:tick]
      i = scene.instance_variable_get(:@pause_i)
      want = { pause_leave: 3, hint: 1, pause_restart: 2 }[policy] || 3
      want = 3 if lg[:done]
      if i != want
        $dir4 = 2 if mem[:tick].even?
      elsif mem[:tick].odd?
        lg[:done] = true if [:hint, :pause_restart].include?(policy) && want != 3
        $pressed = [Input::USE]
      end
    when :card, :freed
      lg[:cards] = (lg[:cards] || []) << scene.phase if (lg[:cards] || []).last != scene.phase || mem[:card].zero?
      mem[:card] += 1
      if mem[:card] > 40
        $pressed = [Input::USE]
        mem[:card] = 0
      end
    end
  end
  $clock = 100.0
  result = scene.run
  mem[:log].merge(result: result, scene: scene, disposed: $all.all?(&:disposed?), se: $se.dup, me: $me.dup, drawn: $drawn.dup,
                  loaded: $loaded.dup, frames: mem[:tick])
end

#--- title, then back, twice --------------------------------------------------------------
st = R.normalize({ stage: :intro })
out = play(st, [0, 1, 2], :back_title)
check(out[:result] == { result: :quit, level: 0, moves: 0 } && out[:disposed], "smoke: Blue on the title leaves with :quit, everything disposed")
check(%w[DJRUSH_TITLE DJRUSH_HOWTO_1 DJRUSH_HOWTO_2 DJRUSH_HOWTO_3 DJRUSH_NEXT].all? { |k| out[:drawn].include?(k) },
      "smoke: the title draws the title and the 3 how-to lines")
out = play(st, [0, 1, 2], :back_title)
check(out[:result][:result] == :quit && out[:disposed] && st == R.normalize({ stage: :intro }), "smoke: a second run works, nothing recorded")

#--- the whole run: 3 boards by the shortest path -----------------------------------------
out = play(st, [0, 1, 2], :solve)
check(out[:result][:result] == :freed && out[:cards] == %i[card card card freed], "smoke: the bot solves 3 boards, 3 solved cards, then the FREED card (#{out[:cards].inspect})")
check(st == { stage: :freed, cleared: 3, best: [3, 8, 15] }, "smoke: free! ran after board 3; best = minimum (#{st.inspect})")
check(out[:se].count("Voltorb Flip level up") == 3 && out[:me] == ["Slots big win"] && out[:drawn].include?("DJRUSH_FREED") &&
      out[:drawn].count("DJRUSH_SOLVED_PERFECT") == 3, "smoke: win sound per board, ME on the FREED card, perfect line each time")
check(%w[DJRUSH_MOVES|15 DJRUSH_MIN|15 DJRUSH_HOWTO_BAR DJRUSH_EXIT].all? { |k| out[:drawn].include?(k) } &&
      out[:drawn].any? { |d| d.start_with?("DJRUSH_LEVEL|3 · DJRUSH_LEVEL_NAME_3") }, "smoke: HUD draws moves, minimum, level label, exit and how-to bar")
check(out[:disposed] && $bgm.empty?, "smoke: disposed after the full run; no BGM call")
check(out[:se].count("GUI sel decision") == 5, "smoke: one confirm sound per Yellow (title, 3 cards, FREED) (#{out[:se].count('GUI sel decision')})")
ring = out[:scene].instance_variable_get(:@ring)
check(ring.y >= 228 && ring.y + 20 - 14 >= 228, "smoke: the restart ring sits below the MIN row (y 204-228)")
check(out[:se].include?("GUI storage pick up") && out[:se].include?("GUI storage put down") && out[:se].include?("Tile Game cursor"),
      "smoke: grab, release and slide sounds")

#--- pause -> leave, hint, restart ------------------------------------------------------------
st = R.normalize({ stage: :intro, cleared: 1 })
out = play(st, [1, 2], :pause_leave)
check(out[:result] == { result: :quit, level: 1, moves: 0 } && out[:paused] && st[:cleared] == 1 && out[:disposed],
      "smoke: a Blue tap pauses; Leave returns :quit; cleared kept")
out = play(st, [1, 2], :hint)
h = out[:hint]
check(h && h[0] == R.hint(R.new_board(1))[0] && h[2].between?(1.8, 2.0), "smoke: Hint blinks the first move of a shortest solution for 2 s (#{h.inspect})")
out = play(st, [1, 2], :pause_restart)
check(out[:result][:result] == :quit && out[:se].include?("Mining collapse"), "smoke: Restart from the pause resets the board")

#--- hold Blue restarts; a Blue release never does ---------------------------------------------
st = R.normalize({ stage: :intro })
out = play(st, [0], :hold_restart)
check(out[:moved] == 1 && out[:after] && out[:after][0] == 0 && out[:after][1] && out[:after][2] == :play && out[:se].include?("Mining collapse"),
      "smoke: holding Blue 1 s restarts the board (moves 0, level start) without opening the pause (#{out[:after].inspect})")
check(out[:mid] && out[:mid][0] == 0, "smoke: the restart lands by 1.0 s of holding")
out = play(st, [0], :blue_release)
check(out[:still] && out[:still] == [0, :play, false] && out[:result][:result] == :quit,
      "smoke: Blue releases a grab, and holding it on afterwards neither restarts nor pauses (#{out[:still].inspect})")

#--- bump ----------------------------------------------------------------------------------------
out = play(st, [0], :bump)
check(out[:se].include?("Player bump") && out[:drawn].count { |d| d.start_with?("DJRUSH_R_BUMP_") } == 1 && out[:released] == 0,
      "smoke: a blocked slide bumps, one BUMP bubble within 2 s, and a net-0 grab counts no move")

#--- a replay after :freed records best only ------------------------------------------------------
st = R.normalize({ stage: :bag, cleared: 3, best: [5, nil, nil] })
out = play(st, [0], :solve, replay: true)
check(out[:result][:result] == :solved && out[:cards] == [:card] && st == { stage: :bag, cleared: 3, best: [3, nil, nil] } && out[:me].empty?,
      "smoke: a replay returns :solved after one card and records only the best (#{st.inspect})")

#--- the F9 board records nothing ---------------------------------------------------------------
st = R.normalize({ stage: :none })
out = play(st, [2], :solve, replay: true, record: false)
check(out[:result][:result] == :solved && st == R.new_state, "smoke: the F9 board (record: false) saves nothing")

#--- PNGs present / wrong size -------------------------------------------------------------------
$pictures = true
out = play(R.normalize({ stage: :intro }), [0], :back_title)
check((%w[dj_poses car_piece djrush_car] - out[:loaded]).empty? && out[:disposed], "smoke: the 3 scene PNGs load at their exact sizes")
out = play(R.normalize({ stage: :intro }), [0], :solve)
check(out[:loaded].count { |n| n.start_with?("dt_") } == R.crowd_ids(0).values.flatten.length, "smoke: one charset per crowd face on board 1")
$sizes["car_piece"] = [90, 40]
out = play(R.normalize({ stage: :intro }), [0], :solve)
check(out[:result][:result] == :freed || out[:result][:result] == :solved, "smoke: a wrong-size car piece falls back without an exception")
check(out[:scene].instance_variable_get(:@car_piece).path.nil?, "smoke: the wrong-size car piece is the drawn fallback")
$sizes["car_piece"] = [96, 48]
$pictures = false
check(DJRush::Art.map_graphic == "dt_fc898478", "smoke: no art -> the map event falls back to the DJ charset")
DJRush::Art.reset_cache
$pictures = true
check(DJRush::Art.map_graphic == "djrush_car", "smoke: the 384x384 sheet is the map event graphic")
DJRush::Art.reset_cache
$sizes["djrush_car"] = [256, 256]
check(DJRush::Art.map_graphic == "dt_fc898478", "smoke: a wrong-size sheet falls back to the DJ charset")
$pictures = false

src = Dir[File.join(dir, "00[0-3]_*.rb")].map { |f| File.read(f) }.join
check(!src.match?(/\$game_player|pbBGM|transfer_player|moveto/), "smoke: the scene never moves the player or touches music")
exit($fails.empty? ? 0 : 1)
