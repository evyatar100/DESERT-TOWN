# TG40 DJ Rush Hour: loaded from plugin_rules_test.rb (shares check/$failures).
# DJRushRules is pure; the map/talk flow runs against stubs; the scene runs in its own process.
require "json"
dj_dir = File.join(ROOT, "Plugins/zDJRush")
load File.join(dj_dir, "000_rules.rb")
DR = DJRushRules

class DJTestBag
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
dj_st = ->(stage, extra = {}) { DR.normalize({ stage: stage, cleared: DR.rank(stage) >= 2 ? 3 : 0 }.merge(extra)) }

#-------------------------------------------------------------------------------
# Board: T1/T2 fuzz, T3 pass-through, T4/T6 search, T7 win, T8 restart, T9 counter, T10 hint
#-------------------------------------------------------------------------------
def dj_board_ok?(b, start)
  seen = {}
  b[:pieces].each do |id, p|
    return false unless (p[:horiz] ? p[:y] : p[:x]) == (start[:pieces][id][:horiz] ? start[:pieces][id][:y] : start[:pieces][id][:x])
    DR.cells(p).each do |c|
      return false if seen[c] || !c.all? { |v| v.between?(0, 5) }
      seen[c] = true
    end
  end
  true
end

rng = Random.new(40)
fuzz_bad = []
cross_ok = true
3.times do |lv|
  b = DR.new_board(lv)
  start = DR.new_board(lv)
  cur = [0, 2]
  20_000.times do
    case rng.rand(4)
    when 0 then cur = DR.cursor(cur, DR::DIRS.keys.sample(random: rng))
    when 1 then (id = DR.piece_at(b, *cur)) && DR.grab(b, id)
    when 2
      if (id = b[:grab])
        dir = DR::DIRS.keys.sample(random: rng)
        p = b[:pieces][id]
        across = p[:horiz] ? %i[up down].include?(dir) : %i[left right].include?(dir)
        r = DR.slide(b, id, dir)
        cross_ok &&= (r == :cross) == across
        cur = DR.cursor(cur, dir) if r == :moved
      end
    else DR.release(b)
    end
    next if dj_board_ok?(b, start)
    fuzz_bad << lv
    break
  end
end
check(fuzz_bad.empty?, "djrush T1/T2: 20k random inputs per level keep pieces disjoint, on the board, on their own line (#{fuzz_bad.inspect})")
check(cross_ok, "djrush T2: a slide across the piece's axis is refused (:cross) and only then")

wall = { level: 0, pieces: DR.parse(%w[...... ...... .....c .....c .....d .....d]), moves: 0, grab: nil, grab_from: nil }
DR.grab(wall, "c")
ten = Array.new(10) { DR.slide(wall, "c", :down) }
check(ten.all? { |r| r == :blocked } && wall[:pieces]["c"][:y] == 2, "djrush T3: a sleeper with a piece right below never moves down")
check(DR.slide(wall, "c", :up) == :moved && wall[:pieces]["c"][:y] == 1, "djrush T3: a slide moves exactly one cell per call")

check(DR::MIN_MOVES == [3, 8, 15] && (0..2).map { |i| DR.min_moves(i) } == DR::MIN_MOVES, "djrush T4: BFS minimum moves are 3, 8, 15")
one_move = (0..2).select do |i|
  b = DR.new_board(i)
  sh = DR.shape(b)
  car = sh.index { |s| s[0] == "A" }
  DR.next_moves(sh, DR.key(b)).any? { |_, _, k| k[car] == 4 }
end
check(DR::MIN_MOVES.all? { |m| m >= 3 } && one_move.empty?, "djrush T6: no board starts one move from the exit (#{one_move.inspect})")

win_ok = (0..2).all? do |i|
  b = DR.new_board(i)
  path = DR.bfs_path(DR.new_board(i))
  path.each_with_index.all? do |(id, delta), n|
    DR.grab(b, id)
    dir = b[:pieces][id][:horiz] ? (delta < 0 ? :left : :right) : (delta < 0 ? :up : :down)
    delta.abs.times { DR.slide(b, id, dir) }
    solved = DR.solved?(b)
    DR.release(b)
    solved == (n == path.length - 1)
  end && b[:moves] == DR::MIN_MOVES[i]
end
check(win_ok, "djrush T7: replaying the shortest solution is solved exactly at its last slide, in MIN_MOVES moves")

st8 = dj_st.(:intro, cleared: 1, best: [5, nil, nil])
b = DR.new_board(1)
DR.grab(b, "d")
DR.slide(b, "d", :left)
DR.release(b)
DR.restart(b)
check(b == DR.new_board(1) && st8 == dj_st.(:intro, cleared: 1, best: [5, nil, nil]), "djrush T8: restart is the level start with 0 moves; cleared and best untouched")

b = DR.new_board(0)
DR.grab(b, "b")
DR.release(b)
DR.grab(b, "b")
DR.slide(b, "b", :up)
DR.slide(b, "b", :down)
c0 = DR.release(b)
DR.grab(b, "b")
DR.slide(b, "b", :up)
c1 = DR.release(b)
DR.grab(b, "c")
DR.slide(b, "c", :up)
c2 = DR.release(b)
check(!c0 && c1 && c2 && b[:moves] == 2, "djrush T9: net-0 grabs count 0; two +1 grabs count 2")

hint_bad = []
[1, 2].each do |i|
  b = DR.new_board(i)
  DR.bfs_path(DR.new_board(i)).each do |id, delta|
    left = DR.bfs_path(b).length
    hid, hd = DR.hint(b)
    t = { level: i, pieces: Marshal.load(Marshal.dump(b[:pieces])), moves: 0, grab: nil, grab_from: nil }
    dir = t[:pieces][hid][:horiz] ? (hd < 0 ? :left : :right) : (hd < 0 ? :up : :down)
    hd.abs.times { DR.slide(t, hid, dir) }
    hint_bad << [i, id] unless DR.bfs_path(t).length == left - 1
    dir = b[:pieces][id][:horiz] ? (delta < 0 ? :left : :right) : (delta < 0 ? :up : :down)
    delta.abs.times { DR.slide(b, id, dir) }
  end
end
check(hint_bad.empty?, "djrush T10: on every L2/L3 shortest-path state the hint is a shortest-path move (#{hint_bad.inspect})")

ids_ok = (0..2).all? do |i|
  all = DR.crowd_ids(i).values.flatten
  all.uniq.length == all.length && (all - DR::CROWD_POOL).empty? && DR.crowd_ids(i) == DR.crowd_ids(i)
end
check(DR::CROWD_POOL.length == 48 && DR::CROWD_POOL.uniq.length == 48 && ids_ok &&
      (DR::CROWD_POOL & %w[cace0cde 845a91aa 4b08e38a fc898478]).empty?, "djrush D6: 48-id crowd pool, deterministic faces, no repeat inside a level")
reacts = Array.new(200) { |n| DR.reaction_key(:couple, false, "DJRUSH_R_COUPLE_1", n / 200.0) }
check(DR.reaction_key(:conga, true, nil, 0.99) && reacts.compact.none?("DJRUSH_R_COUPLE_1") && reacts.count(nil).between?(80, 120),
      "djrush D7: first move of a kind always reacts, later ~50%, never the same key twice in a row")

# TG53: complaints before the swap, Ido's line after it.
excluded = %w[cace0cde 4b08e38a 845a91aa fc898478 207a26e8]
gate = ->(fn, stage, map, id) { DR.public_send(fn, dj_st.(stage), map, id) }
check(DR::COMPLAIN_IDS.length == 47 && DR::COMPLAIN_IDS == DR::CROWD_POOL - %w[207a26e8] &&
      DR::COMPLAIN_IDS.all? { |i| %i[none intro].all? { |stg| gate.(:complain?, stg, 93, i) } } &&
      excluded.none? { |i| %i[none intro].any? { |stg| gate.(:complain?, stg, 93, i) } },
      "djrush TG53 D9: every one of the 47 ids complains at :none/:intro on Map093; Ido, Johnny, Evyatar, She Se and the duel NPC never do")
check(DR::COMPLAIN_IDS.none? { |i| gate.(:complain?, :intro, 98, i) || gate.(:complain?, :none, 91, i) } &&
      DR::COMPLAIN_IDS.none? { |i| %i[freed bag done].any? { |stg| gate.(:complain?, stg, 93, i) } },
      "djrush TG53 D8: no complaint on other maps, and none from :freed on")
check(%i[none intro].none? { |stg| gate.(:ido_floor?, stg, 93, "cace0cde") } && %i[freed bag done].all? { |stg| gate.(:ido_floor?, stg, 93, "cace0cde") } &&
      !gate.(:ido_floor?, :done, 98, "cace0cde") && !gate.(:ido_floor?, :done, 93, "11eaf4fa"),
      "djrush TG53 D11: ido_floor? is the reverse gate, Ido only, Map093 only")
rolls = (0..1000).map { |n| n / 1000.0 }
rng = Random.new(7)
seq = Array.new(1000) { rng.rand }.each_with_object([nil]) { |r, a| a << DR.complaint_key(a.last, r) }
check(rolls.all? { |r| DR::COMPLAIN_KEYS.all? { |k| DR.complaint_key(k, r) != k } } && seq.compact.uniq.sort == DR::COMPLAIN_KEYS.sort &&
      seq.each_cons(2).none? { |a, b| a == b } && DR::COMPLAIN_KEYS.length == 6,
      "djrush TG53 D10: complaint_key never returns last_key over 1000 rolls, and every key can come up")

#-------------------------------------------------------------------------------
# Quest: T11 car only after the solve, T12 bag exactly once, T13 reissue, T14 phrase, T16 no stuck state
#-------------------------------------------------------------------------------
t11 = (0..3).all? { |c| DR.car_decide(dj_st.(:none, cleared: c), nil) == :intro && DR.car_decide(dj_st.(:intro, cleared: c), nil) == :prompt_again }
check(t11, "djrush T11: before :freed the car only offers the puzzle, for every cleared value")
s = dj_st.(:intro, cleared: 2)
check(!DR.give_bag!(s, DJTestBag.new) && !DR.free!(s) && s[:stage] == :intro, "djrush T11: give_bag! needs :freed, free! needs cleared 3")
check(!DR.clear_level!(s, 0, 9) && s[:cleared] == 2 && DR.clear_level!(s, 2, 15) && s[:cleared] == 3 && s[:best][2] == 15,
      "djrush: a cleared board out of order does not count; the next one does")
check(!DR.clear_level!(s, 2, 14), "djrush: fewer moves than the minimum is impossible and rejected")

bag = DJTestBag.new
s = DR.new_state
max_held = 0
walk = [-> { DR.start!(s) }, -> { 3.times { |i| DR.clear_level!(s, i, DR::MIN_MOVES[i] + 1) } }, -> { DR.free!(s) },
        -> { DR.give_bag!(s, bag) }, -> { DR.give_bag!(s, bag) }, -> { DR.reissue!(s, bag) }, -> { DR.deliver!(s, bag) },
        -> { DR.reissue!(s, bag) }, -> { DR.give_bag!(s, bag) }]
walk.each { |f| f.call; max_held = [max_held, bag.quantity(:MUSICBAG)].max }
check(max_held == 1 && s[:stage] == :done && bag.quantity(:MUSICBAG) == 1,
      "djrush T12: never more than 1 Music Bag; give twice = 1; reissue while held or in :done is a no-op; Johnny hands it back (1 after :done)")
check(s[:best] == [4, 9, 16] && DR.clear_level!(s, 1, 8) && s[:best] == [4, 8, 16] && s[:cleared] == 3, "djrush: a replay after :freed records best only")

s = dj_st.(:bag)
bag = DJTestBag.new
check(DR.car_decide(s, bag) == :reissue && DR.reissue!(s, bag) && bag.quantity(:MUSICBAG) == 1 && DR.car_decide(s, bag) == :remind,
      "djrush T13: a lost bag in :bag is reissued once, then the DJ reminds")

check(!DR.deliver!(dj_st.(:freed), DJTestBag.new(MUSICBAG: 1)) && !DR.deliver!(dj_st.(:bag), DJTestBag.new),
      "djrush T14: deliver! only in :bag with the bag held")
check((0..3).map { |i| DR.say_result(i) } == %i[wrong phrase wrong nothing] && DR.say_result(-1) == :nothing &&
      DR::SAY_KEYS[DR::PHRASE_INDEX] == "DJRUSH_SAY_PHRASE", "djrush T14: menu row 2 is the phrase; the decoys and cancel change nothing")

forward = DR::STAGES.product([true, false]).all? do |stage, held|
  st = dj_st.(stage)
  bg = DJTestBag.new(held ? { MUSICBAG: 1 } : {})
  case DR.car_decide(st, bg)
  when :intro, :prompt_again then true
  when :meet then DR.give_bag!(st, bg)
  when :reissue then DR.reissue!(st, bg)
  when :remind then DR.johnny_decide(st, bg, 98) == :menu
  when :after then st[:stage] == :done
  end
end
junk = DR.normalize({ stage: :boss, cleared: 9, best: [1, "x", 99], extra: 1 })
check(forward && junk == { stage: :none, cleared: 3, best: [nil, nil, 99] } && DR.normalize(nil) == DR.new_state,
      "djrush T16: every (stage, held) has a forward talk; normalize repairs junk")
check(DR.johnny_decide(dj_st.(:bag), DJTestBag.new(MUSICBAG: 1), 91).nil? && DR.johnny_decide(dj_st.(:bag), DJTestBag.new, 98).nil? &&
      DR.johnny_decide(dj_st.(:bag), DJTestBag.new, 93) == :hint && DR.johnny_decide(dj_st.(:done), nil, 98) == :after &&
      DR.johnny_decide(dj_st.(:done), nil, 93).nil?, "djrush T15: Johnny acts only on 98 (menu/after) and 93 (hint in :bag)")

class DJNoAddBag < DJTestBag   # the hand-back add fails once; the roll-back add works
  def add(i, n = 1) = (@failed ? super : (@failed = true; false))
end
nb = DJNoAddBag.new(MUSICBAG: 1)
s = dj_st.(:bag)
check(!DR.deliver!(s, nb) && s[:stage] == :bag && nb.quantity(:MUSICBAG) == 1, "djrush: a failed hand-back rolls back (bag kept, stage :bag)")
f9 = DR::STAGES.map { |stg| b9 = DJTestBag.new(MUSICBAG: 2); DR.debug_set!(DR.new_state, b9, stg); b9.quantity(:MUSICBAG) }
check(f9 == [0, 0, 0, 1, 1], "djrush F9: set stage holds one bag in :bag and :done, none before (#{f9.inspect})")

#-------------------------------------------------------------------------------
# Inbar counts the Music Bag (founder, TG40), only after the delivery
#-------------------------------------------------------------------------------
BR2 = BagsRules
mix = DJTestBag.new(MUSICBAG: 1, SURPRISEBAG: 1)
asked = BR2.normalize({ inbar: :asked })
check(BR2.inbar_count(mix, true) == 2 && BR2.inbar_count(mix, false) == 1 && BR2.inbar_count(DJTestBag.new(MUSICBAG: 3), true) == 1,
      "djrush/bags: the Music Bag + 1 Surprise Bag count as 2 after the delivery, 1 before; one Music Bag counts at most")
check(!BR2.hand_over!(asked, mix, false) && asked[:inbar] == :asked && mix.quantity(:MUSICBAG) == 1 &&
      BR2.music_not_yet?(asked, mix, false) && !BR2.music_not_yet?(asked, mix, true), "djrush/bags: before the delivery Inbar refuses it")
two = DJTestBag.new(MUSICBAG: 1, SURPRISEBAG: 2)
s2 = BR2.normalize({ inbar: :asked })
check(BR2.hand_over!(s2, two, true) && two.quantity(:SURPRISEBAG) == 0 && two.quantity(:MUSICBAG) == 1, "djrush/bags: Surprise Bags go first")
class DJStickyBag < DJTestBag
  def remove(i, n = 1) = i == :MUSICBAG ? false : super
end
sticky = DJStickyBag.new(MUSICBAG: 1, SURPRISEBAG: 1)
s4 = BR2.normalize({ inbar: :asked })
check(!BR2.hand_over!(s4, sticky, true) && sticky.items == { MUSICBAG: 1, SURPRISEBAG: 1 } && s4[:inbar] == :asked,
      "djrush/bags: hand_over! is all or nothing (a failed removal puts the Surprise Bag back)")
dj = dj_st.(:bag)
bag = DJTestBag.new(MUSICBAG: 1, SURPRISEBAG: 1)
DR.deliver!(dj, bag)
s3 = BR2.normalize({ inbar: :asked })
took = BR2.hand_over!(s3, bag, DR.delivered?(dj))
check(took && bag.quantity(:MUSICBAG) == 0 && bag.quantity(:SURPRISEBAG) == 0 && s3[:inbar] == :done &&
      !DR.reissue!(dj, bag) && DR.car_decide(dj, bag) == :after && bag.quantity(:MUSICBAG) == 0,
      "djrush/bags: after the delivery Inbar takes it as one of 2; the DJ never reissues it afterwards")

#-------------------------------------------------------------------------------
# Map and talk flow against stubs
#-------------------------------------------------------------------------------
$dj_log = []
$dj_picks = []
$dj_confirm = []
$dj_scenes = []
def pbMessage(msg, commands = nil, _cancel = 0)
  $dj_log << [msg, DesertTalk.name_key]
  return nil unless commands
  $dj_log << [:rows, commands]
  $dj_picks.shift
end
def pbConfirmMessage(m) = ($dj_log << [m, DesertTalk.name_key]; $dj_confirm.shift)
def _INTL(m, *a) = a.empty? ? m : "#{m}|#{a.join(',')}"
def pbMEPlay(name, *) = ($dj_log << [:me, name])
def pbSEPlay(name, *) = ($dj_log << [:se, name])
def pbFadeOutIn = ($dj_log << :fade; yield)
def pbResolveBitmap(_p) = nil
def echoln(*); end unless respond_to?(:echoln, true)
module DJRush
  class Scene
    def initialize(state, levels, replay: false, record: true, seed: nil) = (@st, @levels, @replay = state, levels, replay)
    def run
      $dj_log << [:scene, @levels, @replay]
      r = $dj_scenes.shift || { result: :quit }
      if r[:result] == :freed
        @levels.each { |i| DJRushRules.clear_level!(@st, i, DJRushRules::MIN_MOVES[i]) }
        DJRushRules.free!(@st)
      end
      r
    end
  end
end
%w[001_state 002_art 004_map 005_talk_hooks 006_debug 007_stage_swap].each { |f| load File.join(dj_dir, "#{f}.rb") }
saved = [$game_map, $bag, $PokemonGlobal, $game_player]

class DJLiveEv
  attr_accessor :name, :character_name, :x, :y
  attr_reader :erased
  def initialize(name, graphic, x = 0, y = 0) = (@name, @character_name, @erased, @x, @y = name, graphic, false, x, y)
  def moveto(x, y) = (@x, @y = x, y)
  attr_writer :direction
  def anime? = @step_anime
  def dir = @direction
  def erase = (@erased = true)
  def row = DJRush::ROW_DIR.index(@direction)
  def fixed? = @direction_fix && @step_anime
end
DJMap = Struct.new(:map_id, :events)
DJPlayer = Struct.new(:character_name, :x, :y) do
  def moveto(x, y) = (self.x, self.y = x, y)
end
$PokemonGlobal = PokemonGlobalMetadata.new
$bag = DJTestBag.new
$game_player = DJPlayer.new("trchar000", 12, 25)
live = { 82 => DJLiveEv.new("djrush_car", "djrush_car", 12, 23) }
(1..3).each { |i| live[82 + i] = DJLiveEv.new("djrush_crowd_#{i}", "alien") }
live[50] = DJLiveEv.new("dt_cace0cde", "dt_cace0cde", 34, 12)
live[1] = DJLiveEv.new("dt_11eaf4fa", "dt_11eaf4fa", 5, 5)
$game_map = DJMap.new(93, live)
msgs = ->(log) { log.select { |e| e.is_a?(Array) && e[0].is_a?(String) }.map { |e| e[0].split("|")[0] } }
car = lambda do |confirm: [], picks: [], scenes: []|
  $dj_log.clear
  $dj_confirm, $dj_picks, $dj_scenes = confirm, picks, scenes
  pbDJRushCar(live[82])
  $dj_log.dup
end
st = -> { $PokemonGlobal.dj_rush }

check($PokemonGlobal.dj_rush == DR.new_state, "djrush save: an old save without dj_rush loads the default")
log = car.(confirm: [false])
check(msgs.(log) == %w[DJRUSH_JAM_HONK DJRUSH_JAM_ALIEN DJRUSH_JAM_DJ DJRUSH_JAM_PROMPT DJRUSH_JAM_LATER] && st.()[:stage] == :intro &&
      log.find { |m, _| m == "DJRUSH_JAM_DJ" }[1] == "NAME_FC898478" && log.find { |m, _| m == "DJRUSH_JAM_ALIEN" }[1].nil?,
      "djrush flow: first talk runs the jam (alien without, DJ with a plate), stage :intro, No gives the 'later' line")
$dj_log.clear
$dj_confirm = [true]
$dj_scenes = [{ result: :quit }]
pbDJRushCrowd
check($dj_log.include?(["DJRUSH_JAM_PROMPT_AGAIN|1", nil]) && $dj_log.include?([:scene, [0, 1, 2], false]) && st.()[:stage] == :intro,
      "djrush flow: an alien asks again with the floor number and opens boards 1-3; a quit keeps :intro")
st.()[:cleared] = 1
log = car.(confirm: [true], scenes: [{ result: :freed }])
order = msgs.(log)
check(log.include?([:scene, [1, 2], false]) && st.()[:stage] == :freed && $bag.quantity(:MUSICBAG) == 0 &&
      order == %w[DJRUSH_JAM_PROMPT_AGAIN DJRUSH_DJ_TO_STAGE] && log.index(:fade) < log.index { |e| e[0] == "DJRUSH_DJ_TO_STAGE" } &&
      log.find { |m, _| m == "DJRUSH_DJ_TO_STAGE" }[1] == "NAME_FC898478",
      "djrush TG53 D6: the win ends with the to-stage line only (stage stays :freed, no bag yet) (#{order.inspect})")
check(live.values_at(83, 84, 85).all?(&:erased) && [live[82].x, live[82].y] == [33, 12] && live[82].character_name == "dt_fc898478" &&
      live[82].dir == 2 && live[82].fixed? && [live[50].x, live[50].y] == [35, 19] && live[50].anime? && live[1].anime?,
      "djrush TG53 D2-D4: after the win the crowd is erased, She Se is at (33,12), Ido on (35,19), everyone steps in place")
log = car.(confirm: [false])
order = msgs.(log)
got_line = order.index { |k| k.start_with?('\me[Key item get]') }
check(st.()[:stage] == :bag && $bag.quantity(:MUSICBAG) == 1 &&
      order.first(3) == %w[DJRUSH_DJ_HELLO DJRUSH_DJ_BAG_1 DJRUSH_DJ_BAG_2] && got_line == 3 && order.last == "DJRUSH_DJ_PHRASE" && [live[82].x, live[82].y] == [33, 12] && live[82].dir == 2,
      "djrush TG53 D6: talking to She Se on the stage runs the meeting: hello, bag lines, item, phrase (#{order.inspect})")
log = car.(confirm: [false])
check(msgs.(log) == %w[DJRUSH_DJ_REMIND DJRUSH_REPLAY_PROMPT] && $bag.quantity(:MUSICBAG) == 1, "djrush flow: talk again reminds, then offers a replay")
$bag.remove(:MUSICBAG)
log = car.(confirm: [true], picks: [2], scenes: [{ result: :solved }])
check(msgs.(log).first == "DJRUSH_DJ_REISSUE" && !msgs.(log).include?("DJRUSH_DJ_PHRASE") && $bag.quantity(:MUSICBAG) == 1,
      "djrush T13 flow: a lost bag is reissued with the REISSUE line (it carries the phrase; no PHRASE after)")
log = car.(confirm: [true], picks: [2], scenes: [{ result: :solved }])
rows = log.find { |e| e[0] == :rows }
check(log.include?([:scene, [2], true]) && rows && rows[1] == (0..2).map { |i| "DJRUSH_LEVEL|#{i + 1} · DJRUSH_LEVEL_NAME_#{i + 1}" },
      "djrush flow: the replay pick lists the 3 floors from DJRUSH_LEVEL + LEVEL_NAME and replays one (best only)")
check(live[82].dir == 2 && [live[82].x, live[82].y] == [33, 12], "djrush: She Se stays put, facing down, after every talk")

# Johnny on the Playa (98), at the party (93) and the unreachable demo (91).
johnny = lambda do |map_id, picks = []|
  $dj_log.clear
  $dj_picks = picks
  $game_map = DJMap.new(map_id, {})
  DesertTalk.start_speaker("4b08e38a")
  pbDesertTalk("4b08e38a")
  msgs.($dj_log)
end
check(johnny.(93) == %w[MSG_4B08E38A_LINE DJRUSH_JOHNNY_PARTY_HINT], "djrush T15: party Johnny gives the Playa hint in :bag")
check(johnny.(91) == %w[MSG_4B08E38A_LINE], "djrush T15: Johnny on Map091 does nothing")
check(johnny.(98, [0]) == %w[MSG_4B08E38A_LINE DJRUSH_JOHNNY_ASK DJRUSH_JOHNNY_WRONG] && st.()[:stage] == :bag &&
      $dj_log.find { |e| e[0] == :rows }[1] == DR::SAY_KEYS, "djrush T14: a decoy gets WRONG and changes nothing; the menu order is fixed")
check(johnny.(98, [3]) == %w[MSG_4B08E38A_LINE DJRUSH_JOHNNY_ASK] && st.()[:stage] == :bag, "djrush T14: 'say nothing' ends the talk")
got = johnny.(98, [1])
check(got.first(5) == %w[MSG_4B08E38A_LINE DJRUSH_JOHNNY_ASK DJRUSH_JOHNNY_OK_1 DJRUSH_JOHNNY_OK_2 DJRUSH_JOHNNY_OK_3] &&
      got.include?("DJRUSH_JOHNNY_RETURN") && $dj_log.include?([:me, "Slots big win"]) && st.()[:stage] == :done && $bag.quantity(:MUSICBAG) == 1,
      "djrush T14: the exact phrase delivers (:done), plays the ME, reveals the password and Johnny hands the bag back")
check(johnny.(98) == %w[MSG_4B08E38A_LINE DJRUSH_JOHNNY_AFTER] && DJRush.delivery_done?, "djrush: Playa Johnny's after line; delivery_done? is true")
$game_map = DJMap.new(93, live)
check(msgs.(car.(confirm: [false])) == %w[DJRUSH_DJ_AFTER DJRUSH_REPLAY_PROMPT], "djrush flow: the DJ's after line, then the replay offer")

# Inbar's refusal line before the delivery (zBags talk flow, map 95).
$PokemonGlobal.bags_quest = BagsRules.normalize({ inbar: :asked }) if $PokemonGlobal.respond_to?(:bags_quest=)
$PokemonGlobal.dj_rush = dj_st.(:bag)
$bag = DJTestBag.new(MUSICBAG: 1, SURPRISEBAG: 1)
$dj_log.clear
$game_map = DJMap.new(95, {})
Bags.inbar_talk
check(msgs.($dj_log) == %w[BAGS_INBAR_MUSICBAG_NOT_YET BAGS_INBAR_NOTENOUGH] && $dj_log.any? { |m, _| m == "BAGS_INBAR_NOTENOUGH|1" } &&
      $bag.quantity(:MUSICBAG) == 1, "djrush/bags flow: Inbar refuses the Music Bag before the delivery and counts 1")
$PokemonGlobal.dj_rush = dj_st.(:done)
$dj_log.clear
$dj_picks = [1]
Bags.inbar_talk
check(msgs.($dj_log).first == "BAGS_INBAR_GIVE_ASK" && $bag.quantity(:MUSICBAG) == 1, "djrush/bags flow: after the delivery Music + Surprise Bag make Inbar's offer")

# Mirror line, map dressing (RPG map before the events are built), save restore.
$PokemonGlobal.dj_rush = dj_st.(:freed)
$bag = DJTestBag.new
$game_player = DJPlayer.new("dt_fc898478")
$game_map = DJMap.new(93, live)
log = car.()
check(msgs.(log)[0, 2] == %w[DJRUSH_DJ_HELLO DJRUSH_DJ_MIRROR], "djrush: playing as DJ She Se adds the mirror line")
RpgGraphic = Struct.new(:direction, :character_name, :pattern)
RpgPage = Struct.new(:graphic, :direction_fix, :step_anime)
RpgEv = Struct.new(:name, :pages, :x, :y)
RpgMap = Struct.new(:events)
rpg = lambda do
  RpgMap.new({ 1 => RpgEv.new("dt_11eaf4fa", [RpgPage.new(RpgGraphic.new(2, "dt_11eaf4fa", 1), false, false)], 5, 5),
               50 => RpgEv.new("dt_cace0cde", [RpgPage.new(RpgGraphic.new(8, "dt_cace0cde", 0), false, false)], 34, 12),
               82 => RpgEv.new("djrush_car", [RpgPage.new(RpgGraphic.new(2, "djrush_car", 0), false, false)], 12, 23),
               83 => RpgEv.new("djrush_crowd_1", []), 84 => RpgEv.new("djrush_crowd_2", []), 85 => RpgEv.new("djrush_crowd_3", []) })
end
dressed = DR::STAGES.map do |stage|
  $PokemonGlobal.dj_rush = dj_st.(stage)
  m = rpg.()
  $event_handlers[:djrush_party].call(93, m, nil)
  pg = m.events[82].pages[0]
  [pg.graphic.direction, pg.direction_fix && pg.step_anime, m.events.keys.sort, pg.graphic.character_name, m.events[1].pages[0].graphic.direction]
end
check(dressed.map(&:first) == [4, 4, 2, 2, 2] && dressed.all? { |d| d[1] } && dressed.map { |d| d[2].length } == [6, 6, 3, 3, 3] &&
      dressed.all? { |d| d[3] == "dt_fc898478" && d[4] == 2 }, "djrush T17/T18: map setup picks row 1 (stuck) before :freed, the stage look after, removes the crowd from :freed, falls back to the DJ charset without the art, touches nothing else")
# TG53 D2-D5: authored before :freed, swapped from :freed.
looks = %i[intro bag].map do |stage|
  $PokemonGlobal.dj_rush = dj_st.(stage)
  m = rpg.()
  $event_handlers[:djrush_party].call(93, m, nil)
  [m.events[82], m.events[50], m.events[1]].map { |e| [e.x, e.y, e.pages[0].graphic.character_name, e.pages[0].step_anime, e.pages[0].graphic.direction, e.pages[0].graphic.pattern] }
end
check(looks[0] == [[12, 23, "dt_fc898478", true, 4, 0], [34, 12, "dt_cace0cde", false, 8, 0], [5, 5, "dt_11eaf4fa", false, 2, 1]] &&
      looks[1] == [[33, 12, "dt_fc898478", true, 2, 0], [35, 19, "dt_cace0cde", true, 2, 0], [5, 5, "dt_11eaf4fa", true, 2, 1]],
      "djrush TG53: map setup at :intro leaves 82 and 50 as authored; at :bag She Se is on (33,12), Ido on (35,19), every dt_ page steps in place (#{looks.inspect})")
m = rpg.()
$event_handlers[:djrush_party].call(96, m, nil)
check(m.events[82].pages[0].graphic.direction == 2 && m.events.length == 6, "djrush: map setup on another map changes nothing")
fresh = { 82 => DJLiveEv.new("djrush_car", "x"), 83 => DJLiveEv.new("djrush_crowd_1", "a") }
$game_map = DJMap.new(93, fresh)
$PokemonGlobal.dj_rush = dj_st.(:intro)
$event_handlers[:djrush_saved_map].call(nil, true)
check(fresh[82].row == 1 && !fresh[83].erased && [fresh[82].x, fresh[82].y] == [12, 23], "djrush: a restored save before :freed keeps the crowd, car stuck")
$PokemonGlobal.dj_rush = dj_st.(:done)
$event_handlers[:djrush_saved_map].call(nil, true)
check(fresh[83].erased && [fresh[82].x, fresh[82].y] == [33, 12] && fresh[82].character_name == "dt_fc898478",
      "djrush: a restored save after :freed erases the crowd, She Se on the stage")

# TG53 D3/D12/D13: live dressing is idempotent, dodges the player, and rolls back with F9.
ido = DJLiveEv.new("dt_cace0cde", "dt_cace0cde", 34, 12)
guest = DJLiveEv.new("dt_11eaf4fa", "dt_11eaf4fa", 5, 5)
car82 = DJLiveEv.new("djrush_car", "djrush_car", 12, 23)
$game_map = DJMap.new(93, { 82 => car82, 50 => ido, 1 => guest })
$game_player = DJPlayer.new("trchar000", 35, 19)
$bag = DJTestBag.new
$PokemonGlobal.dj_rush = dj_st.(:bag)
DJRush.dress_live
check([ido.x, ido.y] == [36, 19] && ido.dir == 2 && guest.anime? && [car82.x, car82.y] == [33, 12],
      "djrush TG53 D3: with the player on (35,19) Ido goes to (36,19)")
$game_player = DJPlayer.new("trchar000", 33, 14)
DJRush.dress_live
check([ido.x, ido.y] == [36, 19], "djrush TG53: dress_live is idempotent, Ido stays where he is")
$game_player = DJPlayer.new("trchar000", 36, 19)
DJRush.dress_live
check([ido.x, ido.y] == [35, 19], "djrush TG53: and steps aside the other way when the player takes his tile")
$game_player = DJPlayer.new("trchar000", 33, 12)
DJRush.dress_live
check([$game_player.x, $game_player.y] == [33, 14] && [car82.x, car82.y] == [33, 12],
      "djrush TG53: a player standing on She Se's tile is moved to (33,14) before she lands there")
DJRush.debug_set(:intro)
check([ido.x, ido.y] == [34, 12] && [car82.x, car82.y] == [12, 23] && car82.row == 1 && !guest.anime?,
      "djrush TG53 D5: F9 debug_set(:intro) puts 82 and 50 back and stops the dancing")
DJRush.debug_set(:done)
check([ido.x, ido.y] == [35, 19] && [car82.x, car82.y] == [33, 12] && guest.anime?, "djrush TG53: debug_set(:done) swaps again")

# TG53 D8/D11: the complaint comes before the usual line under the partygoer's plate; Ido speaks the Spotify line.
$game_player = DJPlayer.new("trchar000", 33, 14)
talk = lambda do |map_id, stage, id|
  $PokemonGlobal.dj_rush = dj_st.(stage)
  $game_map = DJMap.new(map_id, {})
  $dj_log.clear
  DesertTalk.start_speaker(id)
  pbDesertTalk(id)
  $dj_log.select { |e| e.is_a?(Array) && e[0].is_a?(String) }
end
got = talk.(93, :intro, "11eaf4fa")
check(got.length == 2 && DR::COMPLAIN_KEYS.include?(got[0][0]) && got[1][0] == "MSG_11EAF4FA_LINE" && got[0][1] == got[1][1] && !got[0][1].nil?,
      "djrush TG53 D8: a partygoer says a complaint, then the usual line, both under their own plate (#{got.inspect})")
seen = Array.new(40) { talk.(93, :none, "11eaf4fa")[0][0] }
check(seen.each_cons(2).none? { |a, b| a == b } && seen.uniq.length >= 4, "djrush TG53 D10: complaints vary and never repeat back to back (#{seen.uniq.length} different)")
check(talk.(93, :freed, "11eaf4fa").map(&:first) == %w[MSG_11EAF4FA_LINE] && talk.(98, :intro, "11eaf4fa").map(&:first) == %w[MSG_11EAF4FA_LINE] &&
      talk.(93, :intro, "207a26e8").none? { |m, _| m.start_with?("DJRUSH_COMPLAIN") },
      "djrush TG53 D8/D9: no complaint from :freed on, on another map, or from the duel NPC")
got = talk.(93, :done, "cace0cde")
check(got.map(&:first) == %w[DJRUSH_IDO_SPOTIFY] && got[0][1] == "NAME_CACE0CDE",
      "djrush TG53 D11: Ido at :done says DJRUSH_IDO_SPOTIFY under his own plate (#{got.inspect})")
$game_player = DJPlayer.new("trchar000", 12, 25)

# T15: the other pbDesertTalk hooks are still in the chain.
chain = %i[alla_pbDesertTalk bags_pbDesertTalk planet_pbDesertTalk toaster_pbDesertTalk djrush_pbDesertTalk].select { |a| Object.private_method_defined?(a) || respond_to?(a, true) }
$PokemonGlobal = PokemonGlobalMetadata.new
$bag = DJTestBag.new
$game_map = DJMap.new(95, {})
$dj_log.clear
DesertTalk.start_speaker("c414cf08")
pbDesertTalk("c414cf08")
inbar = msgs.($dj_log)
check(chain.length == 5 && inbar[0] == "MSG_C414CF08_LINE" && inbar[1] == "BAGS_INBAR_ASK_1" && inbar.none? { |k| k.start_with?("DJRUSH_") },
      "djrush T15: zAlla/zBags/zPlanetarium/zToaster/zDJRush aliases all loaded; Inbar still runs bags only (#{chain.inspect})")

# Purity, writers, keys.
dj_src = Dir.glob(File.join(dj_dir, "*.rb")).to_h { |f| [File.basename(f, ".rb"), File.read(f, encoding: "utf-8")] }
check(dj_src["000_rules"].scan(/pbMessage|\$game_|pbSEPlay|_INTL|Graphics|Bitmap/).empty?, "djrush: 000_rules is pure")
writers = dj_src.reject { |k, _| k == "000_rules" }.select { |_, src| src.match?(/\b(st|state|@state)\[:\w+\]\s*=[^=]/) }
check(writers.empty?, "djrush: only DJRushRules writes the quest state (#{writers.keys.inspect})")
check(!dj_src.values.join.match?(/pbBGM|\$game_switches/), "djrush: no BGM call and no game switch")
tr_doc = JSON.parse(File.read(File.join(ROOT, "PBS/translations.json"), encoding: "utf-8"))["translations"]
used = dj_src.values.flat_map { |src| src.scan(/\b(DJRUSH_[A-Z0-9_]+)\b/).flatten }.uniq
used = used.flat_map { |k| k.end_with?("_") ? (1..3).map { |n| "#{k}#{n}" } : [k] }
used += %w[MUSICBAG Music\ Bag Music\ Bags MUSICBAG_DESC BAGS_INBAR_MUSICBAG_NOT_YET NAME_FC898478 NAME_4B08E38A]
bad = used.reject { |k| tr_doc[k].is_a?(Hash) && !tr_doc[k]["en"].to_s.strip.empty? && !tr_doc[k]["he"].to_s.strip.empty? }
check(used.length > 60 && bad.empty?, "djrush T24: every key the plugin uses has en and he (#{used.length}, missing #{bad.inspect})")
check(tr_doc["DJRUSH_SAY_PHRASE"]["he"].b == "הדיג'יי המפוקסל שלח אותי".b && tr_doc["MUSICBAG"]["he"].b == "שקית מוזיקה".b,
      "djrush T14/T23: the phrase and the item name are byte-exact")

smoke = IO.popen([RbConfig.ruby, File.join(__dir__, "djrush_scene_smoke.rb")], err: [:child, :out], &:read)
smoke_fails = smoke.lines.grep(/FAIL|Error/).map(&:strip)
check($?.success? && smoke_fails.empty?, "djrush: scene smoke run passes (#{smoke_fails.first(3).inspect})")
$game_map, $bag, $PokemonGlobal, $game_player = saved
DesertTalk.clear_speaker if DesertTalk.respond_to?(:clear_speaker)
