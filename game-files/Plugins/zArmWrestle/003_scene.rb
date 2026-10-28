#===============================================================================
# Arm wrestling - the close-up: how-to card, 3-2-1-GO, the bout, the pin, the end card.
# Yellow pushes on the beat, Blue braces. BGM is never touched. Returns {outcome:}.
#===============================================================================

module ArmWrestle
  class Scene
    R = ArmWrestleRules
    A = Art
    PIVOT = [256, 352].freeze          # elbows on screen
    HAND_REACH = 164                   # pivot to the clasped hands, screen px
    BUST_X = 256
    BUST_BOTTOM = 240
    BUST_SHIFT = 6
    METER = [96, 7, 320, 14].freeze
    PIPS = 9                           # 5 s each
    TICK_SE = "Voltorb Flip tile"      # nil mutes the beat tick
    TICK_VOLUME = 50
    SE = {
      count: "GUI sel cursor", go: "Vs flash", perfect: "Mining ping", good: "Tile Game cursor",
      slip: "GUI sel buzzer", flinch: "GUI sel buzzer", tell: "Exclaim", block: "Mining iron",
      hit: "Strength push", pin: "Rock Smash", win: "Mining found all", loss: "Battle damage weak"
    }.freeze
    POP = { perfect: "AW_PERFECT", good: "AW_GOOD", slip: "AW_SLIP", block: "AW_BLOCK", hit: "AW_HIT" }.freeze
    POP_TIME = 0.5
    BUBBLE_TIME = 1.6
    SHAKE = [3, 0.3].freeze
    PIN_TIME = 0.25
    SLAM_HOLD = 0.5
    CARD_LOCK = 0.6
    COUNT_STEP = 0.6
    GOLD = [248, 216, 104].freeze
    RED = [181, 72, 63].freeze
    YELLOW = [232, 196, 64].freeze
    BLUE = [79, 114, 184].freeze
    INK = [24, 18, 28].freeze
    TEXT = [248, 240, 224].freeze

    attr_reader :bout, :phase

    # tier 0..3; rng: anything with #rand (tests pass a seeded ArmWrestleRules::Lcg).
    def initialize(tier, rng = Random.new)
      @tier = tier
      @rng = rng
    end

    def run
      create
      loop do
        Graphics.update
        Input.update
        result = update
        return result if result
      end
    ensure
      dispose
    end

    def update
      now = System.uptime
      dt = (now - @last).clamp(0.0, 0.1)
      @last = now
      @phase_t += dt
      @clock += dt
      red = Input.trigger?(Input::USE)
      blue = Input.trigger?(Input::BACK)
      result = case @phase
               when :howto then update_howto(red, blue)
               when :countdown then update_countdown
               when :bout then update_bout(dt, red, blue)
               when :pin then update_pin
               when :card then update_card(red, blue)
               end
      update_fx(dt)
      result
    end

    def enter(phase)
      @phase = phase
      @phase_t = 0.0
    end

    def update_howto(red, blue)
      return { outcome: :back } if blue
      return nil unless red
      @card.visible = false
      @count_shown = nil
      enter(:countdown)
      nil
    end

    # 3, 2, 1, GO (input ignored), then the bout starts at 2.4 s.
    def update_countdown
      step = (@phase_t / COUNT_STEP).floor
      return start_bout if @phase_t >= R::COUNTDOWN
      return nil if step == @count_shown
      @count_shown = step
      pbSEPlay(step < 3 ? SE[:count] : SE[:go])
      draw_big(step < 3 ? (3 - step).to_s : _INTL("AW_GO"))
      nil
    end

    def start_bout
      @big.visible = false
      @bout = R.new_bout(@tier, @rng)
      enter(:bout)
      show_rings(true)
      nil
    end

    def update_bout(dt, red, blue)
      R.step(@bout, dt, red: red, blue: blue).each { |e| on_event(e) }
      nil
    end

    def on_event(e)
      case e
      when :beat then pbSEPlay(TICK_SE, TICK_VOLUME) if TICK_SE
      when :perfect, :good, :slip, :block, :hit
        pbSEPlay(SE[e])
        pop(POP[e], e == :hit || e == :slip ? RED : GOLD)
        @shake_t = SHAKE[1] if e == :hit
      when :flinch then pbSEPlay(SE[:flinch])
      when :tell then pbSEPlay(SE[:tell])
      when :edge_in then bubble("AW_TAUNT")
      when :edge_out then bubble("AW_STRAIN")
      when :pin_win, :pin_loss
        @pin_from = @shown_b
        show_rings(false)
        enter(:pin)
      when :timeup
        show_rings(false)
        show_card(true)
      end
    end

    # The hands go to the pad over 0.25 s, then the slam and the dust.
    def update_pin
      target = @bout[:over] == :win ? 100.0 : -100.0
      @shown_b = @pin_from + (target - @pin_from) * [@phase_t / PIN_TIME, 1.0].min
      if @phase_t >= PIN_TIME && !@slammed
        @slammed = true
        pbSEPlay(SE[:pin])
        puffs(target > 0 ? 0 : 1)
      end
      show_card(false) if @phase_t >= PIN_TIME + SLAM_HOLD
      nil
    end

    def update_card(red, blue)
      return nil if @phase_t < CARD_LOCK
      return { outcome: @bout[:over] } if red || blue
      nil
    end

    #--- per-frame drawing -------------------------------------------------------
    def update_fx(dt)
      @frame_count += 1
      if @bout && @phase == :bout
        @shown_b += (@bout[:b] - @shown_b) * [dt * 12, 1.0].min
      end
      shaky = @bout && @phase == :bout && (@bout[:surge] || @bout[:edge])
      jitter = shaky ? (@frame_count.even? ? 1 : -1) : 0
      place_arms(jitter)
      place_bust
      place_rings if @rings_on
      place_tell
      @vignette.visible = !!(@bout && @bout[:edge] && @phase == :bout)
      @vignette.opacity = 150 + (70 * Math.sin(@frame_count / 6.0)).round if @vignette.visible
      draw_meter
      @pop.opacity = [(255 * (1 - (@pop_t || POP_TIME) / POP_TIME)).round, 0].max
      @pop.y = @pop_y - ((@pop_t || 0) * 30).round
      @pop_t += dt if @pop_t
      @bubble.visible = !!(@bubble_t && @bubble_t < BUBBLE_TIME)
      @bubble_t += dt if @bubble_t
      @puffs.each do |s, born|
        age = @clock - born
        s.opacity = [255 - (age * 400).round, 0].max
        s.zoom_x = s.zoom_y = 1 + age * 2
      end
      shake(dt)
    end

    def place_arms(jitter)
      x, y = PIVOT[0] + jitter, PIVOT[1]
      if @arms_art
        @arms.src_rect.set(*A.arm_rect(R.frame(@shown_b)))
      else
        @arms.angle = -R.angle(@shown_b)   # Sprite#angle turns counter-clockwise
      end
      @arms.x, @arms.y = x, y
    end

    def place_bust
      return unless @bust
      @bust.x = BUST_X - (BUST_SHIFT * @shown_b / 100.0).round
      face = @bout ? R.face(@bout) : :steady
      return unless @face_art && face != @face
      @face = face
      @bust.src_rect.set(*A.face_rect(face))
    end

    def hands
      A.hands_at(@shown_b, PIVOT, HAND_REACH)
    end

    def place_rings
      hx, hy = hands
      i = A.ring_index(R.ring(@bout))
      @gold.src_rect.set(i * A::RING_BOX, 0, A::RING_BOX, A::RING_BOX)
      [@gold, @target].each { |s| s.x, s.y = hx, hy }
    end

    def show_rings(on)
      @rings_on = on
      @gold.visible = @target.visible = on
    end

    # "!" over her hat for the whole tell; the Blue icon flashes, then stays lit in the brace window.
    def place_tell
      telling = @bout && @phase == :bout && @bout[:surge]
      @bang.visible = !!telling
      @blue_icon.visible = !!telling && (R.brace_open?(@bout) || (@frame_count / 6).even?)
      return unless telling
      hx, hy = hands
      @bang.x = (@bust ? @bust.x : BUST_X) + 52
      @blue_icon.x, @blue_icon.y = hx + 30, hy - 14
    end

    def shake(dt)
      return unless @shake_t
      @shake_t -= dt
      if @shake_t <= 0
        @shake_t = nil
        @viewport.ox = @viewport.oy = 0
      else
        @viewport.ox = @frame_count.even? ? SHAKE[0] : -SHAKE[0]
        @viewport.oy = @frame_count % 4 < 2 ? SHAKE[0] : -SHAKE[0]
      end
    end

    def puffs(pad)
      cx, cy = A::PADS[pad]
      [[-30, -6], [30, -6], [-14, 8], [14, 8]].each do |dx, dy|
        s = sprite(@puff_bmp, 30, cx + dx, cy + dy)
        s.ox = s.oy = 12
        @puffs << [s, @clock]
      end
    end

    #--- setup -----------------------------------------------------------------
    def create
      @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
      @viewport.z = 99_999   # same z as pbFadeOutIn's black layer, created later so drawn above it
      @owned = []
      @sprites = []
      @puffs = []
      @frame_count = 0
      @clock = 0.0
      @shown_b = 0.0
      @last = System.uptime
      create_backdrop
      create_bust
      create_arms
      create_fx
      create_ui
      enter(:howto)
      show_card(nil)
    end

    def own(bmp)
      @owned << bmp if bmp
      bmp
    end

    def sprite(bitmap, z, x = 0, y = 0)
      s = Sprite.new(@viewport)
      s.bitmap = bitmap
      s.z = z
      s.x, s.y = x, y
      @sprites << s
      s
    end

    def create_backdrop
      art = own(A.picture("aw_backdrop"))
      @backdrop = sprite(art || own(A.backdrop), 0)
      @backdrop.zoom_x = @backdrop.zoom_y = A::SCALE if art
    end

    def create_bust
      art = own(A.picture("aw_shirpaz"))
      @face_art = !art.nil?
      bmp = art || own(A.bust_fallback)
      return unless bmp
      @bust = sprite(bmp, 10, BUST_X, BUST_BOTTOM)
      if art
        @bust.src_rect.set(*A.face_rect(:steady))
        @face = :steady
        @bust.ox, @bust.oy = A::FACE_CELL / 2, A::FACE_CELL
        @bust.zoom_x = @bust.zoom_y = A::SCALE
      else
        @bust.src_rect.set(*A::BUST_FRAME)
        @bust.ox, @bust.oy = A::BUST_FRAME[2] / 2, A::BUST_FRAME[3]
        @bust.zoom_x = @bust.zoom_y = A::BUST_ZOOM
      end
    end

    def create_arms
      art = own(A.picture("aw_arms"))
      @arms_art = !art.nil?
      @arms = sprite(art || own(A.arms), 20, *PIVOT)
      @arms.ox, @arms.oy = art ? A::ARM_PIVOT : A::FALLBACK_PIVOT
      @arms.zoom_x = @arms.zoom_y = A::SCALE
      @arms.src_rect.set(*A.arm_rect(R.frame(0))) if art
    end

    def create_fx
      @target = sprite(own(A.target_ring), 30)
      @gold = sprite(own(A.ring_strip), 31)
      [@target, @gold].each { |s| s.ox = s.oy = A::RING_BOX / 2 }
      @gold.src_rect.set(0, 0, A::RING_BOX, A::RING_BOX)
      show_rings(false)
      @bang = sprite(own(A.bang), 32, 0, 44)
      @btn = [own(A.button(YELLOW)), own(A.button(BLUE))]
      @blue_icon = sprite(own(A.button(BLUE)), 33)
      @puff_bmp = own(A.puff)
      @vignette = sprite(own(A.vignette), 35)
      @vignette.visible = false
      @bang.visible = @blue_icon.visible = false
    end

    def create_ui
      @meter = sprite(own(Bitmap.new(METER[2] + 8, 34)), 40, METER[0] - 4, METER[1] - 4)
      @pop_y = 120
      @pop = sprite(own(Bitmap.new(200, 48)), 41, 156, @pop_y)
      @bubble = sprite(own(Bitmap.new(200, 40)), 42, 8, 70)
      @bubble.visible = false
      @big = sprite(own(Bitmap.new(512, 96)), 43, 0, 120)
      @card = sprite(own(Bitmap.new(512, 384)), 44)
      [@pop, @bubble, @big, @card].each { |s| pbSetSystemFont(s.bitmap) if defined?(pbSetSystemFont) }
    end

    def dispose
      (@sprites || []).each { |s| s.dispose unless s.disposed? }
      (@owned || []).each { |b| b.dispose unless b.disposed? }
      @viewport.dispose if @viewport && !@viewport.disposed?
    end

    #--- text and UI ---------------------------------------------------------
    def col(rgb, alpha = 255)
      A.color(rgb, alpha)
    end

    def text(bmp, x, y, w, h, str, size, base = TEXT, align = 1)  # RGSS align: 1 = centre, 2 = right
      bmp.font.size = size
      pbDrawShadowText(bmp, x, y, w, h, str, col(base), col(INK), align)
    end

    def pop(key, rgb)
      bmp = @pop.bitmap
      bmp.clear
      text(bmp, 0, 0, bmp.width, bmp.height, _INTL(key), 40, rgb)
      hx, hy = hands
      @pop.x = (hx - bmp.width / 2).clamp(0, 512 - bmp.width)
      @pop_y = (hy - 90).clamp(40, 300)
      @pop_t = 0.0
    end

    def bubble(key)
      bmp = @bubble.bitmap
      bmp.clear
      bmp.fill_rect(0, 0, bmp.width, bmp.height - 8, col(INK))
      bmp.fill_rect(2, 2, bmp.width - 4, bmp.height - 12, col(TEXT))
      bmp.fill_rect(bmp.width - 28, bmp.height - 8, 8, 8, col(INK))
      text(bmp, 4, 2, bmp.width - 8, bmp.height - 12, _INTL(key), 22, INK, 2)
      @bubble_t = 0.0
    end

    def draw_big(str)
      bmp = @big.bitmap
      bmp.clear
      text(bmp, 0, 0, bmp.width, bmp.height, str, 72, GOLD)
      @big.visible = true
    end

    # Fixed halves (player gold left, Shirpaz red right); the marker sits where the hands lean.
    def draw_meter
      bmp = @meter.bitmap
      bmp.clear
      x0, _, w, h = METER
      half = w / 2
      bmp.fill_rect(0, 0, w + 8, h + 8, col(INK))
      bmp.fill_rect(4, 4, half, h, col(GOLD))
      bmp.fill_rect(4 + half, 4, half, h, col(RED))
      bmp.fill_rect(4 + half, 2, 1, h + 4, col(INK, 160))
      mx = 4 + half - (@shown_b / 100.0 * half).round
      bmp.fill_rect(mx - 3, 0, 7, h + 8, col(INK))
      bmp.fill_rect(mx - 1, 2, 3, h + 4, col(TEXT))
      left = @bout ? R::CAP - @bout[:t] : R::CAP
      PIPS.times do |i|
        px = 4 + (w - PIPS * 14) / 2 + i * 14
        on = left > i * (R::CAP / PIPS)
        bmp.fill_rect(px, h + 12, 10, 6, col(on ? TEXT : INK, on ? 230 : 120))
      end
      @meter.x = x0 - 4
    end

    # nil: the how-to card; true/false: the end card (true = the 45 s cap ended it).
    def show_card(timeup)
      bmp = @card.bitmap
      bmp.clear
      bmp.fill_rect(96, 96, 320, 192, col(TEXT))
      bmp.fill_rect(99, 99, 314, 186, col(INK, 235))
      if timeup.nil?
        draw_howto(bmp)
      else
        win = @bout[:over] == :win
        pbSEPlay(win ? SE[:win] : SE[:loss])
        text(bmp, 96, 116, 320, 40, _INTL("AW_TIMEUP"), 28) if timeup
        text(bmp, 96, 160, 320, 64, _INTL(win ? "AW_WIN_CARD" : "AW_LOSE_CARD"), 52, win ? GOLD : RED)
        enter(:card)
      end
      @card.visible = true
    end

    def draw_howto(bmp)
      [["AW_HOWTO_1", YELLOW], ["AW_HOWTO_2", BLUE]].each_with_index do |(key, rgb), i|
        y = 120 + i * 48
        bmp.blt(370, y + 2, @btn[i], @btn[i].rect) if @btn
        text(bmp, 104, y, 260, 36, _INTL(key), 26, TEXT, 2)
      end
      text(bmp, 104, 228, 304, 36, _INTL("AW_HOWTO_START"), 24, GOLD, 2)
    end
  end
end
