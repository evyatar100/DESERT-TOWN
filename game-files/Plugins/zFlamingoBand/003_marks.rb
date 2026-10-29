#===============================================================================
# Flamingo Band - QuestMarks client (spec quest-marks, TG65): every band member still to
# play on 77/99 while the quest runs; no giver (the intro is a walk-in trigger).
#===============================================================================

if defined?(QuestMarks)
  QuestMarks.register(:flamingo) { |map_id| FlamingoBandRules.marks(FlamingoBand.state, map_id) }
end
