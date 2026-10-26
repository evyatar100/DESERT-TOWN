#===============================================================================
# TempleStickers - board screen. One tab per Inception depth, oldest depth on
# the left. You stick only on the current depth's tab; every other tab is
# read-only. Opens on the current depth's tab.
#   strip: left/right flips tabs, down enters the page
#   page:  left/right step over stickers; where stickers overlap, up/down pick one
#          from the list (newest first) and the bottom box shows its name + sentence
#   place: Orange picks a hand sticker, Red jumps to your tab, Red sticks it.
#          The tray shows only stickers whose home is this board.
#   White + Green together: staff code keyboard (works with an empty hand)
#===============================================================================

module TempleStickers
  class BoardScene
    View = BoardView

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
      @spot = 0
      @pick = 0
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

    # Every sticker still to place; only `fits` can go on this board.
    def hand
      TempleStickers.placeable(@run)
    end

    # Cached per refresh; refresh clears it.
    def fits
      @fits ||= TempleStickers.placeable_on(@run, @board)
    end

    def selected
      fits.empty? ? nil : fits[@hand % fits.length]
    end

    # Nil unless the hand has stickers and none of them fit this board.
    def other_board_line
      return nil if hand.empty? || !fits.empty?
      names = TempleStickers.other_homes(@run, @board).map { |b| _INTL(BOARDS[b][:name_key]) }
      _INTL("TEMPLE_HAND_OTHER_BOARD", names.join(", "))
    end

    # Browse stops in reading order (spot); the stored order stays oldest first.
    def items
      @list[@page]["items"].sort_by { |it| it["p"] }
    end

    # Every sticker overlapping the current stop, newest first.
    def stack
      stop = items[@item]
      stop ? WallStore.stack_at(@list[@page], stop["p"]) : []
    end

    # The sticker whose name and sentence show: the picked one in the stack.
    def current
      stack[@pick] || items[@item]
    end

    def go_to_stop(index)
      @item = index
      @pick = stack.index { |it| it.equal?(items[@item]) } || 0
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
        @hand = fits.empty? ? 0 : (@hand + 1) % fits.length
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
        go_to_stop(0)
      elsif Input.trigger?(Input::USE)
        start_placing
      else
        return nil
      end
      true
    end

    # Up/down cycle the overlap list when there is one; otherwise they step like left/right.
    def input_page
      many = stack.length > 1
      if many && (Input.repeat?(Input::UP) || Input.repeat?(Input::DOWN))
        @pick = (@pick + (Input.repeat?(Input::UP) ? -1 : 1)) % stack.length
      elsif Input.repeat?(Input::UP) || Input.repeat?(Input::LEFT)
        if @item.zero?
          @mode = :strip
        else
          go_to_stop(@item - 1)
        end
      elsif Input.repeat?(Input::DOWN) || Input.repeat?(Input::RIGHT)
        go_to_stop([@item + 1, items.length - 1].min)
      elsif Input.trigger?(Input::USE)
        start_placing
      else
        return nil
      end
      true
    end

    # The cursor moves half a sticker per press, so stickers can partly overlap.
    def input_place
      dir = { Input::LEFT => :left, Input::RIGHT => :right, Input::UP => :up, Input::DOWN => :down }
            .find { |key, _| Input.repeat?(key) }&.last
      if Input.trigger?(Input::BACK)
        @mode = :strip
      elsif dir
        @spot = WallStore.move_spot(@spot, dir)
      elsif Input.trigger?(Input::USE)
        place
      else
        return nil
      end
      true
    end

    # Placing always happens on the current depth's writable page.
    def start_placing
      if fits.empty?
        pbPlayBuzzerSE if defined?(pbPlayBuzzerSE)
        pbMessage(other_board_line) if other_board_line
        return
      end
      @page = target_index
      @spot = WallStore.free_spot(@target)
      @mode = :place
    end

    def place
      sticker = selected
      outcome, item = TempleStickers.place(@wall, @run, @board, @depth, sticker, @spot, saver)
      @fits = nil
      if outcome == :recovered
        pbMessage(_INTL("TEMPLE_ALREADY_PLACED"))
        show_item(item)
        return
      elsif outcome == :save_failed
        pbMessage(_INTL("TEMPLE_SAVE_FAILED"))
        @mode = :strip
        return
      elsif outcome != :ok
        pbPlayBuzzerSE if defined?(pbPlayBuzzerSE)
        return
      end
      show_item(item)
      sign(item) if pbConfirmMessage(_INTL("TEMPLE_ASK_SIGN"))
    end

    # Flips to the page holding item (if it is on this board) and selects it.
    def show_item(item)
      @placed_any = true
      @hand = 0
      refresh_pages
      page = @list.index { |p| p["items"].any? { |it| it.equal?(item) } }
      if page
        @page = page
        @mode = :page
        go_to_stop(items.index { |it| it.equal?(item) } || 0)
      else
        @mode = :strip
      end
      refresh
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
      item = @mode == :page && idx ? current : nil
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
      when :del_text then WallStore.delete_text(@wall, @board, idx, item["p"])
      when :del_sticker then WallStore.delete_item(@wall, @board, idx, item["p"])
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
      go_to_stop([[@item, items.length - 1].min, 0].max)
    end

    def sure?
      pbConfirmMessage(_INTL("TEMPLE_STAFF_SURE")) && pbConfirmMessage(_INTL("TEMPLE_STAFF_SURE2"))
    end

    #--- drawing ----------------------------------------------------------------
    def create
      @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
      # Same z as pbFadeOutIn's black layer but created later, so drawn above it.
      @viewport.z = 99_999
      @sprite = Sprite.new(@viewport)
      @sprite.bitmap = Bitmap.new(Graphics.width, Graphics.height)
      pbSetSystemFont(@sprite.bitmap) if defined?(pbSetSystemFont)
    end

    def refresh
      @fits = nil
      bmp = @sprite.bitmap
      bmp.clear
      View.draw_background(bmp)
      View.draw_title(bmp, _INTL("TEMPLE_BOARD_TITLE", _INTL(BOARDS[@board][:name_key])))
      View.draw_tabs(bmp, @list.map { |p| tab_label(p) }, @page, target_index, @mode == :strip)
      draw_page(bmp)
      # Only this board's stickers (at most 3); the info box names other boards.
      View.draw_hand(bmp, _INTL("TEMPLE_HAND_TITLE"), fits, fits.index(selected),
                     hand.empty? ? _INTL("TEMPLE_HAND_EMPTY") : nil)
      draw_info(bmp)
      View.draw_legend(bmp, legend)
    end

    def tab_label(page)
      return _INTL("TEMPLE_TAB_DEPTH", page["depth"]) if page["sheet"].zero?
      _INTL("TEMPLE_TAB_DEPTH_SHEET", page["depth"], page["sheet"] + 1)
    end

    def draw_page(bmp)
      page_items = @list[@page]["items"]
      page_items.each { |it| View.draw_sticker(bmp, it["s"], it["p"]) }   # stored oldest first: newest on top
      if page_items.empty? && @mode != :place
        lines = [_INTL("TEMPLE_BOARD_EMPTY")]
        lines << _INTL("TEMPLE_BOARD_EMPTY_FIRST") if @list[@page].equal?(@target) && !fits.empty?
        View.draw_empty(bmp, lines)
      end
      if @mode == :page && current
        View.draw_sticker(bmp, current["s"], current["p"]) if stack.length > 1   # lift the picked one
        View.draw_cursor(bmp, current["p"], View::BUTTONS[:orange])
      elsif @mode == :place
        sticker = selected
        free = page_items.none? { |it| it["p"] == @spot }
        View.draw_sticker(bmp, sticker, @spot, 140) if sticker && free
        View.draw_cursor(bmp, @spot, View::BUTTONS[:green])
      end
    end

    # Page: who stuck it and their sentence. Strip: the board's question, or
    # where the hand's stickers belong when none fit here.
    def draw_info(bmp)
      if @mode == :place
        View.draw_info(bmp, nil, _INTL("TEMPLE_PLACE_INFO"))
      elsif @mode == :page && stack.length > 1
        View.draw_stack_info(bmp, stack.map { |it| stack_label(it) }, @pick, current["text"].to_s)
      elsif @mode == :page && current
        name = current["name"].to_s
        top = name.empty? ? _INTL("TEMPLE_ITEM_NO_NAME") : name
        View.draw_info(bmp, top, current["text"].to_s, name.empty? ? View::DIM : View::LABEL)
      elsif other_board_line
        View.draw_info(bmp, nil, other_board_line)
      else
        View.draw_info(bmp, _INTL("TEMPLE_BOARD_ASKS"), _INTL(BOARDS[@board][:prompt_key]))
      end
    end

    # Overlap list entry: the signer's name, else the sticker's honoree.
    def stack_label(item)
      name = item["name"].to_s
      name.empty? ? _INTL(BOARDS[TempleStickers.home_board(item["s"])][:name_key]) : name
    end

    # Red/Orange/Blue only; the White + Green staff combo is never listed.
    def legend
      list = [[:joy, _INTL(@mode == :place ? "TEMPLE_LEG_SPOT" : "TEMPLE_LEG_LOOK")]]
      list << [:red, _INTL("TEMPLE_LEG_STICK")] unless fits.empty?
      list << [:orange, _INTL("TEMPLE_LEG_NEXT")] if fits.length > 1
      list << [:blue, _INTL(@mode == :place ? "TEMPLE_LEG_BACK" : "TEMPLE_LEG_LEAVE")]
      list << [:white, _INTL("TEMPLE_LEG_STAFF")] if Staff.active?
      list
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
  name = _INTL(TempleStickers::BOARDS[board.to_s][:name_key])
  return true unless pbConfirmMessage(_INTL("TEMPLE_BOARD_APPROACH", name))
  scene = nil
  pbFadeOutIn { scene = TempleStickers::BoardScene.new(board).tap(&:run) }
  # The run state lives in Game.rxdata; save so a reset cannot re-place a sticker.
  DesertTownAutosave.save_now(:temple_board) if scene && scene.placed_any && defined?(DesertTownAutosave)
  true
end
