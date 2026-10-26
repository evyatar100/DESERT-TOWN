#===============================================================================
# Bags - the song overlay: karaoke lyrics in the bottom band, sticker rain in the
# side gutters, and Esther, Shirpaz and the duo badge pinned at the top during
# every chorus. Screen space above the map; Bags::Song shows, ticks and hides it.
#===============================================================================

module Bags
  module Song
    STICKER_DIR = "Graphics/Pictures/SakiyotSong/"
    BADGE = "duo_friends_badge"
    HEAVY_RE = /esther|shirpaz|duo/   # unicorn and duo stickers fall 3x as often
  end
end

class Bags::Song::Overlay
  R = BagsRules
  PANEL_Y = R::PANEL_TOP
  PANEL_H = 96
  MARGIN = 12
  MAX_W = 488
  YELLOW = [255, 228, 92].freeze
  WHITE = [255, 255, 255].freeze
  OUTLINE = [36, 12, 44].freeze
  PANEL_BG = [52, 22, 78, 190].freeze
  PINK = [255, 110, 190].freeze
  SHAPE_COLORS = [[255, 120, 200], [170, 90, 230]].freeze

  def initialize(timing)
    @lines = timing[:lines]
    @rng = Random.new
    @stickers = []
    @frame = 0
    @shown = nil
    @kind = nil
    @pins_on = false
    @pin_t = R::PIN_POP
    @t = 0.0
    @char_xs = []
    create
  rescue StandardError
    dispose
    raise
  end

  # t: song time in seconds; char_xs: screen x of the player and the duo (rain avoids them).
  # While hidden nothing moves; the lyrics catch up on return.
  def update(t, visible, char_xs = [])
    @viewport.visible = visible
    return unless visible
    @frame += 1
    @t = t
    @char_xs = char_xs
    idx = R.line_at(@lines, t)
    word = idx ? R.word_at(@lines[idx], t) : nil
    section = R.section_at(@lines, t)
    level = R.intensity(section)
    @kind = R.section_kind(section)
    if [idx, word] != @shown
      burst if idx && word && word >= 0 && @kind == :chorus && sakiyot?(idx, word)
      @shown = [idx, word]
      redraw(idx, word)
    end
    update_pulse(idx, word, t)
    spawn if (@frame % R.rain_every(level)).zero?
    move_stickers(level[:speed])
    update_pins(@kind == :chorus)
  end

  def dispose
    @stickers.each { |sp, _| sp.dispose unless sp.disposed? }
    @stickers.clear
    (@pins || []).each { |sp, _| sp.dispose unless sp.disposed? }
    [@panel, @lyric, @pulse].each do |sp|
      next unless sp
      sp.bitmap.dispose if sp.bitmap && !sp.bitmap.disposed?
      sp.dispose unless sp.disposed?
    end
    (@art || []).each { |b, _, _| b.dispose unless b.disposed? }
    (@shapes || []).each { |b| b.dispose unless b.disposed? }
    @viewport.dispose if @viewport && !@viewport.disposed?
  end

  private

  def color(rgb)
    Color.new(*rgb)
  end

  def create
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99_999
    @panel = Sprite.new(@viewport)
    @panel.bitmap = Bitmap.new(Graphics.width, PANEL_H)
    @panel.bitmap.fill_rect(0, 0, Graphics.width, PANEL_H, color(PANEL_BG))
    @panel.bitmap.fill_rect(0, 0, Graphics.width, 2, color(PINK))
    @panel.y = PANEL_Y
    @panel.z = 10
    @lyric = Sprite.new(@viewport)
    @lyric.bitmap = Bitmap.new(Graphics.width, PANEL_H)
    @lyric.y = PANEL_Y
    @lyric.z = 11
    @pulse = Sprite.new(@viewport)
    @pulse.z = 12
    @art = load_art
    @shapes = make_shapes
    @pins = make_pins
  end

  # [bitmap, weight, name] for each sticker PNG that loads; a bad file is skipped alone.
  def load_art
    paths = (Dir.glob(Bags::Song::STICKER_DIR + "*.png").sort rescue [])
    paths.filter_map do |path|
      name = File.basename(path, ".png")
      [Bitmap.new(path), name.match?(Bags::Song::HEAVY_RE) ? 3 : 1, name]
    rescue StandardError => e
      echoln("[Bags] sticker #{name} skipped: #{e.message}")
      nil
    end
  end

  # Fallback art: pink and purple star, heart and circle.
  def make_shapes
    %i[star heart circle].product(SHAPE_COLORS).map do |shape, rgb|
      bmp = Bitmap.new(48, 48)
      c = color(rgb)
      48.times do |y|
        48.times do |x|
          bmp.set_pixel(x, y, c) if shape_hit?(shape, x - 24, y - 24)
        end
      end
      bmp
    end
  end

  def shape_hit?(shape, dx, dy)
    case shape
    when :circle then dx * dx + dy * dy <= 400
    when :heart
      x = dx / 18.0
      y = -dy / 18.0
      (x * x + y * y - 1)**3 - x * x * y**3 <= 0
    else
      ang = Math.atan2(dy, dx)
      dx * dx + dy * dy <= (14 + 8 * Math.cos(5 * ang))**2
    end
  end

  #---------------------------------------------------------------------------
  # Chorus pins: pop in at the chorus start, sway and tilt, pop out at its end
  #---------------------------------------------------------------------------

  # [[sprite, [name, x, y, size], base zoom, phase], ...]; a missing PNG uses a shape.
  def make_pins
    R.chorus_pins.each_with_index.map do |pin, i|
      name, x, y, size = pin
      hit = @art.find { |_, _, n| n == name }
      bmp = hit ? hit[0] : @shapes[i % @shapes.length]
      sp = Sprite.new(@viewport)
      sp.bitmap = bmp
      sp.ox = bmp.width / 2
      sp.oy = bmp.height / 2
      sp.x = x
      sp.y = y
      sp.z = 5
      sp.visible = false
      [sp, pin, size.to_f / [bmp.width, bmp.height].max, i * 2.1]
    end
  end

  def update_pins(on)
    if on != @pins_on
      @pins_on = on
      @pin_t = R::PIN_POP - [@pin_t, R::PIN_POP].min   # a pop reversed midway continues from there
    end
    @pin_t += 1
    zoom = R.pin_zoom(@pin_t, @pins_on)
    @pins.each do |sp, (name, x, _, _), base, phase|
      sp.visible = zoom > 0
      next unless sp.visible
      sp.zoom_x = sp.zoom_y = base * zoom
      sp.x = x + Math.sin(@frame * 0.05 + phase) * R::PIN_SWAY
      sp.angle = Math.sin(@frame * 0.04 + phase) * R::PIN_TILT
      sp.tone = rainbow if name == Bags::Song::BADGE
    end
  end

  # The badge's tone cycles through the rainbow for the whole chorus.
  def rainbow
    hue = @frame * 12
    Tone.new(Math.sin(hue * 0.0174) * 80, Math.sin((hue + 120) * 0.0174) * 80,
             Math.sin((hue + 240) * 0.0174) * 80, 0)
  end

  #---------------------------------------------------------------------------
  # Rain in the gutters
  #---------------------------------------------------------------------------

  def sakiyot?(idx, word)
    R.sakiyot_word?(@lines[idx][:words][word][:w])
  end

  def pick_art
    pool = @art.reject { |_, _, name| name == Bags::Song::BADGE }
    return @shapes[@rng.rand(@shapes.length)] if pool.empty?
    roll = @rng.rand(pool.sum { |_, w, _| w })
    pool.each do |bmp, w, _|
      return bmp if roll < w
      roll -= w
    end
    pool.last[0]
  end

  def add_sticker(bmp, size)
    return if @stickers.length >= R::MAX_STICKERS
    s = R.spawn_sticker(@rng, size, R.open_gutters(@char_xs))
    return unless s
    sp = Sprite.new(@viewport)
    sp.bitmap = bmp
    sp.ox = bmp.width / 2
    sp.oy = bmp.height / 2
    sp.zoom_x = sp.zoom_y = size.to_f / [bmp.width, bmp.height].max
    sp.z = 1
    sp.visible = false
    @stickers << [sp, s]
  end

  def spawn
    add_sticker(pick_art, R::RAIN_SIZES.min + @rng.rand(R::RAIN_SIZES.size))
  end

  # Chorus: a few small stars on every "שַׂקִּיּוֹת", into the gutters like the rain.
  def burst
    4.times { add_sticker(@shapes[@rng.rand(2)], R::BURST_SIZES.min + @rng.rand(R::BURST_SIZES.size)) }
  end

  def move_stickers(speed)
    @stickers.reject! do |sp, s|
      alive = R.step_sticker(s, speed)
      if alive
        sp.x = s[:dx]
        sp.y = s[:dy]
        sp.angle = s[:angle]
        sp.visible = true
      else
        sp.dispose
      end
      !alive
    end
  end

  #---------------------------------------------------------------------------
  # Lyrics: words placed right to left, each drawn cluster-reversed
  #---------------------------------------------------------------------------

  def words_of(line)
    line[:words] ? line[:words].map { |w| w[:w] } : line[:text].split(" ")
  end

  def set_font(bmp, size)
    pbSetSystemFont(bmp) if defined?(pbSetSystemFont)
    bmp.font.size = size
    bmp.font.outline = true if bmp.font.respond_to?(:outline=)
    bmp.font.out_color = color(OUTLINE) if bmp.font.respond_to?(:out_color=)
  end

  # Lays out one line; returns [[word index, x, y, w, h], ...] and the row count.
  def layout(bmp, vis, size, wrap, top)
    widths, space = measure(bmp, vis, size)
    rows = wrap ? R.wrap_rows(widths, space, MAX_W) : [(0...vis.length).to_a]
    row_h = size + 4
    boxes = []
    rows.each_with_index do |row, r|
      xs = R.word_positions(row.map { |i| widths[i] }, space, Graphics.width - MARGIN)
      row.each_with_index { |i, k| boxes << [i, xs[k], top + r * row_h, widths[i], row_h] }
    end
    [boxes, rows.length]
  end

  def draw_words(bmp, vis, boxes, &colour_for)
    boxes.each do |i, x, y, w, h|
      bmp.font.color = colour_for.call(i)
      bmp.draw_text(x, y, w + 8, h, vis[i])
    end
  end

  def redraw(idx, word)
    bmp = @lyric.bitmap
    bmp.clear
    @pulse_box = nil
    nxt = idx ? idx + 1 : R.next_line(@lines, @t)
    rows = 0
    if idx
      line = @lines[idx]
      vis = words_of(line).map { |w| R.cluster_reverse(w) }
      size, wrap = R.font_plan(MAX_W) { |s| measure(bmp, vis, s) }
      boxes, rows = layout(bmp, vis, size, wrap, rows_top(wrap))
      sung = ->(i) { line[:words].nil? || i <= word }
      draw_words(bmp, vis, boxes) { |i| color(sung.call(i) ? YELLOW : WHITE) }
      @pulse_box = [boxes.find { |b| b[0] == word }, vis[word], size] if line[:words] && word && word >= 0
    end
    draw_preview(bmp, @lines[nxt]) if nxt && @lines[nxt] && rows < 2
  end

  def rows_top(wrap)
    wrap ? 6 : 12
  end

  # [word widths, space width] at one font size, for BagsRules.font_plan / preview_plan.
  def measure(bmp, vis, size)
    set_font(bmp, size)
    [vis.map { |v| bmp.text_size(v).width }, bmp.text_size(" ").width]
  end

  # One faded row at <= 18 px; shrinks to fit MAX_W, and only drops words at 12 px.
  def draw_preview(bmp, line)
    vis = words_of(line).map { |w| R.cluster_reverse(w) }
    size, count = R.preview_plan(MAX_W) { |s| measure(bmp, vis, s) }
    vis = vis.first(count)
    boxes, = layout(bmp, vis, size, false, 52)
    faded = Color.new(*WHITE, 128)
    draw_words(bmp, vis, boxes) { faded }
  end

  # The current word swells to 1.1x while it is sung.
  def update_pulse(idx, word, t)
    box, vis, size = @pulse_box
    live = box && idx && t < @lines[idx][:words][word][:end]
    @pulse.visible = !!live
    return unless live
    if @pulse_key != [idx, word]
      @pulse_key = [idx, word]
      @pulse.bitmap.dispose if @pulse.bitmap && !@pulse.bitmap.disposed?
      @pulse.bitmap = Bitmap.new(box[3] + 8, box[4])
      set_font(@pulse.bitmap, size)
      @pulse.bitmap.font.color = color(YELLOW)
      @pulse.bitmap.draw_text(0, 0, box[3] + 8, box[4], vis)
      @pulse.ox = box[3] / 2
      @pulse.oy = box[4] / 2
      @pulse.x = box[1] + box[3] / 2
      @pulse.y = PANEL_Y + box[2] + box[4] / 2
    end
    z = 1.0 + 0.1 * Math.sin(@frame * 0.3).abs
    @pulse.zoom_x = @pulse.zoom_y = z
  end
end
