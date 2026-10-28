#===============================================================================
# Planetarium (TG10) - pure rules. No engine calls: tests load this file directly.
# The bag argument is anything with quantity/add/remove (PokemonBag in game).
#===============================================================================

module PlanetRules
  ITEM = :LITTLERAM
  STAGES = %i[none asked got delivered shown].freeze
  CLOSING_BGM = nil   # hook for a cleared closing track; the recording has no song (F03)

  def self.new_state
    { stage: :none, shows: 0, finished: false }
  end

  # Old saves, nil or garbage become a valid state. A Hash is repaired in place.
  def self.normalize(x)
    return new_state unless x.is_a?(Hash)
    x[:stage] = :none unless STAGES.include?(x[:stage])
    x[:shows] = 0 unless x[:shows].is_a?(Integer) && x[:shows] >= 0
    x[:finished] = (x[:finished] == true)
    x.keep_if { |k, _| new_state.key?(k) }
  end

  def self.has?(bag)
    !!bag && bag.quantity(ITEM) > 0
  end

  #-----------------------------------------------------------------------------
  # Decisions (spec 3, table) and the only writers of the saved hash
  #-----------------------------------------------------------------------------

  def self.eyal_decide(state, has)
    case state[:stage]
    when :asked, :got then has ? :thanks : :remind
    when :delivered then :warn
    when :shown then state[:finished] ? :after_done : :after_left
    else :ask
    end
  end

  # Nil: Hagar says only her own line.
  def self.hagar_decide(state, has)
    case state[:stage]
    when :asked, :got then has ? :has : :give
    when :delivered then :sent
    when :shown then :after
    end
  end

  def self.ask!(state)
    return false unless state[:stage] == :none
    state[:stage] = :asked
    true
  end

  # Hagar: true when the caller should hand over one ram (the bag lacks it, so never a duplicate).
  def self.give!(state, bag)
    return false unless %i[asked got].include?(state[:stage]) && !has?(bag)
    state[:stage] = :got
    true
  end

  # Removes exactly one ram first; the stage moves only if that removal succeeded.
  def self.deliver!(state, bag)
    return false unless %i[asked got].include?(state[:stage]) && has?(bag)
    return false unless bag.remove(ITEM, 1)
    state[:stage] = :delivered
    true
  end

  # Right before the scene opens: closes the fetch forever and counts the show.
  def self.start_show!(state)
    return false unless %i[delivered shown].include?(state[:stage])
    state[:stage] = :shown
    state[:shows] += 1
    true
  end

  # Only when the audio reached its end.
  def self.finish!(state)
    return false unless state[:stage] == :shown
    state[:finished] = true
  end

  # F9 only: any stage and flag, for playtests.
  def self.debug_set!(state, stage, finished)
    return false unless STAGES.include?(stage)
    state[:stage] = stage
    state[:finished] = finished == true
    true
  end

  #-----------------------------------------------------------------------------
  # Timing: {audio, duration, granularity, placeholder?, source, lines[{passage,
  # section, text, start, end, words?[{w,start,end}]}]}. Missing words = line mode.
  #-----------------------------------------------------------------------------

  EPS = 0.001
  PASSAGE_RE = /\AP\d\d[a-z]?\z/
  AUDIO_DURATION = 558.141   # the recording, when no timing file gives it

  def self.num?(v)
    v.is_a?(Numeric) && v.finite?
  end

  # [timing, nil] or [nil, reason]. doc is the parsed JSON Hash (string keys).
  def self.parse_timing(doc)
    return [nil, "not an object"] unless doc.is_a?(Hash)
    raw = doc["lines"]
    return [nil, "no lines"] unless raw.is_a?(Array) && !raw.empty?
    lines = []
    raw.each_with_index do |l, i|
      return [nil, "line #{i} is not an object"] unless l.is_a?(Hash)
      text, st, en, pid = l["text"], l["start"], l["end"], l["passage"]
      return [nil, "line #{i} has no passage"] unless pid.is_a?(String) && pid.match?(PASSAGE_RE)
      return [nil, "line #{i} has no text"] unless text.is_a?(String) && !text.strip.empty?
      return [nil, "line #{i} times"] unless num?(st) && num?(en) && st >= 0 && st < en
      return [nil, "line #{i} is out of order"] if lines.any? && st < lines[-1][:start]
      words, err = parse_words(l["words"], st, en, i)
      return [nil, err] if err
      words = nil if words && words.length != text.split(" ").length
      lines << { passage: pid, section: l["section"].to_s, text: text, start: st.to_f, end: en.to_f, words: words }
    end
    dur = doc["duration"]
    dur = lines.map { |l| l[:end] }.max unless num?(dur) && dur > 0
    [{ duration: dur.to_f, placeholder: doc["placeholder"] == true, source: doc["source"].to_s, lines: lines }, nil]
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

  # [[passage, first start, last end], ...] in show order.
  def self.passage_spans(lines)
    spans = []
    lines.each do |l|
      if spans.any? && spans[-1][0] == l[:passage]
        spans[-1][2] = [spans[-1][2], l[:end]].max
      else
        spans << [l[:passage], l[:start], l[:end]]
      end
    end
    spans
  end

  #-----------------------------------------------------------------------------
  # Clock: Audio.bgm_pos while it moves; frames while it is missing or stuck at 0.
  # The position is read on frames too: once it moves, the clock re-anchors on it.
  # from: seconds the debug run started at; a position that reads relative is shifted.
  #-----------------------------------------------------------------------------

  STUCK_FRAMES = 60

  # audio: the recording is playing (false = silent show, the position is never read).
  def self.new_clock(audio, from = 0.0)
    { audio: !!audio, mode: audio ? :audio : :frames, frames: 0, last: 0.0, zero: 0, looped: false,
      t: from.to_f, from: from.to_f, shift: nil, anchor_t: from.to_f, anchor_f: 0 }
  end

  # Advances one frame. :frames when it just fell back to frames, :audio when it just
  # re-anchored on a moving position, else nil. A loop is caught in either mode.
  def self.clock_tick(c, pos, fps)
    c[:frames] += 1
    changed = nil
    if c[:audio] && num?(pos)
      c[:shift] = (pos < c[:from] - 1.0 ? c[:from] : 0.0) if c[:shift].nil? && pos > 0
      pos += c[:shift] || 0.0
      c[:looped] = true if pos < c[:last] - 0.5
      c[:zero] = pos > 0 ? 0 : c[:zero] + 1
      moved = pos > c[:last]
      c[:last] = pos.to_f if moved
      if c[:mode] == :frames && moved
        c[:mode] = changed = :audio
      elsif c[:mode] == :audio && c[:zero] >= STUCK_FRAMES && c[:last] <= 0
        c[:mode] = changed = :frames
        c[:anchor_t], c[:anchor_f] = c[:from], 0   # the stuck frames count: the audio may be playing
      end
    elsif c[:mode] == :audio
      c[:mode] = changed = :frames
      c[:anchor_t], c[:anchor_f] = c[:t], c[:frames] - 1
    end
    c[:t] = c[:mode] == :audio ? [c[:last], c[:from]].max : c[:anchor_t] + (c[:frames] - c[:anchor_f]).to_f / fps
    changed
  end

  # Done at the duration or at the first backwards jump (mkxp-z loops the BGM).
  def self.clock_done?(c, duration)
    c[:looped] || c[:t] >= duration
  end

  #-----------------------------------------------------------------------------
  # Crawl: rows wrapped on logical text, chunks of <= 3 rows (word mode), or one
  # shrinking block of <= 6 rows (line mode). Measuring is the caller's: the block
  # maps a font size to [word widths, space width].
  #-----------------------------------------------------------------------------

  MAX_W = 464
  BASE_SIZE = 22                 # the size every non-active line is shown at
  ACTIVE_SCALE = 1.4             # the line being spoken is drawn this much larger
  FONT_SIZE = (BASE_SIZE * ACTIVE_SCALE).round   # rows are drawn and wrapped at the active size
  LINE_SIZES = [31, 28, 25, BASE_SIZE].freeze    # line mode shrinks to fit, never below the base
  CHUNK_ROWS = 3
  LINE_ROWS = 6
  LINE_TAIL = 0.4      # text leaves at the line's end + this, or at the next chunk
  RISE = 0.25
  RECEDE = 0.6
  FADE = 1.5
  BAND_TOP = 270
  BAND_BOTTOM = 370
  RECEDE_TOP = 150
  ZOOM_END = BASE_SIZE.to_f / FONT_SIZE   # a chunk drawn at FONT_SIZE ends at the base size
  GROW = 0.2                     # a line grows from its resting size to the active size
  GAP = 6                        # least px between the active block and the receding one
  BOTTOM_LIMIT = 376
  RISE_DIST = 130
  OPACITY_END = 110
  DIM = 0.7            # upcoming words in word mode

  def self.row_h(size)
    size + 8
  end

  # Index of the line being spoken, nil in a gap or before the first line.
  def self.active_line(chunks, t)
    i = crawl_at(chunks, t)[0]
    i && chunks[i][:line]
  end

  # Zoom of the active line `age` s after its first chunk appeared: eases from `rest` to 1.
  def self.active_zoom(age, rest = ZOOM_END)
    rest + (1.0 - rest) * ease(age / GROW)
  end

  # Resting zoom of a chunk drawn at `size`, so non-active text lands at BASE_SIZE.
  def self.rest_zoom(size)
    [BASE_SIZE.to_f / size, 1.0].min
  end

  # A Latin or number word glued to the Latin/number word before it ("Nature Astrology",
  # "Olympus Mons"): a run never breaks across rows, so it keeps its LTR order.
  def self.glue(words)
    ltr = words.map { |w| !w.match?(/[֐-׿]/) && w.match?(/[A-Za-z0-9]/) }
    ltr.each_index.map { |i| i > 0 && ltr[i] && ltr[i - 1] }
  end

  # Greedy rows of word indices, each <= max_w; glued words move together (a unit
  # wider than a row gets its own row).
  def self.wrap_rows(widths, space, max_w = MAX_W, glued = nil)
    units = []
    widths.each_index { |i| glued && glued[i] && units.any? ? units[-1] << i : units << [i] }
    rows = []
    cur = []
    w = 0
    units.each do |u|
      uw = row_width(u.map { |i| widths[i] }, space)
      if cur.any? && w + space + uw > max_w
        rows << cur
        cur = []
        w = 0
      end
      w += (cur.empty? ? 0 : space) + uw
      cur.concat(u)
    end
    rows << cur if cur.any?
    rows
  end

  def self.row_width(widths, space)
    widths.sum + space * [widths.length - 1, 0].max
  end

  # {size:, rows:, chunks: [[row index, ...], ...], line_mode:}
  def self.plan_line(line, &measure)
    if line[:words]
      widths, space = measure.call(FONT_SIZE)
      rows = wrap_rows(widths, space, MAX_W, glue(line[:text].split(" ")))
      return { size: FONT_SIZE, rows: rows, chunks: (0...rows.length).each_slice(CHUNK_ROWS).to_a, line_mode: false }
    end
    plan = nil
    LINE_SIZES.each do |s|
      widths, space = measure.call(s)
      rows = wrap_rows(widths, space, MAX_W, glue(line[:text].split(" ")))
      plan = { size: s, rows: rows, chunks: [(0...rows.length).to_a], line_mode: true }
      break if rows.length <= LINE_ROWS
    end
    plan
  end

  # Flat chunk list for the whole show. The block: (line index, size) -> [widths, space].
  def self.build_chunks(lines)
    out = []
    lines.each_with_index do |line, li|
      plan = plan_line(line) { |s| yield(li, s) }
      plan[:chunks].each do |row_ids|
        rows = row_ids.map { |r| plan[:rows][r] }
        first = rows[0][0]
        start = line[:words] ? [line[:start], line[:words][first][:start]].max : line[:start]
        out << { line: li, size: plan[:size], rows: rows, start: start, line_mode: plan[:line_mode] }
      end
    end
    out.each_with_index do |c, i|
      tail = lines[c[:line]][:end] + LINE_TAIL
      nxt = out[i + 1] ? out[i + 1][:start] : tail
      c[:leave] = [[nxt, tail].min, c[:start] + EPS].max
    end
    out
  end

  # [active index or nil, receding index or nil]. Text never shows before its start,
  # leaves by its line's end + 0.4 s or the next chunk; one receding chunk at most.
  def self.crawl_at(chunks, t)
    active = nil
    receding = nil
    chunks.each_with_index do |c, i|
      next if c[:start] > t
      if t < c[:leave]
        active = i
      elsif t < c[:leave] + RECEDE + FADE
        receding = i
      end
    end
    [active, receding]
  end

  # Spoken word index for a chunk's line at t (-1 before the first); nil in line mode.
  def self.word_at(line, t)
    return nil unless line[:words]
    line[:words].rindex { |w| w[:start] <= t } || -1
  end

  def self.ease(f)
    f = f.clamp(0.0, 1.0)
    1 - (1 - f)**3
  end

  # Pixels still below the band while a chunk rises in (0 once risen).
  def self.rise_offset(age)
    return RISE_DIST if age < 0
    (1 - ease(age / RISE)) * RISE_DIST
  end

  # [upward shift px, zoom, opacity] for a chunk that started receding `age` seconds ago.
  def self.recede(age, end_zoom = ZOOM_END, from_zoom = 1.0)
    f = ease(age / RECEDE)
    opacity = OPACITY_END + (255 - OPACITY_END) * (1 - f)
    opacity = OPACITY_END * (1 - ((age - RECEDE) / FADE).clamp(0.0, 1.0)) if age > RECEDE
    [(BAND_TOP - RECEDE_TOP) * f, from_zoom - (from_zoom - end_zoom) * f, opacity.round]
  end

  # Top y of a chunk of n rows in the band, centred on the band's middle.
  def self.chunk_top(n, size)
    [((BAND_TOP + BAND_BOTTOM) / 2.0 - n * row_h(size) / 2.0).round, BOTTOM_LIMIT - n * row_h(size)].min
  end

  # [top, bottom] on screen of a chunk's n rows, zoomed about its centre and shifted down by dy.
  def self.chunk_box(n, size, zoom, dy)
    h = n * row_h(size)
    cy = chunk_top(n, size) + h / 2.0 + dy
    [cy - h * zoom / 2.0, cy + h * zoom / 2.0]
  end

  # Extra (<= 0) upward shift keeping a receding block's bottom GAP px above the active block's top.
  def self.push_above(recede_bottom, active_top)
    [active_top - GAP - recede_bottom, 0.0].min
  end

  #-----------------------------------------------------------------------------
  # Sky: scheduled by passage, never by text. The host asks for the scene info at t.
  #-----------------------------------------------------------------------------

  PASSAGE_SCENES = {
    "P01" => :dome, "P02" => :galaxy, "P03" => :moon, "P04" => :moon_flicker, "P05" => :moon_gas,
    "P06" => :north_star, "P07" => :mars, "P08" => :mars, "P09" => :satellite, "P10" => :satellite_war,
    "P11" => :pullback, "P12" => :meteors, "P13" => :dawn
  }.freeze
  GAP_BEFORE = "P13"            # the silence between the last passage before it and it
  GAP_SCENE = :end_of_world
  END_SCENE = :fade
  BASE_SCENE = :base                                # no timing: stars only
  COUNTDOWN_SCENE = GAP_SCENE
  CROSSFADE = 1.5
  COUNTDOWN = 10
  COUNTDOWN_MIN_GAP = 12.0
  FLASH = 0.3
  SPARKLE = 1.5

  # Layers (Sky sprites) and their opacity 0..1 in each scene.
  SCENE_LAYERS = {
    base: {}, dome: { exit_glow: 1.0 }, galaxy: { galaxy: 1.0 }, moon: { moon: 1.0 },
    moon_flicker: { moon: 1.0, flicker: 1.0 }, moon_gas: { moon: 1.0, gas: 1.0 },
    north_star: { north: 1.0 }, mars: { mars: 1.0 }, satellite: { sat: 1.0, laser: 1.0 },
    satellite_war: { sat: 1.0, laser: 1.0, sat2: 1.0, missiles: 1.0 }, pullback: {},
    meteors: { meteors: 1.0, red: 0.25 }, end_of_world: { meteors: 1.0, red: 1.0 },
    dawn: { blue: 1.0 }, fade: {}
  }.freeze
  SCENE_DRIFT = { pullback: 1.8 }.freeze   # star drift multiplier
  STARS = 180          # Q13: halve these two on a slow cabinet
  METEORS = 12
  TWINKLES = 24

  def self.scene_of(passage)
    PASSAGE_SCENES[passage] || PASSAGE_SCENES[passage.to_s[0, 3]] || BASE_SCENE
  end

  # [[start, end, scene], ...] covering 0..duration; equal neighbours merged.
  def self.scene_segments(timing, duration = AUDIO_DURATION)
    return [[0.0, duration.to_f, BASE_SCENE]] unless timing
    dur = timing[:duration]
    spans = passage_spans(timing[:lines])
    segs = []
    spans.each_with_index do |(pid, st, en), i|
      nxt = spans[i + 1]
      st = 0.0 if i == 0
      if nxt && gap_after?(pid, nxt[0])
        segs << [st, en, scene_of(pid)] << [en, nxt[1], GAP_SCENE]
      elsif nxt
        segs << [st, nxt[1], scene_of(pid)]
      else
        segs << [st, en, scene_of(pid)]
        segs << [en, [dur, en].max, END_SCENE]
      end
    end
    segs.each_with_object([]) do |s, acc|
      if acc.any? && acc[-1][2] == s[2]
        acc[-1][1] = s[1]
      else
        acc << s.dup
      end
    end
  end

  # True between the last passage before GAP_BEFORE and it (P12 or a later P12b alike).
  def self.gap_after?(pid, next_pid)
    next_pid.to_s[0, 3] == GAP_BEFORE && pid.to_s[0, 3] != GAP_BEFORE
  end

  def self.segment_index(segs, t)
    segs.rindex { |s| s[0] <= t } || 0
  end

  def self.scene_at(t, segs)
    segs[segment_index(segs, t)][2]
  end

  # {scene:, since:, until:, progress:, layers: {layer => 0..1}} with the 1.5 s crossfade.
  def self.scene_info(t, segs)
    i = segment_index(segs, t)
    st, en, scene = segs[i]
    mix = i == 0 ? 1.0 : ((t - st) / CROSSFADE).clamp(0.0, 1.0)
    cur = SCENE_LAYERS[scene] || {}
    prev = i > 0 ? (SCENE_LAYERS[segs[i - 1][2]] || {}) : {}
    layers = {}
    (cur.keys | prev.keys).each { |k| layers[k] = (prev[k] || 0.0) * (1 - mix) + (cur[k] || 0.0) * mix }
    span = en - st
    { scene: scene, since: st, until: en, progress: span > 0 ? ((t - st) / span).clamp(0.0, 1.0) : 1.0,
      layers: layers, stars: stars_alpha(scene, t, st, en), drift: SCENE_DRIFT[scene] || 1.0 }
  end

  def self.stars_alpha(scene, t, st, en)
    span = [en - st, EPS].max
    case scene
    when :dome then ((t - st) / span).clamp(0.0, 1.0)
    when END_SCENE then 1.0 - ((t - st) / span).clamp(0.0, 1.0)
    else 1.0
    end
  end

  # Seconds the layer has been continuously on at t (nil when off).
  def self.layer_age(t, segs, layer)
    i = segment_index(segs, t)
    return nil unless (SCENE_LAYERS[segs[i][2]] || {}).key?(layer)
    i -= 1 while i > 0 && (SCENE_LAYERS[segs[i - 1][2]] || {}).key?(layer)
    t - segs[i][0]
  end

  # The silent gap's end (the next passage's start) when it is long enough for the countdown.
  def self.countdown_end(segs)
    seg = segs.find { |s| s[2] == COUNTDOWN_SCENE }
    seg && seg[1] - seg[0] >= COUNTDOWN_MIN_GAP ? seg[1] : nil
  end

  # [digit 10..1, fraction of its second elapsed] in the last 10 s of the gap, else nil.
  def self.countdown_at(t, segs)
    stop = countdown_end(segs)
    return nil unless stop && t >= stop - COUNTDOWN && t < stop
    left = stop - t
    n = left.ceil.clamp(1, COUNTDOWN)
    [n, 1.0 - (left - (n - 1))]
  end

  # Seconds since the countdown reached 0 while the flash/sparkle shows, else nil.
  def self.burst_at(t, segs)
    stop = countdown_end(segs)
    return nil unless stop && t >= stop && t < stop + SPARKLE
    t - stop
  end
end
