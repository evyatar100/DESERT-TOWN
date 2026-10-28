# TG31 parity helper: replays a recorded press list through the Ruby rules and prints the
# final-state digest. Usage: ruby tests/tuta_replay.rb DIFF SEED presses.json
load File.expand_path("../Plugins/zTutaMaze/000_rules.rb", __dir__)
require "json"
diff, seed, path = ARGV
presses = JSON.parse(File.read(path))
g = TutaMazeRules.new_game(diff: diff.to_f, seed: seed.to_i)
presses.each { |p| TutaMazeRules.tick(g, p && p.to_sym) }
puts TutaMazeRules.digest(g)
