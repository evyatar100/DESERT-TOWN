#===============================================================================
# TempleStickers - shared wall file (temple_wall.dat beside Game.rxdata).
# Survives every new run. Marshal of core types only:
#   {"v"=>3, "boards"=>{"kusama"=>[page, ...], ...}}   pages sorted by depth, sheet
#   page = {"depth"=>n, "sheet"=>n, "t"=>epoch, "items"=>[item]}   items oldest first
#   item = {"s"=>sticker, "p"=>spot, "run"=>run_id, "name"=>str|nil, "text"=>str|nil}
# A spot is a half-cell position (SPOT_COLS x SPOT_ROWS); v1/v2 items had a whole "c" cell.
# A tab is one Inception depth; every run at that depth shares it, and a full
# tab grows a new sheet. Only the newest sheet of the current depth is writable.
#===============================================================================

module TempleStickers
  module WallStore
    VERSION = 3
    @last_status = nil

    class << self
      attr_reader :last_status   # :ok, :missing, :quarantined, :restored_bak
    end

    def self.path(dir)
      File.join(dir, WALL_FILE)
    end

    def self.empty_wall
      { "v" => VERSION, "boards" => BOARDS.keys.each_with_object({}) { |b, h| h[b] = [] } }
    end

    def self.stamp(time = Time.now)
      time.strftime("%Y%m%d-%H%M%S")
    end

    # Never raises. A bad main file is renamed aside; a valid .bak becomes the main file.
    def self.load(dir)
      main = path(dir)
      bad = false
      if File.exist?(main)
        wall = read_wall(main)
        if wall
          @last_status = :ok
          return wall
        end
        quarantine(dir, main)
        bad = true
      end
      bak = read_wall(main + ".bak")
      if bak
        restore_main(main)
        @last_status = :restored_bak
        return bak
      end
      @last_status = bad || File.exist?(main + ".bak") ? :quarantined : :missing
      empty_wall
    end

    def self.read_wall(file)
      return nil unless File.exist?(file)
      sanitize(Marshal.load(File.binread(file)))
    rescue StandardError
      nil
    end

    def self.restore_main(main)
      tmp = main + ".tmp"
      File.binwrite(tmp, File.binread(main + ".bak"))
      File.rename(tmp, main)
    rescue StandardError
      nil
    end

    def self.quarantine(dir, main)
      File.rename(main, unique_path(File.join(dir, "temple_wall.bad-#{stamp}.dat")))
    rescue StandardError
      nil
    end

    def self.unique_path(file)
      return file unless File.exist?(file)
      base = file.sub(/\.dat\z/, "")
      n = 2
      n += 1 while File.exist?("#{base}-#{n}.dat")
      "#{base}-#{n}.dat"
    end

    # Keeps the valid parts; nil when the top level is not a wall at all, or
    # was written by a newer version. A v1 wall becomes depth-0 sheets, one per
    # old page (a migrated sheet left with no items is dropped); v1/v2 cells become spots.
    def self.sanitize(obj)
      return nil unless obj.is_a?(Hash) && obj["boards"].is_a?(Hash)
      return nil if obj["v"].is_a?(Integer) && obj["v"] > VERSION
      version = obj["v"].is_a?(Integer) ? obj["v"] : 1
      wall = empty_wall
      BOARDS.keys.each do |b|
        raw = obj["boards"][b]
        next unless raw.is_a?(Array)
        migrate = version < 2
        raw = raw.each_with_index.map { |p, i| migrate_v1_page(p, i) } if migrate
        ps = raw.map { |p| sanitize_page(p, version < 3) }.compact
        ps.reject! { |p| p["items"].empty? } if migrate
        ps = ps.sort_by { |p| [p["depth"], p["sheet"]] }
        wall["boards"][b] = ps.uniq { |p| [p["depth"], p["sheet"]] }
        cap!(wall, b)
      end
      wall
    end

    def self.migrate_v1_page(page, index)
      return nil unless page.is_a?(Hash) && page["items"].is_a?(Array)
      items = page["items"].map do |it|
        it.is_a?(Hash) ? it.merge("run" => page["run"], "name" => page["name"]) : it
      end
      { "depth" => 0, "sheet" => index, "t" => page["t"], "items" => items }
    end

    def self.clean_text(value, max)
      value.is_a?(String) && !value.empty? ? value[0, max] : nil
    end

    # A whole old cell's top-left spot on the half-cell grid.
    def self.cell_to_spot(cell)
      (cell / PAGE_COLS) * 2 * SPOT_COLS + (cell % PAGE_COLS) * 2
    end

    def self.spot?(spot)
      spot.is_a?(Integer) && spot.between?(0, SPOTS - 1)
    end

    # Spot of a stored item, or nil; from_cells reads a v1/v2 "c" cell.
    def self.item_spot(item, from_cells)
      return item["p"] if !from_cells && spot?(item["p"])
      c = item["c"]
      from_cells && c.is_a?(Integer) && c.between?(0, PAGE_CELLS - 1) ? cell_to_spot(c) : nil
    end

    def self.sanitize_page(page, from_cells = false)
      return nil unless page.is_a?(Hash) && page["items"].is_a?(Array)
      depth = page["depth"]
      sheet = page["sheet"]
      return nil unless depth.is_a?(Integer) && depth >= 0 && sheet.is_a?(Integer) && sheet >= 0
      items = page["items"].select do |it|
        it.is_a?(Hash) && STICKERS.key?(TempleStickers.canonical(it["s"])) && item_spot(it, from_cells)
      end
      items = items.uniq { |it| item_spot(it, from_cells) }.map do |it|
        { "s" => TempleStickers.canonical(it["s"]), "p" => item_spot(it, from_cells), "run" => it["run"].is_a?(String) ? it["run"] : "",
          "name" => clean_text(it["name"], NAME_MAX), "text" => clean_text(it["text"], SENTENCE_MAX) }
      end
      { "depth" => depth, "sheet" => sheet, "t" => page["t"].is_a?(Integer) ? page["t"] : 0, "items" => items }
    end

    # Two stickers overlap when their spots are at most one half-cell apart on both axes.
    def self.overlap?(a, b)
      ((a % SPOT_COLS) - (b % SPOT_COLS)).abs <= 1 && ((a / SPOT_COLS) - (b / SPOT_COLS)).abs <= 1
    end

    # Every item overlapping the sticker at spot, newest first (items are stored oldest first).
    def self.stack_at(page, spot)
      page["items"].reverse.select { |it| overlap?(it["p"], spot) }
    end

    # One half-cell step of the place cursor; wraps at the sheet edges.
    def self.move_spot(spot, dir)
      x = spot % SPOT_COLS
      y = spot / SPOT_COLS
      case dir
      when :left then x = (x - 1) % SPOT_COLS
      when :right then x = (x + 1) % SPOT_COLS
      when :up then y = (y - 1) % SPOT_ROWS
      when :down then y = (y + 1) % SPOT_ROWS
      end
      y * SPOT_COLS + x
    end

    # Where the place cursor starts: the first spot touching nothing, else the first unused spot.
    def self.free_spot(page)
      used = page["items"].map { |it| it["p"] }
      (0...SPOTS).find { |s| used.none? { |u| overlap?(u, s) } } || (0...SPOTS).find { |s| !used.include?(s) } || 0
    end

    # tmp -> copy current to .bak -> rename tmp over current. False on any error.
    def self.save(dir, wall)
      main = path(dir)
      tmp = main + ".tmp"
      File.open(tmp, "wb") do |f|
        f.write(Marshal.dump(wall))
        f.flush
        f.fsync rescue nil
      end
      File.binwrite(main + ".bak", File.binread(main)) if File.exist?(main)
      File.rename(tmp, main)
      true
    rescue StandardError
      false
    end

    def self.pages(wall, board)
      wall["boards"][board.to_s] ||= []
    end

    def self.full?(page)
      page["items"].length >= PAGE_CELLS
    end

    # The writable page for a depth: its newest sheet if not full, else a new
    # sheet that is not stored until something is placed on it.
    def self.target(wall, board, depth)
      sheets = pages(wall, board).select { |p| p["depth"] == depth }
      last = sheets.max_by { |p| p["sheet"] }
      return last if last && !full?(last)
      { "depth" => depth, "sheet" => last ? last["sheet"] + 1 : 0, "t" => 0, "items" => [] }
    end

    def self.run_has_sticker?(wall, run_id, sticker_id)
      !run_item(wall, run_id, sticker_id).nil?
    end

    # [board, item] for this run's stored sticker on any board, or nil.
    def self.run_item(wall, run_id, sticker_id)
      wall["boards"].each do |board, ps|
        ps.each { |p| p["items"].each { |it| return [board, it] if it["run"] == run_id && it["s"] == sticker_id } }
      end
      nil
    end

    # Adds to the depth's writable page (on top). Nil when the sticker or spot is
    # refused; overlap is fine, the exact same spot is not.
    def self.add_item(wall, board, depth, run_id, sticker_id, spot, name = nil, time = Time.now.to_i)
      return nil unless BOARDS.key?(board.to_s) && STICKERS.key?(sticker_id)
      return nil unless spot?(spot)
      return nil if run_has_sticker?(wall, run_id, sticker_id)
      page = target(wall, board, depth)
      return nil if page["items"].any? { |it| it["p"] == spot }
      ps = pages(wall, board)
      unless ps.any? { |p| p.equal?(page) }
        page["t"] = time
        ps << page
        ps.sort_by! { |p| [p["depth"], p["sheet"]] }
      end
      item = { "s" => sticker_id, "p" => spot, "run" => run_id, "name" => name, "text" => nil }
      page["items"] << item
      cap!(wall, board, MAX_PAGES_PER_BOARD, page)
      item
    end

    # Undoes add_item; an emptied page is dropped too.
    def self.remove_item(wall, board, item)
      ps = pages(wall, board)
      page = ps.find { |p| p["items"].any? { |it| it.equal?(item) } }
      return false unless page
      page["items"].reject! { |it| it.equal?(item) }
      ps.delete(page) if page["items"].empty?
      true
    end

    # Name and sentence on a stored item; false when the item is not on this board.
    def self.sign_item(wall, board, item, name, text)
      return false unless pages(wall, board).any? { |p| p["items"].any? { |it| it.equal?(item) } }
      item["name"] = clean_text(name, NAME_MAX)
      item["text"] = clean_text(text, SENTENCE_MAX)
      true
    end

    def self.find_item(page, spot)
      page["items"].find { |it| it["p"] == spot }
    end

    # Drops the lowest-depth (oldest) pages over the cap, never the page in use.
    def self.cap!(wall, board, max = MAX_PAGES_PER_BOARD, keep = nil)
      ps = pages(wall, board)
      ps.delete_at(ps[0].equal?(keep) ? 1 : 0) while ps.length > max
      ps
    end

    #--- staff edits (page index addressed) -------------------------------------
    def self.delete_text(wall, board, page_idx, spot)
      page = pages(wall, board)[page_idx]
      item = page && find_item(page, spot)
      return false unless item
      item["text"] = nil
      true
    end

    def self.delete_item(wall, board, page_idx, spot)
      page = pages(wall, board)[page_idx]
      return false unless page && find_item(page, spot)
      page["items"].reject! { |it| it["p"] == spot }
      true
    end

    def self.delete_page(wall, board, page_idx)
      return false unless pages(wall, board)[page_idx]
      pages(wall, board).delete_at(page_idx)
      true
    end

    # Keeps a temple_wall.wiped-<time>.dat copy for undo by hand.
    def self.snapshot_before_wipe(dir, wall)
      File.binwrite(unique_path(File.join(dir, "temple_wall.wiped-#{stamp}.dat")), Marshal.dump(wall))
      true
    rescue StandardError
      false
    end

    def self.wipe_board(dir, wall, board)
      snapshot_before_wipe(dir, wall)
      wall["boards"][board.to_s] = []
      true
    end

    def self.wipe_all(dir, wall)
      snapshot_before_wipe(dir, wall)
      BOARDS.keys.each { |b| wall["boards"][b] = [] }
      true
    end
  end

  # One placement as a transaction, home board only; a failed save changes nothing.
  # Returns [:ok, item], [:recovered, item], [:refused, nil] or [:save_failed, nil].
  def self.place(wall, run, board, depth, sticker_id, spot, saver)
    return [:refused, nil] unless placeable_on(run, board).include?(sticker_id)
    stored_board, stored = WallStore.run_item(wall, run[:run_id], sticker_id)
    if stored   # saved on the wall before a crash: record where it really is, keep the item
      record_stored_placement(run, sticker_id, stored_board)
      return [:recovered, stored]
    end
    item = WallStore.add_item(wall, board, depth, run[:run_id], sticker_id, spot, run[:name])
    return [:refused, nil] unless item
    unless saver.call(wall)
      WallStore.remove_item(wall, board, item)
      return [:save_failed, nil]
    end
    record_placement(run, sticker_id, board)
    [:ok, item]
  end
end
