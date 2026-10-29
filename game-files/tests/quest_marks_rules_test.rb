# TG65 QuestMarks: loaded from plugin_rules_test.rb (shares check/$failures and ROOT).
# T1 registry/resolve and T2 visibility; the overlay smoke runs in its own process.
require "rbconfig"
require File.join(ROOT, "Plugins/QuestMarks", "000_rules.rb")
require File.join(ROOT, "Plugins/QuestMarks", "001_registry.rb")

module QuestMarksTest
  R = QuestMarksRules
  idx = { "dt_a" => [3, 7], "dt_flamingo" => [2, 5, 9], "dt_lily" => [4] }
  check(R.resolve([{ next: ["dt_a"] }, { next: ["dt_a", "dt_lily"] }], idx) == [3, 4, 7], "marks T1: duplicates across clients collapse")
  check(R.resolve([{ next: [["dt_flamingo", 1]] }], idx) == [2], "marks T1: [name, cap] keeps the lowest ids")
  check(R.resolve([{ next: ["dt_nobody"] }, nil, "x"], idx) == [], "marks T1: unknown names and non-hash results are ignored")
  res = [{ next: ["dt_a"], giver: ["dt_lily"] }]
  check(R.resolve(res, idx, givers: false) == [3, 7] && R.resolve(res, idx, givers: true) == [3, 4, 7], "marks T1: GIVERS filters givers")
  check(QuestMarks::GIVERS == false && QuestMarks::ENABLED == true, "marks D1/D5: givers off, marks on by default")

  free = { scene_map: true }
  check(R.visible?(free), "marks T2: all clear shows")
  check(R::BUSY.all? { |k| !R.visible?(free.merge(k => true)) }, "marks T2: each busy flag alone hides")
  check(!R.visible?({ scene_map: false }), "marks T2: not on Scene_Map hides")
  check((0...40).map { |f| R.bob_offset(f) }.minmax == [-2, 2] && R.bob_offset(0) == R.bob_offset(40), "marks D2: +-2 px on a 40-frame cycle")
  check(R.position(100, 200, 48) == [94, 134] && R.position(100, 200, 80) == [94, 102], "marks D2: y follows the charset frame height")
  check(!R.drawable?(true, false, 255, "dt_a") && !R.drawable?(false, true, 255, "dt_a") && !R.drawable?(false, false, 0, "dt_a") &&
        !R.drawable?(false, false, 255, "") && R.drawable?(false, false, 255, "dt_a"), "marks D2: erased/transparent/opacity 0/no charset -> no mark")

  # Registry: a raising client gives nothing and stays off for the session.
  calls = 0
  QuestMarks.register(:test_boom) { |_m| calls += 1; raise "boom" }
  QuestMarks.register(:test_ok) { |_m| { next: ["dt_a"] } }
  t1 = QuestMarks.targets(1, idx)
  t2 = QuestMarks.targets(1, idx)
  check(t1 == [3, 7] && t2 == [3, 7] && calls == 1 && QuestMarks.disabled?(:test_boom), "marks T1: a raising client is disabled after one call")
  QuestMarks.givers = true
  QuestMarks.register(:test_giver) { |_m| { giver: ["dt_lily"] } }
  check(QuestMarks.targets(1, idx) == [3, 4, 7], "marks T1: the session givers toggle adds givers")
  QuestMarks.givers = nil
  [:test_boom, :test_ok, :test_giver].each { |k| QuestMarks.instance_variable_get(:@clients).delete(k) }

  meta = File.read(File.join(ROOT, "Plugins/QuestMarks/meta.txt"))
  check(meta.include?("Name       = QuestMarks") && %w[DesertTalk DesertTownArcade].all? { |r| meta.include?("Requires   = #{r}") },
        "quest_marks: meta.txt names QuestMarks and its 2 requirements")

  out = IO.popen([RbConfig.ruby, File.join(__dir__, "quest_marks_smoke.rb")], err: [:child, :out], &:read)
  fails = out.lines.grep(/FAIL|Error/).map(&:strip)
  check($?.success? && fails.empty?, "quest_marks: overlay smoke run passes (#{fails.first(3).inspect})")
end
