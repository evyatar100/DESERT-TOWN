#===============================================================================
# Temple hoop - the free-throw screen: Red shoots, Blue quits (no count).
# 5 shots, then the end card; the BGM is never touched.
#===============================================================================

module TempleHoop
  class Scene
    R = TempleHoopRules
    BAR_X = 478
    BAR_W = 18
    BAR_TOP = 64
    BAR_H = 240
    PATH_COLORS = {
      short: [96, 96, 110], rim_front: [214, 140, 48], rim_in: [86, 176, 92], swish: [250, 214, 90],
      board_in: [86, 176, 92], rim_back: [214, 140, 48], long: [190, 60, 56]
    }.freeze
    MADE_COL = [232, 140, 56].freeze
    MISS_COL = [120, 120, 130].freeze
    TEXT = [248, 240, 224].freeze
    SHADOW = [24, 18, 28].freeze

    # [[upper edge, rgb], ...] bottom to top, edges taken from the rules' bands.
    def self.band_colors(bands = R::BANDS)
      bands.map { |limit, _, path| [limit, PATH_COLORS[path]] } + [[100, PATH_COLORS[:long]]]
    end

    # state: read only, for the end card's best.
    def initialize(state)
      @state = state
      @results = []
      @shot = 0
    end

    # {finished: true/false, made: count}
    def run
      create
      start_aim
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

    def made_count
      @results.count(true)
    end

    def update
      return finish(false) if @phase != :card && Input.trigger?(Input::BACK)
      case @phase
      when :aim then update_aim
      when :flight then update_flight
      when :card then update_card
      end
    end

    def start_aim
      @phase = :aim
      @aim_at = now
      @ball.x, @ball.y = R::BALL_START
      @ball.z = 40
      @ball.src_rect.x = 0
      @marker.y = bar_y(marker_value)
      refresh_ui
    end

    def marker_value
      R.meter(now - @aim_at, R::PERIODS[@shot])
    end

    def update_aim
      @marker.y = bar_y(marker_value)
      return nil unless Input.trigger?(Input::USE)
      @path = R.shot(marker_value)
      @release = now
      @sounds = R.sounds(@path)
      @popped = false
      @phase = :flight
      pbSEPlay("Battle throw")
      nil
    end

    def update_flight
      t = now - @release
      x, y, = R.ball_at(@path, t)
      @ball.x, @ball.y = x.round, y.round
      @ball.src_rect.x = ((t * 12).to_i % Art::BALL_FRAMES) * R::BALL_R * 2
      @ball.z = R.behind_front?(@path, t) ? (@front ? 20 : 5) : 40
      pbSEPlay(@sounds.shift[1]) while @sounds.any? && @sounds[0][0] <= t
      jiggle_net(t)
      if !@popped && t >= R::ARC_TIME
        @popped = true
        @results << R.made?(R::OUTCOME[@path])
        refresh_ui(R.word_key(R::OUTCOME[@path]))
      end
      refresh_ui if @popped && @pop_key && t >= R::ARC_TIME + R::POP_TIME
      next_shot if t >= [R.duration(@path) + R::NEXT_DELAY, R::ARC_TIME + R::POP_TIME].max
      nil
    end

    def jiggle_net(t)
      return unless @front
      wobble = R.net_jiggle?(@path) && t > R::ARC_TIME && t < R::ARC_TIME + 0.3
      @front.x = R::HOOP_ORIGIN[0] + (wobble ? ((t * 30).to_i.even? ? 1 : -1) : 0)
    end

    def next_shot
      @shot += 1
      return start_aim if @shot < R::SHOTS
      @phase = :card
      @card_at = now
      @card = R.card(@state, made_count)
      pbSEPlay(made_count == R::SHOTS ? "Mining found all" : "GUI sel decision")
      refresh_ui
    end

    def update_card
      return nil if now - @card_at < R::CARD_LOCK
      return finish(true) if Input.trigger?(Input::USE) || Input.trigger?(Input::BACK)
      nil
    end

    def finish(finished)
      { finished: finished, made: made_count }
    end

    #--- drawing ----------------------------------------------------------------
    def create
      @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
      # Same z as pbFadeOutIn's black layer but created later, so drawn above it.
      @viewport.z = 99_999
      @bg = sprite(Art.backdrop, 0)
      @hoop = sprite(Art.picture("hoop_big") || Art.placeholder_hoop, 10, *R::HOOP_ORIGIN)
      front = Art.picture("hoop_front")
      @front = front && sprite(front, 30, *R::HOOP_ORIGIN)
      @ball = sprite(Art.ball_frames, 40)
      @ball.src_rect.set(0, 0, R::BALL_R * 2, R::BALL_R * 2)
      @ball.ox = @ball.oy = R::BALL_R
      @bar = sprite(draw_bar, 50, BAR_X - 4, BAR_TOP - 4)
      @marker = sprite(draw_marker, 55, BAR_X - 10, 0)
      @marker.oy = 3
      @ui = sprite(Bitmap.new(Graphics.width, Graphics.height), 60)
      pbSetSystemFont(@ui.bitmap) if defined?(pbSetSystemFont)
    end

    def sprite(bitmap, z, x = 0, y = 0)
      s = Sprite.new(@viewport)
      s.bitmap = bitmap
      s.z = z
      s.x, s.y = x, y
      s
    end

    def col(rgb, alpha = 255)
      Art.color(rgb, alpha)
    end

    def bar_y(v)
      BAR_TOP + BAR_H - (v / 100.0 * BAR_H).round
    end

    def draw_bar
      bmp = Bitmap.new(BAR_W + 8, BAR_H + 8)
      bmp.fill_rect(0, 0, bmp.width, bmp.height, col(SHADOW))
      low = 0
      self.class.band_colors.each do |high, rgb|
        top = bar_y(high) - BAR_TOP + 4
        bmp.fill_rect(4, top, BAR_W, bar_y(low) - bar_y(high), col(rgb))
        low = high
      end
      bmp
    end

    def draw_marker
      bmp = Bitmap.new(BAR_W + 20, 7)
      bmp.fill_rect(0, 0, bmp.width, 7, col(SHADOW))
      bmp.fill_rect(1, 1, bmp.width - 2, 5, col(TEXT))
      bmp
    end

    def text(bmp, x, y, w, h, str, size, base = TEXT, align = 1)  # RGSS align: 1 = centre, 2 = right
      bmp.font.size = size
      pbDrawShadowText(bmp, x, y, w, h, str, col(base), col(SHADOW), align)
    end

    # pop_key: the make/miss word shown over the hall, nil for none.
    def refresh_ui(pop_key = nil)
      @pop_key = pop_key
      bmp = @ui.bitmap
      bmp.clear
      draw_dots(bmp)
      text(bmp, 420, 6, 80, 30, _INTL("HOOP_SHOT", [@shot + 1, R::SHOTS].min, R::SHOTS), 24, TEXT, 1)
      bmp.fill_rect(0, 356, bmp.width, 28, col(SHADOW, 200))
      text(bmp, 0, 356, bmp.width, 28, _INTL("HOOP_HINT"), 22)
      if pop_key
        text(bmp, 200, 96, 260, 56, _INTL(pop_key), 48, @results.last ? MADE_COL : MISS_COL)
      end
      draw_card(bmp) if @phase == :card
    end

    def draw_dots(bmp)
      R::SHOTS.times do |i|
        x = 290 + i * 24
        bmp.fill_rect(x, 14, 16, 16, col(SHADOW))
        rgb = @results[i].nil? ? nil : (@results[i] ? MADE_COL : MISS_COL)
        bmp.fill_rect(x + 2, 16, 12, 12, rgb ? col(rgb) : col(TEXT, 60))
      end
    end

    def draw_card(bmp)
      bmp.fill_rect(116, 112, 280, 150, col(TEXT))
      bmp.fill_rect(119, 115, 274, 144, col(SHADOW, 235))
      text(bmp, 116, 132, 280, 56, _INTL("HOOP_RESULT", @card[:made], @card[:of]), 44, MADE_COL)
      text(bmp, 116, 200, 280, 36, _INTL("HOOP_BEST", @card[:best]), 26) if @card[:best]
    end

    def dispose
      [@ui, @marker, @bar, @ball, @front, @hoop, @bg].each do |s|
        next if !s || s.disposed?
        s.bitmap.dispose if s.bitmap && !s.bitmap.disposed?
        s.dispose
      end
      @viewport.dispose if @viewport && !@viewport.disposed?
    end
  end
end
