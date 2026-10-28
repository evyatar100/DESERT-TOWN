#===============================================================================
# Toaster - Yunik's Stamp Desk (the hearing): 12 forms, Yellow approve / Blue reject
# by a rule amended twice. Modal like zTempleHoop; the BGM is never touched.
#===============================================================================

module Toaster
  class DeskScene
    R = ToasterDeskRules
    SHEET_X = 166
    SHEET_Y = 70
    SHEET_W = 180
    SHEET_H = 220
    BACK_OFF = 6
    BAR_Y = 306
    STRIPE_H = 28
    STRIPE_RGB = { green: [70, 160, 84], red: [196, 58, 52], blue: [58, 104, 204], yellow: [232, 200, 64] }.freeze
    COLOR_KEYS = { green: "TOAST_DESK_COLOR_GREEN", red: "TOAST_DESK_COLOR_RED",
                   blue: "TOAST_DESK_COLOR_BLUE", yellow: "TOAST_DESK_COLOR_YELLOW" }.freeze
    STAMPS = { ok: ["TOAST_DESK_STAMP_OK", [40, 150, 64]], no: ["TOAST_DESK_STAMP_NO", [196, 48, 44]],
               late: ["TOAST_DESK_STAMP_LATE", [128, 128, 136]] }.freeze
    PAPER = [246, 240, 226].freeze
    INK = [40, 34, 44].freeze
    TEXT = [248, 240, 224].freeze
    SHADOW = [24, 18, 28].freeze
    DESK = [92, 64, 48].freeze
    WALL = [52, 46, 58].freeze
    GOOD = [96, 200, 110].freeze
    BAD = [224, 80, 72].freeze

    # losses: retry easing; seed: one Random for the whole hearing.
    def initialize(losses, seed)
      @losses = losses
      @window = R.window(losses)
      @hearing = R.hearing(seed)
      @index = 0
      @correct = 0
      @wrong = 0
      @tint = 0
      @shake = 0
    end

    # {passed:, correct:, shown:}
    def run
      create
      start_banner
      loop do
        Graphics.update
        Input.update
        result = update
        return result if result
      end
    ensure
      dispose
    end

    def now
      System.uptime
    end

    def enter(phase)
      @phase = phase
      @at = now
    end

    def form
      @hearing[:forms][@index]
    end

    def rule
      @hearing[:rules][R.phase([@index, R::FORMS - 1].min)]
    end

    def update
      animate_sheet
      t = now - @at
      case @phase
      when :banner then start_slide_in if t >= R::BANNER_TIME
      when :slide_in then update_slide_in(t)
      when :settle then enter(:decide) if t >= R::SETTLE_TIME
      when :decide then update_decide(t)
      when :stamp then enter(:slide_out) if t >= R::STAMP_TIME
      when :slide_out then update_slide_out(t)
      when :card then return update_card(t)
      end
      nil
    end

    def start_banner
      enter(:banner)
      @sheet.visible = false
      @bar.visible = false
      pbSEPlay("GUI summary change page") if @index > 0
      refresh_ui
    end

    def start_slide_in
      draw_form
      @sheet.x = Graphics.width
      @sheet.visible = true
      @bar.visible = true
      @bar.src_rect.width = SHEET_W
      enter(:slide_in)
      refresh_ui
    end

    def update_slide_in(t)
      f = [t / R::SLIDE_TIME, 1.0].min
      @sheet.x = (Graphics.width + (SHEET_X - Graphics.width) * f).round
      enter(:settle) if f >= 1.0
    end

    def update_decide(t)
      @bar.src_rect.width = (SHEET_W * [1.0 - t / @window, 0.0].max).round
      return judge(true) if Input.trigger?(Input::USE)
      return judge(false) if Input.trigger?(Input::BACK)
      judge(nil) if t >= @window
    end

    # pressed: true approve, false reject, nil timeout (counts as wrong).
    def judge(pressed)
      ok = R.correct?(form, pressed)
      pbSEPlay("Mining hammer") unless pressed.nil?
      if ok
        @correct += 1
        @shake = 2
        @sheet.x = SHEET_X + 3
      else
        @wrong += 1
        @tint = 6
        @sheet.color = col([220, 40, 40], 120)
        pbSEPlay("GUI sel buzzer")
      end
      draw_form(pressed.nil? ? :late : (pressed ? :ok : :no))
      enter(:stamp)
      refresh_ui
    end

    def update_slide_out(t)
      f = [t / R::SLIDE_TIME, 1.0].min
      @sheet.x = (SHEET_X - (SHEET_X + SHEET_W + 2 * BACK_OFF) * f).round
      return if f < 1.0
      @index += 1
      return start_card if @index >= R::FORMS || R.early_fail?(@wrong, @losses)
      @index % R::PHASE_LEN == 0 ? start_banner : start_slide_in
    end

    def start_card
      @passed = @index >= R::FORMS && R.passed?(@correct, @losses)
      @sheet.visible = false
      @bar.visible = false
      enter(:card)
      refresh_ui
    end

    def update_card(t)
      return nil if t < R::CARD_LOCK
      return nil unless Input.trigger?(Input::USE) || Input.trigger?(Input::BACK)
      { passed: @passed, correct: @correct, shown: @index }
    end

    # judge applies the first shake/tint frame; this counts the shown frames down, then restores.
    def animate_sheet
      if @shake > 0
        @shake -= 1
        @sheet.x = @shake > 0 ? SHEET_X - 3 : SHEET_X
      end
      return unless @tint > 0
      @tint -= 1
      @sheet.color = col([0, 0, 0], 0) if @tint == 0
    end

    #--- drawing ----------------------------------------------------------------
    def create
      @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
      # Same z as pbFadeOutIn's black layer but created later, so drawn above it.
      @viewport.z = 99_999
      @sprites = []
      @bg = sprite(draw_backdrop, 0)
      @yunik = yunik_sprite
      @sheet = sprite(Bitmap.new(SHEET_W + 2 * BACK_OFF, SHEET_H + 2 * BACK_OFF), 20, SHEET_X, SHEET_Y)
      @bar = sprite(Bitmap.new(SHEET_W, 10), 25, SHEET_X, BAR_Y)
      @bar.bitmap.fill_rect(0, 0, SHEET_W, 10, col([236, 196, 72]))
      @ui = sprite(Bitmap.new(Graphics.width, Graphics.height), 40)
      [@sheet, @ui].each { |s| pbSetSystemFont(s.bitmap) if defined?(pbSetSystemFont) }
    end

    def sprite(bitmap, z, x = 0, y = 0)
      s = Sprite.new(@viewport)
      s.bitmap = bitmap
      s.z = z
      s.x, s.y = x, y
      @sprites << s
      s
    end

    def col(rgb, alpha = 255)
      Color.new(rgb[0], rgb[1], rgb[2], alpha)
    end

    # Shrinks the font until the line fits its box (long Hebrew labels).
    def fit_font(bmp, str, size, w)
      bmp.font.size = size
      bmp.font.size -= 1 while bmp.font.size > 12 && bmp.text_size(str).width > w - 4
    end

    def text(bmp, x, y, w, h, str, size, base = TEXT, shadow = SHADOW, align = 1)  # 1 = centre
      fit_font(bmp, str, size, w)
      pbDrawShadowText(bmp, x, y, w, h, str, col(base), col(shadow), align)
    end

    def draw_backdrop
      bmp = Bitmap.new(Graphics.width, Graphics.height)
      bmp.fill_rect(0, 0, bmp.width, bmp.height, col(WALL))
      bmp.fill_rect(0, 260, bmp.width, 90, col(DESK))
      bmp.fill_rect(0, 0, bmp.width, 58, col(SHADOW, 220))
      bmp
    end

    # Frame 0 (facing down) of his 4x4 walk sheet at 2x, in the left column.
    def yunik_sprite
      path = pbResolveBitmap("Graphics/Characters/dt_326f5ab5")
      return nil unless path
      s = sprite(Bitmap.new(path), 10)
      fw, fh = s.bitmap.width / 4, s.bitmap.height / 4
      s.src_rect.set(0, 0, fw, fh)
      s.zoom_x = s.zoom_y = 2
      s.x = 68 - fw
      s.y = 262 - fh * 2
      s
    end

    # The form, its back copies and (after a decision) the stamp imprint.
    def draw_form(stamp = nil)
      bmp = @sheet.bitmap
      bmp.clear
      f = form
      (f[:copies] - 1).downto(0) do |k|
        o = k * BACK_OFF
        bmp.fill_rect(o, o, SHEET_W, SHEET_H, col(INK))
        bmp.fill_rect(o + 2, o + 2, SHEET_W - 4, SHEET_H - 4, col(PAPER, k == 0 ? 255 : 225))
      end
      rgb = STRIPE_RGB[f[:stripe]]
      bmp.fill_rect(2, 2, SHEET_W - 4, STRIPE_H, col(rgb))
      dark = f[:stripe] == :yellow
      text(bmp, 2, 2, SHEET_W - 4, STRIPE_H, _INTL(COLOR_KEYS[f[:stripe]]), 20, dark ? INK : TEXT, dark ? rgb : SHADOW)
      text(bmp, 0, 80, SHEET_W, 44, _INTL("TOAST_DESK_APPL_#{f[:appliance]}"), 30, INK, PAPER)
      text(bmp, 0, SHEET_H - 40, SHEET_W, 28, _INTL("TOAST_DESK_COPIES", f[:copies]), 20, INK, PAPER)
      draw_stamp(bmp, *STAMPS[stamp]) if stamp
    end

    def draw_stamp(bmp, key, rgb)
      x, y, w, h = 24, 128, SHEET_W - 48, 44
      bmp.fill_rect(x, y, w, h, col(rgb))
      bmp.fill_rect(x + 3, y + 3, w - 6, h - 6, col(PAPER))
      text(bmp, x, y + 2, w, h - 4, _INTL(key), 28, rgb, PAPER)
    end

    def refresh_ui
      bmp = @ui.bitmap
      bmp.clear
      phase = R.phase([@index, R::FORMS - 1].min)
      text(bmp, 0, 0, bmp.width, 22, _INTL("TOAST_DESK_AMEND_#{phase}"), 16)
      text(bmp, 0, 20, bmp.width, 34, _INTL("TOAST_DESK_RULE_#{rule}"), 24)
      text(bmp, 392, 70, 116, 30, _INTL("TOAST_DESK_COUNT", [@index + 1, R::FORMS].min, R::FORMS), 22)
      draw_tally(bmp, 112, @correct, GOOD, true)
      draw_tally(bmp, 146, @wrong, BAD, false)
      bmp.fill_rect(0, 350, bmp.width, 34, col(SHADOW, 210))
      text(bmp, 0, 352, bmp.width, 30, _INTL("TOAST_DESK_HINT"), 20)
      draw_banner(bmp, phase) if @phase == :banner
      draw_card(bmp) if @phase == :card
    end

    # A drawn tick or cross (no font glyph needed), then the count as digits.
    def draw_tally(bmp, y, count, rgb, tick)
      c = col(rgb)
      if tick
        5.times { |i| bmp.fill_rect(414 + i, y + 12 + i, 3, 3, c) }
        9.times { |i| bmp.fill_rect(418 + i, y + 16 - 2 * i, 3, 3, c) }
      else
        12.times { |i| bmp.fill_rect(414 + i, y + 4 + i, 3, 3, c) }
        12.times { |i| bmp.fill_rect(425 - i, y + 4 + i, 3, 3, c) }
      end
      text(bmp, 440, y, 60, 26, count.to_s, 24, rgb)
    end

    def draw_banner(bmp, phase)
      bmp.fill_rect(56, 120, 400, 120, col(TEXT))
      bmp.fill_rect(59, 123, 394, 114, col(SHADOW, 240))
      head = phase == 0 ? "TOAST_DESK_AMEND_0" : "TOAST_DESK_AMEND_BANNER"
      text(bmp, 56, 132, 400, 34, _INTL(head), 24, [236, 196, 72])
      text(bmp, 56, 176, 400, 40, _INTL("TOAST_DESK_RULE_#{rule}"), 26)
    end

    def draw_card(bmp)
      bmp.fill_rect(116, 112, 280, 150, col(TEXT))
      bmp.fill_rect(119, 115, 274, 144, col(SHADOW, 240))
      text(bmp, 116, 136, 280, 44, _INTL("TOAST_DESK_RESULT", @correct, @index), 28, @passed ? GOOD : BAD)
      text(bmp, 116, 196, 280, 40, _INTL(@passed ? "TOAST_DESK_PASS" : "TOAST_DESK_FAIL"), 28)
    end

    def dispose
      (@sprites || []).each do |s|
        next if s.disposed?
        s.bitmap.dispose if s.bitmap && !s.bitmap.disposed?
        s.dispose
      end
      @viewport.dispose if @viewport && !@viewport.disposed?
    end
  end
end
