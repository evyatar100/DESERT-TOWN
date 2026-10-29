#===============================================================================
# LilyHappy - the Wheel of Happiness modal screen: title, play (+ finale), pause, end card.
# Joystick turns (left/right), Up = compromise, Down = throw away, Yellow fixes, Blue pauses.
# The BGM is never touched. Returns { result: :finished | :quit, peak:, laps:, fixes: }.
#===============================================================================

module LilyHappy
  class Scene
    A = Art
    R = LilyHappyRules
    MAX_STEPS = 3                      # fixed steps per frame at most
    CENTER = [256, 162].freeze         # seat circle: front (256,262), back (256,62)
    RADIUS = 100
    ZOOM = 1.5
    FIX_SHOW_F = 48                    # the fix line, then the new complaint (1.6 s in all)
    FLOAT_F = 36                       # 0.6 s
    TIMER = [156, 10, 200, 8].freeze
    HUB_W = 64                         # "lap N" label inside the chain ring
    CHAIN_R = 42
    STRIP = [8, 318, 496, 64].freeze
    CARD = [56, 82, 400, 220].freeze
    PAUSE_ROWS = %w[LILY_PAUSE_RESUME LILY_PAUSE_RESTART LILY_PAUSE_QUIT].freeze
    SE = { ok: ["GUI sel decision", 80], bump: ["GUI sel cancel", 80] }.freeze
    DIRS = { Input::LEFT => :left, Input::RIGHT => :right, Input::UP => :comp, Input::DOWN => :moop }.freeze

    attr_reader :phase, :game, :seed

    # record: false for F9 games, which never write the saved state. seed: fixed for tests.
    def initialize(state, record: true, seed: nil)
      @state = state
      @record = record
      @fixed_seed = seed
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
      @anim += 1 unless @phase == :pause   # blinking freezes in the pause
      yellow = Input.trigger?(Input::USE)
      blue = Input.trigger?(Input::BACK)
      case @phase
      when :title then update_title(yellow, blue)
      when :play then update_play(dt, yellow, blue)
      when :pause then update_pause(yellow, blue)
      when :card then update_card(yellow)
      end
    end

    def enter(phase)
      @phase = phase
      draw_panel
      nil
    end

    def update_title(yellow, blue)
      return outcome(:quit) if blue
      start_game if yellow
      nil
    end

    def start_game
      @seed = @fixed_seed || rand(1 << 30)
      @game = R.new_game(@seed)
      @acc = 0.0
      @input = nil
      @feedback = nil
      @fb_next = nil
      @fb_t = 0
      @floats.each { |f| f[:t] = 0 }
      @hud_key = @hub_key = @strip_key = nil
      enter(:play)
      draw_play
    end

    def read_input(yellow)
      return :fix if yellow
      DIRS.each { |btn, act| return act if Input.trigger?(btn) }
      nil
    end

    # Inputs wait for the next fixed step; Blue pauses (never during the 2 s finale).
    def update_play(dt, yellow, blue)
      return enter(:pause) if blue && @game[:over].nil?
      @input ||= read_input(yellow) if @game[:over].nil?
      @acc += dt
      steps = 0
      while @acc >= R::DT && steps < MAX_STEPS
        @acc -= R::DT
        steps += 1
        R.tick(@game, @input).each { |e| on_event(e) }
        @input = nil
        step_fx
        return finish if @game[:over] == :done
      end
      @acc = 0.0 if steps == MAX_STEPS
      draw_play
      nil
    end

    def update_pause(yellow, blue)
      return enter(:play) if blue
      if Input.trigger?(Input::UP) || Input.trigger?(Input::DOWN)
        @pause_sel = (@pause_sel + (Input.trigger?(Input::UP) ? -1 : 1)) % PAUSE_ROWS.size
        draw_panel
      end
      return nil unless yellow
      case @pause_sel
      when 0 then enter(:play)
      when 1 then start_game
      else outcome(:quit)       # quitting records nothing
      end
    end

    def update_card(yellow)
      return nil unless yellow && @card_t + 30 <= @anim
      outcome(:finished)
    end

    def on_event(e)
      case e[0]
      when :fix
        se(:ok)
        float(e[1], "+#{R::FIX_GAIN}", A::GREEN)
        float(R.opp(e[1]), "-#{R::FIX_HIT}", A::RED)
        feedback(_INTL("LILY_W_F#{e[2]}"), _INTL("LILY_W_N#{e[2]}"))
      when :comp then feedback(_INTL("LILY_W_COMP_#{e[1]}"))
      when :moop then se(:bump); feedback(_INTL("LILY_W_MOOP"))
      when :nofix then se(:bump); feedback(_INTL("LILY_W_NOCOMPLAINT"))
      when :nocomp then se(:bump); feedback(_INTL("LILY_W_NOCOMP"))
      when :expire then float(e[1], "-1", A::RED)
      when :finale then feedback(_INTL("LILY_W_ALL"))
      end
    end

    def feedback(now, after = nil)
      @feedback = now
      @fb_next = after
      @fb_t = after ? FIX_SHOW_F : 0
    end

    # Feedback and floats run on game steps, so they freeze with the pause.
    def step_fx
      if @fb_t > 0
        @fb_t -= 1
        @feedback = @fb_next if @fb_t.zero? && @fb_next
      end
      @floats.each { |f| f[:t] -= 1 if f[:t] > 0 }
    end

    def finish
      R.record!(@state, @game) if @record
      @card_t = @anim
      enter(:card)
      nil
    end

    def outcome(result)
      g = @game || {}
      { result: result, peak: g[:peak] || 0, laps: g[:laps] || 0, fixes: g[:fixes] || 0 }
    end

    def se(key)
      pbSEPlay(*SE[key]) if defined?(pbSEPlay)
    end

    def float(seat, str, rgb)
      f = @floats.min_by { |x| x[:t] }
      f[:bmp].clear
      text(f[:bmp], 0, 0, 40, 20, str, 18, rgb)
      f[:seat] = seat
      f[:t] = FLOAT_F
    end

    #--- setup -------------------------------------------------------------------
    def create
      @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
      @viewport.z = 99_999   # same z as pbFadeOutIn's black layer, created later so drawn above it
      @owned = []
      @sprites = []
      @anim = 0
      @pause_sel = 0
      @last = System.uptime
      sprite(own(A.background), 0)
      @seats = R::SEAT_IDS.each_with_index.map do |id, i|
        s = sprite(own(A.charset(id, i)), 100)
        s.src_rect = Rect.new(0, 0, A::FW, A::FH)
        s.zoom_x = s.zoom_y = ZOOM
        s.ox, s.oy = A::FW / 2, A::FH / 2
        s
      end
      @icons = { full: own(A.heart_icon(true)), empty: own(A.heart_icon(false)), bang: own(A.bubble(false)),
                 half: own(A.bubble(true)), chevron: own(A.chevron) }
      @seats.each_with_index { |s, i| s.x, s.y = seat_xy(i).map(&:round) }   # wheel at rest behind the title
      @names = R::SEAT_IDS.map { |id| _INTL("NAME_#{id.upcase}") }
      @overlay = sprite(own(Bitmap.new(Graphics.width, Graphics.height)), 500)
      @hud = sprite(own(Bitmap.new(Graphics.width, 40)), 600)   # the backdrop keeps 0-40 dark
      @hub = sprite(own(Bitmap.new(HUB_W, 24)), 600, A::RING[0] - HUB_W / 2, A::RING[1] - 12)
      @strip = sprite(own(Bitmap.new(STRIP[2], STRIP[3])), 600, STRIP[0], STRIP[1])
      @floats = Array.new(4) { { bmp: own(Bitmap.new(40, 20)), t: 0, seat: 0 } }
      @float_sprites = @floats.map { |f| sprite(f[:bmp], 700) }
      @panel = sprite(own(Bitmap.new(Graphics.width, Graphics.height)), 950)
      bitmaps = [@hud, @hub, @strip, @panel].map(&:bitmap) + @floats.map { |f| f[:bmp] }
      bitmaps.each { |b| pbSetSystemFont(b) if defined?(pbSetSystemFont) }
      enter(:title)
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

    def dispose
      (@sprites || []).each { |s| s.dispose unless s.disposed? }
      (@owned || []).each { |b| b.dispose unless b.disposed? }
      @viewport.dispose if @viewport && !@viewport.disposed?
    end

    #--- drawing -----------------------------------------------------------------
    def col(rgb, alpha = 255) = A.color(rgb, alpha)

    def text(bmp, x, y, w, h, str, size, base = A::TEXT, align = 1)   # RGSS align: 1 centre, 2 right
      bmp.font.size = size
      pbDrawShadowText(bmp, x, y, w, h, str, col(base), col(A::INK), align)
    end

    # Logical-order word wrap by measured width (zTutaMaze); each line then goes through the bidi draw.
    def wrap(bmp, str, w, size)
      bmp.font.size = size
      lines = []
      str.to_s.split("\n").each do |para|
        line = ""
        para.split(" ").each do |word|
          try = line.empty? ? word : "#{line} #{word}"
          if !line.empty? && bmp.text_size(try).width > w
            lines << line
            line = word
          else
            line = try
          end
        end
        lines << line
      end
      lines
    end

    def paragraph(bmp, x, y, w, str, size, line_h = size + 2)
      rows = wrap(bmp, str, w, size)
      rows.each_with_index { |l, i| text(bmp, x, y + i * line_h, w, line_h, l, size) }
      y + rows.size * line_h
    end

    # Seat i's screen centre: the wheel eases one seat per turn (0.15 s).
    def seat_xy(i)
      g = @game
      disp = g ? g[:rot] - g[:last_turn] * (g[:turn].to_f / R::TURN_F)**2 : 0
      a = (90 - 60 * (i - disp)) * Math::PI / 180
      [CENTER[0] + RADIUS * Math.cos(a), CENTER[1] + RADIUS * Math.sin(a)]
    end

    def draw_play
      g = @game
      bmp = @overlay.bitmap
      bmp.clear
      fr = R.front(g)
      R::SEATS.times do |i|
        x, y = seat_xy(i)
        s = @seats[i]
        s.x, s.y = x.round, y.round
        s.z = 100 + y.round
        draw_seat(bmp, i, x.round, y.round, i == fr)
      end
      draw_timer(bmp)
      draw_chain(bmp)
      draw_floats
      draw_hud
      draw_hub
      draw_strip
    end

    def draw_seat(bmp, i, x, y, front)
      g = @game
      top = y - (A::FH * ZOOM / 2).round
      bottom = y + (A::FH * ZOOM / 2).round
      R::HEART_MAX.times do |h|
        icon = h < g[:hearts][i] ? @icons[:full] : @icons[:empty]
        bmp.blt(x - 22 + h * 9, bottom + 4, icon, icon.rect)
      end
      bmp.blt(x - 7, bottom + 12, @icons[:chevron], @icons[:chevron].rect) if front && bottom + 19 <= STRIP[1]
      b = g[:bubbles][i]
      return unless b
      bx, by = top - 28 < 30 ? [x + 20, top] : [x - 14, top - 28]
      icon = b[:half] ? @icons[:half] : @icons[:bang]
      bmp.blt(bx, by, icon, icon.rect)
      bmp.fill_rect(bx, by + 24, 28, 3, col(A::INK))
      bmp.fill_rect(bx, by + 24, (28.0 * b[:left] / b[:total]).ceil, 3, col(A::YELLOW))
    end

    def draw_timer(bmp)
      x, y, w, h = TIMER
      left = [R::PLAY_F - @game[:f], 0].max.to_f / R::PLAY_F
      bmp.fill_rect(x - 1, y - 1, w + 2, h + 2, col(A::OUTLINE))
      bmp.fill_rect(x, y, (w * left).ceil, h, col(A::PHASE_RGB[@game[:phase]]))
    end

    # 11 dots around the hub, the current chain step lit.
    def draw_chain(bmp)
      cx, cy = A::RING[0], A::RING[1]
      R::CHAIN.times do |i|
        a = (-90 + 360.0 * i / R::CHAIN) * Math::PI / 180
        x = (cx + CHAIN_R * Math.cos(a)).round
        y = (cy + CHAIN_R * Math.sin(a)).round
        lit = i + 1 == @game[:k]
        bmp.fill_rect(x - 3, y - 3, 6, 6, col(A::OUTLINE))
        bmp.fill_rect(x - 2, y - 2, 4, 4, col(lit ? A::YELLOW : [90, 80, 70]))
      end
    end

    def draw_floats
      @floats.each_with_index do |f, n|
        s = @float_sprites[n]
        s.visible = f[:t] > 0
        next unless s.visible
        x, y = seat_xy(f[:seat])
        s.x = x.round - 20
        s.y = (y - 40 - (FLOAT_F - f[:t]) / 2).round
      end
    end

    def draw_hud
      key = [@game[:peak], R.happy(@game)]
      return if key == @hud_key
      @hud_key = key
      bmp = @hud.bitmap
      bmp.clear
      text(bmp, 360, 2, 148, 24, _INTL("LILY_W_TITLE"), 20, A::YELLOW, 2)
      text(bmp, 4, 3, 146, 22, _INTL("LILY_HUD_HAPPY", R.happy(@game)), 18, A::TEXT, 2)
      text(bmp, 4, 20, 146, 20, _INTL("LILY_HUD_GOAL"), 16, A::YELLOW, 2)
    end

    def draw_hub
      return if @hub_key == @game[:laps]
      @hub_key = @game[:laps]
      @hub.bitmap.clear
      text(@hub.bitmap, 0, 0, HUB_W, 24, _INTL("LILY_HUB_LAP", @game[:laps] + 1), 16)
    end

    def draw_strip
      fr = R.front(@game)
      b = @game[:bubbles][fr]
      say = b ? _INTL(b[:half] ? "LILY_W_HALF" : "LILY_W_C#{b[:step]}") : nil
      line1 = say ? "#{@names[fr]}: #{say}" : @names[fr]
      key = [line1, @feedback]
      return if key == @strip_key
      @strip_key = key
      bmp = @strip.bitmap
      bmp.clear
      bmp.fill_rect(0, 0, bmp.width, bmp.height, col(A::INK, 230))
      text(bmp, 8, 4, bmp.width - 16, 28, line1, 22, A::YELLOW, 2)
      text(bmp, 8, 32, bmp.width - 16, 28, @feedback.to_s, 20, A::TEXT, 2) if @feedback
    end

    def draw_panel
      bmp = @panel.bitmap
      bmp.clear
      case @phase
      when :title then draw_title(bmp)
      when :pause then draw_pause(bmp)
      when :card then draw_card(bmp)
      end
    end

    def box(bmp, x, y, w, h)
      bmp.fill_rect(x, y, w, h, col(A::YELLOW))
      bmp.fill_rect(x + 3, y + 3, w - 6, h - 6, col(A::INK, 240))
    end

    def draw_title(bmp)
      box(bmp, 40, 30, 432, 324)
      text(bmp, 40, 44, 432, 40, _INTL("LILY_W_TITLE"), 34, A::YELLOW)
      y = 96
      %w[LILY_W_HOW_1 LILY_W_HOW_2 LILY_W_HOW_3 LILY_W_HOW_4].each { |k| y = paragraph(bmp, 60, y, 392, _INTL(k), 20) + 6 }
      y = paragraph(bmp, 60, y + 4, 392, _INTL("LILY_W_HOW_GOAL"), 22) + 6
      paragraph(bmp, 60, y, 392, _INTL("LILY_W_HOW_PAUSE"), 18)
      text(bmp, 40, 318, 432, 28, _INTL("LILY_W_START"), 20, A::YELLOW)
    end

    def draw_pause(bmp)
      box(bmp, 116, 110, 280, 164)
      text(bmp, 116, 122, 280, 32, _INTL("LILY_PAUSE"), 28, A::YELLOW)
      PAUSE_ROWS.each_with_index do |k, i|
        sel = i == @pause_sel
        bmp.fill_rect(140, 166 + i * 34, 232, 30, col(A::YELLOW, 80)) if sel
        text(bmp, 140, 168 + i * 34, 232, 28, _INTL(k), 22, sel ? A::YELLOW : A::TEXT)
      end
    end

    def draw_card(bmp)
      x, y, w, h = CARD
      box(bmp, x, y, w, h)
      g = @game
      yy = paragraph(bmp, x + 16, y + 12, w - 32, _INTL("LILY_W_REALIZE"), 20) + 6
      stats = [_INTL("LILY_W_PEAK", g[:peak]), _INTL("LILY_W_LAPS", g[:laps]), _INTL("LILY_W_FIXES", g[:fixes])]
      text(bmp, x + 16, yy, w - 32, 26, stats.join("   "), 20, A::YELLOW)
      paragraph(bmp, x + 16, yy + 32, w - 32, _INTL("LILY_W_CAP"), 20)
      text(bmp, x, y + h - 34, w, 26, _INTL("LILY_W_CONTINUE"), 18, A::YELLOW)
    end
  end
end
