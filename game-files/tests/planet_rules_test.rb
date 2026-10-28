# TG10 planetarium: loaded from plugin_rules_test.rb (shares check/$failures).
# PlanetRules is pure; Eyal and Hagar run against stubs; the show runs in its own process.
require "json"
planet_dir = File.join(ROOT, "Plugins/zPlanetarium")
load File.join(planet_dir, "000_rules.rb")
PR = PlanetRules
SPOKEN_MD = File.join(ROOT, "..", "docs", "design", "planetarium-narration-spoken.md")
PLANET_TIMING = JSON.parse(File.read(File.join(ROOT, "Data/planetarium_timing.json"), encoding: "utf-8"))

class PlanetTestBag
  def initialize(items = {}) = (@items = Hash.new(0).merge(items))
  def quantity(i) = @items[i]
  def add(i, n = 1) = (@items[i] += n; true)
  def remove(i, n = 1)
    return false if @items[i] < n
    @items[i] -= n
    true
  end
end

# The 54 rows of the spoken file's '## Lines' table (the text authority, dec:tg-26), byte-exact:
# [id, passage, start, end, text, change column, notes].
def planet_spoken_rows
  inside = false
  File.read(SPOKEN_MD, encoding: "utf-8").split("\n").filter_map do |raw|
    inside = raw.start_with?("## Lines") if raw.start_with?("## ")
    next unless inside && raw.match?(/\A\| (\d+|P\d\d[a-z]) \|/)
    c = raw[2..-3].split(" | ", -1).map(&:strip)
    [c[0], c[1], c[2].to_f, c[3].to_f, c[4], c[5], c[6]]
  end
end

def planet_passages
  planet_spoken_rows.map { |r| r[1] }.uniq
end

#-------------------------------------------------------------------------------
# 1-4: decisions, mutators, normalize
#-------------------------------------------------------------------------------
eyal_want = { none: [:ask, :ask], asked: [:remind, :thanks], got: [:remind, :thanks], delivered: [:warn, :warn] }
hagar_want = { none: [nil, nil], asked: [:give, :has], got: [:give, :has], delivered: [:sent, :sent], shown: [:after, :after] }
bad = []
PR::STAGES.each do |stage|
  [false, true].each_with_index do |has, k|
    st = PR.normalize({ stage: stage })
    e = stage == :shown ? :after_left : eyal_want[stage][k]
    bad << [:eyal, stage, has] unless PR.eyal_decide(st, has) == e
    bad << [:hagar, stage, has] unless PR.hagar_decide(st, has) == hagar_want[stage][k]
  end
end
check(PR.eyal_decide({ stage: :shown, finished: true }, false) == :after_done, "planet: a finished show gives AFTER_DONE")
check(bad.empty?, "planet: the decision table, every stage x has (wrong: #{bad.inspect})")

st = PR.new_state
check(PR.ask!(st) && st[:stage] == :asked && !PR.ask!(st), "planet: ask! moves :none to :asked once")
bag = PlanetTestBag.new
check(PR.give!(st, bag) && st[:stage] == :got, "planet: Hagar gives when the bag lacks the ram")
bag.add(:LITTLERAM)
check(!PR.give!(st, bag), "planet: Hagar never gives a second ram while one is held")
check(!PR.give!(PR.new_state, PlanetTestBag.new), "planet: Hagar gives nothing before Eyal asked")
two = PlanetTestBag.new(LITTLERAM: 2)
s2 = PR.normalize({ stage: :got })
check(PR.deliver!(s2, two) && two.quantity(:LITTLERAM) == 1 && s2[:stage] == :delivered, "planet: deliver! takes exactly one ram")
none = PR.normalize({ stage: :got })
check(!PR.deliver!(none, PlanetTestBag.new) && none[:stage] == :got, "planet: deliver! without a ram fails and keeps the stage")
s3 = PR.normalize({ stage: :delivered })
check(PR.start_show!(s3) && s3[:stage] == :shown && s3[:shows] == 1 && !s3[:finished], "planet: start_show! closes the fetch and counts")
check(PR.start_show!(s3) && s3[:shows] == 2, "planet: a replay counts again")
check(!PR.start_show!(PR.normalize({ stage: :got })), "planet: no show before delivery")
check(PR.finish!(s3) && s3[:finished] && !PR.finish!(PR.new_state), "planet: finish! only after a show started")
check(PR.normalize(nil) == PR.new_state && PR.normalize("x") == PR.new_state && PR.normalize([1]) == PR.new_state,
      "planet: nil or garbage state becomes fresh")
check(PR.normalize({ stage: :party, shows: -2, finished: "yes", junk: 1 }) == PR.new_state, "planet: garbage values are repaired")
kept = { stage: :shown, shows: 3, finished: true }
check(PR.normalize(kept).equal?(kept) && kept == { stage: :shown, shows: 3, finished: true }, "planet: a valid state is unchanged")

#-------------------------------------------------------------------------------
# 5: timing parse
#-------------------------------------------------------------------------------
timing, err = PR.parse_timing(PLANET_TIMING)
check(timing && !timing[:placeholder] && timing[:source].include?("KA71") && timing[:lines].length == 54 &&
      (timing[:duration] - 558.141).abs < 1e-6, "planet: the shipped KA71 timing parses (54 lines, 558.141 s, no placeholder) (#{err})")
sample = { "audio" => "planetarium.ogg", "duration" => 12.0, "granularity" => "word", "source" => "kerem",
           "lines" => [{ "passage" => "P01", "section" => "a", "text" => "א ב", "start" => 1.0, "end" => 2.0,
                         "words" => [{ "w" => "א", "start" => 1.0, "end" => 1.4 }, { "w" => "ב", "start" => 1.5, "end" => 2.0 }] },
                       { "passage" => "P02", "section" => "b", "text" => "ג", "start" => 3.0, "end" => 4.0 }] }
ok, = PR.parse_timing(sample)
check(ok && ok[:lines][0][:words].length == 2 && ok[:lines][1][:words].nil? && !ok[:placeholder],
      "planet: a converted Kerem sample parses; a line without words is line mode")
mutate = lambda do |&blk|
  doc = JSON.parse(JSON.generate(sample))
  blk.call(doc)
  PR.parse_timing(doc)[0].nil?
end
check(mutate.call { |d| d["lines"].reverse! }, "planet: unsorted lines are rejected")
check(mutate.call { |d| d["lines"][0]["end"] = 1.0 }, "planet: start >= end is rejected")
check(mutate.call { |d| d["lines"][0]["words"][1]["end"] = 2.5 }, "planet: a word outside its line is rejected")
check(mutate.call { |d| d["lines"][0].delete("passage") }, "planet: a line without a passage is rejected")
check(mutate.call { |d| d["lines"][0]["passage"] = "Q01" }, "planet: an unknown passage is rejected")
check(PR.parse_timing({ "lines" => [] })[0].nil? && PR.parse_timing("x")[0].nil?, "planet: no lines or no object is rejected")

#-------------------------------------------------------------------------------
# 9 + 6: wrap, chunks, crawl timing (a fixed-width fake measure, 9 px per char)
#-------------------------------------------------------------------------------
measure = ->(words, size) { [words.map { |w| w.length * size * 9 / 22 }, size * 4 / 22] }
lines = timing[:lines]
chunks = PR.build_chunks(lines) { |li, size| measure.call(lines[li][:text].split(" "), size) }
widths_ok = chunks.all? do |c|
  w = lines[c[:line]][:text].split(" ")
  c[:rows].all? { |r| ws, sp = measure.call(r.map { |i| w[i] }, c[:size]); PR.row_width(ws, sp) <= PR::MAX_W || r.length == 1 }
end
check(widths_ok && chunks.all? { |c| c[:rows].length <= PR::CHUNK_ROWS }, "planet: rows <= 464 px, chunks <= 3 rows")
p10 = chunks.select { |c| lines[c[:line]][:passage] == "P10" }
check(p10.length >= 2, "planet: P10's 49-word sentence splits into several chunks in word mode (#{p10.length})")
joined = lines.each_index.map do |li|
  w = lines[li][:text].split(" ")
  chunks.select { |c| c[:line] == li }.flat_map { |c| c[:rows] }.map { |r| r.map { |i| w[i] }.join(" ") }.join(" ")
end
check(joined == lines.map { |l| l[:text] }, "planet: the chunks' rows rebuild every line exactly")
line_mode = { passage: "P10", text: lines.find { |l| l[:passage] == "P10" }[:text], start: 0, end: 9, words: nil }
wide = ->(s) { measure.call(line_mode[:text].split(" "), s) }
plan = PR.plan_line(line_mode, &wide)
check(plan[:line_mode] && plan[:chunks].length == 1 && plan[:size] < PR::FONT_SIZE && plan[:rows].length <= PR::LINE_ROWS,
      "planet: line mode shrinks the font to fit <= 6 rows, one block (size #{plan[:size]}, #{plan[:rows].length} rows)")
tiny = ->(_s) { [Array.new(300, 40), 4] }
plan = PR.plan_line({ text: "x", words: nil }, &tiny)
check(plan[:size] == PR::LINE_SIZES.last && plan[:chunks].length == 1, "planet: line mode stops shrinking at the base size (#{PR::BASE_SIZE} px)")

early = []
late = []
step = 0.05
(0..(timing[:duration] / step).to_i).each do |k|
  t = k * step
  a, = PR.crawl_at(chunks, t)
  next unless a
  c = chunks[a]
  line = lines[c[:line]]
  early << t if t < c[:start] || t < line[:start]
  nxt = chunks[a + 1]
  late << t if t >= line[:end] + PR::LINE_TAIL || (nxt && t >= nxt[:start])
end
check(early.empty?, "planet: no text before its line/word start (#{early.first(3).inspect})")
check(late.empty?, "planet: text is gone by end + 0.4 s and never past the next chunk (#{late.first(3).inspect})")
first = chunks[0][:start]
check(PR.crawl_at(chunks, first - 0.01) == [nil, nil] && PR.crawl_at(chunks, first)[0] == 0, "planet: the first chunk appears exactly at its start")
gap_t = 500.0
check(PR.crawl_at(chunks, gap_t) == [nil, nil], "planet: the band is empty in the silent gap")
check(PR.rise_offset(0) > 0 && PR.rise_offset(PR::RISE).abs < 1e-9 && PR.rise_offset(-1) > 0, "planet: rows rise in over 0.25 s")
r0, r1, r2 = PR.recede(0), PR.recede(PR::RECEDE), PR.recede(PR::RECEDE + PR::FADE)
check(r0 == [0.0, 1.0, 255] && r1[0] == 120 && (r1[1] - PR::ZOOM_END).abs < 1e-9 && r1[2] == 110 && r2[2] == 0,
      "planet: receding rows move 120 px up, zoom 1.0 -> base size (#{PR::ZOOM_END.round(3)}), opacity 255 -> 110 -> 0")
check(PR.word_at(lines[0], lines[0][:start] - 1) == -1 && PR.word_at(lines[0], lines[0][:end]) == lines[0][:words].length - 1 &&
      PR.word_at({ words: nil }, 1).nil?, "planet: word_at counts spoken words; nil in line mode")

#-------------------------------------------------------------------------------
# TG38: the line being spoken is drawn larger; pure choice, ease and spacing
#-------------------------------------------------------------------------------
word_li = lines.index { |l| l[:words] }
low_li = lines.index { |l| l[:words].nil? }
check(word_li && low_li, "planet: the timing has word-timed and line-timed (low_confidence) lines")
bad = []
[word_li, low_li].each do |li|
  l = lines[li]
  mid = (l[:start] + l[:end]) / 2
  bad << [:mid, li] unless PR.active_line(chunks, mid) == li
  bad << [:before, li] if PR.active_line(chunks, l[:start] - 0.01) == li
  bad << [:after, li] if PR.active_line(chunks, l[:end] + PR::LINE_TAIL + 0.01) == li
end
check(bad.empty?, "planet: active_line is the line being spoken, word-timed and line-timed alike (#{bad.inspect})")
check(PR.active_line(chunks, 0.0).nil? && PR.active_line(chunks, 500.0).nil?, "planet: no active line before the first line or in the silent gap")
wrong = []
(0..(timing[:duration] / 0.05).to_i).each do |k|
  t = k * 0.05
  al = PR.active_line(chunks, t)
  next unless al
  wrong << t unless t >= lines[al][:start] && t < lines[al][:end] + PR::LINE_TAIL
end
check(wrong.empty?, "planet: the active line's time span always holds t (#{wrong.first(3).inspect})")
check(PR::FONT_SIZE >= (PR::BASE_SIZE * 1.35).floor && PR::FONT_SIZE <= PR::BASE_SIZE * 1.5 &&
      PR::LINE_SIZES.first == PR::FONT_SIZE && PR::LINE_SIZES.min >= PR::BASE_SIZE,
      "planet: active size #{PR::FONT_SIZE} px is 1.35-1.5x the base #{PR::BASE_SIZE}; line mode never goes under the base")
rz = PR.rest_zoom(PR::FONT_SIZE)
z = [0.0, 0.05, 0.1, 0.15, 0.2, 0.5].map { |a| PR.active_zoom(a, rz) }
check((z[0] - rz).abs < 1e-9 && (z[4] - 1.0).abs < 1e-9 && z == z.sort && z[1] > z[0] && z[1] < z[3] && PR.rest_zoom(PR::BASE_SIZE) == 1.0,
      "planet: the size grows monotonically from the base size to the active size in #{PR::GROW} s, no jump")
# no overlap: sweep every chunk change; the receding block never reaches the active one
over = []
hi_px = []
chunks.each_with_index do |c, i|
  n = c[:rows].length
  rest = PR.rest_zoom(c[:size])
  next unless i > 0
  prev = chunks[i - 1]
  pn = prev[:rows].length
  prest = PR.rest_zoom(prev[:size])
  0.step(2.1, 0.05) do |age|
    a_dy = PR.rise_offset(age)
    a_zoom = PR.active_zoom(age, rest)
    a_top = PR.chunk_box(n, c[:size], a_zoom, a_dy)[0]
    shift, r_zoom, = PR.recede(age, prest, 1.0)
    r_dy = -shift
    r_box = PR.chunk_box(pn, prev[:size], r_zoom, r_dy)
    settled = r_box[1] <= a_top - PR::GAP + 1e-6
    over << [i, age, :settled] if age >= PR::RECEDE && !settled   # it clears the active block by itself
    r_dy += PR.push_above(r_box[1], a_top)
    over << [i, age] if PR.chunk_box(pn, prev[:size], r_zoom, r_dy)[1] > a_top - PR::GAP + 1e-6
    hi_px << [i, age] if PR.chunk_box(n, c[:size], 1.0, 0)[1] > 384
  end
end
check(over.empty?, "planet: the receding block stays GAP px above the active one at every step, and clears it unaided once receded (#{over.first(3).inspect})")
check(hi_px.empty?, "planet: a resting active block ends above the screen bottom (#{hi_px.first(3).inspect})")
all_in = chunks.all? { |c| PR.chunk_box(c[:rows].length, c[:size], 1.0, 0)[1] <= PR::BOTTOM_LIMIT }
check(all_in, "planet: every resting block fits above the screen bottom")

#-------------------------------------------------------------------------------
# 7: scenes and countdown
#-------------------------------------------------------------------------------
segs = PR.scene_segments(timing)
spans = PR.passage_spans(lines)
check(spans.map(&:first) == planet_passages && planet_passages == (1..13).map { |n| format("P%02d", n) },
      "planet: the timing covers P01..P13 in order, one span each (added lines carry their parent passage)")
start_of = spans.to_h { |p, s, _| [p, s] }
end_of = spans.to_h { |p, _, e| [p, e] }
wrong = PR::PASSAGE_SCENES.reject { |p, sc| PR.scene_at(start_of[p] + 0.01, segs) == sc }.keys
check(wrong.empty?, "planet: each passage shows its scene from its first line (#{wrong.inspect})")
check(PR.scene_at(0, segs) == :dome && PR.scene_at(end_of["P12"] + 0.01, segs) == :end_of_world &&
      PR.scene_at(start_of["P13"] - 0.01, segs) == :end_of_world && PR.scene_at(end_of["P13"] + 0.01, segs) == :fade,
      "planet: dome from 0, end_of_world exactly between P12 and P13, fade after P13")
check(PR.scene_at(end_of["P01"] + 1, segs) == :dome && PR.scene_at(end_of["P07"] + 0.2, segs) == :mars,
      "planet: a pause between passages keeps the scene; P07-P08 is one mars scene")
check(segs.each_cons(2).all? { |a, b| a[1] == b[0] && a[2] != b[2] } && segs[0][0] == 0 && segs[-1][1] == timing[:duration],
      "planet: scene segments cover the whole show without holes")
info = PR.scene_info(start_of["P03"] + 0.75, segs)
check(info[:scene] == :moon && (info[:layers][:moon] - 0.5).abs < 1e-6 && (info[:layers][:galaxy] - 0.5).abs < 1e-6,
      "planet: scene changes crossfade over 1.5 s")
check(PR.scene_info(1.0, segs)[:stars] < 0.1 && PR.scene_info(start_of["P02"] + 2, segs)[:stars] == 1.0,
      "planet: stars fade in over P01")
stop = start_of["P13"]
check(PR.countdown_at(stop - 10.01, segs).nil? && PR.countdown_at(stop - 10, segs)[0] == 10 &&
      PR.countdown_at(stop - 0.01, segs)[0] == 1 && PR.countdown_at(stop, segs).nil?,
      "planet: the countdown is 10..1 in the last 10 s, ending exactly at P13's start")
digits = (0..999).map { |k| PR.countdown_at(stop - 10 + k / 100.0, segs) }.compact.map(&:first).uniq
check(digits == (1..10).to_a.reverse, "planet: every digit 10..1 shows once, in order")
check(PR.burst_at(stop, segs) == 0 && PR.burst_at(stop - 0.1, segs).nil? && PR.burst_at(stop + PR::SPARKLE, segs).nil?,
      "planet: the flash and sparkle ring start at 0")
short = JSON.parse(JSON.generate(PLANET_TIMING))
short["lines"].select { |l| l["passage"] == "P13" }.each do |l|
  shift = l["start"] - (end_of["P12"] + 8)
  l["start"] -= shift
  l["end"] -= shift
  (l["words"] || []).each { |w| w["start"] -= shift; w["end"] -= shift }
end
short_segs = PR.scene_segments(PR.parse_timing(short)[0])
check(PR.countdown_end(short_segs).nil? && PR.countdown_at(end_of["P12"] + 5, short_segs).nil?, "planet: no countdown in a gap under 12 s")
split = JSON.parse(JSON.generate(PLANET_TIMING))
p12 = split["lines"].select { |l| l["passage"] == "P12" }
p12[-1]["passage"] = "P12b"
split_segs = PR.scene_segments(PR.parse_timing(split)[0])
gaps = split_segs.select { |sg| sg[2] == :end_of_world }
check(p12.length > 1 && gaps == [[end_of["P12"], start_of["P13"], :end_of_world]] && PR.countdown_end(split_segs) == start_of["P13"],
      "planet: a P12b keeps one gap, from the last passage before P13 to P13 (#{gaps.inspect})")
check(PR.gap_after?("P12", "P13") && PR.gap_after?("P12b", "P13") && !PR.gap_after?("P12", "P12b") && !PR.gap_after?("P13", "P13b"),
      "planet: the gap is keyed on the passage before P13, not on P12")
gap_segs = segs.select { |sg| sg[2] == :end_of_world }
check(gap_segs == [[458.0, 534.68, :end_of_world]] && stop == 534.68 && stop - PR::COUNTDOWN > 489.841 && stop - PR::COUNTDOWN < 533.732,
      "planet: one gap 458.0..534.68; the countdown starts inside the digital silence and ends at P13's first word (#{gap_segs.inspect})")
check(segs[-1] == [557.86, timing[:duration], :fade] && lines[-1][:text] == "זהו, זה הסוף." &&
      PR.crawl_at(chunks, 557.0)[0] == chunks.length - 1 && PR.scene_at(545.0, segs) == :dawn,
      "planet: P13x/P13y stay in the dawn scene, the show's last line is P13y, then the fade to the end")
check(PR.scene_segments(nil, 100.0) == [[0.0, 100.0, :base]] && PR.countdown_at(50, PR.scene_segments(nil)).nil?,
      "planet: no timing: stars only, no countdown")
check(PR.layer_age(start_of["P05"] + 2, segs, :moon) > start_of["P05"] - start_of["P03"],
      "planet: the moon keeps its age across P03-P05")

#-------------------------------------------------------------------------------
# 8: clock
#-------------------------------------------------------------------------------
c = PR.new_clock(true)
[10.0, 20.0, 30.5].each { |p| PR.clock_tick(c, p, 60) }
check(c[:mode] == :audio && c[:t] == 30.5, "planet clock: follows Audio.bgm_pos")
PR.clock_tick(c, 30.3, 60)
check(c[:t] == 30.5 && !c[:looped], "planet clock: a small jitter back is ignored")
PR.clock_tick(c, 0.2, 60)
check(PR.clock_done?(c, 600), "planet clock: a jump back (mkxp-z loop) is done")
c = PR.new_clock(true)
switched = (1..60).map { PR.clock_tick(c, 0.0, 60) }
check(switched.count(:frames) == 1 && switched.compact == [:frames] && c[:mode] == :frames,
      "planet clock: stuck at 0 for 60 frames falls back to frames")
check((c[:t] - 1.0).abs < 1e-9, "planet clock: the stuck frames count on the frame clock")
# A slow cabinet: the position reads 0 for 90 frames, then moves (late start).
c = PR.new_clock(true)
ticks = (1..90).map { PR.clock_tick(c, 0.0, 60) }
check(c[:mode] == :frames && (c[:t] - 1.5).abs < 1e-9, "planet clock late: 90 frames at 0 run on frames (t 1.5)")
ticks << PR.clock_tick(c, 0.02, 60)
check(ticks.compact == %i[frames audio] && c[:mode] == :audio && (c[:t] - 0.02).abs < 1e-9,
      "planet clock late: the first moving position re-anchors on the audio (t follows the recording)")
pos = 0.02
300.times { PR.clock_tick(c, pos += 1.0 / 60, 60) }
check(c[:mode] == :audio && (c[:t] - pos).abs < 1e-9 && !c[:looped], "planet clock late: then follows the audio, no false loop")
PR.clock_tick(c, 0.1, 60)
check(PR.clock_done?(c, 600), "planet clock late: a loop after re-anchoring still ends the show")
# Position lost mid-show (nil) runs on frames from where it was, and comes back.
c = PR.new_clock(true)
PR.clock_tick(c, 10.0, 60)
r = (1..30).map { PR.clock_tick(c, nil, 60) }
check(r.compact == [:frames] && (c[:t] - 10.5).abs < 1e-9, "planet clock: a lost position continues on frames from its last time")
check(PR.clock_tick(c, 10.6, 60) == :audio && (c[:t] - 10.6).abs < 1e-9, "planet clock: a position that returns re-anchors")
# On frames, a loop of the recording is still caught (it never restarts unnoticed).
c = PR.new_clock(true)
PR.clock_tick(c, 557.9, 60)
PR.clock_tick(c, nil, 60)
check(c[:mode] == :frames && !PR.clock_done?(c, 558.141), "planet clock loop: on frames near the end")
PR.clock_tick(c, 0.05, 60)
check(PR.clock_done?(c, 558.141) && c[:looped], "planet clock loop: a jump back read on frames ends the show")
c = PR.new_clock(false)
10.times { PR.clock_tick(c, 5.0, 60) }
check(c[:mode] == :frames && (c[:t] - 10.0 / 60).abs < 1e-9, "planet clock: a silent show never reads a position")
c = PR.new_clock(false)
120.times { PR.clock_tick(c, nil, 60) }
check(c[:mode] == :frames && (c[:t] - 2.0).abs < 1e-9 && PR.clock_done?(c, 2.0), "planet clock: frame clock without audio")
c = PR.new_clock(true)
PR.clock_tick(c, nil, 60)
check(c[:mode] == :frames, "planet clock: no position at all -> frames")
c = PR.new_clock(true, 100.0)
PR.clock_tick(c, 0.5, 60)
check((c[:t] - 100.5).abs < 1e-9, "planet clock: a debug start reading a relative position is shifted")
c = PR.new_clock(true, 100.0)
PR.clock_tick(c, 100.5, 60)
check((c[:t] - 100.5).abs < 1e-9, "planet clock: a debug start reading an absolute position is not shifted")
c = PR.new_clock(false, 40.0)
60.times { PR.clock_tick(c, nil, 60) }
check((c[:t] - 41.0).abs < 1e-9, "planet clock: a silent debug start counts from its offset")

#-------------------------------------------------------------------------------
# 10-11: static: writers, layers, keys, narration
#-------------------------------------------------------------------------------
planet_src = Dir.glob(File.join(planet_dir, "*.rb")).sort.to_h { |f| [File.basename(f, ".rb"), File.read(f, encoding: "utf-8")] }
writers = planet_src.reject { |n, _| n == "000_rules" }.select { |_, s| s.match?(/\b(st|state)\[:\w+\]\s*=(?!=)|planet_quest\[/) }.keys
check(planet_src.length == 7 && writers.empty?, "planet: only PlanetRules writes the quest state (#{writers.inspect})")
check(!planet_src["000_rules"].gsub(/#.*$/, "").match?(/\b(pb[A-Z]\w*|Graphics|Audio|Sprite|Bitmap|\$game_\w+|\$bag|\$PokemonGlobal|_INTL)\b/),
      "planet: 000_rules makes no engine calls")
upward = {
  "001_state" => /Planet::(Sky|Crawl|Show)|pbPlanetEyal|after_talk|\bsay\(|dt_planet/,
  "002_sky" => /Crawl|Show|Planet\.state|PlanetRules\.\w+!|pbPlanetEyal|after_talk|pbMessage|dt_planet/,
  "003_crawl" => /Sky|Show|Planet\.state|PlanetRules\.\w+!|pbPlanetEyal|after_talk|pbMessage|dt_planet/,
  "004_show" => /Planet\.state|PlanetRules\.\w+!|pbPlanetEyal|after_talk|eyal_talk|\bsay\(|dt_planet/,
  "005_talk" => /dt_planet|MenuHandlers|Planet\.reset|debug_/
}
hits = upward.select { |n, re| planet_src[n].match?(re) }.keys
check(hits.empty?, "planet: units only call downward (upward calls in #{hits.inspect})")
check(!planet_src["004_show"].match?(/PASSAGE|"P\d\d"|:dome|:moon|:end_of_world/) &&
      !planet_src["002_sky"].match?(/"P\d\d"/) && !planet_src["003_crawl"].match?(/"P\d\d"|passage/),
      "planet: the scene, sky and crawl never branch on a passage id")
check(!planet_src.values.join.match?(/_INTL\([^)]*(narration|line\[:text\]|:text)/), "planet: narration never goes through _INTL")
check(planet_src["005_talk"].include?("$game_map.map_id == HAGAR_MAP") && planet_src["005_talk"].include?('HAGAR = "b19b1f15"') &&
      !planet_src["005_talk"].match?(/EYAL.*after_talk|when EYAL/), "planet: the pbDesertTalk hook keys on map 95 + Hagar only, never Eyal")
tr = JSON.parse(File.read(File.join(ROOT, "PBS/translations.json"), encoding: "utf-8"))["translations"]
keys = planet_src.values.join.scan(/\bPLANET_[A-Z0-9_]+/).uniq
all_keys = tr.keys.grep(/\APLANET_/) + %w[LITTLERAM LITTLERAM_DESC]
missing = (keys | all_keys).reject { |k| tr.dig(k, "he").to_s != "" && tr.dig(k, "en").to_s != "" }
check(keys.length >= 24 && all_keys.length == 28 && missing.empty?, "planet: every PLANET_ key used and the 28 spec keys have he and en (#{keys.length} used, missing #{missing.inspect})")
warn_he = tr.dig("PLANET_EYAL_WARN", "he").to_s
check(warn_he.include?("עשר דקות") && warn_he.include?("לשכב על הקרקע") && !warn_he.match?(/[״"]\z|\A[״"]/),
      "planet: WARN keeps both facts (ten minutes, lie on the ground), no outer quote marks")
check(tr.dig("LITTLERAM", "he") == "איל קטן" && tr.dig("LITTLERAM_DESC", "he").to_s.include?("לא לבלבל עם אייל"),
      "planet: the item is 'איל קטן' (one yod)")
spoken = planet_spoken_rows
shipped = PLANET_TIMING["lines"]
check(spoken.length == 54 && shipped.map { |l| l["text"].b } == spoken.map { |r| r[4].b } &&
      shipped.map { |l| [l["id"], l["passage"]] } == spoken.map { |r| r[0, 2] },
      "planet: the on-screen lines equal planetarium-narration-spoken.md byte for byte (54 lines, ids, passages, order)")
texts = shipped.map { |l| l["text"] }.join
check(!texts.match?(/\[|\]|מבוטא|rotter/), "planet: no bracket, 'מבוטא' or 'rotter' in any narration text")
check(texts.include?("Nature Fictional Astrology") && texts.include?("Rotter.net"), "planet: the spoken Latin runs are on screen")
words_ok = shipped.all? { |l| l["words"].nil? || l["words"].map { |w| w["w"] }.join(" ") == l["text"] }
check(words_ok && shipped.count { |l| l["words"] } == 50, "planet: each aligned line's words join to its text (50 word lines)")
added = { "P06x" => ["P06", 216.06, 218.54], "P09x" => ["P09", 334.60, 336.36], "P13x" => ["P13", 537.52, 544.60],
          "P13y" => ["P13", 556.96, 557.86] }
got = shipped.select { |l| added.key?(l["id"]) }
check(got.map { |l| l["id"] } == added.keys && got.all? { |l| added[l["id"]] == [l["passage"], l["start"], l["end"]] && l["words"].nil? && l["low_confidence"] },
      "planet: the 4 added lines sit at their times under their parent passage, line mode, low confidence")
ends = { "3" => 17.78, "25" => 262.0, "47" => 458.0 }
check(ends.all? { |id, e| (l = shipped.find { |x| x["id"] == id }) && l["end"] == e && l["words"][-1]["end"] == e },
      "planet: lines 3, 25 and 47 end at the real speech end (17.78, 262.0, 458.0), last word included")
check(shipped.count { |l| l["low_confidence"] } == 17 && shipped.each_cons(2).all? { |a, b| b["start"] >= a["end"] },
      "planet: Kerem's 13 low_confidence lines + the 4 added; no line overlaps the next")

#-------------------------------------------------------------------------------
# 12: Eyal and Hagar with stubs (the show itself is stubbed: its own process below)
#-------------------------------------------------------------------------------
$planet_log = []
$planet_picks = []
$planet_confirm = []
def pbMessage(msg, commands = nil, _cancel = 0)
  $planet_log << [msg, DesertTalk.name_key]
  return nil unless commands
  raise "planet test: no scripted choice for #{msg}" if $planet_picks.empty?
  $planet_picks.shift
end
def _INTL(m, *a) = a.empty? ? m : "#{m}|#{a.join(',')}"
def pbConfirmMessage(m) = ($planet_log << [m, nil]; $planet_confirm.shift)
def pbReceiveItem(i, n = 1) = ($planet_log << [:got, i, DesertTalk.name_key]; $bag.add(i, n))
PlanetFakeMap = Struct.new(:map_id)
module Planet
  class Show
    @script = []
    @running = false
    class << self; attr_accessor :script, :running; end
    def self.running? = @running
    def self.prepare(from: 0.0)
      r = script.shift
      r.nil? ? nil : new(r)
    end
    def initialize(result) = (@result = result)
    def play = ($planet_log << [:show, Planet.state[:stage], Planet.state[:shows]]; @result)
  end
end
module MenuHandlers
  def self.add(_menu, id, _h) = (($planet_menu ||= []) << id)
end unless defined?(MenuHandlers)
class PokemonGlobalMetadata; end
%w[001_state 005_talk 006_debug].each { |f| load File.join(planet_dir, "#{f}.rb") }
saved = [$game_map, $bag, $PokemonGlobal]
$PokemonGlobal = PokemonGlobalMetadata.new
$bag = PlanetTestBag.new
eyal = lambda do |picks = [], shows = []|
  $planet_log.clear
  $planet_picks = picks
  Planet::Show.script = shows
  $game_map = PlanetFakeMap.new(33)
  pbPlanetEyal
  $planet_log.dup
end
hagar = lambda do |map_id = 95|
  $planet_log.clear
  $game_map = PlanetFakeMap.new(map_id)
  pbDesertTalk("b19b1f15")
  $planet_log.dup
end
msgs = ->(log) { log.map(&:first) }
st = -> { $PokemonGlobal.planet_quest }

check(msgs.call(hagar.call).length == 1 && st.call[:stage] == :none, "planet Q3: Hagar before Eyal says only her own line")
log = eyal.call
check(msgs.call(log) == %w[PLANET_EYAL_ASK_1 PLANET_EYAL_ASK_2 PLANET_EYAL_ASK_3] && log.all? { |_, n| n == "NAME_0F0FDCF5" } &&
      st.call[:stage] == :asked, "planet Q1: Eyal asks (3 lines, his name plate), stage asked")
check(msgs.call(eyal.call) == ["PLANET_EYAL_REMIND"], "planet Q1: without the ram Eyal reminds")
check(msgs.call(hagar.call(93)).length == 1 && $bag.quantity(:LITTLERAM) == 0, "planet Q3: Hagar at the party gives her own line only")
log = hagar.call
check(msgs.call(log)[1, 3] == ["PLANET_HAGAR_GIVE_1", "PLANET_HAGAR_GIVE_2", :got] && log[1][1] == "NAME_B19B1F15" &&
      log[3][2].nil? && $bag.quantity(:LITTLERAM) == 1 && st.call[:stage] == :got,
      "planet Q1: Hagar says her line, GIVE_1..2, then the ram with no name plate; stage got")
check(msgs.call(hagar.call)[1..] == ["PLANET_HAGAR_HAS"] && $bag.quantity(:LITTLERAM) == 1, "planet Q1: Hagar again: HAS, no second ram")
log = eyal.call([1])
check(msgs.call(log) == %w[PLANET_EYAL_THANKS PLANET_EYAL_TAKEN PLANET_EYAL_WARN PLANET_EYAL_START_ASK PLANET_EYAL_LATER] &&
      log[1][1].nil? && $bag.quantity(:LITTLERAM) == 0 && st.call[:stage] == :delivered,
      "planet Q1: Eyal takes the ram (TAKEN has no plate), warns, Later ends the talk")
check(msgs.call(eyal.call([1])) == %w[PLANET_EYAL_WARN PLANET_EYAL_START_ASK PLANET_EYAL_LATER], "planet Q1: next talk goes straight to WARN")
log = eyal.call([0], [])
check(msgs.call(log).last == "PLANET_EYAL_BROKEN" && st.call[:stage] == :delivered && st.call[:shows] == 0,
      "planet Q7: no timing and no audio: BROKEN, the stage stays delivered")
check(msgs.call(hagar.call)[1..] == ["PLANET_HAGAR_SENT"], "planet: Hagar asks about the planetarium after delivery")
Planet::Show.running = true
log = eyal.call([0], [:done])
check(!log.any? { |e| e[0] == :show } && st.call == { stage: :delivered, shows: 0, finished: false } && Planet::Show.script == [:done],
      "planet: a show already running: Eyal does not prepare or play, the state does not move")
Planet::Show.running = false
log = eyal.call([0], [:done])
check(log.include?([:show, :shown, 1]) && msgs.call(log).last == "PLANET_EYAL_AFTER_DONE" && st.call == { stage: :shown, shows: 1, finished: true },
      "planet Q1: Now: start_show! before the scene, AFTER_DONE after, finished set")
log = eyal.call([1])
check(msgs.call(log) == %w[PLANET_EYAL_AFTER_DONE PLANET_EYAL_REPLAY_ASK PLANET_EYAL_REPLAY_NO], "planet Q1: later visits offer a replay")
log = eyal.call([0, 0], [:left])
check(msgs.call(log)[0, 3] == %w[PLANET_EYAL_AFTER_DONE PLANET_EYAL_REPLAY_ASK PLANET_EYAL_WARN] &&
      msgs.call(log).last == "PLANET_EYAL_AFTER_LEFT" && st.call[:shows] == 2 && st.call[:finished],
      "planet Q4: a replay warns first; leaving early says AFTER_LEFT and keeps finished")
check(msgs.call(hagar.call)[1..] == ["PLANET_HAGAR_AFTER"] && $bag.quantity(:LITTLERAM) == 0, "planet: Hagar after the show")
$PokemonGlobal.planet_quest = { stage: :delivered, shows: 0, finished: false }
log = eyal.call([0], [:left])
check(msgs.call(log).last == "PLANET_EYAL_AFTER_LEFT" && st.call[:stage] == :shown && !st.call[:finished],
      "planet Q4: a first show left early is not finished")
check(msgs.call(eyal.call([1]))[0] == "PLANET_EYAL_AFTER_LEFT", "planet: Eyal remembers leaving early")
$PokemonGlobal.planet_quest = { stage: :got, shows: 0, finished: false }
log = hagar.call
check(msgs.call(log).include?(:got) && $bag.quantity(:LITTLERAM) == 1, "planet Q2: a save with stage got and no ram: Hagar gives it again (repair)")
check($planet_menu.nil? || %i[dt_planet_stage dt_planet_ram dt_planet_show dt_planet_from dt_planet_info dt_planet_reset].all? { |i| $planet_menu.include?(i) },
      "planet: the F9 entries are registered")
$PokemonGlobal.planet_quest = "garbage"
check(st.call == PR.new_state, "planet Q2: a broken saved value loads as a fresh state")
$game_map, $bag, $PokemonGlobal = saved
DesertTalk.clear_speaker if DesertTalk.respond_to?(:clear_speaker)

# The modal show runs in its own process (fake Bitmap/Sprite/Audio/Input/clock).
require "rbconfig"
smoke = IO.popen([RbConfig.ruby, File.join(__dir__, "planet_show_smoke.rb")], err: [:child, :out], &:read)
smoke_fails = smoke.lines.grep(/FAIL|\.rb:\d+:in|Error \(/).map(&:strip)
check($?.success? && smoke_fails.empty?, "planet: show smoke run passes (#{smoke_fails.first(3).inspect})")
