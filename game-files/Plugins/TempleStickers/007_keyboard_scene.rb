#===============================================================================
# TempleStickers - on-screen keyboard (own scene; stock PokemonEntryScene2 is
# not edited). Joystick moves; Yellow types, Blue deletes (cancels when empty),
# Orange next tab, White space, Green done. Every action also has a grid cell.
#===============================================================================

module TempleStickers
  class KeyboardScene
    CELL_W = 36
    CELL_H = 38
    GRID_X = (512 - Keyboard::COLUMNS * CELL_W) / 2
    GRID_Y = 100

    # mask: true draws "*" per character (the staff code keyboard).
    def initialize(prompt, max, prefill = nil, mask: false)
      @prompt = prompt
      @mask = mask
      @buffer = TextBuffer.new(max, prefill)
      @tab = TempleStickers.hebrew?(prefill.to_s) || prefill.to_s.empty? ? :he : :lower
      @rows = Keyboard.rows(@tab)
      @row = 1
      @index = 0
    end

    # The typed text (logical order, stripped), or nil when cancelled.
    def run
      result = nil
      TempleStickers.silenced do
        create
        refresh
        loop do
          Graphics.update
          Input.update
          action = read_action
          next if action.nil?
          outcome = apply(action)
          if outcome == :cancel
            break
          elsif outcome == :done
            result = @buffer.result
            break
          end
          refresh
        end
      end
      result
    ensure
      dispose
    end

    def read_action
      return [:move, :left] if Input.repeat?(Input::LEFT)
      return [:move, :right] if Input.repeat?(Input::RIGHT)
      return [:move, :up] if Input.repeat?(Input::UP)
      return [:move, :down] if Input.repeat?(Input::DOWN)
      return [:press] if Input.trigger?(Input::USE)
      return [:token, :del] if Input.trigger?(Input::BACK)
      return [:token, :next_tab] if TempleStickers.raw_color?(:orange)
      return [:token, :space] if TempleStickers.raw_color?(:white)
      return [:token, :done] if TempleStickers.raw_color?(:green)
      nil
    end

    def apply(action)
      if action[0] == :move
        @row, @index = Keyboard.move(@rows, @row, @index, action[1])
        pbPlayCursorSE if defined?(pbPlayCursorSE)
        return nil
      end
      token = action[0] == :press ? @rows[@row][@index][0] : action[1]
      press(token)
    end

    def press(token)
      case token
      when :del
        return :cancel if @buffer.backspace == :cancel
      when :done
        return :done if @buffer.done?
        pbPlayBuzzerSE if defined?(pbPlayBuzzerSE)
      when :next_tab
        switch_tab(Keyboard.next_tab(@tab))
      when :tab_he, :tab_lower, :tab_upper
        switch_tab(token.to_s.sub("tab_", "").to_sym)
      else
        type(token == :space ? " " : token)
      end
      nil
    end

    def type(ch)
      outcome = @buffer.type(ch)
      if outcome == :rejected
        pbPlayBuzzerSE if defined?(pbPlayBuzzerSE)
      elsif outcome == :full
        @row, @index = Keyboard.find(@rows, :done)
      end
    end

    # Keeps the cursor on the same control cell, or the same row clamped.
    def switch_tab(tab)
      token = @rows[@row][@index][0]
      @tab = tab
      @rows = Keyboard.rows(tab)
      spot = token.is_a?(Symbol) ? Keyboard.find(@rows, token) : nil
      if spot
        @row, @index = spot
      else
        @row = [@row, @rows.length - 2].min
        @index = [@index, @rows[@row].length - 1].min
      end
    end

    def create
      @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
      # Equal z, created later: above the board and pbFadeOutIn's black layer.
      @viewport.z = 99_999
      @sprite = Sprite.new(@viewport)
      @sprite.bitmap = Bitmap.new(Graphics.width, Graphics.height)
      pbSetSystemFont(@sprite.bitmap) if defined?(pbSetSystemFont)
    end

    def label(token)
      case token
      when :tab_he then _INTL("TEMPLE_KB_TAB_HE")
      when :tab_lower then "abc"
      when :tab_upper then "ABC"
      when :space then _INTL("TEMPLE_KB_SPACE")
      when :del then _INTL("TEMPLE_KB_DEL")
      when :done then _INTL("TEMPLE_KB_DONE")
      else token
      end
    end

    def refresh
      bmp = @sprite.bitmap
      bmp.clear
      bmp.fill_rect(0, 0, bmp.width, bmp.height, Color.new(20, 16, 14))
      TempleStickers.draw_text(bmp, 16, 6, 480, 32, @prompt, TEXT_BASE, TEXT_SHADOW, 1)
      bmp.fill_rect(32, 44, 448, 40, TempleStickers.color(PAPER))
      shown = @mask ? "*" * @buffer.text.length : @buffer.text
      TempleStickers.draw_text(bmp, 42, 48, 428, 32, shown, INK, INK_SHADOW)
      @rows.each_with_index { |row, ri| draw_row(bmp, row, ri) }
      size = bmp.font.size
      bmp.font.size = [size - 6, 16].max
      TempleStickers.draw_text(bmp, 8, GRID_Y + @rows.length * CELL_H + 6, 496, 28,
                               _INTL("TEMPLE_KB_HINT"), TEXT_BASE, TEXT_SHADOW, 1)
      bmp.font.size = size
    end

    def draw_row(bmp, row, ri)
      y = GRID_Y + ri * CELL_H
      row.each_index do |ci|
        first, last = Keyboard.span(row, ci)
        x = GRID_X + first * CELL_W
        w = (last - first + 1) * CELL_W - 4
        token = row[ci][0]
        active_tab = token.to_s == "tab_#{@tab}"
        fill = active_tab ? Color.new(95, 154, 108) : Color.new(60, 50, 44)
        if ri == @row && ci == @index
          bmp.fill_rect(x - 2, y - 2, w + 4, CELL_H, Color.new(216, 138, 59))
        end
        bmp.fill_rect(x, y, w, CELL_H - 4, fill)
        TempleStickers.draw_text(bmp, x, y, w, CELL_H - 4, label(token), TEXT_BASE, TEXT_SHADOW, 1)
      end
    end

    def dispose
      @sprite.bitmap.dispose if @sprite && @sprite.bitmap && !@sprite.bitmap.disposed?
      @sprite.dispose if @sprite && !@sprite.disposed?
      @viewport.dispose if @viewport && !@viewport.disposed?
    end
  end
end
