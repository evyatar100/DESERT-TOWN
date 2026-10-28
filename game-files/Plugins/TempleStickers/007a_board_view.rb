#===============================================================================
# TempleStickers - board screen layout and drawing (no state, no input).
# Paper sheet pinned to the temple wall, depth tabs on its top edge, the hand
# tray on the right, an info box and a button legend under it.
# Background art: Graphics/Pictures/TempleStickers/board_bg.png (drawn if missing).
#===============================================================================

module TempleStickers
  module BoardView
    BG_FILE = "Graphics/Pictures/TempleStickers/board_bg"
    PAPER_RECT = [14, 60, 408, 240].freeze
    GRID_X = 22
    GRID_Y = 68
    CELL = 56
    HALF = CELL / 2   # one spot step: stickers move half a sticker per press
    TRAY_RECT = [430, 60, 70, 240].freeze
    SLOT = 52
    SLOT_X = 439
    HAND_Y = 86
    HAND_STEP = 53
    HAND_SLOTS = 4
    INFO_RECT = [14, 306, 486, 46].freeze
    LEGEND_Y = 357
    TAB_X = 14
    TAB_Y = 38
    TAB_W = 76
    TAB_GAP = 4
    TABS_SHOWN = 5
    SMALL = 21
    WALL = [34, 25, 29].freeze
    OUTLINE = [32, 22, 21].freeze
    TAB_IDLE = [196, 186, 162].freeze
    PANEL = [22, 17, 18].freeze
    PANEL_EDGE = [70, 52, 48].freeze
    SLOT_FILL = [40, 32, 32].freeze
    BAND = [12, 9, 10].freeze
    DIM = [150, 140, 122].freeze
    LABEL = [248, 216, 104].freeze
    BUTTONS = { yellow: [232, 196, 64], blue: [79, 114, 184], orange: [216, 138, 59],
                white: [242, 236, 220], green: [95, 154, 108], pink: [214, 112, 196] }.freeze
    @bg = nil
    @bg_checked = false

    def self.c(rgb) = TempleStickers.color(rgb)

    def self.sized(bmp, size)
      old = bmp.font.size
      bmp.font.size = size
      yield
    ensure
      bmp.font.size = old
    end

    def self.background
      return @bg if @bg && !@bg.disposed?
      return nil if @bg_checked
      @bg_checked = true
      file = pbResolveBitmap(BG_FILE)
      @bg = file ? Bitmap.new(file) : nil
    rescue StandardError
      @bg = nil
    end

    def self.outline(bmp, x, y, w, h, rgb, t = 1)
      col = c(rgb)
      bmp.fill_rect(x, y, w, t, col)
      bmp.fill_rect(x, y + h - t, w, t, col)
      bmp.fill_rect(x, y, t, h, col)
      bmp.fill_rect(x + w - t, y, t, h, col)
    end

    def self.panel(bmp, rect, fill, edge)
      bmp.fill_rect(*rect, c(fill))
      outline(bmp, *rect, edge)
    end

    def self.disc(bmp, cx, cy, r, rgb)
      col = c(rgb)
      (-r...r).each do |dy|
        half = Math.sqrt(r * r - (dy + 0.5)**2).round
        bmp.fill_rect(cx - half, cy + dy, half * 2, 1, col)
      end
    end

    # The art file holds wall, paper, pins, tray, info box and legend band.
    def self.draw_background(bmp)
      bg = background
      return bmp.blt(0, 0, bg, bg.rect) if bg
      bmp.fill_rect(0, 0, bmp.width, bmp.height, c(WALL))
      panel(bmp, PAPER_RECT, PAPER, OUTLINE)
      panel(bmp, TRAY_RECT, PANEL, PANEL_EDGE)
      panel(bmp, INFO_RECT, PANEL, PANEL_EDGE)
      bmp.fill_rect(0, LEGEND_Y - 3, bmp.width, bmp.height - LEGEND_Y + 3, c(BAND))
    end

    def self.draw_title(bmp, title)
      TempleStickers.draw_text(bmp, 14, 2, 486, 34, title, TEXT_BASE, TEXT_SHADOW)
    end

    # The selected tab joins the paper; mine gets a green bar; focus = orange edge.
    def self.draw_tabs(bmp, labels, sel, mine, focused)
      first = [[sel - TABS_SHOWN / 2, labels.length - TABS_SHOWN].min, 0].max
      sized(bmp, SMALL) do
        TempleStickers.draw_text(bmp, 0, TAB_Y, 14, 22, "<", TEXT_BASE, TEXT_SHADOW, 1) if first > 0
        if first + TABS_SHOWN < labels.length
          TempleStickers.draw_text(bmp, 416, TAB_Y, 14, 22, ">", TEXT_BASE, TEXT_SHADOW, 1)
        end
        [TABS_SHOWN, labels.length - first].min.times do |slot|
          i = first + slot
          draw_tab(bmp, TAB_X + slot * (TAB_W + TAB_GAP), labels[i], i == sel, i == mine, focused)
        end
      end
    end

    def self.draw_tab(bmp, x, label, selected, mine, focused)
      y = selected ? TAB_Y - 3 : TAB_Y
      h = PAPER_RECT[1] - y + (selected ? 1 : 0)
      bmp.fill_rect(x, y, TAB_W, h, c(selected ? PAPER : TAB_IDLE))
      bmp.fill_rect(x, y, TAB_W, 1, c(OUTLINE))
      bmp.fill_rect(x, y, 1, h, c(OUTLINE))
      bmp.fill_rect(x + TAB_W - 1, y, 1, h, c(OUTLINE))
      bmp.fill_rect(x + 3, y + 3, TAB_W - 6, 3, c(BUTTONS[:green])) if mine
      if selected && focused
        bmp.fill_rect(x - 2, y - 2, TAB_W + 4, 2, c(BUTTONS[:orange]))
        bmp.fill_rect(x - 2, y - 2, 2, h + 2, c(BUTTONS[:orange]))
        bmp.fill_rect(x + TAB_W, y - 2, 2, h + 2, c(BUTTONS[:orange]))
      end
      TempleStickers.draw_text(bmp, x + 2, y + 4, TAB_W - 4, h - 4, label, INK, INK_SHADOW, 1)
    end

    def self.spot_origin(spot)
      [GRID_X + (spot % SPOT_COLS) * HALF, GRID_Y + (spot / SPOT_COLS) * HALF]
    end

    def self.draw_sticker(bmp, sticker, spot, opacity = 255)
      src = Art.bitmap(sticker)
      x, y = spot_origin(spot)
      pad = (CELL - Art::SIZE) / 2
      bmp.blt(x + pad, y + pad, src, src.rect, opacity)
    end

    def self.draw_cursor(bmp, spot, rgb)
      x, y = spot_origin(spot)
      outline(bmp, x, y, CELL, CELL, rgb, 2)
    end

    # Fresh board: two centred lines on the paper.
    def self.draw_empty(bmp, lines)
      x, y, w, h = PAPER_RECT
      top = y + (h - lines.length * 30) / 2
      lines.each_with_index do |line, i|
        TempleStickers.draw_text(bmp, x + 16, top + i * 30, w - 32, 30, line, INK, INK_SHADOW, 1)
      end
    end

    # Always 4 slots, so an empty slot reads as "room for one more".
    # The scene passes only this board's stickers (at most 3).
    def self.draw_hand(bmp, title, hand, selected, empty_note)
      x, y, w = TRAY_RECT
      sized(bmp, SMALL) { TempleStickers.draw_text(bmp, x, y + 2, w, 22, title, LABEL, TEXT_SHADOW, 1) }
      HAND_SLOTS.times do |i|
        sy = HAND_Y + i * HAND_STEP
        bmp.fill_rect(SLOT_X, sy, SLOT, SLOT, c(SLOT_FILL))
        next unless hand[i]
        src = Art.bitmap(hand[i])
        bmp.blt(SLOT_X + 2, sy + 2, src, src.rect)
        outline(bmp, SLOT_X - 2, sy - 2, SLOT + 4, SLOT + 4, BUTTONS[:orange], 2) if i == selected
      end
      draw_wrapped(bmp, empty_note, x + 4, HAND_Y + 8, w - 8, DIM) if hand.empty? && empty_note
    end

    def self.draw_wrapped(bmp, text, x, y, w, rgb)
      sized(bmp, SMALL) do
        lines = []
        text.split(" ").each do |word|
          trial = lines.empty? ? word : "#{lines.last} #{word}"
          if !lines.empty? && bmp.text_size(trial).width <= w
            lines[-1] = trial
          else
            lines << word
          end
        end
        lines.each_with_index do |line, i|
          TempleStickers.draw_text(bmp, x, y + i * 22, w, 22, line, rgb, TEXT_SHADOW, 1)
        end
      end
    end

    # Overlapping stickers: a row of labels (newest first) over the picked one's sentence.
    # Labels share the width; Hebrew runs from the right edge.
    def self.draw_stack_info(bmp, labels, pick, main)
      x, y, w = INFO_RECT
      rtl = labels.any? { |l| TempleStickers.hebrew?(l) }
      slot = (w - 16) / labels.length
      sized(bmp, SMALL) do
        labels.each_with_index do |label, i|
          lx = rtl ? x + w - 8 - (i + 1) * slot : x + 8 + i * slot
          rgb = i == pick ? LABEL : DIM
          TempleStickers.draw_text(bmp, lx, y + 1, slot - 6, 22, label, rgb, TEXT_SHADOW, rtl ? 2 : 0)
        end
      end
      sized(bmp, 24) { TempleStickers.draw_text(bmp, x + 8, y + 20, w - 16, 26, main.to_s, TEXT_BASE, TEXT_SHADOW) }
    end

    # top: small label line (may be nil); main: the sentence line.
    def self.draw_info(bmp, top, main, top_rgb = LABEL)
      x, y, w = INFO_RECT
      if top && !top.empty?
        sized(bmp, SMALL) { TempleStickers.draw_text(bmp, x + 8, y + 1, w - 16, 22, top, top_rgb, TEXT_SHADOW) }
        sized(bmp, 24) { TempleStickers.draw_text(bmp, x + 8, y + 20, w - 16, 26, main.to_s, TEXT_BASE, TEXT_SHADOW) }
      else
        sized(bmp, 24) { TempleStickers.draw_text(bmp, x + 8, y + 10, w - 16, 26, main.to_s, TEXT_BASE, TEXT_SHADOW) }
      end
    end

    def self.icon(bmp, kind, cx, cy)
      if kind == :joy
        disc(bmp, cx, cy, 7, DIM)
        disc(bmp, cx, cy, 4, BAND)
        disc(bmp, cx, cy, 2, DIM)
      else
        disc(bmp, cx, cy, 7, OUTLINE)
        disc(bmp, cx, cy, 6, BUTTONS[kind])
      end
    end

    # entries: [[:yellow, "label"], ...]. Hebrew runs right to left from the right edge.
    def self.draw_legend(bmp, entries)
      sized(bmp, SMALL) do
        rtl = entries.any? { |_, label| TempleStickers.hebrew?(label) }
        x = rtl ? 500 : 14
        entries.each do |kind, label|
          w = bmp.text_size(label).width + 4
          if rtl
            icon(bmp, kind, x - 7, LEGEND_Y + 13)
            TempleStickers.draw_text(bmp, x - 20 - w, LEGEND_Y, w, 26, label, TEXT_BASE, TEXT_SHADOW, 2)
            x -= 20 + w + 16
          else
            icon(bmp, kind, x + 7, LEGEND_Y + 13)
            TempleStickers.draw_text(bmp, x + 20, LEGEND_Y, w, 26, label, TEXT_BASE, TEXT_SHADOW, 0)
            x += 20 + w + 16
          end
        end
      end
    end
  end
end
