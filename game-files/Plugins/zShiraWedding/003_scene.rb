#===============================================================================
# Shira's wedding - the modal seating board (D7, D8). Joystick moves the cursor, Yellow (USE)
# picks / swaps / drops, Blue (BACK) drops or pauses. BGM is never touched.
# run returns { result: :solved, swaps: } or { result: :quit }. It never writes the saved state.
#===============================================================================

module ShiraWedding
  class Scene
    R = ShiraWeddingRules
    A = Art
    SEAT_XY = {
      A1: [56, 116], A2: [88, 116], B1: [224, 116], B2: [256, 116], C1: [392, 116], C2: [424, 116],
      K1: [208, 236], K2: [240, 236], K3: [272, 236]
    }.freeze
    TABLE_XY = [[40, 148], [208, 148], [376, 148]].freeze
    PROP_XY = { 0 => [16, 36], 1 => [400, 36], 3 => [308, 212] }.freeze
    POSE_XY = [16, 232].freeze
    INFO = [336, 232, 168, 108].freeze
    HOWTO = %w[SHIRA_HOWTO_1 SHIRA_HOWTO_2 SHIRA_HOWTO_3].freeze
    PAUSE_ROWS = %w[SHIRA_PAUSE_RESUME SHIRA_PAUSE_HINT SHIRA_PAUSE_RESTART SHIRA_PAUSE_LEAVE].freeze
    POSE_PLAY = 3
    POSE_STRESSED = 0
    POSE_WIN = 1
    STRESS_AT = 6
    REPEAT_FIRST = 0.30
    REPEAT_NEXT = 0.10
    BUBBLE_TIME = 1.4
    HINT_TIME = 2.0
    WIN_TIME = 1.0
    HOP_TIME = 0.5
    CARD_LOCK = 0.5
    LIFT = 4
    SE = {
      pick: "GUI storage pick up", drop: "GUI storage put down", cancel: "GUI sel cancel",
      ok: "GUI sel decision", cursor: "GUI sel cursor", win: "Mining found all"
    }.freeze
    DIR4 = { 2 => :down, 4 => :left, 6 => :right, 8 => :up }.freeze
    PULSE = Array.new(17) { |i| Color.new(*A::RED, i * 5) }.freeze   # red tint levels 0..80
    CLEAR = PULSE[0]
    CAPTION_W = 96

    attr_reader :phase, :arr, :swaps, :cursor, :sel, :hint

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
      @t += dt unless @phase == :pause   # animations freeze in the pause
      @phase_t += dt
      yellow = Input.trigger?(Input::USE)
      blue = Input.trigger?(Input::BACK)
      step = repeat(DIR4[Input.dir4], dt)
      result = case @phase
               when :title then update_title(yellow, blue)
               when :play then update_play(yellow, blue, step)
               when :pause then update_pause(yellow, blue, step)
               when :win then update_win
               when :card then update_card(yellow)
               end
      update_fx
      result
    end

    def enter(phase)
      @phase = phase
      @phase_t = 0.0
      nil
    end

    # Joystick step now, then after 0.30 s, then every 0.10 s while held.
    def repeat(dir, dt)
      if dir.nil?
        @rep_dir = nil
        return nil
      end
      if dir != @rep_dir
        @rep_dir = dir
        @rep_t = REPEAT_FIRST
        return dir
      end
      @rep_t -= dt
      return nil if @rep_t > 0
      @rep_t += REPEAT_NEXT
      dir
    end

    #--- phases ----------------------------------------------------------------------
    def update_title(yellow, blue)
      return se(:cancel) && { result: :quit } if blue
      return nil unless yellow
      se(:ok)
      @title.visible = false
      start_board
      enter(:play)
    end

    def update_play(yellow, blue, step)
      if step && (to = R::NAV[R::SEATS[@cursor]][step])
        @cursor = R::SEATS.index(to)
        se(:cursor)
      end
      if blue
        return drop_selection if @sel
        return open_pause
      end
      return nil unless yellow
      if @sel.nil?
        @sel = @cursor
        se(:pick)
      elsif @sel == @cursor
        drop_selection
      else
        swap_seats(@sel, @cursor)
      end
      nil
    end

    def drop_selection
      @sel = nil
      se(:cancel)
      nil
    end

    def swap_seats(i, j)
      before = @arr
      @arr = R.swap(@arr, i, j)
      refresh_board
      @swaps += 1
      @sel = nil
      @hint = nil
      se(:drop)
      mood = R.react(before, @arr, i, j)
      bubble(*mood) if mood
      draw_top
      win if R.solved?(@arr)
    end

    def win
      se(:win)
      @sel = nil
      @bubble.visible = false
      enter(:win)
    end

    def update_win
      return nil if @phase_t < WIN_TIME
      pbMEPlay("Slots big win") if defined?(pbMEPlay)
      draw_card
      enter(:card)
    end

    def update_card(yellow)
      return nil unless yellow && @phase_t >= CARD_LOCK
      se(:ok)
      { result: :solved, swaps: @swaps }
    end

    def open_pause
      @pause_i = 0
      draw_pause
      enter(:pause)
    end

    def update_pause(yellow, blue, step)
      return close_pause if blue
      if %i[up down].include?(step)
        @pause_i = (@pause_i + (step == :down ? 1 : -1)) % PAUSE_ROWS.length
        se(:cursor)
        draw_pause
      end
      return nil unless yellow
      se(:ok)
      case @pause_i
      when 0 then close_pause
      when 1 then show_hint
      when 2 then restart_board
      when 3 then { result: :quit }
      end
    end

    def close_pause
      @panel.visible = false
      enter(:play)
    end

    def show_hint
      h = R.hint(@arr)
      @hint = h && { seats: h, until: @t + HINT_TIME }
      close_pause
    end

    def restart_board
      start_board
      close_pause
    end

    def start_board
      @arr = R::START.dup
      refresh_board
      @swaps = 0
      @cursor = 0
      @sel = nil
      @hint = nil
      @bubble.visible = false
      draw_top
    end

    # Rule state, once per change of the board (not per frame).
    def refresh_board
      @broken = R.broken(@arr)
      @unhappy = R.unhappy(@arr)
    end

    #--- per-frame drawing -------------------------------------------------------------
    def update_fx
      @floor.bitmap = @floor_bmps[(@t / 0.5).floor % 2]
      return unless @arr
      bad = @unhappy
      pulse = (8 + 8 * Math.sin(@t * 6)).round.clamp(0, 16)
      hopping = @phase == :win
      hop = hopping ? -(6 * Math.sin(Math::PI * (@phase_t % HOP_TIME) / HOP_TIME).abs).round : 0
      blink = @hint && @t < @hint[:until] && ((@t * 6).floor % 2).zero?
      @arr.each_with_index do |g, i|
        x, y = SEAT_XY[R::SEATS[i]]
        s = @guests[g]
        lift = i == @sel ? -LIFT : 0
        s.x = x
        s.y = y + lift + hop
        s.src_rect.set((hopping && hop < 0 ? 1 : 0) * A::FW, 0, A::FW, A::FH)
        s.color = bad.include?(g) && @phase == :play ? PULSE[pulse] : CLEAR
        s.visible = !(blink && @hint[:seats][0] == i)
        b = @badges[g]
        b.visible = bad.include?(g) && @phase != :title
        b.x = x + 20
        b.y = y - 6 + lift + hop
      end
      cx, cy = SEAT_XY[R::SEATS[@cursor]]
      @cursor_s.visible = @phase == :play
      @cursor_s.x = cx - 2
      @cursor_s.y = cy - 2
      @cursor_s.opacity = 160 + (95 * Math.sin(@t * 8)).round
      @glow.visible = !@sel.nil?
      if @sel
        gx, gy = SEAT_XY[R::SEATS[@sel]]
        @glow.x = gx - 2
        @glow.y = gy - 2 - LIFT
      end
      @target.visible = blink ? true : false
      if @hint
        tx, ty = SEAT_XY[R::SEATS[@hint[:seats][1]]]
        @target.x = tx - 2
        @target.y = ty - 2
      end
      @hint = nil if @hint && @t >= @hint[:until]
      @bubble.visible = false if @bubble.visible && @t - @bubble_t > BUBBLE_TIME
      pose = @phase == :win || @phase == :card ? POSE_WIN : (@broken.length > STRESS_AT ? POSE_STRESSED : POSE_PLAY)
      @shira.src_rect.set((pose % 2) * A::POSE[0], (pose / 2) * A::POSE[1], *A::POSE)
      draw_info
    end

    #--- setup -------------------------------------------------------------------------
    def create
      @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
      @viewport.z = 99_999   # same z as pbFadeOutIn's black layer, created later so drawn above it
      @owned = []
      @sprites = []
      @t = 0.0
      @phase_t = 0.0
      @last = System.uptime
      @bubble_t = -10.0
      @bubble_n = 0
      @info_key = nil
      @props = own(A.sheet("venue_props"))
      @poses = own(A.sheet("shira_poses"))
      sprite(own(build_back), 0)
      @floor_bmps = [own(A.dance_floor(0)), own(A.dance_floor(1))]
      @floor = sprite(@floor_bmps[0], 2, 184, 36)
      @glow = sprite(own(A.glow), 15)
      @target = sprite(own(A.cursor), 16)
      @target.color = A.color(A::GREEN, 200)
      @guests = {}
      R::GUESTS.each_with_index do |(g, id), k|
        @guests[g] = sprite(own(A.charset(id, k)), 20)
        @guests[g].src_rect.set(0, 0, A::FW, A::FH)
      end
      sprite(own(build_front), 30)
      badge = own(A.badge)
      @badges = R::GUESTS.keys.to_h { |g| [g, sprite(badge, 40)] }
      @cursor_s = sprite(own(A.cursor), 45)
      @shira = sprite(@poses, 25, *POSE_XY)
      @shira.src_rect.set(0, 0, *A::POSE)
      @top = sprite(own(Bitmap.new(512, 32)), 50)
      @bottom = sprite(own(Bitmap.new(512, 32)), 50, 0, 352)
      @info = sprite(own(Bitmap.new(INFO[2], INFO[3])), 50, INFO[0], INFO[1])
      @bubble = sprite(own(Bitmap.new(132, 30)), 60)
      @panel = sprite(own(Bitmap.new(512, 384)), 80)
      @card = sprite(own(Bitmap.new(512, 384)), 90)
      @title = sprite(own(Bitmap.new(512, 384)), 100)
      [@top, @bottom, @info, @bubble, @panel, @card, @title].each { |s| pbSetSystemFont(s.bitmap) if defined?(pbSetSystemFont) }
      [@glow, @target, @cursor_s, @bubble, @panel, @card].each { |s| s.visible = false }
      @badges.each_value { |b| b.visible = false }
      @guests.each_value { |s| s.visible = false }
      draw_bottom
      draw_title
      enter(:title)
    end

    def build_back
      bmp = A.background(512, 384)
      PROP_XY.slice(0, 1).each { |cell, (x, y)| blt_prop(bmp, cell, x, y) }
      pbSetSystemFont(bmp) if defined?(pbSetSystemFont)
      text(bmp, 16, 102, 96, 16, _INTL("SHIRA_LBL_DJ"), 14)
      text(bmp, 184, 102, 144, 16, _INTL("SHIRA_LBL_DANCE"), 14)
      text(bmp, 400, 102, 96, 16, _INTL("SHIRA_LBL_BAR"), 14)
      %w[SHIRA_TABLE_A SHIRA_TABLE_B SHIRA_TABLE_C].each_with_index do |key, k|   # centred on the 80 px tables
        text(bmp, TABLE_XY[k][0] - (CAPTION_W - 80) / 2, 190, CAPTION_W, 16, _INTL(key), 14, A::YELLOW)
      end
      text(bmp, 200, 304, 112, 16, _INTL("SHIRA_LBL_KIDS"), 14)
      bmp
    end

    # Tables, the kids' table and the lamp sit in front of the guests.
    def build_front
      bmp = Bitmap.new(512, 384)
      TABLE_XY.each { |x, y| blt_prop(bmp, 2, x, y) }
      A.kids_table(bmp)
      blt_prop(bmp, 3, *PROP_XY[3])
      bmp
    end

    def blt_prop(bmp, cell, x, y)
      rx, ry, rw, rh = A::PROP_RECTS[cell]
      bmp.blt(x, y, @props, Rect.new(cell * A::PROP + rx, ry, rw, rh))
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

    def se(key)
      pbSEPlay(SE[key], 80) if defined?(pbSEPlay)
      true
    end

    #--- text ----------------------------------------------------------------------------
    def col(rgb, alpha = 255) = A.color(rgb, alpha)

    # align: 0 left, 1 centre, 2 right. Hebrew left-align draws in a box exactly its width.
    def text(bmp, x, y, w, h, str, size, base = A::TEXT, align = 1)
      bmp.font.size = size
      if align.zero?
        w = [bmp.text_size(str).width + 4, w].min
        align = 1
      end
      pbDrawShadowText(bmp, x, y, w, h, str, col(base), col(A::INK), align)
    end

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

    def guest_name(g) = _INTL("NAME_#{R::GUESTS[g].upcase}")

    def draw_title
      bmp = @title.bitmap
      bmp.clear
      bmp.fill_rect(0, 0, 512, 384, col(A::NIGHT))
      A.box(bmp, 56, 12, 400, 52, A::INK, A::LILAC, 3)
      text(bmp, 56, 16, 400, 44, _INTL("SHIRA_TITLE"), 32, A::LILAC)
      bmp.stretch_blt(Rect.new(12, 96, 128, 192), @poses, Rect.new(A::POSE[0], A::POSE[1], *A::POSE))
      y = 84
      HOWTO.each do |key|
        lines = wrap(bmp, _INTL(key), 340, 20)
        lines.each_with_index { |l, i| text(bmp, 156, y + i * 22, 344, 22, l, 20) }
        y += lines.length * 22 + 10
      end
      text(bmp, 0, 340, 512, 28, _INTL("SHIRA_CONTINUE"), 22, A::YELLOW)
      @title.visible = true
    end

    def draw_top
      bmp = @top.bitmap
      bmp.clear
      bmp.fill_rect(0, 0, 512, 28, col(A::INK, 220))
      text(bmp, 256, 2, 248, 24, _INTL("SHIRA_TITLE"), 20, A::LILAC, 2)
      text(bmp, 8, 2, 160, 24, _INTL("SHIRA_COMPLAINTS", @broken.length), 18, A::RED, 0)
      text(bmp, 168, 4, 120, 22, _INTL("SHIRA_SWAPS", @swaps), 16, A::TEXT)
    end

    def draw_bottom
      bmp = @bottom.bitmap
      bmp.clear
      bmp.fill_rect(0, 0, 512, 28, col(A::INK, 220))
      text(bmp, 0, 2, 512, 24, _INTL("SHIRA_HOWTO_BAR"), 16)
    end

    # The guest under the cursor: name, then each of their rules, red when broken.
    def draw_info
      g = @arr[@cursor]
      bad = @broken
      key = [g, bad]
      return if key == @info_key
      @info_key = key
      bmp = @info.bitmap
      bmp.clear
      A.box(bmp, 0, 0, INFO[2], INFO[3], A::INK, A::LILAC, 2)
      text(bmp, 4, 2, INFO[2] - 8, 22, guest_name(g), 18, A::YELLOW, 2)
      rules = R.rules_of(g)
      rows = rules.empty? ? [["SHIRA_RULE_TOGA_NONE", false]] : rules.map { |r| ["SHIRA_RULE_#{r.upcase}", bad.include?(r)] }
      y = 26
      rows.each do |rk, broken|
        wrap(bmp, _INTL(rk), INFO[2] - 12, 14).each do |l|
          break if y > INFO[3] - 18
          text(bmp, 6, y, INFO[2] - 12, 16, l, 14, broken ? A::RED : A::GREEN, 2)
          y += 16
        end
        y += 2
      end
    end

    def bubble(g, mood)
      @bubble_n += 1
      key = "SHIRA_R_#{mood == :happy ? 'HAPPY' : 'ANGRY'}_#{(@bubble_n - 1) % 3 + 1}"
      bmp = @bubble.bitmap
      bmp.clear
      A.box(bmp, 0, 0, bmp.width, bmp.height - 6, A::WHITE, A::INK, 2)
      bmp.fill_rect(bmp.width / 2 - 4, bmp.height - 8, 8, 8, col(A::INK))
      text(bmp, 4, 2, bmp.width - 8, bmp.height - 10, _INTL(key), 16, mood == :happy ? A::INK : A::RED)
      x, y = SEAT_XY[R::SEATS[@arr.index(g)]]
      @bubble.x = (x + 16 - bmp.width / 2).clamp(0, 512 - bmp.width)
      @bubble.y = (y - bmp.height).clamp(32, 352 - bmp.height)
      @bubble.visible = true
      @bubble_t = @t
      @last_bubble = key
    end

    def draw_pause
      bmp = @panel.bitmap
      bmp.clear
      A.box(bmp, 136, 100, 240, 184, A::INK, A::LILAC, 3)
      PAUSE_ROWS.each_with_index do |key, i|
        on = i == @pause_i
        bmp.fill_rect(148, 116 + i * 40, 216, 34, col(A::LILAC_DARK)) if on
        text(bmp, 148, 118 + i * 40, 216, 30, _INTL(key), 22, on ? A::YELLOW : A::TEXT)
      end
      @panel.visible = true
    end

    def draw_card
      bmp = @card.bitmap
      bmp.clear
      A.box(bmp, 76, 72, 360, 240, A::INK, A::LILAC, 3)
      A.confetti(bmp, @swaps)
      text(bmp, 76, 84, 360, 40, _INTL("SHIRA_SOLVED"), 30, A::YELLOW)
      text(bmp, 76, 132, 360, 26, _INTL("SHIRA_SWAPS", @swaps), 22)
      text(bmp, 76, 160, 360, 26, _INTL("SHIRA_MIN", R::MIN_SWAPS), 22)
      text(bmp, 76, 196, 360, 26, _INTL("SHIRA_SOLVED_PERFECT"), 22, A::YELLOW) if @swaps == R::MIN_SWAPS
      text(bmp, 76, 268, 360, 28, _INTL("SHIRA_CONTINUE"), 22, A::YELLOW)
      @card.visible = true
    end
  end
end
