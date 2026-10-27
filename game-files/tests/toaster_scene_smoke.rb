# TG17 Stamp Desk and Eviction smoke runs with fake graphics, input and clock (own
# process: its stubs would clash with plugin_rules_test.rb). Exit 0 = all checks passed.
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
module GameData
  module Species
    def self.play_cry_from_species(sp, form) = ($se << "cry #{sp}_#{form}")
  end
end
$pressed = []
$se = []
$drawn = []
def pbSEPlay(name, *) = ($se << name)
def pbDrawShadowText(_b, _x, _y, _w, _h, s, *) = ($drawn << s)
def _INTL(m, *a) = a.empty? ? m : "#{m}|#{a.join(',')}"
$pictures = true
def pbResolveBitmap(p) = $pictures ? p : nil

dir = File.join(ROOT, "Plugins/zToaster")
%w[000_game_rules 006_desk 008_eviction].each { |f| load File.join(dir, "#{f}.rb") }
DR = ToasterDeskRules
ER = ToasterEvictRules

#-------------------------------------------------------------------------------
# Stamp Desk. mode: :right answers correctly, :red/:blue presses one button, :idle never presses.
#-------------------------------------------------------------------------------
def desk(mode, losses = 0, seed = 5)
  $se.clear
  $drawn.clear
  $all.clear
  scene = Toaster::DeskScene.new(losses, seed)
  decide_at = []
  fx = { shake: 0, tint: 0 }
  card_at = nil
  $frame_hook = lambda do
    $pressed = []
    phase = scene.instance_variable_get(:@phase)
    sheet = scene.instance_variable_get(:@sheet)
    fx[:shake] += 1 if phase == :stamp && sheet.x != Toaster::DeskScene::SHEET_X
    fx[:tint] += 1 if sheet.color && sheet.color.a.to_i > 0
    decide_at << [$clock, scene.instance_variable_get(:@index)] if phase == :decide && decide_at.last&.last != scene.instance_variable_get(:@index)
    card_at ||= scene.instance_variable_get(:@at) if phase == :card
    case phase
    when :slide_in, :settle, :card, :decide
      want = mode == :right && phase != :card ? scene.form[:approve] : mode == :red
      $pressed = [want ? Input::USE : Input::BACK] unless mode == :idle && phase != :card
    end
  end
  start = $clock = 100.0
  result = scene.run
  { result: result, time: $clock - start, card_for: $clock - card_at, decide_at: decide_at, fx: fx, disposed: $all.all?(&:disposed?) }
end

out = desk(:right)
check(out[:result] == { passed: true, correct: 12, shown: 12 }, "desk: correct answers pass 12/12 (#{out[:result].inspect})")
check($se.count("Mining hammer") == 12 && $se.count("GUI summary change page") == 2 && !$se.include?("GUI sel buzzer"),
      "desk: a stamp SE per form, the amendment SE twice, no buzzer")
check(out[:time] < 95 && out[:card_for] >= DR::CARD_LOCK, "desk: under 95 s; Red held on the card is ignored for 1.0 s (#{out[:time].round(1)} s)")
check($drawn.include?("TOAST_DESK_RESULT|12,12") && $drawn.include?("TOAST_DESK_PASS") && $drawn.include?("TOAST_DESK_AMEND_BANNER") &&
      %w[TOAST_DESK_HINT TOAST_DESK_STAMP_OK TOAST_DESK_STAMP_NO TOAST_DESK_AMEND_0].all? { |k| $drawn.include?(k) },
      "desk: hint, stamps, amendment banner and the pass card are drawn")
first = out[:decide_at].first[0] - 100.0
check((first - (DR::BANNER_TIME + DR::SLIDE_TIME + DR::SETTLE_TIME)).abs < 0.1, "desk: the first decision opens after banner, slide and settle (#{first.round(3)})")
check(out[:disposed], "desk: every bitmap, sprite and the viewport are disposed")

check(out[:fx] == { shake: 24, tint: 0 }, "desk: a correct stamp shakes the sheet for exactly 2 frames (#{out[:fx].inspect})")
%i[red blue].each do |m|
  out = desk(m)
  wrong = out[:result][:shown] - out[:result][:correct]
  check(!out[:result][:passed] && out[:result][:shown] < 12, "desk: only #{m} fails early (#{out[:result].inspect})")
  check(out[:fx][:tint] == 6 * wrong, "desk: a wrong stamp tints the sheet for exactly 6 frames (#{out[:fx].inspect}, #{wrong} wrong)")
end
out = desk(:idle)
expect = DR::BANNER_TIME + 3 * (2 * DR::SLIDE_TIME + DR::SETTLE_TIME + DR.window(0) + DR::STAMP_TIME)
check(out[:result] == { passed: false, correct: 0, shown: 3 } && $se.count("GUI sel buzzer") == 3 && !$se.include?("Mining hammer") &&
      $drawn.include?("TOAST_DESK_STAMP_LATE") && (out[:time] - out[:card_for] - expect).abs < 0.4,
      "desk: three timeouts end the hearing at P=10 (#{out[:result].inspect}, #{(out[:time] - out[:card_for]).round(2)} vs #{expect.round(2)})")
out = desk(:idle, 3)
check(out[:result][:shown] == 6, "desk: at losses 3 (P=7) the hearing ends after 6 timeouts (#{out[:result].inspect})")
gap = out[:decide_at][1][0] - out[:decide_at][0][0]
check((gap - (DR.window(3) + DR::STAMP_TIME + 2 * DR::SLIDE_TIME + DR::SETTLE_TIME)).abs < 0.1, "desk: the window eases to 9 s (#{gap.round(2)})")

#-------------------------------------------------------------------------------
# Eviction. mode: :hunt chases and stamps the real Rotom; :blue quits; :idle never presses; :spam stamps every frame.
#-------------------------------------------------------------------------------
def evict(mode, losses: 0, start: 0, seed: 3)
  $se.clear
  $drawn.clear
  $all.clear
  scene = Toaster::EvictScene.new(losses, start, seed)
  info = { flickers: [], windows: [], max_cursor_jump: 0, white: 0 }
  $frame_hook = lambda do
    $pressed = []
    phase = scene.instance_variable_get(:@phase)
    r_phase = scene.instance_variable_get(:@r_phase)
    cell = scene.instance_variable_get(:@r_cell)
    cursor = scene.instance_variable_get(:@cursor)
    h = scene.instance_variable_get(:@h)
    info[:flickers] << h if r_phase == :flicker && info[:last_flicker] != scene.instance_variable_get(:@r_until)
    info[:last_flicker] = scene.instance_variable_get(:@r_until) if r_phase == :flicker
    if r_phase == :up
      info[:real_on_cursor] = true if scene.instance_variable_get(:@r_since) == $clock - 1 / 60.0 && cell == cursor
    end
    rotom = scene.instance_variable_get(:@rotom)
    info[:white] += 1 if rotom.visible && rotom.color && rotom.color.r == 255 && rotom.color.a.to_i > 0
    next unless phase == :play
    case mode
    when :blue then $pressed = [Input::BACK]
    when :spam then $pressed = [Input::USE]
    when :hunt
      next unless r_phase == :up
      if cursor == cell
        $pressed = [Input::USE]
      else
        cr, cc = cursor.divmod(3)
        tr, tc = cell.divmod(3)
        $pressed = [tr > cr ? Input::DOWN : tr < cr ? Input::UP : tc > cc ? Input::RIGHT : Input::LEFT]
      end
    end
  end
  start_clock = $clock = 500.0
  result = scene.run
  info.merge(result: result, time: $clock - start_clock, disposed: $all.all?(&:disposed?))
end

out = evict(:hunt)
check(out[:result] == { won: true, hits: 5 } && $se.count("cry ROTOM_1") == 5 && $se.last == "Slots coin" && $se.count("Slots coin") == 1 &&
      $drawn.include?("TOAST_VAULT_WIN") && $drawn.include?("TOAST_VAULT_NOTICE|5"), "evict: five hits win, cry per hit, coin, win card (#{out[:result].inspect})")
check(out[:white] == 20, "evict: each of the 5 hits shows Rotom white for exactly 4 frames (#{out[:white]})")
check(out[:flickers].all? { |h| h >= 2 }, "evict: flickers only from 2 stamps on (#{out[:flickers].inspect})")
check(!out[:real_on_cursor], "evict: the real Rotom never spawns on the cursor cell")
check(out[:disposed] && %w[TOAST_VAULT_HINT TOAST_VAULT_APPL_1 TOAST_VAULT_APPL_9].all? { |k| $drawn.include?(k) },
      "evict: hint and the 9 cell words drawn; everything disposed")
many = (1..20).map { |s| evict(:hunt, seed: s) }
check(many.all? { |o| o[:result][:won] } && many.sum { |o| o[:flickers].length } > 0, "evict: 20 seeds all winnable by a fast player; fake-outs do happen")
out = evict(:hunt, start: 3)
check(out[:result] == { won: true, hits: 5 } && $se.count("cry ROTOM_1") == 2, "evict: a head start of 3 needs only 2 new stamps")
out = evict(:blue, start: 2)
check(out[:result] == { won: false, hits: 2 } && out[:time] < 0.05 && !$drawn.include?("TOAST_VAULT_FAIL") && out[:disposed],
      "evict: Blue quits at once as a fail, no card")
out = evict(:idle)
check(out[:result] == { won: false, hits: 0 } && (out[:time] - (ER::TIME + ER::CARD_TIME)).abs < 0.1 && $drawn.include?("TOAST_VAULT_FAIL"),
      "evict: a time-out fails after 60 s with the 1.5 s card (#{out[:time].round(2)})")
out = evict(:spam)
wastes = $se.count("GUI sel buzzer")
check(wastes.between?(60, ER::TIME / ER::WASTE_LOCK + 2) && $drawn.include?("TOAST_VAULT_WASTE"),
      "evict: stamping every frame wastes, locked 0.5 s each time (#{wastes} wastes, #{out[:result].inspect})")

exit($fails.empty? ? 0 : 1)
