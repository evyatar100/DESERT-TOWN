#===============================================================================
# Bags (TG7) - pure rules. No engine calls: tests load this file directly.
# The bag argument is anything with quantity/add/remove (PokemonBag in game).
#===============================================================================

module BagsRules
  INBAR_STATES = %i[none asked done].freeze
  # The duo: standing by Inbar, following the player during the song, or gone to the Spaceship.
  DUO_STATES = %i[kusomo touring gone].freeze
  NEED = 2
  # Pixel never takes bills: the 5 Map088 bills are one-time and the ice seller needs all 5.
  PAY_ITEMS = %i[DESERTBAG ICEBAG].freeze
  BILL_CAP = 2
  OUTCOMES = [[:confetti, 35], [:note, 30], [:recurse, 20], [:bill, 15]].freeze

  def self.new_state
    { inbar: :none, payoff_given: false, toga_gift: false, toga_desert: false, bills_from_bags: 0, duo: :kusomo }
  end

  # Old saves, nil or garbage become a valid state. A Hash is repaired in place.
  def self.normalize(x)
    return new_state unless x.is_a?(Hash)
    x[:inbar] = :none unless INBAR_STATES.include?(x[:inbar])
    %i[payoff_given toga_gift toga_desert].each { |k| x[k] = (x[k] == true) }
    x[:bills_from_bags] = 0 unless x[:bills_from_bags].is_a?(Integer) && x[:bills_from_bags] >= 0
    x[:duo] = :kusomo unless DUO_STATES.include?(x[:duo])
    x.keep_if { |k, _| new_state.key?(k) }
  end

  #-----------------------------------------------------------------------------
  # Inbar, payoff, Pixel, Bag of Bags, Surprise Bag, Toga
  #-----------------------------------------------------------------------------

  def self.inbar_decide(state, qty)
    case state[:inbar]
    when :done then :party
    when :asked then qty.to_i >= NEED ? :offer : :short
    else :intro
    end
  end

  # Inbar's first talk: :none -> :asked. Never moves a :done quest back.
  def self.ask!(state)
    return false unless state[:inbar] == :none
    state[:inbar] = :asked
    true
  end

  # The one list of what Inbar counts, in the order she takes them (TG40, founder: the Music
  # Bag counts as a bag). The Music Bag counts once, and only after its Playa delivery.
  # TG48: Shira's Wedding Bag counts once, from the moment she gives it; taken last.
  INBAR_BAGS = { SURPRISEBAG: nil, MUSICBAG: 1, WEDDINGBAG: 1 }.freeze
  GATED = %i[MUSICBAG WEDDINGBAG].freeze

  # gates: { item => open } per gated item, or a boolean (old callers) = the Music Bag's delivery.
  def self.gate_open?(gates, item)
    gates.is_a?(Hash) ? !!gates[item] : (item == :MUSICBAG && !!gates)
  end

  # item -> how many Inbar would count now.
  def self.inbar_counted(bag, delivered = false)
    return {} unless bag
    INBAR_BAGS.to_h do |item, cap|
      n = GATED.include?(item) && !gate_open?(delivered, item) ? 0 : bag.quantity(item).to_i
      [item, cap ? [n, cap].min : n]
    end
  end

  def self.inbar_count(bag, delivered = false) = inbar_counted(bag, delivered).values.sum

  # Holding the Music Bag before its delivery while still short: Inbar says it is not hers.
  def self.music_not_yet?(state, bag, delivered)
    state[:inbar] != :done && !gate_open?(delivered, :MUSICBAG) && bag && bag.quantity(:MUSICBAG).to_i > 0 &&
      inbar_count(bag, delivered) < NEED
  end

  # Removes exactly NEED counted bags (Surprise Bags first) and marks :done in one step; a repeat is a no-op.
  def self.hand_over!(state, bag, delivered = false)
    counted = inbar_counted(bag, delivered)
    return false if state[:inbar] == :done || counted.values.sum < NEED
    left = NEED
    plan = counted.filter_map do |item, n|
      take = [n, left].min
      left -= take
      [item, take] if take > 0
    end
    return false unless plan.all? { |item, take| bag.quantity(item) >= take }   # all or nothing
    done = []
    plan.each do |item, take|
      unless bag.remove(item, take)
        done.each { |i, t| bag.add(i, t) }
        return false
      end
      done << [item, take]
    end
    state[:inbar] = :done
    true
  end

  # True once, after the hand-over: the caller then gives one SURPRISEBAG.
  def self.payoff!(state)
    return false if state[:inbar] != :done || state[:payoff_given]
    state[:payoff_given] = true
    true
  end

  def self.payoff_pending?(state)
    state[:inbar] == :done && !state[:payoff_given]
  end

  # The unicorn events on Map095 show exactly when this is true (S106).
  def self.unicorns_home?(state)
    state[:inbar] == :done && state[:duo] == :kusomo
  end

  # The song starts: the duo leaves its spot and follows the player.
  def self.tour!(state)
    return false unless unicorns_home?(state)
    state[:duo] = :touring
    true
  end

  # Gone to the Spaceship, from any value. Never touches bags or the payoff.
  def self.leave!(state)
    state[:duo] = :gone
    true
  end

  def self.payable(bag)
    PAY_ITEMS.select { |i| bag.quantity(i) > 0 }
  end

  # Pixel's cat in a sack: one payable item in, one SURPRISEBAG out.
  def self.trade!(bag, pay_item)
    pay_item = pay_item.to_sym rescue nil
    return false unless PAY_ITEMS.include?(pay_item) && bag.quantity(pay_item) > 0
    return false unless bag.remove(pay_item, 1)
    bag.add(:SURPRISEBAG, 1)
    true
  end

  # Never consumes the Bag of Bags. Returns :filled or :full.
  def self.bag_of_bags_use!(bag)
    return :full if bag.quantity(:DESERTBAG) > 0
    bag.add(:DESERTBAG, 1)
    :filled
  end

  def self.roll(rng)
    n = rng.rand(100)
    OUTCOMES.each do |outcome, weight|
      return outcome if n < weight
      n -= weight
    end
    OUTCOMES.last[0]
  end

  def self.warn_inbar?(state, qty)
    state[:inbar] != :done && qty.to_i <= NEED
  end

  # Removes the opened bag first, then rolls and grants. Nil when none is held.
  def self.open_surprise!(state, bag, rng)
    return nil unless bag.quantity(:SURPRISEBAG) > 0 && bag.remove(:SURPRISEBAG, 1)
    outcome = roll(rng)
    outcome = :confetti if outcome == :bill && state[:bills_from_bags] >= BILL_CAP
    case outcome
    when :recurse then bag.add(:SURPRISEBAG, 1)
    when :bill
      bag.add(:TWENTYSHECKELBILL, 1)
      state[:bills_from_bags] += 1
    end
    outcome
  end

  def self.toga_branch(state, holds_desert)
    return :gift unless state[:toga_gift]
    return :desert_offer if holds_desert && !state[:toga_desert]
    return :desert_seen if state[:toga_desert]
    :again
  end

  def self.toga_gift!(state)
    return false if state[:toga_gift]
    state[:toga_gift] = true
  end

  def self.toga_desert!(state, bag)
    return false unless state[:toga_gift] && !state[:toga_desert] && bag.quantity(:DESERTBAG) > 0
    return false unless bag.remove(:DESERTBAG, 1)
    state[:toga_desert] = true
  end

  #-----------------------------------------------------------------------------
  # Song timing: parse, validate, clock lookup, section intensity
  #-----------------------------------------------------------------------------

  EPS = 0.001

  def self.num?(v)
    v.is_a?(Numeric) && v.finite?
  end

  # [timing, nil] or [nil, reason]. doc is the parsed JSON Hash (string keys).
  def self.parse_timing(doc)
    return [nil, "not an object"] unless doc.is_a?(Hash)
    raw = doc["lines"]
    return [nil, "no lines"] unless raw.is_a?(Array) && !raw.empty?
    line_mode = doc["granularity"] == "line"
    lines = []
    raw.each_with_index do |l, i|
      return [nil, "line #{i} is not an object"] unless l.is_a?(Hash)
      text, st, en = l["text"], l["start"], l["end"]
      return [nil, "line #{i} has no text"] unless text.is_a?(String) && !text.strip.empty?
      return [nil, "line #{i} times"] unless num?(st) && num?(en) && st >= 0 && st < en
      return [nil, "line #{i} is out of order"] if lines.any? && st < lines[-1][:start]
      words, err = parse_words(l["words"], st, en, i)
      return [nil, err] if err
      lines << { section: l["section"].to_s, text: text, start: st.to_f, end: en.to_f,
                 words: line_mode ? nil : words }
    end
    dur = doc["duration"]
    dur = lines.map { |l| l[:end] }.max unless num?(dur) && dur > 0
    [{ duration: dur.to_f, placeholder: doc["placeholder"] == true, lines: lines }, nil]
  end

  def self.parse_words(raw, st, en, i)
    return [nil, nil] if raw.nil?
    return [nil, "line #{i} words"] unless raw.is_a?(Array) && !raw.empty?
    words = []
    raw.each do |w|
      ok = w.is_a?(Hash) && w["w"].is_a?(String) && num?(w["start"]) && num?(w["end"]) &&
           w["start"] <= w["end"] && w["start"] >= st - EPS && w["end"] <= en + EPS &&
           (words.empty? || w["start"] >= words[-1][:start])
      return [nil, "line #{i} has a word outside its line or out of order"] unless ok
      words << { w: w["w"], start: w["start"].to_f, end: w["end"].to_f }
    end
    [words, nil]
  end

  # Index of the line sung at t (the latest that started), or nil in a gap.
  def self.line_at(lines, t)
    idx = nil
    lines.each_with_index { |l, i| idx = i if l[:start] <= t && t < l[:end] }
    idx
  end

  def self.next_line(lines, t)
    lines.index { |l| l[:start] > t }
  end

  # Last word started by t (-1 before the first); nil for a line-mode line.
  def self.word_at(line, t)
    return nil unless line[:words]
    line[:words].rindex { |w| w[:start] <= t } || -1
  end

  def self.section_at(lines, t)
    started = lines.select { |l| l[:start] <= t }
    (started.last || lines.first)[:section]
  end

  def self.section_kind(section)
    s = section.to_s.strip.downcase
    return :chorus if s.start_with?("chorus")
    return :bridge if s.start_with?("bridge")
    return :build_up if s.match?(/\Abuild[\s_-]?up/)
    :verse
  end

  # Rain per section. No screen tone: $game_screen is saved, so a dim could outlive the song.
  INTENSITY = {
    verse:    { every: 40,  speed: 1.0 },
    chorus:   { every: 12,  speed: 1.0 },
    bridge:   { every: 120, speed: 0.5 },
    build_up: { every: 8,   speed: 1.5 }
  }.freeze

  def self.intensity(section)
    INTENSITY[section_kind(section)]
  end

  # Clock: Audio.bgm_pos while it moves; a frame clock if it is missing or stuck at 0.
  def self.new_clock(audio)
    { mode: audio ? :audio : :frames, frames: 0, last: 0.0, zero: 0, looped: false, t: 0.0 }
  end

  # Advances one frame. Returns true when the clock just fell back to frames.
  def self.clock_tick(c, pos, fps)
    c[:frames] += 1
    switched = false
    if c[:mode] == :audio
      if !num?(pos)
        c[:mode] = :frames
        switched = true
      else
        c[:looped] = true if pos < c[:last] - 0.5
        c[:zero] = pos > 0 ? 0 : c[:zero] + 1
        c[:last] = pos.to_f if pos > c[:last]
        if c[:zero] >= 60 && c[:last] <= 0
          c[:mode] = :frames
          switched = true
        end
      end
    end
    c[:t] = c[:mode] == :audio ? c[:last] : c[:frames].to_f / fps
    switched
  end

  def self.clock_done?(c, duration)
    c[:looped] || c[:t] >= duration
  end

  SONG_BGM = "sakiyot_haftaa"

  # Nil while the song runs; :done at its end or loop; :interrupted once another BGM (or none) plays.
  def self.song_end_reason(clock, duration, bgm_name)
    return :interrupted if bgm_name.to_s != SONG_BGM
    return :done if clock_done?(clock, duration)
    nil
  end

  # The map's music comes back while the song still plays or nothing plays (never a silent
  # map); any other music (battle, an event's track) is left alone.
  def self.restore_map_music?(bgm_name)
    bgm_name.to_s.empty? || bgm_name.to_s == SONG_BGM
  end

  INBAR_MAP = 95

  # Map095's north edge is the way to the Spaceship; elsewhere they walk away from the player.
  def self.leave_dir(map_id)
    map_id == INBAR_MAP ? :up : :away
  end

  # Nearest open column on row 0 (ties: the left one), so the walk-in starts off-screen.
  def self.walk_in_start(end_x, open_xs)
    return end_x if open_xs.include?(end_x) || open_xs.empty?
    open_xs.min_by { |x| [(x - end_x).abs, x] }
  end

  # Along row 0 to the spot's column, then straight down to the spot.
  def self.walk_in_moves(start_x, end_x, end_y)
    side = end_x > start_x ? :right : :left
    Array.new((end_x - start_x).abs, side) + Array.new(end_y, :down)
  end

  #-----------------------------------------------------------------------------
  # Text: grapheme clusters (base + niqqud/cantillation), RTL word placement
  #-----------------------------------------------------------------------------

  # Same mark set as HebrewText::MARK_CLASS (maqaf and sof pasuq are not marks).
  MARK_CLASS = "[\u0591-\u05BD\u05BF\u05C1\u05C2\u05C4\u05C5\u05C7]"
  CLUSTER_RE = /(?:(?!#{MARK_CLASS}).)#{MARK_CLASS}*|#{MARK_CLASS}+/m
  MARK_RE = /#{MARK_CLASS}/

  def self.clusters(text)
    text.to_s.scan(CLUSTER_RE)
  end

  # Visual (left-to-right) form of one Hebrew word; marks stay after their letter.
  def self.cluster_reverse(word)
    clusters(word).reverse.join
  end

  def self.sakiyot_word?(word)
    word.to_s.gsub(MARK_RE, "").gsub(/[^א-ת]/, "") == "שקיות"
  end

  # Left x of each word (logical order), laid out from right_edge leftwards.
  def self.word_positions(widths, space, right_edge)
    x = right_edge
    widths.map do |w|
      x -= w
      left = x
      x -= space
      left
    end
  end

  # Word index rows: one row if it fits, else two split at the space nearest the middle.
  def self.wrap_rows(widths, space, max_w)
    n = widths.length
    total = widths.sum + space * [n - 1, 0].max
    return [(0...n).to_a] if total <= max_w || n < 2
    best = (1...n).min_by do |k|
      left = widths[0...k].sum + space * (k - 1)
      right = widths[k..].sum + space * (n - k - 1)
      (left - right).abs
    end
    [(0...best).to_a, (best...n).to_a]
  end

  FONT_SIZES = [26, 24, 22, 20, 18].freeze
  WRAP_SIZES = [18, 16, 14, 12].freeze
  PREVIEW_SIZES = [18, 16, 14, 12].freeze

  def self.row_width(widths, space)
    widths.sum + space * [widths.length - 1, 0].max
  end

  # The block maps a font size to [word widths, space width].
  # [size, wrap?]: largest one-row size that fits, else largest two-row size whose rows fit.
  def self.font_plan(max_w)
    FONT_SIZES.each do |s|
      widths, space = yield(s)
      return [s, false] if row_width(widths, space) <= max_w
    end
    WRAP_SIZES.each do |s|
      widths, space = yield(s)
      rows = wrap_rows(widths, space, max_w)
      return [s, true] if rows.all? { |r| row_width(r.map { |i| widths[i] }, space) <= max_w }
    end
    [WRAP_SIZES.last, true]
  end

  # Next-line preview, one row: [size, word count]. At the smallest size trailing words drop.
  def self.preview_plan(max_w)
    PREVIEW_SIZES.each do |s|
      widths, space = yield(s)
      return [s, widths.length] if row_width(widths, space) <= max_w
    end
    widths, space = yield(PREVIEW_SIZES.last)
    n = widths.length
    n -= 1 while n > 1 && row_width(widths[0, n], space) > max_w
    [PREVIEW_SIZES.last, n]
  end

  #-----------------------------------------------------------------------------
  # Rain: only in side gutters no character stands in, never into the lyric
  # panel (y >= PANEL_TOP). Chorus pins: top strip.
  #-----------------------------------------------------------------------------

  SCREEN_W = 512
  PANEL_TOP = 288
  GUTTER_W = 128
  MAX_STICKERS = 6
  RAIN_SIZES = (32..44).freeze
  BURST_SIZES = (22..29).freeze

  def self.sticker_radius(size)
    (size * 0.75).ceil
  end

  def self.rain_every(level)
    level[:every] * 2
  end

  GUTTERS = [[0, GUTTER_W], [SCREEN_W - GUTTER_W, SCREEN_W]].freeze
  CHAR_HALF_W = 16   # a 32 px character centred on its screen_x

  # The gutters no character overlaps: near a map edge the player or the duo can stand in one.
  def self.open_gutters(char_xs)
    GUTTERS.reject { |lo, hi| char_xs.any? { |x| x + CHAR_HALF_W > lo && x - CHAR_HALF_W < hi } }
  end

  # Centre x keeps the whole wobble inside one of gutters; nil when none is open.
  def self.spawn_sticker(rng, size, gutters = GUTTERS)
    return nil if gutters.empty?
    r = sticker_radius(size)
    amp = 4 + rng.rand(5)
    lo = r + amp
    cx = lo + rng.rand(GUTTER_W - r - amp - lo + 1)
    cx += gutters[rng.rand(gutters.length)][0]
    { size: size, r: r, cx: cx, cy: -r.to_f, vy: 1.2 + rng.rand * 1.0,
      amp: amp, phase: rng.rand * 6.28, spin: rng.rand * 4 - 2, angle: 0.0, t: 0 }
  end

  # Advances one frame and sets :dx/:dy (drawn centre). False once it would touch the panel.
  def self.step_sticker(s, speed)
    s[:t] += 1
    s[:cy] += s[:vy] * speed
    s[:angle] = (s[:angle] + s[:spin] * speed) % 360
    s[:dx] = s[:cx] + Math.sin(s[:phase] + s[:t] * 0.06) * s[:amp]
    s[:dy] = s[:cy] - Math.sin(s[:t] * 0.25).abs * 4
    s[:dy] + s[:r] < PANEL_TOP
  end

  PIN_STRIP = 96
  PIN_SWAY = 6     # px, sideways
  PIN_TILT = 8     # degrees
  PIN_POP = 12     # frames to pop in or out
  # [sticker name, centre x, centre y, long side]
  CHORUS_PINS = [["esther_pink", 64, 50, 76], ["shirpaz_purple", 448, 50, 76], ["duo_friends_badge", 256, 46, 68]].freeze

  def self.chorus_pins
    CHORUS_PINS
  end

  # The pins show for the whole chorus span: from its first line to the next section's first line.
  def self.pins_on?(lines, t)
    section_kind(section_at(lines, t)) == :chorus
  end

  # Side of the box a size x size pin covers at the full tilt (any narrower art fits inside it).
  def self.pin_extent(size)
    a = PIN_TILT * Math::PI / 180
    size * (Math.cos(a) + Math.sin(a))
  end

  # [x, y, w, h] a pin can cover at full zoom: the tilted box plus the sway.
  def self.pin_rect(pin)
    _, x, y, size = pin
    e = pin_extent(size)
    [x - e / 2 - PIN_SWAY, y - e / 2, e + 2 * PIN_SWAY, e]
  end

  # Zoom for frames since the pin started showing or hiding.
  def self.pin_zoom(frames, showing)
    f = [frames.to_f / PIN_POP, 1.0].min
    showing ? f : 1.0 - f
  end
end
