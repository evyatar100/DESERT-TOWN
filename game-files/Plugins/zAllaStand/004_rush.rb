#===============================================================================
# AllaStand - the Hot-Dog Rush: 9 orders, Alla's decree changes twice. Direction =
# topping on/off, Yellow serves, Blue empties the bun. Modal like zToaster's desk; BGM untouched.
#===============================================================================

module AllaStand
  class RushScene
    R = AllaRushRules
    TICKET_X = 116
    TICKET_Y = 64
    TICKET_W = 280
    TICKET_H = 76
    BUN_X = 96
    BUN_Y = 152
    BAR_X = 166
    BAR_Y = 296
    BAR_W = 180
    WORD_Y = 308
    WORDS_X = 96   # right of Alla's zoomed sprite (x 24-88)
    WORD_W = 104
    TOPPING_KEYS = { ketchup: "ALLA_TOP_KETCHUP", mustard: "ALLA_TOP_MUSTARD", onion: "ALLA_TOP_ONION", kraut: "ALLA_TOP_KRAUT" }.freeze
    TOPPING_RGB = { ketchup: [214, 48, 40], mustard: [236, 196, 40], onion: [140, 86, 40], kraut: [170, 210, 140] }.freeze
    DIRS = { Input::UP => :ketchup, Input::RIGHT => :mustard, Input::DOWN => :onion, Input::LEFT => :kraut }.freeze
    # Voted customers are the campers; the stranger (Nisim, Map098) is the one who has not voted.
    CUSTOMER_IDS = { tal: "9b3660d1", elias: "788b2614", mario: "bb70b1dd", stranger: "d107409e" }.freeze
    PAPER = [246, 240, 226].freeze
    INK = [40, 34, 44].freeze
    TEXT = [248, 240, 224].freeze
    SHADOW = [24, 18, 28].freeze
    WALL = [48, 52, 70].freeze
    GOOD = [96, 200, 110].freeze
    BAD = [224, 80, 72].freeze
    GOLD = [236, 196, 72].freeze

    # losses: retry easing; seed: one Random for the whole rush.
    def initialize(losses, seed)
      @losses = losses
      @window = R.window(losses)
      @rush = R.rush(seed)
      @index = 0
      @correct = 0
      @wrong = 0
      @bun = []
      @tint = 0
      @law_shown = 0
    end

    # {passed:, correct:, shown:}
    def run
      create
      start_slide_in
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

    def order
      @rush[:orders][@index]
    end

    def law
      @rush[:laws][R.phase([@index, R::ORDERS - 1].min)]
    end

    def update
      animate
      t = now - @at
      case @phase
      when :banner then update_banner(t)
      when :slide_in then update_slide_in(t)
      when :decide then update_decide(t)
      when :result then finish_order if t >= R::RESULT_TIME
      when :card then return update_card(t)
      end
      nil
    end

    #--- flow ---------------------------------------------------------------------
    def start_banner
      enter(:banner)
      @ticket.visible = @bar.visible = false
      @digit = nil
      refresh_ui
    end

    def update_banner(t)
      digit = [3 - t.floor, 1].max
      if digit != @digit
        @digit = digit
        pbSEPlay("GUI summary change page")
        refresh_ui
      end
      return if t < R::BANNER_TIME
      @law_shown = R.phase(@index)
      start_slide_in
    end

    def start_slide_in
      @bun = []
      @fb.visible = false
      draw_bun
      draw_ticket
      @ticket.x = Graphics.width
      @ticket.visible = true
      @bar.visible = false
      enter(:slide_in)
      refresh_ui
    end

    def update_slide_in(t)
      f = [t / R::SLIDE_TIME, 1.0].min
      @ticket.x = (Graphics.width + (TICKET_X - Graphics.width) * f).round
      return if f < 1.0
      @bar.visible = true
      @bar.src_rect.width = BAR_W
      enter(:decide)
    end

    def update_decide(t)
      @bar.src_rect.width = (BAR_W * [1.0 - t / @window, 0.0].max).round
      if t >= R::INPUT_LOCK
        return serve(@bun) if Input.trigger?(Input::USE)
        if Input.trigger?(Input::BACK)
          @bun = []
          draw_bun
        end
        DIRS.each { |btn, top| toggle(top) if Input.trigger?(btn) }
      end
      serve(nil) if t >= @window
    end

    def toggle(topping)
      @bun.include?(topping) ? @bun.delete(topping) : @bun << topping
      draw_bun
    end

    # served: the toppings on the bun; nil = timeout (counts as wrong).
    def serve(served)
      ok = !served.nil? && R.correct?(law, order, served)
      pbSEPlay(ok ? "Mining hammer" : "GUI sel buzzer")
      if ok
        @correct += 1
      else
        @wrong += 1
        @tint = 6
        @bun_sprite.color = col([220, 40, 40], 120)
      end
      key = ok ? "ALLA_RUSH_OK" : (served.nil? ? "ALLA_RUSH_LATE" : "ALLA_RUSH_ILLEGAL")
      show_feedback(key, ok ? GOOD : BAD, ok)
      @bar.visible = false
      enter(:result)
      refresh_ui
    end

    def finish_order
      @index += 1
      return start_card if @index >= R::ORDERS || R.early_fail?(@wrong, @losses)
      R.phase(@index) != R.phase(@index - 1) ? start_banner : start_slide_in
    end

    def start_card
      @passed = @index >= R::ORDERS && R.passed?(@correct, @losses)
      @ticket.visible = @bar.visible = @fb.visible = false
      enter(:card)
      refresh_ui
    end

    def update_card(t)
      return nil if t < R::CARD_LOCK
      return nil unless Input.trigger?(Input::USE) || Input.trigger?(Input::BACK)
      { passed: @passed, correct: @correct, shown: @index }
    end

    # Floats the feedback up a little; counts the wrong-tint frames down, then restores.
    def animate
      @fb.y = [@fb.y - 1, @fb_top].max if @fb.visible
      return unless @tint > 0
      @tint -= 1
      @bun_sprite.color = col([0, 0, 0], 0) if @tint == 0
    end

    #--- drawing ----------------------------------------------------------------
    def create
      @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
      # Same z as pbFadeOutIn's black layer but created later, so drawn above it.
      @viewport.z = 99_999
      @sprites = []
      sprite(draw_backdrop, 0)
      @alla = char_sprite("4c4e039d", 2, 24, 244)
      @bun_sprite = pic_sprite
      @top = sprite(Bitmap.new(320, 128), 16, BUN_X, BUN_Y)
      @ticket = sprite(Bitmap.new(TICKET_W, TICKET_H), 20, TICKET_X, TICKET_Y)
      @bar = sprite(Bitmap.new(BAR_W, 8), 25, BAR_X, BAR_Y)
      @bar.bitmap.fill_rect(0, 0, BAR_W, 8, col(GOLD))
      @fb = sprite(Bitmap.new(TICKET_W, 34), 30, TICKET_X, TICKET_Y + TICKET_H)
      @fb.visible = false
      @words = sprite(Bitmap.new(Graphics.width, 30), 35, 0, WORD_Y)
      @ui = sprite(Bitmap.new(Graphics.width, Graphics.height), 40)
      @customers = CUSTOMER_IDS.transform_values { |id| char_bitmap(id) }
      [@ticket, @fb, @words, @ui].each { |s| pbSetSystemFont(s.bitmap) if defined?(pbSetSystemFont) }
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

    def char_bitmap(id)
      path = pbResolveBitmap("Graphics/Characters/dt_#{id}")
      path ? Bitmap.new(path) : nil
    end

    # Frame 0 (facing down) of a 4x4 walk sheet, zoomed.
    def char_sprite(id, zoom, x, y)
      bmp = char_bitmap(id)
      return nil unless bmp
      s = sprite(bmp, 10, x, y)
      s.src_rect.set(0, 0, bmp.width / 4, bmp.height / 4)
      s.zoom_x = s.zoom_y = zoom
      s
    end

    # The giant hot dog crop at 2x; a flat bun if the picture is missing.
    def pic_sprite
      path = pbResolveBitmap("Graphics/Pictures/alla_hotdog")
      bmp = path ? Bitmap.new(path) : Bitmap.new(160, 64)
      bmp.fill_rect(0, 16, 160, 32, col([214, 150, 80])) unless path
      s = sprite(bmp, 15, BUN_X, BUN_Y)
      s.zoom_x = s.zoom_y = 2
      s
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
      bmp.fill_rect(0, 0, bmp.width, 58, col(SHADOW, 220))
      bmp
    end

    # The bun's toppings: a 6 px squiggle per topping plus its word (never colour alone).
    def draw_bun
      @top.bitmap.clear
      @bun.each do |t|
        y0 = 18 + R::TOPPINGS.index(t) * 24
        (0...296).step(4) { |px| @top.bitmap.fill_rect(12 + px, y0 + (4 * Math.sin(px / 9.0)).round, 4, 6, col(TOPPING_RGB[t])) }
      end
      draw_words
    end

    def draw_words
      @words.bitmap.clear
      x0 = WORDS_X + (Graphics.width - WORDS_X - WORD_W * @bun.length) / 2
      @bun.each_with_index { |t, i| text(@words.bitmap, x0 + WORD_W * i, 0, WORD_W, 28, _INTL(TOPPING_KEYS[t]), 22, TOPPING_RGB[t]) }
    end

    # Customer frame 0 at 1x, the toppings as words with a colour chip, the ballot badge if they voted.
    def draw_ticket
      bmp = @ticket.bitmap
      bmp.clear
      bmp.fill_rect(0, 0, TICKET_W, TICKET_H, col(INK))
      bmp.fill_rect(2, 2, TICKET_W - 4, TICKET_H - 4, col(PAPER))
      src = @customers[order[:customer]]
      bmp.blt(8, 14, src, Rect.new(0, 0, src.width / 4, src.height / 4)) if src
      order[:toppings].each_with_index do |t, i|
        bmp.fill_rect(48, 10 + 22 * i, 14, 6, col(TOPPING_RGB[t]))
        text(bmp, 66, 4 + 22 * i, 134, 22, _INTL(TOPPING_KEYS[t]), 20, INK, PAPER, 0)
      end
      text(bmp, 206, 48, 70, 26, _INTL("ALLA_RUSH_VOTED"), 16, INK, PAPER) if order[:voted]
    end

    def show_feedback(key, rgb, ok)
      bmp = @fb.bitmap
      bmp.clear
      text(bmp, 0, 0, TICKET_W, 34, _INTL(key), 26, rgb)
      @fb.x = TICKET_X
      @fb.y = ok ? TICKET_Y + TICKET_H : BUN_Y + 40
      @fb_top = @fb.y - 14
      @fb.visible = true
    end

    def refresh_ui
      bmp = @ui.bitmap
      bmp.clear
      shown = [@index + 1, R::ORDERS].min
      text(bmp, 0, 0, bmp.width, 20, _INTL("ALLA_LAW_NUM", @law_shown + 1), 16)
      text(bmp, 0, 20, bmp.width, 34, _INTL("ALLA_LAW_#{@rush[:laws][@law_shown]}"), 24)
      text(bmp, 400, 64, 108, 30, _INTL("ALLA_RUSH_COUNT", shown, R::ORDERS), 22)
      draw_tally(bmp, 108, @correct, GOOD, true)
      draw_tally(bmp, 142, @wrong, BAD, false)
      bmp.fill_rect(0, 350, bmp.width, 34, col(SHADOW, 210))
      text(bmp, 0, 352, bmp.width, 30, _INTL("ALLA_RUSH_HINT"), 20)
      draw_banner(bmp) if @phase == :banner
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

    # New decree: banner, the 3-2-1 digits, then the new law replaces the old one in the top band.
    def draw_banner(bmp)
      bmp.fill_rect(56, 100, 400, 150, col(TEXT))
      bmp.fill_rect(59, 103, 394, 144, col(SHADOW, 240))
      text(bmp, 56, 112, 400, 34, _INTL("ALLA_LAW_BANNER"), 24, GOLD)
      text(bmp, 56, 152, 400, 40, _INTL("ALLA_LAW_#{@rush[:laws][R.phase(@index)]}"), 26)
      text(bmp, 56, 198, 400, 44, @digit.to_s, 36, GOLD)
    end

    def draw_card(bmp)
      bmp.fill_rect(116, 112, 280, 150, col(TEXT))
      bmp.fill_rect(119, 115, 274, 144, col(SHADOW, 240))
      text(bmp, 116, 136, 280, 44, _INTL("ALLA_RUSH_RESULT", @correct, @index), 28, @passed ? GOOD : BAD)
      text(bmp, 116, 196, 280, 40, _INTL(@passed ? "ALLA_RUSH_PASS" : "ALLA_RUSH_FAIL"), 28)
    end

    def dispose
      (@sprites || []).each do |s|
        next if s.disposed?
        s.bitmap.dispose if s.bitmap && !s.bitmap.disposed?
        s.dispose
      end
      (@customers || {}).each_value { |b| b.dispose if b && !b.disposed? }
      @viewport.dispose if @viewport && !@viewport.disposed?
    end
  end
end
