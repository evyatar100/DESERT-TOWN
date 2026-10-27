# TG14 arm-wrestling scene smoke run with fake graphics, input and clock (own process:
# its stubs would clash with plugin_rules_test.rb). Exit 0 = all checks passed.
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
# Picture sizes the fake "files" have; a test may change one to a wrong size.
$sizes = { "aw_backdrop" => [256, 192], "aw_shirpaz" => [288, 192], "aw_arms" => [1232, 728], "dt_670f79e3" => [128, 192] }
class Bitmap
  Font = Struct.new(:size)
  attr_reader :width, :height, :font, :path
  def initialize(w, h = nil)
    if w.is_a?(String)
      @path = w
      w, h = $sizes.fetch(File.basename(w))
    end
    @width, @height, @font, @disposed = w, h, Font.new(20), false
    $all << self
  end
  def rect = Rect.new(0, 0, @width, @height)
  def fill_rect(*); end
  def set_pixel(*); end
  def blt(*); end
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
end
$pressed = []
$se = []
$drawn = []
def pbSEPlay(name, *) = ($se << name)
def pbDrawShadowText(_b, _x, _y, _w, _h, s, *) = ($drawn << s)
def _INTL(m, *a) = a.empty? ? m : "#{m}|#{a.join(',')}"
$pictures = false
def pbResolveBitmap(p)
  return p if p.end_with?("dt_670f79e3")
  $pictures ? p : nil
end

dir = File.join(ROOT, "Plugins/zArmWrestle")
%w[000_rules 002_art 003_scene].each { |f| load File.join(dir, "#{f}.rb") }
R = ArmWrestleRules

# policy: :perfect (Red on each beat centre, Blue on each surge), :idle, :masher, :back.
# Returns what the run did; red_in_countdown presses Red on every countdown frame.
def play(tier, policy, seed: 3, red_in_countdown: false)
  $se.clear
  $drawn.clear
  $all.clear
  scene = ArmWrestle::Scene.new(tier, R::Lcg.new(seed))
  frames = 0
  log = { go_at: nil, end_t: nil, card_frames: 0, angles: [], cells: [], faces: [], countdown_b: [], shake: [] }
  next_beat = 1
  blocked = nil
  $frame_hook = lambda do
    frames += 1
    $pressed = []
    bout = scene.bout
    case scene.phase
    when :howto
      $pressed = [policy == :back ? Input::BACK : Input::USE] if frames > 5
    when :countdown
      $pressed = [Input::USE] if red_in_countdown
      log[:countdown_b] << (bout && bout[:b])
    when :bout
      log[:go_at] ||= $clock
      c = bout[:cfg]
      t = bout[:t] + 1 / 60.0
      case policy
      when :masher then $pressed = [Input::USE] if frames % 4 == 0
      when :perfect
        if t >= next_beat * c[:period] - 0.5 / 60
          $pressed << Input::USE
          next_beat += 1
        end
        if bout[:surge] && blocked != bout[:surge] && t >= bout[:surge] - c[:brace] / 2.0
          $pressed << Input::BACK
          blocked = bout[:surge]
        end
      end
      log[:shake] << scene.instance_variable_get(:@viewport).ox
    when :pin
      log[:end_t] ||= bout[:t]
    when :card
      log[:end_t] ||= bout[:t]
      log[:card_frames] += 1
      $pressed = [Input::USE]
    end
    arms = scene.instance_variable_get(:@arms)
    log[:angles] << arms.angle
    log[:cells] << arms.src_rect.to_a
    bust = scene.instance_variable_get(:@bust)
    log[:faces] << bust.src_rect.to_a if bust
  end
  $clock = 100.0
  result = scene.run
  log.merge(result: result, scene: scene, disposed: $all.all?(&:disposed?), se: $se.dup, drawn: $drawn.dup)
end

#--- fallback art only (no PNGs) ---------------------------------------------
out = play(1, :perfect)
check(out[:result] == { outcome: :win }, "smoke: Red on the beat and Blue on the tells wins (#{out[:result].inspect})")
check(out[:end_t] && out[:end_t] <= 15, "smoke: the perfect run pins her at T1 within 15 s (#{out[:end_t]&.round(2)})")
check(out[:se].first(4) == ["GUI sel cursor"] * 3 + ["Vs flash"], "smoke: countdown SE 3, 2, 1, then the GO flash")
check(out[:se].include?("Mining ping") && out[:se].include?("Voltorb Flip tile"), "smoke: PERFECT ping and the beat tick play")
pin = out[:se].index("Rock Smash")
check(pin && out[:se][pin + 1] == "Mining found all", "smoke: the pin slam, then the win card SE")
check(%w[AW_HOWTO_1 AW_HOWTO_2 AW_HOWTO_START 3 2 1 AW_GO AW_PERFECT AW_WIN_CARD].all? { |k| out[:drawn].include?(k) },
      "smoke: how-to card, countdown digits, GO, pop word and win card are drawn")
check(!out[:drawn].include?("AW_TIMEUP"), "smoke: a pin win has no time-up title")
check(out[:card_frames] >= (ArmWrestle::Scene::CARD_LOCK * 60).floor, "smoke: Red held on the card is ignored for 0.6 s (#{out[:card_frames]} frames)")
check(out[:angles].last.round == 72, "smoke: fallback arms end on the pad, +72 deg (counter-clockwise = left) on a win (#{out[:angles].last.round(1)})")
check(out[:faces].uniq.length == 1, "smoke: the map-sprite bust fallback has no expressions")
check(out[:disposed], "smoke: every bitmap, sprite and the viewport are disposed")

out = play(3, :idle)
check(out[:result] == { outcome: :loss } && out[:se].include?("Battle damage weak") && out[:drawn].include?("AW_LOSE_CARD"),
      "smoke: no input loses by pin with the loss card")
check(out[:se].include?("Exclaim") && out[:se].include?("Strength push") && out[:drawn].include?("AW_HIT"),
      "smoke: an unblocked surge tells, hits and shows the hit word")
check(out[:shake].max == ArmWrestle::Scene::SHAKE[0] && out[:shake].last == 0, "smoke: a hit shakes the screen 3 px, then it settles")
check(out[:drawn].include?("AW_TAUNT"), "smoke: her taunt bubble shows on the edge")
check(out[:disposed], "smoke: disposed after a loss")

out = play(0, :idle)
check(out[:result] == { outcome: :loss } && out[:drawn].include?("AW_TIMEUP") && (out[:end_t] - R::CAP).abs < 0.05,
      "smoke: the 45 s cap ends the bout with the time-up title (#{out[:end_t]&.round(2)})")
check(!out[:se].include?("Rock Smash"), "smoke: the cap has no slam")

out = play(1, :masher, red_in_countdown: true)
check(out[:result] == { outcome: :loss } && out[:se].count("GUI sel buzzer") > 10, "smoke: mashing Red slips and loses")
check(out[:countdown_b].all?(&:nil?), "smoke: presses during the countdown are ignored (no bout yet)")

out = play(1, :back)
check(out[:result] == { outcome: :back } && out[:go_at].nil? && !out[:se].include?("Vs flash"), "smoke: Blue on the how-to card backs out before the countdown")
check(out[:disposed], "smoke: disposed after backing out")

#--- with the 3 PNGs ------------------------------------------------------------
$pictures = true
out = play(1, :perfect)
check(out[:result] == { outcome: :win } && out[:disposed], "smoke: with the PNGs the bout still wins and disposes")
check(out[:cells].include?(ArmWrestle::Art.arm_rect(0)) && out[:cells].all? { |c| c[2, 2] == [176, 104] },
      "smoke: the arms strip shows 176x104 cells, reaching frame 0 (-72 deg) on the win")
check(out[:faces].uniq.length >= 3 && out[:faces].last == ArmWrestle::Art.face_rect(:pinned),
      "smoke: her face changes with the action and ends :pinned (#{out[:faces].uniq.length} faces)")
s = out[:scene]
check(s.instance_variable_get(:@backdrop).zoom_x == 2 && s.instance_variable_get(:@arms).ox == 88 && s.instance_variable_get(:@arms).oy == 96,
      "smoke: native art at x2, arms pivot at cell (88,96)")

$sizes["aw_arms"] = [1000, 700]
out = play(1, :perfect)
check(out[:cells].all? { |c| c == [0, 0, 0, 0] } && out[:angles].last.round == 72 && out[:result] == { outcome: :win },
      "smoke: an arms PNG at the wrong size falls back to the rotated drawn arms")
exit($fails.empty? ? 0 : 1)
