#===============================================================================
# TempleStickers - board screen. One tab per Inception depth, oldest depth on
# the left. You stick only on the current depth's tab; every other tab is
# read-only. Opens on the current depth's tab.
#   strip: left/right flips tabs, down enters the page
#   page:  the cursor steps over stickers; the bottom box shows name + sentence
#   place: Orange picks a hand sticker, Red jumps to your tab, Red sticks it
#   White + Green together: staff code keyboard (works with an empty hand)
#===============================================================================

module TempleStickers
  class BoardScene
    PAGE_X = 8
    PAGE_Y = 44
    CELL = 64
    HAND_X = 460
    STRIP_MARKS = 5
    MARK_W = 88

    attr_reader :placed_any

    def initialize(board)
      @board = board.to_s
      @dir = TempleStickers.data_dir
      @run = TempleStickers.run
      @depth = TempleStickers.depth
      @wall = WallStore.load(@dir)
      @placed_any = false
      @mode = :strip
      @item = 0
      @cell = 0
      @hand = 0
      refresh_pages
      @page = target_index
    end

    def run_id
      @run[:run_id]
    end

    # Stored pages plus the current depth's writable page if it is not stored yet.
    def refresh_pages
      @target = WallStore.target(@wall, @board, @depth)
      stored = WallStore.pages(@wall, @board)
      list = stored.any? { |p| p.equal?(@target) } ? stored.dup : stored + [@target]
      @list = list.sort_by { |p| [p["depth"], p["sheet"]] }
    end

    def target_index
      @list.index { |p| p.equal?(@target) }
    end

    def stored_index(page)
      WallStore.pages(@wall, @board).index { |p| p.equal?(page) }
    end

    def hand
      TempleStickers.placeable(@run)
    end

    def items
      @list[@page]["items"].sort_by { |it| it["c"] }
    end

    def saver
      ->(wall) { WallStore.save(@dir, wall) }
    end

    def run
      TempleStickers.silenced do
        create
        refresh
        loop do
          Graphics.update
          Input.update
          result = handle_input
          break if result == :exit
          refresh if result
        end
      end
    ensure
      dispose
    end

    # Returns :exit, true (redraw) or nil.
    def handle_input
      if !Staff.active? && TempleStickers.staff_combo?
        enter_staff_code
        return true
      end
      return :exit if Input.trigger?(Input::BACK) && @mode != :place
      if TempleStickers.raw_color?(:orange)
        @hand = hand.empty? ? 0 : (@hand + 1) % hand.length
        return true
      end
      if Staff.active? && (TempleStickers.raw_color?(:white) || Input.trigger?(Input::ACTION))
        staff_menu
        return true
      end
      case @mode
      when :strip then input_strip
      when :page then input_page
      when :place then input_place
      end
    end

    def input_strip
      if Input.repeat?(Input::LEFT) && @page > 0
        @page -= 1
      elsif Input.repeat?(Input::RIGHT) && @page < @list.length - 1
        @page += 1
      elsif Input.trigger?(Input::DOWN) && !items.empty?
        @mode = :page
        @item = 0
      elsif Input.trigger?(Input::USE)
        start_placing
      else
        return nil
      end
      true
    end

    def input_page
      if Input.repeat?(Input::UP) || Input.repeat?(Input::LEFT)
        if @item.zero?
          @mode = :strip
        else
          @item -= 1
        end
      elsif Input.repeat?(Input::DOWN) || Input.repeat?(Input::RIGHT)
        @item = [@item + 1, items.length - 1].min
      elsif Input.trigger?(Input::USE)
        start_placing
      else
        return nil
      end
      true
    end

    def input_place
      col = @cell % PAGE_COLS
      row = @cell / PAGE_COLS
      if Input.trigger?(Input::BACK)
        @mode = :strip
      elsif Input.repeat?(Input::LEFT)
        @cell = row * PAGE_COLS + (col - 1) % PAGE_COLS
      elsif Input.repeat?(Input::RIGHT)
        @cell = row * PAGE_COLS + (col + 1) % PAGE_COLS
      elsif Input.repeat?(Input::UP)
        @cell = ((row - 1) % PAGE_ROWS) * PAGE_COLS + col
      elsif Input.repeat?(Input::DOWN)
        @cell = ((row + 1) % PAGE_ROWS) * PAGE_COLS + col
      elsif Input.trigger?(Input::USE)
        place
      else
        return nil
      end
      true
    end

    # Placing always happens on the current depth's writable page.
    def start_placing
      if hand.empty?
        pbPlayBuzzerSE if defined?(pbPlayBuzzerSE)
        return
      end
      @page = target_index
      taken = @target["items"].map { |it| it["c"] }
      @cell = (0...PAGE_CELLS).find { |c| !taken.include?(c) } || 0
      @mode = :place
    end

    def place
      sticker = hand[@hand % hand.length]
      outcome, item = TempleStickers.place(@wall, @run, @board, @depth, sticker, @cell, saver)
      if outcome == :save_failed
        pbMessage(_INTL("TEMPLE_SAVE_FAILED"))
        @mode = :strip
        return
      elsif outcome != :ok
        pbPlayBuzzerSE if defined?(pbPlayBuzzerSE)
        return
      end
      @placed_any = true
      @hand = 0
      refresh_pages
      @page = @list.index { |p| p["items"].any? { |it| it.equal?(item) } }
      @mode = :page
      @item = items.index { |it| it.equal?(item) } || 0
      refresh
      sign(item) if pbConfirmMessage(_INTL("TEMPLE_ASK_SIGN"))
    end

    # Name (prefilled after the first time), then the board's sentence prompt.
    def sign(item)
      name = KeyboardScene.new(_INTL("TEMPLE_NAME_PROMPT"), NAME_MAX, @run[:name]).run
      return if name.nil?
      TempleStickers.set_name(@run, name)
      sentence = KeyboardScene.new(_INTL(BOARDS[@board][:prompt_key]), SENTENCE_MAX).run
      return unless WallStore.sign_item(@wall, @board, item, @run[:name], sentence)
      pbMessage(_INTL("TEMPLE_SIGN_SAVE_FAILED")) unless saver.call(@wall)
    end

    #--- staff ------------------------------------------------------------------
    # No cfg: nothing happens (staff mode does not exist on this cabinet).
    def enter_staff_code
      cfg = Staff.read(@dir)
      return if cfg.nil?
      Staff.warn_if_untypeable(cfg)
      code = KeyboardScene.new(_INTL("TEMPLE_STAFF_CODE_PROMPT"), CODE_MAX, nil, mask: true).run
      return if code.nil?
      if Staff.matches?(code, cfg)
        Staff.activate
        pbMessage(_INTL("TEMPLE_STAFF_ON"))
      else
        pbMessage(_INTL("TEMPLE_STAFF_CODE_WRONG"))
      end
    end

    def staff_menu
      idx = stored_index(@list[@page])
      item = @mode == :page && idx ? items[@item] : nil
      cmds = []
      cmds << [:del_text, _INTL("TEMPLE_STAFF_DEL_TEXT")] if item && item["text"]
      cmds << [:del_sticker, _INTL("TEMPLE_STAFF_DEL_STICKER")] if item
      cmds << [:del_page, _INTL("TEMPLE_STAFF_DEL_PAGE")] if idx && !item
      cmds << [:wipe_board, _INTL("TEMPLE_STAFF_WIPE_BOARD")] unless item
      cmds << [:wipe_wall, _INTL("TEMPLE_STAFF_WIPE_WALL")] unless item
      reward = Staff.reward_on?(Staff.read(@dir))
      cmds << [:reward, _INTL(reward ? "TEMPLE_STAFF_REWARD_ON" : "TEMPLE_STAFF_REWARD_OFF")] unless item
      cmds << [:cancel, _INTL("TEMPLE_STAFF_CANCEL")]
      choice = pbShowCommands(nil, cmds.map { |c| c[1] }, cmds.length)   # Blue = last (cancel)
      staff_action(cmds[choice] ? cmds[choice][0] : :cancel, idx, item, reward)
    end

    def staff_action(action, idx, item, reward)
      case action
      when :del_text then WallStore.delete_text(@wall, @board, idx, item["c"])
      when :del_sticker then WallStore.delete_item(@wall, @board, idx, item["c"])
      when :del_page then WallStore.delete_page(@wall, @board, idx)
      when :wipe_board then return unless sure? && WallStore.wipe_board(@dir, @wall, @board)
      when :wipe_wall then return unless sure? && WallStore.wipe_all(@dir, @wall)
      when :reward then return Staff.write_reward(@dir, !reward)
      else return
      end
      pbMessage(_INTL("TEMPLE_SIGN_SAVE_FAILED")) unless saver.call(@wall)
      refresh_pages
      @page = [[@page, @list.length - 1].min, 0].max
      @mode = :strip if items.empty?
      @item = [[@item, items.length - 1].min, 0].max
    end

    def sure?
      pbConfirmMessage(_INTL("TEMPLE_STAFF_SURE")) && pbConfirmMessage(_INTL("TEMPLE_STAFF_SURE2"))
    end

    #--- drawing ----------------------------------------------------------------
    def create
      @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
      @viewport.z = 99_990
      @sprite = Sprite.new(@viewport)
      @sprite.bitmap = Bitmap.new(Graphics.width, Graphics.height)
      pbSetSystemFont(@sprite.bitmap) if defined?(pbSetSystemFont)
    end

    def refresh
      bmp = @sprite.bitmap
      bmp.clear
      bmp.fill_rect(0, 0, bmp.width, bmp.height, Color.new(50, 40, 36))
      draw_strip(bmp)
      draw_page(bmp)
      draw_hand(bmp)
      draw_bottom(bmp)
    end

    def tab_label(page)
      return _INTL("TEMPLE_TAB_DEPTH", page["depth"]) if page["sheet"].zero?
      _INTL("TEMPLE_TAB_DEPTH_SHEET", page["depth"], page["sheet"] + 1)
    end

    def draw_strip(bmp)
      count = @list.length
      first = [[@page - STRIP_MARKS / 2, count - STRIP_MARKS].min, 0].max
      TempleStickers.draw_text(bmp, 0, 4, 20, 28, "<", TEXT_BASE, TEXT_SHADOW, 1) if first > 0
      TempleStickers.draw_text(bmp, 492, 4, 20, 28, ">", TEXT_BASE, TEXT_SHADOW, 1) if first + STRIP_MARKS < count
      [STRIP_MARKS, count - first].min.times do |slot|
        i = first + slot
        x = 24 + slot * (MARK_W + 6)
        if i == @page
          ring = @mode == :strip ? Color.new(216, 138, 59) : Color.new(160, 150, 130)
          bmp.fill_rect(x - 3, 3, MARK_W + 6, 34, ring)
        end
        mine = @list[i].equal?(@target)
        bmp.fill_rect(x, 6, MARK_W, 28, mine ? Color.new(200, 225, 200) : TempleStickers.color(PAPER))
        TempleStickers.draw_text(bmp, x + 2, 6, MARK_W - 4, 28, tab_label(@list[i]), INK, INK_SHADOW, 1)
      end
    end

    def draw_page(bmp)
      bmp.fill_rect(PAGE_X, PAGE_Y, PAGE_COLS * CELL, PAGE_ROWS * CELL, TempleStickers.color(PAPER))
      page_items = @list[@page]["items"]
      page_items.each { |it| blt_sticker(bmp, it["s"], it["c"], 255) }
      if @mode == :page && items[@item]
        frame(bmp, items[@item]["c"], Color.new(216, 138, 59))
      elsif @mode == :place
        frame(bmp, @cell, Color.new(95, 154, 108))
        sticker = hand[@hand % [hand.length, 1].max]
        free = page_items.none? { |it| it["c"] == @cell }
        blt_sticker(bmp, sticker, @cell, 140) if sticker && free
      end
    end

    def cell_origin(cell)
      [PAGE_X + (cell % PAGE_COLS) * CELL, PAGE_Y + (cell / PAGE_COLS) * CELL]
    end

    def blt_sticker(bmp, sticker, cell, opacity)
      src = Art.bitmap(sticker)
      x, y = cell_origin(cell)
      bmp.blt(x + (CELL - Art::SIZE) / 2, y + (CELL - Art::SIZE) / 2, src, src.rect, opacity)
    end

    def frame(bmp, cell, color)
      x, y = cell_origin(cell)
      [[x, y, CELL, 3], [x, y + CELL - 3, CELL, 3], [x, y, 3, CELL], [x + CELL - 3, y, 3, CELL]].each do |r|
        bmp.fill_rect(*r, color)
      end
    end

    def draw_hand(bmp)
      hand.each_with_index do |sticker, i|
        y = PAGE_Y + i * CELL
        if i == @hand % hand.length
          bmp.fill_rect(HAND_X - 4, y + 4, Art::SIZE + 8, Art::SIZE + 8, Color.new(216, 138, 59))
        end
        src = Art.bitmap(sticker)
        bmp.blt(HAND_X, y + 8, src, src.rect)
      end
    end

    def draw_bottom(bmp)
      if @mode == :page && items[@item]
        TempleStickers.draw_text(bmp, 12, 302, 488, 28, items[@item]["name"].to_s, TEXT_BASE, TEXT_SHADOW)
        TempleStickers.draw_text(bmp, 12, 328, 488, 28, items[@item]["text"].to_s, TEXT_BASE, TEXT_SHADOW)
      end
      key = if @mode == :place then "TEMPLE_HINT_PLACE"
            elsif hand.empty? then "TEMPLE_HINT_BROWSE"
            else "TEMPLE_HINT_HAND"
            end
      hint = _INTL(key)
      hint += " / " + _INTL("TEMPLE_HINT_STAFF") if Staff.active?
      size = bmp.font.size
      bmp.font.size = [size - 6, 16].max
      TempleStickers.draw_text(bmp, 8, 356, 496, 26, hint, TEXT_BASE, TEXT_SHADOW, 1)
      bmp.font.size = size
    end

    def dispose
      @sprite.bitmap.dispose if @sprite && @sprite.bitmap && !@sprite.bitmap.disposed?
      @sprite.dispose if @sprite && !@sprite.disposed?
      @viewport.dispose if @viewport && !@viewport.disposed?
    end
  end
end

# Event Script command: pbTempleBoard(:kusama) / :yonath / :curry / :parton.
def pbTempleBoard(board)
  raise ArgumentError, "Unknown temple board: #{board}" unless TempleStickers.board?(board)
  scene = nil
  pbFadeOutIn { scene = TempleStickers::BoardScene.new(board).tap(&:run) }
  # The run state lives in Game.rxdata; save so a reset cannot re-place a sticker.
  DesertTownAutosave.save_now(:temple_board) if scene && scene.placed_any && defined?(DesertTownAutosave)
  true
end
