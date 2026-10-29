# TG65 QuestMarks T7 (Batches 2-3): every quest's pure marks(...) across the spec's target table.
# Loaded from plugin_rules_test.rb after the quests' own rules tests (shares check/$failures and ROOT).
{
  ToasterRules: "zToaster/000_rules.rb", AllaRules: "zAllaStand/000_rules.rb",
  PlanetRules: "zPlanetarium/000_rules.rb", DJRushRules: "zDJRush/000_rules.rb",
  BagsRules: "zBags/000_rules.rb", ShiraWeddingRules: "zShiraWedding/000_rules.rb",
  FlamingoBandRules: "zFlamingoBand/000_rules.rb"
}.each { |mod, file| load File.join(ROOT, "Plugins", file) unless Object.const_defined?(mod) }

module QuestMarksClientsTest
  # Toaster: HaNoodles 95, Yonik 80, altar 94; ctx = held flags.
  t = ->(stage, extra = {}) { ToasterRules.normalize({ stage: stage }.merge(extra)) }
  noodles = { next: ["dt_c081cd67"] }
  yonik = { next: ["dt_326f5ab5"] }
  altar = { next: ["toaster_altar"] }
  tm = ->(st, map, ctx = {}) { ToasterRules.marks(st, map, ctx) }
  check(tm.(t.(:none), 95) == { giver: ["dt_c081cd67"] } && tm.(t.(:none), 80) == {}, "marks T7 toaster: :none is giver only")
  check(tm.(t.(:asked), 95) == noodles && tm.(t.(:asked), 80) == {}, "marks T7 toaster: :asked marks HaNoodles")
  check(tm.(t.(:lead), 80) == yonik && tm.(t.(:lead), 93) == {} && tm.(t.(:lead), 111) == {} && tm.(t.(:lead), 95) == {},
        "marks T7 toaster: :lead marks Yonik on 80 only")
  check(tm.(t.(:permit), 94, permit: true) == altar && tm.(t.(:permit), 80, permit: true) == {},
        "marks T7 toaster: :permit with the permit marks the altar")
  check(tm.(t.(:permit), 80, permit: false) == yonik && tm.(t.(:permit), 94, permit: false) == {},
        "marks T7 toaster: :permit without the permit marks Yonik (reissue)")
  check(tm.(t.(:toaster), 95, toaster: true) == noodles && tm.(t.(:toaster), 94, toaster: true) == {},
        "marks T7 toaster: :toaster held marks HaNoodles (finale)")
  check(tm.(t.(:toaster), 94, toaster: false) == altar && tm.(t.(:toaster), 95, toaster: false) == {},
        "marks T7 toaster: :toaster not held marks the altar (regive)")
  check(tm.(t.(:done), 95) == noodles && [95, 80, 94].all? { |m| tm.(t.(:done, crumb_given: true), m) == {} },
        "marks T7 toaster: :done marks HaNoodles until the crumb, then nothing")

  # Alla: Playa 98 only.
  a = ->(stage, votes = [], hd = false) { AllaRules.normalize({ stage: stage, votes: votes, hotdog_given: hd }) }
  alla = { next: ["dt_4c4e039d"] }
  check(AllaRules.marks(a.(:none), 98) == { giver: ["dt_4c4e039d"] }, "marks T7 alla: :none is giver only")
  check(AllaRules.marks(a.(:campaign), 98) == { next: %w[dt_9b3660d1 dt_788b2614 dt_bb70b1dd] } &&
        AllaRules.marks(a.(:campaign, %i[elias]), 98) == { next: %w[dt_9b3660d1 dt_bb70b1dd] },
        "marks T7 alla: the campers not yet voted")
  check(AllaRules.marks(a.(:campaign, AllaRules::CAMPERS.dup), 98) == alla && AllaRules.marks(a.(:rush), 98) == alla,
        "marks T7 alla: 3 votes or :rush marks Alla")
  check(AllaRules.marks(a.(:done), 98) == alla && AllaRules.marks(a.(:done, [], true), 98) == {} &&
        AllaRules.marks(a.(:campaign), 95) == {}, "marks T7 alla: hot dog unclaimed marks Alla; done/off-map give {}")

  # Planetarium: Eyal 33, Hagar 95.
  ps = ->(stage) { PlanetRules.normalize({ stage: stage }) }
  eyal = { next: ["planet_eyal"] }
  check(PlanetRules.marks(ps.(:none), 33, false) == { giver: ["planet_eyal"] } && PlanetRules.marks(ps.(:none), 95, false) == {},
        "marks T7 planet: :none is giver only")
  check(%i[asked got].all? { |s| PlanetRules.marks(ps.(s), 95, false) == { next: ["dt_b19b1f15"] } && PlanetRules.marks(ps.(s), 33, false) == {} },
        "marks T7 planet: no ram marks Hagar")
  check(%i[asked got].all? { |s| PlanetRules.marks(ps.(s), 33, true) == eyal && PlanetRules.marks(ps.(s), 95, true) == {} },
        "marks T7 planet: holding the ram marks Eyal")
  check(PlanetRules.marks(ps.(:delivered), 33, false) == eyal && PlanetRules.marks(ps.(:shown), 33, false) == {},
        "marks T7 planet: :delivered marks Eyal (the show); :shown gives {}")

  # DJ Rush: car 93, Johnny 98.
  d = ->(stage) { DJRushRules.normalize({ stage: stage }) }
  car = { next: ["djrush_car"] }
  check(DJRushRules.marks(d.(:none), 93, false) == { giver: ["djrush_car"] }, "marks T7 dj: :none is giver only")
  check(%i[intro freed].all? { |s| DJRushRules.marks(d.(s), 93, false) == car && DJRushRules.marks(d.(s), 98, false) == {} },
        "marks T7 dj: :intro and :freed mark the car")
  check(DJRushRules.marks(d.(:bag), 98, true) == { next: ["dt_4b08e38a"] } && DJRushRules.marks(d.(:bag), 93, true) == {},
        "marks T7 dj: :bag held marks Johnny on the Playa, never the party Johnny")
  check(DJRushRules.marks(d.(:bag), 93, false) == car && DJRushRules.marks(d.(:done), 98, true) == {},
        "marks T7 dj: :bag not held marks the car (reissue); :done gives {}")

  # Bags: Inbar/cowboy 95, Toga 98, Pixel 109.
  b = ->(inbar, gift = false) { BagsRules.normalize({ inbar: inbar, toga_gift: gift }) }
  bm = ->(st, map, count = 0, payable = false) { BagsRules.marks(st, map, { count: count, payable: payable }) }
  check(bm.(b.(:none), 95) == { giver: ["dt_c414cf08"] } && bm.(b.(:none), 98) == {}, "marks T7 bags: :none is giver only")
  check(bm.(b.(:asked), 95, 2) == { next: ["dt_c414cf08"] } && bm.(b.(:asked), 98, 3, true) == {} && bm.(b.(:asked), 109, 2, true) == {},
        "marks T7 bags: count >= 2 marks Inbar only")
  check(bm.(b.(:asked), 95, 1) == { next: ["dt_670f79e3"] } && bm.(b.(:asked), 98) == { next: ["dt_7a2a022c"] } &&
        bm.(b.(:asked), 109) == {} && bm.(b.(:asked), 109, 0, true) == { next: ["dt_d5383627"] },
        "marks T7 bags: short marks the cowboy, Toga, and Pixel only when payable")
  check(bm.(b.(:asked, true), 98) == {} && bm.(b.(:done), 95, 2) == {} && bm.(b.(:asked), 111, 0, true) == {},
        "marks T7 bags: Toga after his gift, :done and the demo map give {}")

  # Shira: Playa 98 only.
  sh = ->(stage) { ShiraWeddingRules.normalize({ stage: stage }) }
  check(ShiraWeddingRules.marks(sh.(:none), 98) == { giver: ["shira_eviatar"] }, "marks T7 shira: :none is giver only")
  check(%i[asked seated bag].all? { |s| ShiraWeddingRules.marks(sh.(s), 98) == { next: %w[shira_eviatar shira_wedding] } },
        "marks T7 shira: Eviatar and Shira while the quest runs")
  check(ShiraWeddingRules.marks(sh.(:done), 98) == {} && ShiraWeddingRules.marks(sh.(:asked), 95) == {},
        "marks T7 shira: :done and off-map give {}")

  # Flamingo Band: 77/99, 708d6c34 capped at 1.
  f = FlamingoBandRules.new_state
  check(FlamingoBandRules.marks(f, 77) == {}, "marks T7 band: nothing before the intro (no giver)")
  f[:intro_done] = true
  all = FlamingoBandRules.marks(f, 77)[:next]
  check(all.first == ["dt_708d6c34", 1] && all.length == 8 && !all.include?("dt_9923f1c4") && FlamingoBandRules.marks(f, 99) == { next: all },
        "marks T7 band: 8 members (no host), 708d6c34 capped at 1 (#{all.inspect})")
  FlamingoBandRules.claim(f, "c626f0d6", 77)
  check(!FlamingoBandRules.marks(f, 77)[:next].include?("dt_c626f0d6") && FlamingoBandRules.marks(f, 98) == {},
        "marks T7 band: a consumed member loses the mark; other maps give {}")
  %w[671405a6 754ba04a 5990bffc].each { |id| FlamingoBandRules.claim(f, id, 99) }
  check(f[:stage] == 4 && FlamingoBandRules.marks(f, 77) == {}, "marks T7 band: stage 4 removes every mark")
  f2 = FlamingoBandRules.new_state.merge(intro_done: true, procession: true)
  check(FlamingoBandRules.marks(f2, 77) == {}, "marks T7 band: no mark during the procession")
end
