# TG7 bags: loaded at the end of plugin_rules_test.rb (shares check/$failures).
# BagsRules is pure; the hooks run against small stubs (no engine, no scene).
require "json"
bags_dir = File.join(ROOT, "Plugins/zBags")
load File.join(bags_dir, "000_rules.rb")
BR = BagsRules

# PokemonBag-like: remove fails (false) when short, like the real bag.
class BagsTestBag
  attr_reader :items
  def initialize(items = {}) = (@items = Hash.new(0).merge(items))
  def quantity(i) = @items[i]
  def add(i, n = 1) = (@items[i] += n; true)
  def remove(i, n = 1)
    return false if @items[i] < n
    @items[i] -= n
    true
  end
end

# 9: normalize (old saves)
check(BR.normalize(nil) == BR.new_state && BR.normalize("x") == BR.new_state, "bags: nil or garbage state becomes a fresh quest")
partial = BR.normalize({ inbar: :asked })
check(partial[:inbar] == :asked && partial[:payoff_given] == false && partial[:bills_from_bags] == 0, "bags: a missing key is filled in")
check(BR.normalize({ inbar: :party, bills_from_bags: -3 })[:inbar] == :none, "bags: an unknown :inbar becomes :none")
kept = { inbar: :done, payoff_given: true, toga_gift: true, toga_desert: false, bills_from_bags: 2 }
check(BR.normalize(kept).equal?(kept) && kept[:payoff_given], "bags: a valid state is kept as the same object")

# 2: inbar_decide
st = BR.new_state
check(BR.inbar_decide(st, 5) == :intro, "bags: first talk is the intro")
st[:inbar] = :asked
check(BR.inbar_decide(st, 0) == :short && BR.inbar_decide(st, 1) == :short, "bags: 0 or 1 bags is short")
check(BR.inbar_decide(st, 2) == :offer && BR.inbar_decide(st, 7) == :offer, "bags: 2 or more is the offer")
st[:inbar] = :done
check(BR.inbar_decide(st, 0) == :party, "bags: after the hand-over it is the party")

# Only BagsRules moves :inbar; ask! is the :none -> :asked step.
st = BR.new_state
check(BR.ask!(st) && st[:inbar] == :asked && !BR.ask!(st), "bags: ask! moves :none to :asked once")
done = BR.normalize({ inbar: :done })
check(!BR.ask!(done) && done[:inbar] == :done, "bags: ask! never moves a finished quest back")
hook_files = Dir.glob(File.join(bags_dir, "*.rb")).sort.reject { |f| f.end_with?("000_rules.rb") }
hooks_src = hook_files.map { |f| File.read(f, encoding: "utf-8") }.join("\n")
check(hook_files.length == 9 && !hooks_src.match?(/st(ate)?\[:\w+\]\s*=(?!=)/), "bags: no file outside BagsRules writes a quest-state key")
# Layers: 000 <- 001 <- 005 <- 009 <- 008 <- 003 (Song.start); 002, 004 <- 009; 006 overlay <- 000 only;
# 007_debug on top. A unit may not name anything in a layer above it.
above_low = /pbBagsToga|pbBagsUnicorn|ItemHandlers|bags_pbDesertTalk|Bags\.reset|dt_bags/
upward = {
  "001_state" => /\b(Song|Duo)\.|\bsay\(|\bchoose\(|walk_together|unicorn_event|\breset\b|#{above_low}/,
  "002_items" => /\bSong\.|pbBagsUnicorn|pbBagsToga|Bags\.reset|dt_bags/,
  "004_toga" => /\bSong\.|pbBagsUnicorn|Bags\.reset|dt_bags|MenuHandlers/,
  "005_unicorns" => /\b(Song|Duo)\.|\bsay\(|\bchoose\(|after_song|#{above_low}/,
  "006_song_overlay" => /\bDuo\.|Song\.(start|stop|current|running|active)|after_song|after_talk|#{above_low}/,
  "009_duo" => /\bSong\.|after_song|after_talk|#{above_low}/,
  "008_song" => /after_song|after_talk|pbBagsUnicorn|pbBagsToga|Bags\.reset/,
  "003_talk_hooks" => /Bags\.reset|dt_bags|MenuHandlers/
}
upward_hits = upward.select { |n, re| File.read(File.join(bags_dir, "#{n}.rb"), encoding: "utf-8").match?(re) }.keys
check(upward_hits.empty?, "bags: units only call downward, no dependency cycle (upward calls in #{upward_hits.inspect})")

# 3: hand-over
[2, 5].each do |n|
  s = BR.normalize({ inbar: :asked })
  bag = BagsTestBag.new(SURPRISEBAG: n)
  ok = BR.hand_over!(s, bag)
  check(ok && bag.quantity(:SURPRISEBAG) == n - 2 && s[:inbar] == :done, "bags: hand-over takes exactly 2 of #{n}")
  check(!BR.hand_over!(s, bag) && bag.quantity(:SURPRISEBAG) == n - 2, "bags: a second hand-over of #{n} is a no-op")
end
one = BagsTestBag.new(SURPRISEBAG: 1)
s1 = BR.normalize({ inbar: :asked })
check(!BR.hand_over!(s1, one) && one.quantity(:SURPRISEBAG) == 1 && s1[:inbar] == :asked, "bags: 1 bag is not taken")

# 4: payoff once
s = BR.normalize({ inbar: :done })
check(BR.payoff_pending?(s) && BR.payoff!(s) && !BR.payoff!(s) && !BR.payoff_pending?(s), "bags: the payoff fires once")
check(!BR.payoff!(BR.normalize({ inbar: :asked })), "bags: no payoff before the hand-over")

# Rev 2 R1: the duo key (old saves keep their unicorns)
check(BR.new_state[:duo] == :kusomo && BR.normalize({ inbar: :asked })[:duo] == :kusomo, "bags rev2: a missing duo is :kusomo")
check([nil, :party, "gone", 3].all? { |v| BR.normalize({ inbar: :done, duo: v })[:duo] == :kusomo }, "bags rev2: a bad duo is :kusomo")
rev1 = BR.normalize({ inbar: :done, payoff_given: true, toga_gift: false, toga_desert: false, bills_from_bags: 0 })
check(BR.unicorns_home?(rev1) && BR.normalize({ inbar: :done, duo: :gone })[:duo] == :gone, "bags rev2: a rev-1 :done save has its unicorns home")
# R2: unicorns_home? over inbar x duo
home = BR::INBAR_STATES.product(BR::DUO_STATES).select { |i, d| BR.unicorns_home?({ inbar: i, duo: d }) }
check(home == [%i[done kusomo]], "bags rev2: unicorns are home only when :done and :kusomo")
# R3: tour! / leave!
watch_bag = BagsTestBag.new(SURPRISEBAG: 3)
s = BR.normalize({ inbar: :done, payoff_given: true })
before = s.reject { |k, _| k == :duo }
check(BR.tour!(s) && s[:duo] == :touring && !BR.tour!(s), "bags rev2: tour! only from :kusomo")
check(BR.leave!(s) && BR.leave!(s) && s[:duo] == :gone && !BR.tour!(s), "bags rev2: leave! is idempotent and final")
check(s.reject { |k, _| k == :duo } == before && watch_bag.quantity(:SURPRISEBAG) == 3, "bags rev2: tour! and leave! touch no bag and no payoff")
check(!BR.tour!(BR.normalize({ inbar: :asked })) && BR.leave!(g = BR.new_state) && g[:duo] == :gone, "bags rev2: no tour before the hand-over; leave! from any value")
# R4: hand_over! -> payoff! -> tour!, payoff given before the tour
s = BR.normalize({ inbar: :asked })
bag = BagsTestBag.new(SURPRISEBAG: 2)
seq = [BR.hand_over!(s, bag), BR.payoff!(s), s[:payoff_given], BR.tour!(s)]
check(seq == [true, true, true, true] && s[:duo] == :touring, "bags rev2: the payoff is given before the tour starts")
# R8: where they walk off
check(BR.leave_dir(95) == :up && [86, 96, 109, 1].all? { |m| BR.leave_dir(m) == :away }, "bags rev2: north on Map095, away elsewhere")
# Walk-in from row 0
check(BR.walk_in_start(20, (0..34).to_a) == 20 && BR.walk_in_start(20, [17, 19, 21, 23]) == 19 && BR.walk_in_start(22, [24, 21]) == 21,
      "bags rev2: the walk-in starts in its own column, else the nearest open one (left on a tie)")
check(BR.walk_in_moves(20, 20, 10) == [:down] * 10 && BR.walk_in_moves(19, 20, 10) == [:right] + [:down] * 10 &&
      BR.walk_in_moves(24, 22, 3) == %i[left left down down down], "bags rev2: along row 0, then straight down to the spot")

# 5: Pixel trade
check(BR::PAY_ITEMS == %i[DESERTBAG ICEBAG], "bags: Pixel takes only the Desert Bag and the ice bag")
bag = BagsTestBag.new(TWENTYSHECKELBILL: 5, ICEBAG: 1)
check(!BR.trade!(bag, :TWENTYSHECKELBILL) && bag.quantity(:TWENTYSHECKELBILL) == 5 && bag.quantity(:SURPRISEBAG) == 0,
      "bags: Pixel refuses a bill, so all 5 stay for the ice seller")
check(BR.payable(bag) == %i[ICEBAG], "bags: bills never show in Pixel's menu")
check(!BR.trade!(bag, :DESERTBAG) && !BR.trade!(bag, :POTION) && !BR.trade!(bag, :SURPRISEBAG),
      "bags: an unheld or unknown pay item is refused")
check(BR.trade!(bag, :ICEBAG) && bag.quantity(:ICEBAG) == 0 && bag.quantity(:SURPRISEBAG) == 1, "bags: the ice bag is accepted")
check(BR.trade!(BagsTestBag.new(DESERTBAG: 1), :DESERTBAG), "bags: the Desert Bag is accepted")
check(BR.payable(BagsTestBag.new(DESERTBAG: 1, ICEBAG: 2)) == %i[DESERTBAG ICEBAG], "bags: the menu lists held payable items in order")

# 6 + 1: Bag of Bags and the no-debug path to two bags
bag = BagsTestBag.new(BAGOFBAGS: 1)
check(BR.bag_of_bags_use!(bag) == :filled && bag.quantity(:DESERTBAG) == 1, "bags: Bag of Bags gives a Desert Bag")
check(BR.bag_of_bags_use!(bag) == :full && bag.quantity(:DESERTBAG) == 1 && bag.quantity(:BAGOFBAGS) == 1,
      "bags: a held Desert Bag stays 1 and the Bag of Bags is never removed")
2.times do
  BR.bag_of_bags_use!(bag)
  BR.trade!(bag, :DESERTBAG)
end
check(bag.quantity(:SURPRISEBAG) == 2 && bag.quantity(:BAGOFBAGS) == 1, "bags: two surprise bags without debug (Bag of Bags + Pixel, twice)")

# 7: outcome table
check(BR::OUTCOMES.sum { |_, w| w } == 100, "bags: outcome weights sum to 100")
check(Array.new(20) { BR.roll(Random.new(42)) }.uniq.length == 1, "bags: a seeded roll is deterministic")
fixed = Class.new { def initialize(n) = (@n = n); def rand(_m) = @n }
check([0, 34, 35, 64, 65, 84, 85, 99].map { |n| BR.roll(fixed.new(n)) } ==
      %i[confetti confetti note note recurse recurse bill bill], "bags: roll boundaries follow the weights")
s = BR.new_state
bag = BagsTestBag.new(SURPRISEBAG: 1)
watch = Class.new(BagsTestBag) { attr_reader :log; def add(i, n = 1) = ((@log ||= []) << [:add, i, @items[:SURPRISEBAG]]; super) }.new(SURPRISEBAG: 1)
BR.open_surprise!(s, watch, fixed.new(70))
check(watch.log == [[:add, :SURPRISEBAG, 0]] && watch.quantity(:SURPRISEBAG) == 1, "bags: the opened bag is removed before the grant")
bills = Array.new(3) { BR.open_surprise!(s, BagsTestBag.new(SURPRISEBAG: 1), fixed.new(90)) }
check(bills == %i[bill bill confetti] && s[:bills_from_bags] == 2, "bags: the third bill becomes confetti (cap 2)")
check(BR.open_surprise!(s, BagsTestBag.new, fixed.new(0)).nil?, "bags: nothing opens with no bag")
check(BR.warn_inbar?(BR.normalize({ inbar: :asked }), 2) && !BR.warn_inbar?(BR.normalize({ inbar: :asked }), 3) &&
      !BR.warn_inbar?(BR.normalize({ inbar: :done }), 1), "bags: the Inbar warning shows while she still needs them")

# 8: Toga rules
s = BR.new_state
check(BR.toga_branch(s, true) == :gift && BR.toga_gift!(s) && !BR.toga_gift!(s), "bags: Toga's gift happens once")
bag = BagsTestBag.new(DESERTBAG: 1)
check(BR.toga_branch(s, false) == :again && BR.toga_branch(s, true) == :desert_offer, "bags: the desert offer needs a Desert Bag")
check(!BR.toga_desert!(BR.new_state, bag), "bags: the desert hand-over needs the gift first")
check(BR.toga_desert!(s, bag) && bag.quantity(:DESERTBAG) == 0 && !BR.toga_desert!(s, BagsTestBag.new(DESERTBAG: 1)),
      "bags: the desert hand-over happens once")
check(BR.toga_branch(s, true) == :desert_seen, "bags: after the desert Toga says he still has it")

# 10 + 11: timing
lyric_src = File.read(File.join(ROOT, "../docs/design/sakiyot-haftaa-lyrics.md"), encoding: "utf-8")
lyrics = lyric_src.split("\n").drop_while { |l| !l.start_with?("[") }.reject { |l| l.strip.empty? || l.start_with?("[") }
doc = JSON.parse(File.read(File.join(ROOT, "Data/sakiyot_haftaa_timing.json"), encoding: "utf-8"))
timing, err = BR.parse_timing(doc)
raw = doc["lines"]
timing_src = File.read(File.join(ROOT, "Data/sakiyot_haftaa_timing.json"), encoding: "utf-8")
check(SimpleJSONParser.parse(timing_src) == doc, "bags timing: the game's SimpleJSONParser reads the real file the same as JSON")
check(timing && !timing[:placeholder] && lyrics.length == 39 && raw.length == 44, "bags timing: the real file parses, 44 lines, not a placeholder (#{err})")
marks = ->(t) { t.scan(BR::MARK_RE).length }
given = raw.select { |l| l["in_given_lyrics"] == true }.map { |l| l["text"] }
same = given.length == 39 && given.each_with_index.all? { |t, i| t.b == lyrics[i].b && marks.(t) == marks.(lyrics[i]) }
check(same, "bags timing: the given-lyrics lines equal the 39 lyrics in order, byte for byte, niqqud count unchanged")
extra = raw.select { |l| l["in_given_lyrics"] == false }
check(extra.length == 5 && extra.all? { |l| lyrics.any? { |y| y.b == l["text"].b } }, "bags timing: every extra sung line repeats a lyric verbatim")
check(timing && timing[:lines][-1][:end] < timing[:duration] && (timing[:duration] - 193.954).abs < 0.001,
      "bags timing: the 194 s song ends after the last Build Up line")
section_kinds = { "Verse 1" => :verse, "Verse 2" => :verse, "Verse 3" => :verse, "Verse 4" => :verse, "Chorus" => :chorus,
                  "Chorus (extra, not in given lyrics)" => :chorus, "bridge | energy:low" => :bridge,
                  "Build Up - Faster and Silly" => :build_up }
labels = timing ? timing[:lines].map { |l| l[:section] }.uniq.sort : []
check(labels == section_kinds.keys.sort && section_kinds.all? { |k, v| BR.section_kind(k) == v },
      "bags timing: every section label in the real file maps to its intended intensity")
check(BR.intensity("Chorus (extra, not in given lyrics)") == BR.intensity("Chorus"), "bags timing: the extra chorus gets chorus intensity")
# The ogg has no LOOPSTART, so bgm_pos tops out just under 193.954 s and then wraps to 0.
song = BR.new_clock(true)
early = (1..11_637).any? { |f| BR.clock_tick(song, f / 60.0, 60); BR.clock_done?(song, timing[:duration]) && f / 60.0 <= timing[:lines][-1][:end] }
BR.clock_tick(song, 0.02, 60)
check(!early && song[:t] > timing[:lines][-1][:end] && BR.clock_done?(song, timing[:duration]),
      "bags timing: the real song is not cut before its last line and ends at the BGM loop jump-back")
sample = { "audio" => "a.ogg", "duration" => 10, "granularity" => "word", "lines" => [
  { "section" => "Verse 1", "text" => "א ב", "start" => 1.0, "end" => 2.0,
    "words" => [{ "w" => "א", "start" => 1.0, "end" => 1.5 }, { "w" => "ב", "start" => 1.5, "end" => 2.0 }] },
  { "section" => "Chorus", "text" => "ג ד", "start" => 3, "end" => 4 }
] }
parsed, = BR.parse_timing(sample)
check(parsed && parsed[:lines][0][:words].length == 2 && parsed[:lines][1][:words].nil?, "bags timing: a real-schema file parses; no words is line mode")
bad = ->(mut) { d = JSON.parse(JSON.dump(sample)); mut.(d); BR.parse_timing(d)[0].nil? }
check(bad.(->(d) { d["lines"].reverse! }), "bags timing: unsorted lines are rejected")
check(bad.(->(d) { d["lines"][0]["end"] = 1.0 }), "bags timing: start >= end is rejected")
check(bad.(->(d) { d["lines"][0]["words"][1]["end"] = 2.5 }), "bags timing: a word outside its line is rejected")
check(bad.(->(d) { d["lines"] = [] }) && BR.parse_timing(nil)[0].nil?, "bags timing: empty or missing input is rejected")
check(BR.parse_timing(sample.merge("granularity" => "line"))[0][:lines][0][:words].nil?, "bags timing: granularity line drops words")

# 12: clock lookup
ls = parsed[:lines]
check(BR.line_at(ls, 0.5).nil? && BR.line_at(ls, 1.0) == 0 && BR.line_at(ls, 1.99) == 0, "bags clock: line starts at its start")
check(BR.line_at(ls, 2.0).nil? && BR.line_at(ls, 2.5).nil? && BR.line_at(ls, 3.0) == 1 && BR.line_at(ls, 4.0).nil?, "bags clock: no line in gaps")
check(BR.word_at(ls[0], 1.0) == 0 && BR.word_at(ls[0], 1.49) == 0 && BR.word_at(ls[0], 1.5) == 1 && BR.word_at(ls[0], 0.9) == -1,
      "bags clock: word index at boundaries")
check(BR.word_at(ls[1], 3.5).nil? && BR.next_line(ls, 2.5) == 1 && BR.section_at(ls, 2.5) == "Verse 1", "bags clock: line mode, next line, gap section")
c = BR.new_clock(true)
59.times { BR.clock_tick(c, 0.0, 60) }
check(c[:mode] == :audio && BR.clock_tick(c, 0.0, 60) && c[:mode] == :frames, "bags clock: bgm_pos stuck at 0 for 60 frames falls back to frames")
c = BR.new_clock(true)
[0.5, 1.0, 1.5].each { |p| BR.clock_tick(c, p, 60) }
check(c[:t] == 1.5 && !BR.clock_done?(c, 10), "bags clock: audio position drives t")
BR.clock_tick(c, 0.1, 60)
check(BR.clock_done?(c, 10), "bags clock: bgm_pos going backwards (loop) ends the song")
c = BR.new_clock(false)
120.times { BR.clock_tick(c, nil, 60) }
check(c[:t] == 2.0 && BR.clock_done?(c, 2.0), "bags clock: the frame clock ends at the duration")

# 13: section intensity
kinds = ["Verse 2", "Chorus", "Bridge — Low Energy", "Build Up — Faster and Silly", "Outro"].map { |x| BR.section_kind(x) }
check(kinds == %i[verse chorus bridge build_up verse], "bags: section prefix gives the intensity kind")
check(BR.intensity("Chorus")[:every] == 12 && BR.intensity("Bridge")[:speed] == 0.5 && BR.intensity("Build Up")[:every] == 8,
      "bags: chorus, bridge and build-up intensities")
check(BR::INTENSITY.values.none? { |l| l.key?(:tone) } && !hooks_src.include?("start_tone_change"),
      "bags rev2: no screen tone anywhere (the bridge no longer dims the saved screen)")
check(BR.rain_every(BR.intensity("Chorus")) == 24 && BR.rain_every(BR.intensity("Verse 1")) == 80, "bags rev2: rain spawns half as often as rev 1")
# R5: end reasons
clk = BR.new_clock(true)
BR.clock_tick(clk, 50.0, 60)
check(BR.song_end_reason(clk, 193.954, "sakiyot_haftaa").nil?, "bags rev2: no end reason while the song runs")
check(BR.song_end_reason(clk, 50.0, "sakiyot_haftaa") == :done, "bags rev2: done at the duration")
BR.clock_tick(clk, 0.1, 60)
check(BR.song_end_reason(clk, 193.954, "sakiyot_haftaa") == :done, "bags rev2: done when the BGM loops back")
check(BR.song_end_reason(BR.new_clock(true), 193.954, "Battle wild") == :interrupted &&
      BR.song_end_reason(BR.new_clock(true), 193.954, nil) == :interrupted, "bags rev2: another BGM or none interrupts")
check(BR.restore_map_music?("sakiyot_haftaa") && BR.restore_map_music?(nil) && BR.restore_map_music?("") && !BR.restore_map_music?("Battle wild"),
      "bags rev2: map music returns over the song or silence (never a silent map), never over other music")

# 14: clusters (both the song panel and HebrewText menus)
word = "שַׂקִּית"
expect = [0x05EA, 0x05D9, 0x05E7, 0x05B4, 0x05BC, 0x05E9, 0x05B7, 0x05C2]
check(BR.cluster_reverse(word).codepoints == expect, "bags: cluster reverse of שַׂקִּית keeps marks on their letters")
check(HebrewText.visual_reverse(word).codepoints == expect, "bidi: menus reverse niqqud by cluster too")
check(BR.clusters(word) == HebrewText.clusters(word), "bidi: song panel and menus split clusters the same way")
check(lyrics.all? { |l| BR.clusters(l).all? { |cl| !cl[0].match?(BR::MARK_RE) } }, "bags: every lyric mark follows a base letter")
check(BR.sakiyot_word?("שַׂקִּיּוֹת") && BR.sakiyot_word?("שַׂקִּיּוֹת,") && !BR.sakiyot_word?("שַׂקִּית"), "bags: chorus burst word matches with niqqud and punctuation")

# Layout helpers
check(BR.word_positions([10, 20], 5, 100) == [90, 65], "bags: words are placed from the right edge in logical order")
check(BR.wrap_rows([100, 100], 10, 488) == [[0, 1]] && BR.wrap_rows([300, 100, 200], 10, 488) == [[0], [1, 2]],
      "bags: a long line wraps at the space nearest the middle")
check(BR.font_plan(488) { |s| [[s * 10] * 2, s] } == [22, false], "bags: font shrinks in 2px steps")
check(BR.font_plan(488) { |s| [[s * 15] * 2, s] } == [18, true] && BR.font_plan(488) { |s| [[s * 30] * 2, s] } == [16, true],
      "bags: a long line wraps at 18, and shrinks further until each row fits")
check(BR.font_plan(488) { [[999], 0] } == [12, true], "bags: one unbreakable word ends at the smallest size")
check(BR.preview_plan(488) { |s| [[s * 10] * 2, s] } == [18, 2] && BR.preview_plan(488) { |s| [[s * 14] * 2, s] } == [16, 2],
      "bags: the preview stays 18 when it fits and shrinks when it does not")
check(BR.preview_plan(488) { [[300] * 3, 10] } == [12, 1], "bags: a preview too wide at 12 drops trailing words")
check(BR.cluster_reverse("בית־ספר") == "רפס־תיב", "bags: maqaf is its own character, not a mark")

# R7 (replaces 15): rain stays in the side gutters and above the panel band
rng = Random.new(5)
worst = 0
inner = [BR::SCREEN_W, 0]   # nearest approach to the centre from the left, and from the right
sides = [0, 0]
600.times do
  s = BR.spawn_sticker(rng, (BR::BURST_SIZES.min..BR::RAIN_SIZES.max).to_a.sample(random: rng))
  speed = [0.5, 1.0, 1.5][rng.rand(3)]
  while BR.step_sticker(s, speed)
    worst = [worst, s[:dy] + s[:r]].max
    left, right = s[:dx] - s[:r], s[:dx] + s[:r]
    if s[:cx] < BR::SCREEN_W / 2
      sides[0] += 1
      inner[1] = [inner[1], right].max
      inner[1] = 999 if left < 0
    else
      sides[1] += 1
      inner[0] = [inner[0], left].min
      inner[0] = -999 if right > BR::SCREEN_W
    end
  end
end
check(worst < BR::PANEL_TOP && worst > 250, "bags: no sticker's drawn box reaches y 288 (max bottom #{worst.round(1)})")
check(inner[1] <= BR::GUTTER_W && inner[0] >= BR::SCREEN_W - BR::GUTTER_W && sides.all?(&:positive?),
      "bags rev2: rain never enters x 128..384 and stays on screen (left max #{inner[1].round(1)}, right min #{inner[0].round(1)})")
check(BR::MAX_STICKERS == 6 && BR::RAIN_SIZES == (32..44), "bags rev2: at most 6 stickers, 32-44 px")
check(BR.open_gutters([256]) == BR::GUTTERS && BR.open_gutters([80]) == [[384, 512]] && BR.open_gutters([272, 470]) == [[0, 128]] &&
      BR.open_gutters([143]) == [[384, 512]] && BR.open_gutters([144]) == BR::GUTTERS &&
      BR.open_gutters([60, 400]).empty? && BR.open_gutters([]) == BR::GUTTERS,
      "bags rev2: a gutter the player or a follower stands in (32 px wide) is closed to rain")
grng = Random.new(9)
right_only = 200.times.map { BR.spawn_sticker(grng, 40, BR.open_gutters([48])) }
check(right_only.all? { |s| s[:cx] - s[:r] - s[:amp] >= BR::SCREEN_W - BR::GUTTER_W } && BR.spawn_sticker(grng, 40, []).nil?,
      "bags rev2: rain spawns only in open gutters, none when both are taken")
# R6: chorus pins on the real file: exactly the 4 chorus spans, inside the top strip
starts = timing[:lines].each_cons(2).select { |a, b| a[:section] != b[:section] }.map { |_, b| [b[:section], b[:start]] }
starts.unshift([timing[:lines][0][:section], timing[:lines][0][:start]])
spans = starts.each_with_index.select { |(sec, _), _| BR.section_kind(sec) == :chorus }.map { |(_, st), i| [st, starts[i + 1][1]] }
check(spans.map { |a, _| a } == [37.16, 71.54, 107.84, 154.34], "bags rev2: four chorus spans in the real file (#{spans.inspect})")
wrong = (0..(timing[:duration] * 100).to_i).map { |c| c / 100.0 }.reject do |t|
  BR.pins_on?(timing[:lines], t) == spans.any? { |a, b| t >= a && t < b }
end
check(wrong.empty?, "bags rev2: pins show exactly on the chorus spans (mismatch at #{wrong.first(3).inspect})")
check(BR.chorus_pins.map(&:first) == %w[esther_pink shirpaz_purple duo_friends_badge] &&
      BR.chorus_pins.all? { |p| x, y, w, h = BR.pin_rect(p); x >= 0 && y >= 0 && x + w <= BR::SCREEN_W && y + h < BR::PIN_STRIP },
      "bags rev2: Esther left, Shirpaz right, the badge centre; every pin stays in the top strip")
tilt = BR::PIN_TILT * Math::PI / 180
corners = BR.chorus_pins.flat_map do |_, cx, cy, size|
  [[-1, -1], [1, -1], [1, 1], [-1, 1]].map do |sx, sy|
    hx, hy = sx * size / 2.0, sy * size / 2.0
    [-1, 1].map { |dir| cy + hx * Math.sin(dir * tilt) + hy * Math.cos(dir * tilt) }
  end
end.flatten
check(BR.pin_rect(["x", 100, 50, 76])[3] > 76 && corners.min >= 0 && corners.max < BR::PIN_STRIP,
      "bags rev2: pin bounds include the 8 degree tilt; every rotated corner stays in y 0..95 (max #{corners.max.round(1)})")
check(BR.pin_zoom(0, true) == 0 && BR.pin_zoom(6, true) == 0.5 && BR.pin_zoom(12, true) == 1 && BR.pin_zoom(40, true) == 1 &&
      BR.pin_zoom(6, false) == 0.5 && BR.pin_zoom(12, false) == 0, "bags rev2: pins pop in and out over 12 frames")

#-------------------------------------------------------------------------------
# Hooks: Inbar, Pixel, Toga, unicorns with stubs (song scene stubbed)
#-------------------------------------------------------------------------------
$bags_log = []
$bags_picks = []
def pbMessage(msg, commands = nil, _cancel = 0)
  $bags_log << [msg, DesertTalk.name_key]
  $bags_seen << [msg, $bags_watch.x, $bags_watch.y] if $bags_watch
  return nil unless commands
  raise "bags test: no scripted choice for #{msg}" if $bags_picks.empty?
  $bags_picks.shift
end
def _INTL(m, *a) = a.empty? ? m : "#{m}|#{a.join(',')}"
def pbConfirmMessage(m) = (pbMessage(m, %w[y n]) == 0)
def pbReceiveItem(i, n = 1) = ($bags_log << [:got, i]; $bag.add(i, n))
$bags_frames = 0
# Like the engine: a wait runs map frames, and every map frame fires :on_frame_update.
def pbUpdateSceneMap = ($bags_frames += 1; $event_handlers[:bags_song]&.call)
def pbWait(_s) = 3.times { pbUpdateSceneMap }
def pbSEPlay(*); end
def pbResolveBitmap(_path) = nil unless defined?(pbResolveBitmap)
module FileTest
  def self.audio_exist?(_f) = true
end unless FileTest.respond_to?(:audio_exist?)
module ItemHandlers
  module UseFromBag; def self.add(id, pr) = (($bags_handlers ||= {})[[:bag, id]] = pr); end
  module UseInField; def self.add(id, pr) = (($bags_handlers ||= {})[[:field, id]] = pr); end
end
class Game_Map
  attr_accessor :need_refresh
  attr_writer :events
  def events = (@events ||= {})
  def width = 35
  def passable?(x, y, _d) = !($bags_blocked || []).include?([x, y])
  def setup(_id); end unless method_defined?(:setup)
end
module RPG
  class MoveCommand
    attr_reader :code
    def initialize(code = 0) = (@code = code)
  end
  class MoveRoute
    attr_accessor :repeat, :skippable, :list
    def initialize = (@list = [MoveCommand.new])
  end
  class EventCommand
    attr_reader :code, :indent, :parameters
    def initialize(code = 0, indent = 0, parameters = []) = (@code, @indent, @parameters = code, indent, parameters)
  end
end unless defined?(RPG::MoveRoute)
# A map event or follower; a forced route is walked at once and logged.
class BagsFakeChar
  STEP = { 1 => [0, 1], 2 => [-1, 0], 3 => [1, 0], 4 => [0, -1], 11 => [0, 1] }.freeze
  attr_accessor :x, :y, :through, :move_speed, :opacity, :character_name, :name
  attr_reader :walked, :refreshed
  def initialize(name, x, y)
    @name, @x, @y = name, x, y
    @through, @move_speed, @opacity, @character_name, @walked, @refreshed = false, 3, 255, "unicorn", [], 0
  end
  def refresh = (@refreshed += 1)
  def screen_x = @x * 32 + 16
  def moveto(x, y) = (@x, @y = x, y)
  def move_route_forcing = false
  def moving? = false
  def force_move_route(route)
    route.list.each do |c|
      next unless STEP[c.code]
      @walked << [c.code, @through, @move_speed]
      @x += STEP[c.code][0]
      @y += STEP[c.code][1]
    end
  end
end
# The factory copies the leader's speed (3) onto a follower every frame, before it moves.
class Game_Follower < BagsFakeChar
  def force_move_route(route) = (self.move_speed = 3; super)
end
# Game_FollowerFactory with $PokemonGlobal.followers kept in step.
class BagsFakeFactory
  FData = Struct.new(:name, :invisible_after_transfer)
  attr_reader :list
  def initialize = (@list = [])
  def add_follower(ev, name)
    @list << [Game_Follower.new(ev.name, ev.x, ev.y), FData.new(name, true)]
    $PokemonGlobal.followers << @list.last[1]
  end
  def each_follower(&blk) = @list.each { |e, d| blk.call(e, d) }
  def remove_follower_by_name(name)
    @list.reject! { |_, d| d.name == name }
    $PokemonGlobal.followers.reject! { |d| d.name == name }
  end
end
class PokemonGlobalMetadata
  def followers = (@followers ||= [])
end
class << $game_temp
  attr_accessor :in_menu, :player_transferring
  attr_writer :followers
  def followers = (@followers ||= BagsFakeFactory.new)
end
$bags_faces = []
$bags_seen = []
def pbTurnTowardEvent(ch, _target) = ($bags_faces << ch.name)
module Bags
  module Song
    def self.start(duo:) = ($bags_log << [:song, duo, Bags.state[:payoff_given], Bags.state[:duo]]; true)
    def self.stop = false
    def self.active? = false
  end
end
module MenuHandlers
  def self.add(_menu, id, _h) = (($bags_menu ||= []) << id)
end unless defined?(MenuHandlers)
%w[001_state 002_items 003_talk_hooks 004_toga 005_unicorns 007_debug 009_duo].each { |f| load File.join(bags_dir, "#{f}.rb") }
$PokemonGlobal = PokemonGlobalMetadata.new
$game_switches = {}
$game_map = Game_Map.new(95)
$bag = BagsTestBag.new
keys = -> { $bags_log.map { |e| e[0].is_a?(String) ? e[0].split("|")[0] : e } }
gots = -> { keys.call.count { |e| e.is_a?(Array) && e[0] == :got } }
talk = lambda do |id, picks = []|
  $bags_log = []
  $bags_picks = picks.dup
  DesertTalk.start_speaker(id)
  pbDesertTalk(id)
  keys.call
end

check($PokemonGlobal.bags_quest == BR.new_state, "bags save: an old save without the key loads a fresh quest")
check(talk.("c414cf08") == %w[MSG_C414CF08_LINE BAGS_INBAR_ASK_1 BAGS_INBAR_ASK_2 BAGS_INBAR_ASK_3] &&
      Bags.state[:inbar] == :asked, "bags Inbar: her own line, then the ask; state :asked")
$bag.add(:SURPRISEBAG, 1)
check(talk.("c414cf08") == %w[MSG_C414CF08_LINE BAGS_INBAR_NOTENOUGH] && $bags_log[1][0] == "BAGS_INBAR_NOTENOUGH|1" &&
      $bag.quantity(:SURPRISEBAG) == 1, "bags Inbar: one bag is counted and not taken")
$game_map = Game_Map.new(77)
check(talk.("c414cf08") == %w[MSG_C414CF08_LINE], "bags Inbar: only on map 95")
$game_map = Game_Map.new(95)
check(talk.("d5383627") == %w[MSG_D5383627_LINE BAGS_PIXEL_OFFER_1 BAGS_PIXEL_OFFER_2 BAGS_PIXEL_NOTHING],
      "bags Pixel: nothing payable points to Toga")
$bag = BagsTestBag.new(TWENTYSHECKELBILL: 5)
check(talk.("d5383627").last == "BAGS_PIXEL_NOTHING" && $bag.quantity(:TWENTYSHECKELBILL) == 5,
      "bags Pixel: bills alone are nothing to trade")
$bag = BagsTestBag.new(SURPRISEBAG: 1, DESERTBAG: 1, TWENTYSHECKELBILL: 1)
got = talk.("d5383627", [0])
check(got == %w[MSG_D5383627_LINE BAGS_PIXEL_OFFER_1 BAGS_PIXEL_CHOOSE_ONE BAGS_PIXEL_PAID_DESERT BAGS_PIXEL_MEOW BAGS_PIXEL_REVEAL] &&
      $bag.quantity(:SURPRISEBAG) == 2 && $bag.quantity(:DESERTBAG) == 0 && $bag.quantity(:TWENTYSHECKELBILL) == 1,
      "bags Pixel: one payable item is a deal question (#{got})")
check(Bags::PAY_KEYS.keys == BR::PAY_ITEMS && !Bags::PAY_KEYS.key?(:TWENTYSHECKELBILL), "bags Pixel: one choice and thank-you line per pay item")
$bag.add(:DESERTBAG, 1)
$bag.add(:ICEBAG, 1)
got = talk.("d5383627", [1])
check(got[2] == "BAGS_PIXEL_CHOOSE" && got[3] == "BAGS_PIXEL_PAID_ICE" && $bag.quantity(:ICEBAG) == 0 && $bag.quantity(:DESERTBAG) == 1,
      "bags Pixel: several payable items show the menu in order (desert, ice)")
check(talk.("d5383627", [1]).last == "BAGS_PIXEL_NEVERMIND" && $bag.quantity(:DESERTBAG) == 1, "bags Pixel: never mind keeps the item")
$bag.remove(:SURPRISEBAG, 1)
check(talk.("c414cf08", [1]).last == "BAGS_INBAR_NOTYET" && $bag.quantity(:SURPRISEBAG) == 2, "bags Inbar: not yet keeps both bags")
uni = { esther: BagsFakeChar.new("bags_unicorn_esther", 20, 10), shirpaz: BagsFakeChar.new("bags_unicorn_shirpaz", 22, 10) }
$game_map.events = { 15 => BagsFakeChar.new("dt_c414cf08", 21, 9), 17 => uni[:esther], 18 => uni[:shirpaz] }
$game_player = BagsFakeChar.new("player", 21, 10)
$bags_watch = uni[:esther]
$bags_seen = []
$bags_faces = []
got = talk.("c414cf08", [0])
$bags_watch = nil
check(Bags.state[:inbar] == :done && $game_switches[106] == true && $bag.quantity(:SURPRISEBAG) == 1 && Bags.state[:payoff_given],
      "bags Inbar: hand-over takes 2, sets :done and S106, payoff given")
check(got.index("BAGS_UNICORN_GIVEN") < got.index("BAGS_UNICORN_ARRIVE_1") && got.index("BAGS_UNICORN_ACCEPT_2") < got.index("BAGS_UNICORN_AFTER_1") &&
      got.last(4) == ["BAGS_UNICORN_AFTER_4", [:got, :SURPRISEBAG], "BAGS_UNICORN_PRESONG", [:song, true, true, :kusomo]] && gots.call == 1,
      "bags rev2 Inbar: arrival, after lines and the bag back, then PRESONG, then the song (payoff already given)")
seen_given = $bags_seen.find { |m, _, _| m == "BAGS_UNICORN_GIVEN" }
seen_arrive = $bags_seen.find { |m, _, _| m == "BAGS_UNICORN_ARRIVE_1" }
check(seen_given && seen_given[1..] == [20, 0] && seen_arrive[1..] == [20, 10] && uni.values.all? { |u| u.refreshed >= 1 },
      "bags rev2 walk-in: off-screen on row 0 from the first message after the hand-over, at the spot for the arrival lines")
check(uni.values.all? { |u| u.walked.length == 10 && u.walked.all? { |c, th, sp| c == 1 && th && sp == 4 } } &&
      [uni[:esther].x, uni[:esther].y, uni[:shirpaz].x, uni[:shirpaz].y] == [20, 10, 22, 10] &&
      uni.values.all? { |u| !u.through && u.move_speed == 3 }, "bags rev2 walk-in: 10 steps down at speed 4 through anything, then through and speed restored")
duo_lines = $bags_log.count { |m, _| m.is_a?(String) && Bags::ARRIVAL.any? { |k, sp| k == m && sp != :inbar } }
check($bags_faces.count("bags_unicorn_esther") >= duo_lines && $bags_faces.count("bags_unicorn_shirpaz") >= duo_lines && duo_lines == 7,
      "bags rev2: both unicorns turn to the player before every duo line")
plate = $bags_log.find { |m, _| m == "BAGS_UNICORN_ARRIVE_2" }
check(plate && plate[1] == "BAGS_NAME_SHIRPAZ" && $bags_log.find { |m, _| m == "BAGS_UNICORN_GIVEN" }[1].nil?,
      "bags Inbar: unicorn lines carry their name plate; narration has none")
check(talk.("c414cf08") == %w[MSG_C414CF08_LINE BAGS_INBAR_PARTY_1 BAGS_INBAR_PARTY_2], "bags Inbar: party lines afterwards")
# dec:tg-29: the cowboy's bag comes only from an arm-wrestling win (zArmWrestle; full flow in arm_rules_test.rb).
cowboy_talk_before = talk.("670f79e3")
check(cowboy_talk_before == %w[MSG_670F79E3_LINE BAGS_SHIRPAZ_COWBOY_CLASH], "bags cowboy: without zArmWrestle, his line and the clash only")
%w[000_rules 001_state 004_offer].each { |f| require File.join(ROOT, "Plugins/zArmWrestle/#{f}.rb") }
cowboy_before = Marshal.load(Marshal.dump(Bags.state))
cowboy_bags = $bag.quantity(:SURPRISEBAG)
cowboy_talks = 3.times.map { talk.("670f79e3", [1]) }
check(cowboy_talks.all? { |t| t == %w[MSG_670F79E3_LINE BAGS_SHIRPAZ_COWBOY_CLASH AW_CHALLENGE AW_LATER] },
      "bags cowboy: his line, the name clash after the party, then the challenge; not now ends it (#{cowboy_talks[0].inspect})")
check($bag.quantity(:SURPRISEBAG) == cowboy_bags && Bags.state == cowboy_before && $PokemonGlobal.arm_wrestle == ArmWrestleRules.new_state,
      "bags cowboy: no bag without a win, and neither quest state changes")
$bags_log = []
$bags_picks = [0]
pbBagsUnicorn(:esther)
check(keys.call == ["BAGS_UNICORN_ENCORE_ASK", "BAGS_UNICORN_ENCORE_YES", [:song, true, true, :kusomo]] && $bag.quantity(:SURPRISEBAG) == 1,
      "bags encore: the rev-2 song with the duo following, no reward")
check($bags_log[0][1] == "BAGS_NAME_ESTHER", "bags encore: talking to Esther shows Esther's plate on the question")
$bags_log = []
$bags_picks = [1]
pbBagsUnicorn(:shirpaz)
check($bags_log[0] == ["BAGS_UNICORN_ENCORE_ASK", "BAGS_NAME_SHIRPAZ"], "bags encore: talking to Shirpaz shows Shirpaz's plate")
Bags.state[:payoff_given] = false
$bags_log = []
pbBagsUnicorn(:shirpaz)
$bags_picks = [1]
pbBagsUnicorn(:shirpaz)
check(gots.call == 1 && $bag.quantity(:SURPRISEBAG) == 2 && Bags.state[:payoff_given] && keys.call.last == "BAGS_UNICORN_ENCORE_NO",
      "bags recovery: :done without payoff pays once via a unicorn, then only the encore offer")
$game_switches[106] = false
Bags.sync_switch
check($game_switches[106] == true, "bags: S106 re-syncs from the saved state")
BagsPage = Struct.new(:graphic, :step_anime)
BagsGraphic = Struct.new(:character_name)
BagsEvent = Struct.new(:name, :pages)
def bags_fake_map(name, charset)
  Struct.new(:events).new({ 1 => BagsEvent.new(name, [BagsPage.new(BagsGraphic.new(charset), true)]) })
end
$game_switches[106] = false
m95 = bags_fake_map("bags_unicorn_esther", "unicorn_esther")
$event_handlers[:bags_unicorns].call(95, m95, nil)
check(m95.events[1].pages[0].graphic.character_name == "unicorn_esther_placeholder" && $game_switches[106] == true,
      "bags map setup: map 95 gets S106 and the placeholder charset before its events exist")
check(m95.events[1].pages[0].step_anime == false, "bags rev2 map setup: the unicorns stand still (no step animation)")
BR.leave!(Bags.state)
$event_handlers[:bags_unicorns].call(95, m95, nil)
check($game_switches[106] == false && !BR.unicorns_home?(Bags.state), "bags rev2: S106 goes off once the duo has left")
Bags.state[:duo] = :kusomo
Bags.sync_switch
other = bags_fake_map("bags_unicorn_esther", "unicorn_esther")
$event_handlers[:bags_unicorns].call(94, other, nil)
check(other.events[1].pages[0].graphic.character_name == "unicorn_esther", "bags map setup: other maps are left alone")
$event_handlers[:bags_unicorns].call(95, m95, nil)
check(m95.events[1].pages[0].graphic.character_name == "unicorn_esther_placeholder", "bags map setup: a second setup does not stack suffixes")
check(!File.read(File.join(bags_dir, "005_unicorns.rb"), encoding: "utf-8").include?("instance_variable_get"),
      "bags map setup: no reach into Game_Event internals")

# Toga
$bag = BagsTestBag.new
Bags.reset
$bags_log = []
$bags_picks = [1]
check(pbBagsToga == true && $bag.quantity(:BAGOFBAGS) == 1 && keys.call.include?("MSG_7A2A022C_BAG_4B") &&
      keys.call.last(2) == [[:got, :BAGOFBAGS], "MSG_7A2A022C_BAG_GIFT_3"], "bags Toga: first visit gives the Bag of Bags, then ends")
$bags_log = []
check(pbBagsToga == false && keys.call == ["MSG_7A2A022C_BAG_AGAIN_1"], "bags Toga: repeat visit is an AGAIN line, back to the menu")
$bags_log = []
$bags_picks = [0]
check($bags_handlers[[:bag, :BAGOFBAGS]].call(:BAGOFBAGS) == 1 && $bag.quantity(:DESERTBAG) == 1, "bags item: using the Bag of Bags fills a Desert Bag")
$bags_picks = [1]
check(pbBagsToga == false && $bag.quantity(:DESERTBAG) == 1 && Bags.state[:toga_desert] == false, "bags Toga: KEEP changes nothing")
$bags_picks = [0]
check(pbBagsToga == true && $bag.quantity(:DESERTBAG) == 0 && Bags.state[:toga_desert], "bags Toga: the desert hand-over ends the event")
$bags_log = []
check(pbBagsToga == false && keys.call.first == "MSG_7A2A022C_DESERTBAG_SEEN", "bags Toga: afterwards he still has the desert")
$bag = BagsTestBag.new(SURPRISEBAG: 2)
Bags.state[:inbar] = :asked
$bags_log = []
$bags_picks = [1]
check($bags_handlers[[:bag, :SURPRISEBAG]].call(:SURPRISEBAG) == 0 && keys.call.first == "BAGS_SURPRISE_WARN_INBAR" &&
      $bag.quantity(:SURPRISEBAG) == 2, "bags item: declining the open keeps the bag (with the Inbar warning)")
$bags_picks = [0]
check($bags_handlers[[:bag, :SURPRISEBAG]].call(:SURPRISEBAG) == 1 && keys.call.last.start_with?("BAGS_SURPRISE_"),
      "bags item: opening shows an outcome line")
$PokemonGlobal = nil

pre_party = talk.("670f79e3", [1])
check(pre_party == %w[MSG_670F79E3_LINE AW_CHALLENGE AW_LATER], "bags cowboy: before the party no name clash, straight to the challenge (#{pre_party.inspect})")
check(!BR.respond_to?(:cowboy_gift) && !defined?(BR::COWBOY_GIFT_LINES), "bags cowboy: the free gift (dec:tg-17) is gone")
state_write_re = /\[:(?:#{BR.new_state.keys.join("|")})\]\s*(?:\+|-|\|\||&&)?=(?!=)/
check("st[:inbar] = :done".match?(state_write_re) && "x[:bills_from_bags] += 1".match?(state_write_re) && !"st[:inbar] == :done".match?(state_write_re),
      "bags: the quest-state write scan catches assignments and skips comparisons")
state_writes = Dir.glob(File.join(bags_dir, "*.rb")).reject { |f| f.end_with?("000_rules.rb") }.flat_map do |f|
  File.read(f, encoding: "utf-8").scan(state_write_re).map { |m| "#{File.basename(f)}: #{m}" }
end
check(state_writes.empty?, "bags: only BagsRules assigns quest state keys (#{state_writes.inspect})")

tr = File.read(File.join(ROOT, "PBS/translations.json"), encoding: "utf-8")
bag_keys = Dir.glob(File.join(bags_dir, "*.rb")).flat_map { |f| File.read(f, encoding: "utf-8").scan(/"((?:BAGS|MSG_7A2A022C_BAG|MSG_7A2A022C_DESERTBAG|CHOICE_7A2A022C_(?:BAG|DESERTBAG))[A-Z0-9_]*)"/).flatten }
bag_keys += %w[1 2 3 4A 4B 5 6 Q GIFT GIFT_2 GIFT_3 AGAIN_1 AGAIN_2 AGAIN_3].map { |s| "MSG_7A2A022C_BAG_#{s}" }
bag_keys += %w[2 3 4 KEEP SEEN].map { |s| "MSG_7A2A022C_DESERTBAG_#{s}" }
bag_keys += %w[1 2 3].map { |s| "BAGS_SHIRPAZ_COWBOY_GIFT_#{s}" }
bag_keys += %w[1 2 3 FULL].map { |s| "BAGS_BAGOFBAGS_USE_#{s}" } + %w[CONFETTI NOTE RECURSE BILL].map { |s| "BAGS_SURPRISE_#{s}" }
missing = bag_keys.uniq.reject { |k| k == Bags::TOGA_KEY || tr.include?("\"#{k}\": {") }
check(missing.empty?, "bags: every key the plugin shows is in translations.json (missing #{missing.inspect})")

#-------------------------------------------------------------------------------
# Song overlay and runner (stubbed engine): one bad PNG is skipped; the run, its
# end conditions, the music carry, the end scene and a load mid-song
#-------------------------------------------------------------------------------
def echoln(*); end unless respond_to?(:echoln, true)
$song_calls = []
def pbBGSPlay(bgs) = ($song_calls << [:bgs, bgs])
class Bitmap
  attr_reader :path
  def initialize(path) = (raise "bad png" if path.include?("bad"); @path = path)
  def disposed? = false
end unless defined?(Bitmap)
load File.join(bags_dir, "006_song_overlay.rb")
class Scene_Map
  def update = ($bags_update_ran = true)
  def dispose = ($bags_dispose_ran = true)
end unless Scene_Map.method_defined?(:update) && Scene_Map.method_defined?(:dispose)
load File.join(bags_dir, "008_song.rb")
Dir.mktmpdir("bags_art") do |dir|
  Dir.chdir(dir) do
    FileUtils.mkdir_p(Bags::Song::STICKER_DIR)
    %w[a_esther bad_one c_duo].each { |n| File.write(File.join(Bags::Song::STICKER_DIR, "#{n}.png"), "x") }
    art = Bags::Song::Overlay.allocate.send(:load_art)
    check(art.map { |_, w, n| [n, w] } == [["a_esther", 3], ["c_duo", 3]], "bags song: one bad sticker PNG is skipped, the rest load")
  end
end

# Engine stubs for the runner. The overlay is replaced by a recorder.
bags_prev_dir = Dir.pwd
Dir.chdir(ROOT)
SongR = Bags::Song
real_overlay = SongR::Overlay
class BagsFakeOverlay
  attr_reader :updates, :disposed, :xs
  def initialize(timing) = (@timing = timing; @updates = []; @disposed = false)
  def update(t, visible, xs) = (@updates << [t, visible]; @xs = xs)
  def dispose = (@disposed = true)
end
SongR.send(:remove_const, :Overlay)
SongR.const_set(:Overlay, BagsFakeOverlay)
module Graphics
  def self.update; end
end
module Audio
  def self.bgm_pos = $bags_pos
end
def pbBGMPlay(name, *) = ($bgm_calls << [:play, name]; $bgm_now = name)
def pbBGMFade(_s) = ($bgm_calls << [:fade_out]; $bgm_now = nil)
def pbBGMStop = ($bgm_calls << [:stop]; $bgm_now = nil)
def pbMapInterpreter = ($bags_interp ||= Struct.new(:scripts).new([]).tap { |i| def i.setup(list, _id) = scripts << list[0].parameters[0] })
$map_interpreter_running = false
$scene = Scene_Map.new
$game_temp.message_window_showing = false
$game_temp.in_menu = false
$game_temp.in_battle = false
$game_temp.player_transferring = false
$game_temp.followers = BagsFakeFactory.new
$PokemonGlobal = PokemonGlobalMetadata.new
$game_switches = {}
$game_map = Game_Map.new(95)
$bag = BagsTestBag.new
frame = SongR.method(:on_frame)
song_on = -> { $bgm_now == SongR::AUDIO }
check($event_handlers[:bags_song] && SongR.current.nil? && !SongR.running?, "bags rev2 song: a frame hook, and no song at start")

$game_player = BagsFakeChar.new("player", 8, 6)
# Debug song: overlay and music only. The fade runs 3 map frames before the run exists.
$bgm_now = "Calm Camps Area"
$bgm_calls = []
$bags_frames = 0
SongR.start(duo: false)
run = SongR.current
check($bags_frames == 3 && run.reason.nil? && run.clock && song_on.(),
      "bags rev2 song: the fade's map frames run during start, and the song starts live (reason #{run.reason.inspect})")
check(SongR.running? && song_on.() && $bgm_calls == [[:fade_out], [:play, "sakiyot_haftaa"]] && run.overlay.is_a?(BagsFakeOverlay) &&
      Bags.state == BR.new_state && $PokemonGlobal.followers.empty?, "bags rev2 song: the debug song is music and overlay only, no state, no followers")
check(SongR.start(duo: false) == false && SongR.current.equal?(run), "bags rev2 song: one song at a time")
half = SongR::Run.new($PokemonGlobal, false, run.timing)
SongR.instance_variable_set(:@current, half)
half_ok = (SongR.tick(half).nil? && (frame.(); true) && half.reason.nil? && half.clock.nil? rescue false)
SongR.instance_variable_set(:@current, run)
check(half_ok, "bags rev2 song: a run whose setup has not finished (no clock) is never ticked or ended")
$bags_pos = 10.0
frame.()
$game_temp.message_window_showing = true
$bags_pos = 10.5
frame.()
$game_temp.message_window_showing = false
$game_temp.in_menu = true
frame.()
$game_temp.in_menu = false
check(run.overlay.updates == [[10.0, true], [10.5, false], [10.5, false]], "bags rev2 song: the clock runs on while messages and menus hide the overlay")
check(run.overlay.xs == [$game_player.screen_x], "bags rev2 song: the overlay is told where the player stands (rain keeps out of that gutter)")
# Leaving Scene_Map (title, arcade restart): the overlay goes in the update that changes $scene,
# before the engine freezes the screen; the dispose hook is the backstop.
old_overlay = run.overlay
$bags_update_ran = false
$scene.update
check($bags_update_ran && !old_overlay.disposed && run.overlay.equal?(old_overlay), "bags rev2 song: a normal map frame keeps the overlay")
map_scene = $scene
$scene = Object.new
map_scene.update
check(old_overlay.disposed && run.overlay.nil? && SongR.running?, "bags rev2 song: the update that leaves Scene_Map disposes the overlay before the freeze")
$scene = map_scene
$bags_pos = 10.8
frame.()
fresh = run.overlay
$bags_dispose_ran = false
map_scene.dispose
check($bags_dispose_ran && fresh.disposed && run.overlay.nil?, "bags rev2 song: Scene_Map#dispose also takes the overlay down (F12 or a double load)")
map_scene.dispose
check(run.overlay.nil?, "bags rev2 song: disposing twice is harmless")
# scene_left never raises, even when the overlay's dispose does
$bags_pos = 10.9
frame.()
boom = run.overlay
boom.define_singleton_method(:dispose) { raise "gone" }
check((SongR.scene_left; true) && run.overlay.nil?, "bags rev2 song: scene_left swallows an overlay dispose error")
$bags_pos = 11.0
frame.()
check(run.overlay.is_a?(BagsFakeOverlay) && !run.overlay.equal?(old_overlay) && run.overlay.updates == [[11.0, true]],
      "bags rev2 song: back on the map, a fresh overlay picks up the song time")
# Music carry: the next map keeps the song (its own BGS still plays)
$bgm_calls = []
$game_map = Game_Map.new(109)
$scene.autofade(86)
$game_map.autoplay
$game_map.autoplayAsCue
check($bgm_calls.empty? && song_on.(), "bags rev2 song: map changes neither fade nor replace the song")
# Interrupted by other music: overlay gone, that music left alone
$bgm_now = "Battle wild"
$bgm_calls = []
frame.()
check(!SongR.running? && run.overlay.disposed && $bgm_calls.empty? && $bgm_now == "Battle wild", "bags rev2 song: another BGM ends the song and is left alone")
$bgm_calls = []
$game_map.autoplay
check($bgm_calls == [[:own, 109]], "bags rev2 song: after the song each map plays its own music again")
# Done at the loop: the map's music comes back
SongR.start(duo: false)
run = SongR.current
[5.0, 6.0, 0.2].each { |p| $bags_pos = p; frame.() }
check(!SongR.running? && run.overlay.disposed && $bgm_calls.last(2) == [[:stop], [:own, 109]], "bags rev2 song: the end of the song brings the map music back")
# A new game, load or F12 swaps $PokemonGlobal: the old song stops silently
SongR.start(duo: false)
run = SongR.current
$PokemonGlobal = PokemonGlobalMetadata.new
$bgm_calls = []
$game_map.autoplay
frame.()
check($bgm_calls == [[:own, 109]] && run.overlay.disposed && SongR.current.nil?, "bags rev2 song: a new game plays its own music and the old song is dropped")
# A start that fails part-way has no clock; the end path still brings the map music back
real_start_audio = SongR.method(:start_audio)
[[true, "the song started"], [false, "the fade left silence"]].each do |played, what|
  SongR.define_singleton_method(:start_audio) do |_r|
    pbBGMFade(0.5)
    pbBGMPlay(SongR::AUDIO) if played
    raise "boom"
  end
  $bgm_now = "Calm Camps Area"
  failed = SongR.start(duo: false) == false && SongR.current&.reason == :done && SongR.current.clock.nil?
  $bgm_calls = []
  frame.()
  check(failed && SongR.current.nil? && $bgm_calls == [[:stop], [:own, 109]], "bags rev2 song: a start that fails after #{what} still restores the map music")
end
SongR.define_singleton_method(:start_audio, real_start_audio)

# The duo song: they follow, then the end scene sends them off
$game_map = Game_Map.new(95)
duo_events = { 17 => BagsFakeChar.new("bags_unicorn_esther", 20, 10), 18 => BagsFakeChar.new("bags_unicorn_shirpaz", 22, 10) }
$game_map.events = duo_events
$game_player = BagsFakeChar.new("player", 21, 10)
$game_temp.followers = BagsFakeFactory.new
$PokemonGlobal.bags_quest = BR.normalize({ inbar: :done, payoff_given: true })
$game_switches[106] = true
$bag = BagsTestBag.new(SURPRISEBAG: 1)
$bgm_now = "Calm Camps Area"
SongR.start(duo: true)
check(Bags.state[:duo] == :touring && $PokemonGlobal.followers.map(&:name) == %w[bags_duo_esther bags_duo_shirpaz] &&
      $game_switches[106] == false && song_on.(), "bags rev2 duo: Esther then Shirpaz follow, the map events hide, the song plays")
# Load mid-song: no song, no followers, gone, nothing re-given
$bgm_calls = []
pbAutoplayOnSave
check(SongR.current.nil? && Bags.state[:duo] == :gone && $PokemonGlobal.followers.empty? && $game_temp.followers.list.empty? &&
      $game_switches[106] == false && $bag.quantity(:SURPRISEBAG) == 1 && Bags.state[:payoff_given] && $bgm_calls == [[:own, 95]],
      "bags rev2 load: a mid-song save loads as song over, duo gone, no bag change, map music")
pbAutoplayOnSave
check(Bags.state[:duo] == :gone && $bag.quantity(:SURPRISEBAG) == 1, "bags rev2 load: loading again changes nothing")
# Encore on a rev-1 save, then the end: line, walk north, fade, gone
$PokemonGlobal.bags_quest = BR.normalize({ inbar: :done, payoff_given: true })
Bags.sync_switch
$bgm_now = "Calm Camps Area"
SongR.start(duo: true)
duo = $game_temp.followers.list.map(&:first)
$bags_log = []
$bags_faces = []
$game_temp.message_window_showing = true
check(SongR.end_now && (frame.(); pbMapInterpreter.scripts.empty?), "bags rev2 end: the end scene waits for a safe frame")
$game_temp.message_window_showing = false
frame.()
frame.()
check(pbMapInterpreter.scripts == ["Bags::Song.end_scene"] && SongR.current.ending, "bags rev2 end: the end scene runs once, through the map interpreter")
$bgm_calls = []
eval(pbMapInterpreter.scripts.shift)
check($bags_log.first == ["BAGS_UNICORN_SONG_END", "BAGS_NAME_ESTHER"] && $bags_faces.sort == %w[bags_unicorn_esther bags_unicorn_shirpaz],
      "bags rev2 end: both turn to the player and Esther says the end line with her plate")
check(duo.all? { |d| d.walked.map(&:first) == [4] * 4 && d.walked.all? { |_, th, _| th } && d.opacity == 0 },
      "bags rev2 end: on Map095 both walk 4 steps north through anything, then fade out")
check(duo.all? { |d| d.is_a?(Game_Follower) && d.walked.all? { |_, _, sp| sp == Bags::WALK_SPEED } && d.bags_speed_lock.nil? },
      "bags rev2 end: the leave walk keeps WALK_SPEED though the follower factory copies the player's speed every frame")
check(SongR.current.nil? && Bags.state[:duo] == :gone && $game_temp.followers.list.empty? && $game_switches[106] == false &&
      $bgm_calls == [[:stop], [:own, 95]] && $bag.quantity(:SURPRISEBAG) == 1, "bags rev2 end: followers removed, gone for good, map music, no item change")
# Away from Map095 they walk away from the player; an interruption leaves the other music
$PokemonGlobal.bags_quest = BR.normalize({ inbar: :done, payoff_given: true })
$bgm_now = "Calm Camps Area"
SongR.start(duo: true)
duo = $game_temp.followers.list.map(&:first)
$game_map = Game_Map.new(86)
$bgm_now = "Aliens"
$bgm_calls = []
frame.()
eval(pbMapInterpreter.scripts.shift)
check(duo.all? { |d| d.walked.map(&:first) == [11] * 4 } && $bgm_calls.empty? && Bags.state[:duo] == :gone,
      "bags rev2 end: on another map they walk away from the player; other music stays")
# An event fades the music and transfers while the end scene waits: no silent map
$PokemonGlobal.bags_quest = BR.normalize({ inbar: :done, payoff_given: true })
$bgm_now = "Calm Camps Area"
SongR.start(duo: true)
pbBGMFade(1.0)
$bgm_calls = []
$game_map = Game_Map.new(109)
$game_map.autoplay
check($bgm_calls == [[:own, 109]], "bags rev2: a transfer right after an event fades the song is not held silent")
$game_temp.message_window_showing = true
frame.()
$game_map = Game_Map.new(86)
$bgm_calls = []
$game_map.autoplay
check(SongR.current.reason == :interrupted && !SongR.running? && pbMapInterpreter.scripts.empty? && $bgm_calls == [[:own, 86]],
      "bags rev2: once the song has ended, map music is no longer held while the end scene waits")
$game_temp.message_window_showing = false
$bgm_now = nil
$bgm_calls = []
frame.()
eval(pbMapInterpreter.scripts.shift)
check($bgm_calls == [[:stop], [:own, 86]] && Bags.state[:duo] == :gone, "bags rev2: an end scene over silence plays the map's music")
# No timing file: no song, straight to the end scene
$game_map = Game_Map.new(95)
$game_map.events = duo_events
$PokemonGlobal.bags_quest = BR.normalize({ inbar: :done, payoff_given: true })
real_load_timing = SongR.method(:load_timing)
SongR.define_singleton_method(:load_timing) { nil }
$bgm_now = "Calm Camps Area"
$bgm_calls = []
SongR.start(duo: true)
frame.()
eval(pbMapInterpreter.scripts.shift)
check($bgm_calls.empty? && Bags.state[:duo] == :gone && $game_temp.followers.list.empty?, "bags rev2: no timing file means no song, and the duo still leaves")
SongR.define_singleton_method(:load_timing, real_load_timing)
# Debug reset: stops the song, drops the followers, fresh quest
$PokemonGlobal.bags_quest = BR.normalize({ inbar: :done, payoff_given: true })
SongR.start(duo: true)
Bags.reset
check(SongR.current.nil? && $game_temp.followers.list.empty? && Bags.state == BR.new_state && $game_switches[106] == false,
      "bags rev2 debug: reset stops the song and drops the duo followers")
SongR.send(:remove_const, :Overlay)
SongR.const_set(:Overlay, real_overlay)
$game_player = nil
Dir.chdir(bags_prev_dir)

# R10: the end line is the founder's, byte for byte; the skip prompt is gone
founder = "מה?? נגמרה השקית? שירפז בואי, הולכות לספייסשיפ, שמעתי יש להם מלא שקיות"
tr_doc = JSON.parse(File.read(File.join(ROOT, "PBS/translations.json"), encoding: "utf-8"))["translations"]
check(tr_doc["BAGS_UNICORN_SONG_END"]["he"].b == founder.b && Bags::Duo::END_LINE == "BAGS_UNICORN_SONG_END",
      "bags rev2: BAGS_UNICORN_SONG_END is the founder's line byte for byte")
check(!hooks_src.include?("BAGS_SONG_SKIP"), "bags rev2: no skip prompt (BAGS_SONG_SKIP is not referenced)")

# Duo.join raising after tour!: the failed start undoes the tour and publishes nothing
$game_map = Game_Map.new(95)
$game_map.events = duo_events
$game_temp.followers = BagsFakeFactory.new
$PokemonGlobal.followers.clear
$PokemonGlobal.bags_quest = BR.normalize({ inbar: :done, payoff_given: true })
$game_temp.followers.define_singleton_method(:add_follower) do |ev, name|
  raise "no room" if name.end_with?("shirpaz")
  @list << [Game_Follower.new(ev.name, ev.x, ev.y), BagsFakeFactory::FData.new(name, true)]
  $PokemonGlobal.followers << @list.last[1]
end
$bgm_now = "Calm Camps Area"
SongR.stop
failed = SongR.start(duo: true)
check(failed == false && SongR.current.nil? && $game_temp.followers.list.empty? && $PokemonGlobal.followers.empty? && Bags.state[:duo] == :gone,
      "bags rev2: a join that raises for Shirpaz leaves no half duo (no followers, :gone, no run)")
