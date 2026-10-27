#===============================================================================
# Planetarium - the narration crawl. One sprite per text row; rows rise into the
# band, then recede upward (smaller, dimmer). Text comes only from the timing file.
# Word mode: spoken words full gold over a 70% copy (a mask sprite per row).
#===============================================================================

module Planet
  class Crawl
    R = PlanetRules
    W = 512
    GOLD = [255, 232, 160].freeze
    OUTLINE = [28, 18, 34].freeze
    PAD = 3

    attr_reader :chunks

    def initialize(viewport, timing)
      @vp = viewport
      @lines = timing[:lines]
      @words = @lines.map { |l| l[:text].split(" ") }
      @slots = {}
      @measure = Bitmap.new(16, 16)
      @chunks = R.build_chunks(@lines) { |li, size| measure(@words[li], size) }
    rescue StandardError
      @measure&.dispose
      raise
    end

    def update(t)
      active, receding = R.crawl_at(@chunks, t)
      (@slots.keys - [active, receding]).each { |i| drop(i) }
      place(active, t, nil) if active
      place(receding, t, t - @chunks[receding][:leave]) if receding
    end

    def dispose
      @slots.keys.each { |i| drop(i) }
      @measure.dispose unless @measure.disposed?
    end

    # The text of every row the crawl will ever draw, per line (tests: equals the narration).
    def row_texts
      @chunks.map { |c| [c[:line], c[:rows].map { |r| r.map { |i| @words[c[:line]][i] }.join(" ") }] }
    end

    private

    def col(rgb, mul = 1.0)
      Color.new((rgb[0] * mul).round, (rgb[1] * mul).round, (rgb[2] * mul).round)
    end

    def set_font(bmp, size)
      pbSetSystemFont(bmp) if defined?(pbSetSystemFont)
      bmp.font.size = size
    end

    def measure(words, size)
      set_font(@measure, size)
      [words.map { |w| @measure.text_size(w).width }, @measure.text_size(" ").width]
    end

    def place(i, t, recede_age)
      c = @chunks[i]
      rows = (@slots[i] ||= build(c))
      rh = R.row_h(c[:size])
      top = R.chunk_top(rows.length, c[:size])
      cy = top + rows.length * rh / 2.0
      if recede_age
        shift, zoom, opacity = R.recede(recede_age)
        dy = -shift
      else
        dy = R.rise_offset(t - c[:start])
        zoom = 1.0
        opacity = 255
      end
      refresh_masks(rows, R.word_at(@lines[c[:line]], t))
      rows.each_with_index do |row, r|
        y = (cy + (top + r * rh + rh / 2.0 - cy) * zoom + dy).round
        row[:sprites].each do |s|
          s.y = y
          s.zoom_x = s.zoom_y = zoom
          s.opacity = opacity
        end
      end
    end

    def refresh_masks(rows, spoken)
      return if spoken.nil?
      rows.each do |row|
        next if row[:spoken] == spoken
        row[:spoken] = spoken
        mask = row[:mask].bitmap
        mask.clear
        row[:spans].each do |gid, x0, x1|
          next if gid > spoken || x0.nil?
          src = Rect.new(x0 - PAD, 0, x1 - x0 + 2 * PAD, mask.height)
          mask.blt(x0 - PAD, 0, row[:bright], src)
        end
      end
    end

    def build(c)
      words = @words[c[:line]]
      rh = R.row_h(c[:size])
      c[:rows].map do |ids|
        text = ids.map { |k| words[k] }.join(" ")
        dim = row_bitmap(text, c[:size], rh, c[:line_mode] ? 1.0 : R::DIM)
        row = { sprites: [row_sprite(dim, 1, rh)], spoken: nil }
        unless c[:line_mode]
          row[:bright] = row_bitmap(text, c[:size], rh, 1.0)
          row[:spans] = spans(row[:bright], text, ids)
          row[:mask] = row_sprite(Bitmap.new(W, rh + 4), 2, rh)
          row[:sprites] << row[:mask]
        end
        row
      end
    end

    def row_bitmap(text, size, rh, mul)
      bmp = Bitmap.new(W, rh + 4)
      set_font(bmp, size)
      pbDrawOutlineText(bmp, 0, 2, W, rh, text, col(GOLD, mul), col(OUTLINE), 1)
      bmp
    end

    def row_sprite(bmp, z, rh)
      s = Sprite.new(@vp)
      s.bitmap = bmp
      s.z = 100 + z
      s.ox = W / 2
      s.oy = (rh + 4) / 2
      s.x = W / 2
      s.y = 999
      s
    end

    # [[global word index, left x, right x], ...] where each word lands after the
    # bidi reorder pbDrawOutlineText applies (HebrewText.visual_reverse).
    def spans(bmp, text, ids)
      order = self.class.visual_order(text)
      chars = HebrewText.clusters(text)
      word_of = []
      w = 0
      chars.each do |ch|
        word_of << (ch == " " ? nil : w)
        w += 1 if ch == " "
      end
      visual = order.map { |k| chars[k] }
      xs = (0..visual.length).map { |k| bmp.text_size(visual[0, k].join).width }
      left = (W - xs[-1]) / 2
      box = {}
      order.each_with_index do |li, k|
        wi = word_of[li]
        next if wi.nil?
        x0, x1 = left + xs[k], left + xs[k + 1]
        box[wi] = box[wi] ? [[box[wi][0], x0].min, [box[wi][1], x1].max] : [x0, x1]
      end
      ids.each_with_index.map { |gid, local| [gid, *(box[local] || [nil, nil])] }
    end

    # Logical cluster index at each visual position: the same reorder as HebrewText.visual_reverse.
    def self.visual_order(text)
      chars = HebrewText.clusters(text)
      return (0...chars.length).to_a unless text.match?(HebrewText::HEBREW_RANGE)
      runs = HebrewText.bidi_runs(HebrewText.bidi_ltr_flags(chars.map { |ch| HebrewText.bidi_class(ch) }))
      runs.reverse.flat_map do |ltr, start, len|
        idx = (start...start + len).to_a
        ltr ? idx : idx.reverse
      end
    end

    def drop(i)
      (@slots.delete(i) || []).each do |row|
        row[:sprites].each do |s|
          s.bitmap.dispose if s.bitmap && !s.bitmap.disposed?
          s.dispose unless s.disposed?
        end
        row[:bright].dispose if row[:bright] && !row[:bright].disposed?
      end
    end
  end
end
