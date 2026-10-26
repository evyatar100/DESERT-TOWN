#===============================================================================
# TempleStickers - keyboard layout, cursor moves and text buffer (no engine).
# No digits and no @ on any tab: a cheap guard against phone numbers/emails.
#===============================================================================

module TempleStickers
  module Keyboard
    COLUMNS = 13
    TABS = [:he, :lower, :upper].freeze
    HEBREW = %w[א ב ג ד ה ו ז ח ט י כ ל מ נ ס ע פ צ ק ר ש ת].freeze
    FINALS = %w[ך ם ן ף ץ].freeze
    PUNCT = [".", ",", "?", "!", "'", "-", "׳"].freeze
    TAB_ROW = [[:tab_he, 4], [:tab_lower, 5], [:tab_upper, 4]].freeze
    CONTROL_ROW = [[:space, 5], [:del, 4], [:done, 4]].freeze

    def self.cells(chars)
      chars.map { |c| [c, 1] }
    end

    # Hebrew rows are stored in screen order, so alef sits on the right.
    def self.char_rows(tab)
      case tab
      when :he
        [cells(HEBREW[0, 11].reverse), cells(HEBREW[11, 11].reverse), cells(FINALS.reverse), cells(PUNCT)]
      when :upper
        [cells(("A".."M").to_a), cells(("N".."Z").to_a), cells(PUNCT)]
      else
        [cells(("a".."m").to_a), cells(("n".."z").to_a), cells(PUNCT)]
      end
    end

    # Row 0 is the tab row; the last row is space / delete / done.
    def self.rows(tab)
      [TAB_ROW] + char_rows(tab) + [CONTROL_ROW]
    end

    ALLOWED = (HEBREW + FINALS + PUNCT + ("a".."z").to_a + ("A".."Z").to_a + [" "]).freeze

    def self.allowed_char?(ch)
      ALLOWED.include?(ch)
    end

    # Column span [first, last] of a cell; rows are centred on the 13 columns.
    def self.span(row, index)
      offset = (COLUMNS - row.sum { |c| c[1] }) / 2
      first = offset + row[0, index].sum { |c| c[1] }
      [first, first + row[index][1] - 1]
    end

    def self.index_at_column(row, column)
      best = 0
      best_dist = nil
      row.each_index do |i|
        a, b = span(row, i)
        return i if column.between?(a, b)
        dist = [(a - column).abs, (b - column).abs].min
        if best_dist.nil? || dist < best_dist
          best = i
          best_dist = dist
        end
      end
      best
    end

    # Returns the new [row, index]; every edge wraps.
    def self.move(rows, row, index, dir)
      case dir
      when :left  then [row, (index - 1) % rows[row].length]
      when :right then [row, (index + 1) % rows[row].length]
      when :up, :down
        a, b = span(rows[row], index)
        target = (row + (dir == :up ? -1 : 1)) % rows.length
        [target, index_at_column(rows[target], (a + b) / 2)]
      else [row, index]
      end
    end

    def self.find(rows, token)
      rows.each_with_index do |r, ri|
        ci = r.index { |c| c[0] == token }
        return [ri, ci] if ci
      end
      nil
    end

    def self.next_tab(tab)
      TABS[(TABS.index(tab).to_i + 1) % TABS.length]
    end

    # Drops characters the keyboard cannot type, then caps the length.
    def self.sanitize(text, max)
      text.to_s.dup.force_encoding("UTF-8").chars.select { |c| allowed_char?(c) }.first(max).join
    end
  end

  # Text being typed, in logical order (drawing handles RTL).
  class TextBuffer
    attr_reader :text, :max

    def initialize(max, prefill = nil)
      @max = max
      @text = Keyboard.sanitize(prefill, max)
    end

    # :typed, :full (at the cap after this char or already) or :rejected.
    def type(ch)
      return :rejected unless Keyboard.allowed_char?(ch)
      return :full if full?
      @text += ch
      full? ? :full : :typed
    end

    # :deleted, or :cancel on an empty field.
    def backspace
      return :cancel if @text.empty?
      @text = @text[0...-1]
      :deleted
    end

    def full?
      @text.length >= @max
    end

    def done?
      !@text.strip.empty?
    end

    def result
      @text.strip
    end
  end
end
