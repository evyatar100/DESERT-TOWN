# TG64 LilyHappy: loaded from plugin_rules_test.rb (shares check/$failures and ROOT).
# LilyHappyRules is pure; the scene and the quest flow run in their own processes.
require "json"
require "rbconfig"
%w[000_rules 000_wheel_rules 001_state].each { |f| require File.join(ROOT, "Plugins/zLilyHappy", "#{f}.rb") }

module LilyHappyTest
  R = LilyHappyRules
  DIR = File.join(ROOT, "Plugins/zLilyHappy")
  CAP_RUNS = (ENV["LILY_CAP_RUNS"] || "60").to_i

  def self.game_with(front_bubble: true, opp_bubble: false)
    g = R.new_game(1)
    g[:first] = false
    g[:spawn_t] = 10_000
    g[:bubbles][0] = R.bubble(g, 1, false) if front_bubble
    g[:bubbles][3] = R.bubble(g, 1, false) if opp_bubble
    g
  end

  # T1 / T2
  s = R.new_state
  check(R.start!(s) && s[:stage] == :asked && !R.start!(s) && s[:stage] == :asked, "lily T1: start! only from :none; a second call is a no-op")
  check(!R.hear!(R.new_state, :kusomo), "lily T2: hear! refused before the quest is asked")
  check(R.hear!(s, :kusomo) && !R.hear!(s, :kusomo) && !R.hear!(s, :bogus) && s[:heard] == [:kusomo],
        "lily T2: hear! once per encounter, unknown symbols rejected")
  # T3
  check(!R.ready?(s) && !R.wheel_done!(s, 3, 1) && s[:stage] == :asked, "lily T3: wheel_done! refused before 4 heard")
  %i[circus cats].each { |e| R.hear!(s, e) }
  check(!R.ready?(s), "lily T3: 3 heard is not ready")
  R.hear!(s, :escher)
  check(R.ready?(s), "lily T3: ready at exactly 4")
  check(R.wheel_done!(s, 2, 3) && s[:stage] == :wheeled && s[:best] == 2 && s[:laps] == 3, "lily T3: wheel_done! moves :asked -> :wheeled once")
  check(!R.wheel_done!(s, 1, 9) && s[:best] == 2 && s[:laps] == 3, "lily T3: a lower replay changes nothing")
  # T4
  check(!R.finish!(R.state_at(:asked)), "lily T4: finish! refused in :asked")
  check(R.lily_decide(s) == :payoff, "lily T4: :wheeled resumes the payoff on the next talk")
  check(R.finish!(s) && s[:stage] == :done && !R.finish!(s), "lily T4: finish! only from :wheeled, once")
  check(!R.wheel_done!(s, 3, 9) && s[:stage] == :done && s[:best] == 3 && s[:laps] == 3, "lily T3: a replay in :done raises only best")
  check(!R.hear!(s, :glass) && R.camp_decide(s, :glass).nil?, "lily: camps say nothing extra in :done")
  # T5
  held = { stage: :weird, heard: [:cats, :cats, :nope, :glass], best: 7, laps: "x", junk: 1 }
  check(R.normalize(held).equal?(held) && held == { stage: :none, heard: [], best: 3, laps: 0 },
        "lily T5: normalize repairs in place (#{held.inspect})")
  kept = R.normalize({ stage: :asked, heard: %i[cats glass], best: nil, laps: 0 })
  check(kept[:stage] == :asked && kept[:heard] == %i[cats glass], "lily T5: a valid stage keeps its heard list")
  check(R.normalize("garbage") == R.new_state && R.normalize(nil) == R.new_state, "lily T5: garbage / missing key loads fresh")
  check(R.normalize({ stage: :done, heard: [], best: 2.5, laps: -4 }) == { stage: :done, heard: [], best: nil, laps: 0 },
        "lily T5: non-integer best -> nil, laps clamped")
  # T6/T7 at rules level (the hook itself runs in lily_happy_quest_smoke.rb)
  check(R::LILY_MAPS.all? { |m| R.lily_here?(m, R::LILY) } && !R.lily_here?(111, R::LILY), "lily T7: Lily fires on 98/91/93, not 111")
  pairs = R::ENCOUNTERS.values.flatten(1)
  check(pairs.uniq.size == 12 && R::ENCOUNTERS.all? { |e, ps| ps.all? { |m, id| R.encounter_at(m, id) == e } },
        "lily T6: the 12 pinned (map, id) pairs are encounters (A1)")
  check([[88, "a715ed37"], [85, "661f55e6"], [112, "8d654949"], [111, "f9348fd0"], [111, "6b53f14c"]].all? { |m, id| R.encounter_at(m, id).nil? },
        "lily T6: Mor on 88, Changa on 85, Turtle on 112, Shorty and Loooo on 111 are not encounters")
  # T21 (A1): the "!" rule
  s = R.new_state
  check(R::ENCOUNTERS.keys.none? { |e| R.mark?(s, e) }, "lily T21: no mark in :none")
  R.start!(s)
  check(R::ENCOUNTERS.keys.all? { |e| R.mark?(s, e) } && !R.mark?(s, :bogus), "lily T21: every unheard encounter is marked in :asked")
  R.hear!(s, :shorty)
  check(!R.mark?(s, :shorty) && R.marks(s, 91) == { next: [] } && R.marks(s, 97) == { next: %w[dt_1be29576 dt_8d654949] },
        "lily T21: a heard encounter loses its mark on both of its maps (#{R.marks(s, 97).inspect})")
  %i[loooo gufak turtle].each { |e| R.hear!(s, e) }
  check(R.marks(s, 98) == { next: ["dt_648b924a"] }, "lily TG65 D8: ready in :asked marks Lily too")
  check(%i[wheeled done].all? { |st| R::ENCOUNTERS.keys.none? { |e| R.mark?(R.state_at(st), e) } } &&
        R.marks(R.state_at(:wheeled), 93) == { next: ["dt_648b924a"] } && R.marks(R.state_at(:done), 98) == { next: [] },
        "lily T21: no complainer mark in :wheeled/:done; Lily marked in :wheeled only")
  check(R.marks(R.new_state, 98) == { next: [], giver: ["dt_648b924a"] }, "lily TG65 D1: Lily is a giver in :none")

  # T9
  g = game_with
  g[:hearts] = [4, 2, 2, 0, 2, 2]
  ev = []
  R.apply(g, :fix, ev)
  check(g[:hearts][0] == 5 && g[:hearts][3] == 0 && g[:k] == 2 && g[:fixes] == 1, "lily T9: fix +2 capped at 5, opposite -1 floored at 0, k advances")
  check(ev.include?([:spawn, 3, 2, 0]), "lily T9: the new complaint (step k+1) lands on the opposite seat (#{ev.inspect})")
  g = game_with(opp_bubble: true)
  g[:k] = 11
  ev = []
  R.apply(g, :fix, ev)
  check(g[:k] == 1 && g[:laps] == 1 && ev.include?([:spawn, 4, 1, 0]), "lily T9: k wraps 11 -> 1 with laps += 1; a busy opposite passes clockwise")
  g = game_with
  g[:phase] = 2
  ev = []
  R.apply(g, :fix, ev)
  check(ev.count { |e| e[0] == :spawn } == 2, "lily T9: in phase 3 a fix spawns two complaints")
  g = game_with(front_bubble: false)
  ev = []
  R.apply(g, :fix, ev)
  check(ev == [[:nofix]] && g[:hearts] == [2] * 6, "lily: a fix with no complaint in front only shows NOCOMPLAINT")

  # T10: the cap, every frame of seeded random runs.
  bad = nil
  CAP_RUNS.times do |seed|
    g = R.new_game(seed)
    rng = R::Lcg.new(seed + 77)
    until g[:over] == :done
      R.tick(g, R.random_input(rng))
      pair = (0..2).any? { |i| g[:hearts][i] == 5 && g[:hearts][i + 3] == 5 }
      bad ||= [seed, g[:f]] if R.happy(g) > R::CAP || pair
    end
  end
  check(bad.nil?, "lily T10: #{CAP_RUNS} random runs never exceed 3 happy or fill a pair (#{bad.inspect})")
  # T11
  g = R.new_game(0)
  R.tick(g, R.bot_input(g)) until g[:over] == :done
  check(g[:peak] == R::CAP, "lily T11: the bot reaches 3/6 on seed 0 (peak #{g[:peak]})")

  # T12
  g = game_with(opp_bubble: true)
  ev = []
  R.apply(g, :comp, ev)
  check(ev == [[:comp, 1]] && g[:bubbles].none? && g[:hearts] == [2] * 6, "lily T12: a compromise clears both, hearts unchanged")
  R::HALF_DELAY_F.times { R.tick(g, nil) }
  check(g[:bubbles][0] && g[:bubbles][0][:half] && g[:bubbles][3] && g[:bubbles][3][:half], "lily T12: HALF bubbles on both after 3.0 s")
  g = game_with
  ev = []
  R.apply(g, :comp, ev)
  check(ev == [[:nocomp]] && g[:bubbles][0], "lily T12: no compromise without both complaints")
  # T13
  g = game_with
  before = Marshal.load(Marshal.dump(g[:hearts]))
  ev = R.tick(g, :moop)
  check(ev.include?([:moop]) && g[:lock] == R::MOOP_LOCK_F, "lily T13: MOOP starts a 0.6 s lockout")
  (R::MOOP_LOCK_F).times { R.tick(g, :fix) }
  check(g[:fixes].zero? && g[:hearts] == before, "lily T13: inputs during the lockout do nothing")
  R.tick(g, :fix)
  check(g[:fixes] == 1, "lily T13: input works again after 0.6 s")
  # T14
  g = game_with
  g[:bubbles][0][:left] = 1
  ev = R.tick(g, nil)
  check(ev.include?([:expire, 0]) && g[:hearts][0] == 1, "lily T14: an expired complaint costs 1 heart")
  (R::SPREAD_DELAY_F - 1).times { R.tick(g, nil) }
  check(g[:bubbles][1].nil?, "lily T14: no spread before 1.0 s")
  R.tick(g, nil)
  check(g[:bubbles][1] && g[:bubbles][1][:step] == 1, "lily T14: it spreads to seat+1 after 1.0 s")
  # T15
  check([R.phase_at(1799), R.phase_at(1800), R.phase_at(3599), R.phase_at(3600)] == [0, 1, 1, 2], "lily T15: phases switch at 30.0 / 60.0 s")
  g = game_with(front_bubble: false)
  g[:f] = 1799
  R.tick(g, nil)
  check(g[:phase] == 1 && R.bubble(g, 1, false)[:left] == 360, "lily T15: phase 2 patience is 6.0 s")
  # First bubble teaches the game.
  g = R.new_game(5)
  29.times { R.tick(g, nil) }
  check(g[:bubbles].none?, "lily: nothing before 0.5 s")
  R.tick(g, nil)
  check(g[:bubbles][0], "lily: the first complaint spawns on the front seat at 0.5 s")
  # T16 at rules level: the run ends at 90 s, then the 2 s finale.
  g = R.new_game(3)
  R.tick(g, nil) until g[:over]
  check(g[:f] == R::PLAY_F && g[:over] == :finale && g[:bubbles].all?, "lily T16: play ends at 90.0 s and everyone complains")
  (R::FINALE_F - 1).times { R.tick(g, :fix) }
  check(g[:over] == :finale && g[:fixes].zero?, "lily T16: the finale ignores input")
  check(R.tick(g, nil) == [[:end]] && g[:over] == :done && R.tick(g, :fix) == [], "lily T16: the finale ends after 2.0 s")
  st = R.state_at(:asked)
  check(!R.record!(st, R.new_game(1)) && st[:stage] == :asked, "lily T16: an unfinished game records nothing")
  check(R.record!(st, g) && st[:stage] == :wheeled, "lily T16: a finished game in :asked records")

  meta = File.read(File.join(DIR, "meta.txt"))
  check(meta.include?("Name       = LilyHappy") && %w[HebrewSupport DesertTalk DesertTownArcade].all? { |r| meta.include?("Requires   = #{r}") },
        "lily_happy: meta.txt names LilyHappy and its 3 requirements")

  [["lily_happy_scene_smoke.rb", "scene"], ["lily_happy_quest_smoke.rb", "quest"]].each do |file, what|
    out = IO.popen([RbConfig.ruby, File.join(__dir__, file)], err: [:child, :out], &:read)
    fails = out.lines.grep(/FAIL|Error/).map(&:strip)
    check($?.success? && fails.empty?, "lily_happy: #{what} smoke run passes (#{fails.first(3).inspect})")
  end
end
