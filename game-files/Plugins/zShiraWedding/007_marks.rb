#===============================================================================
# Shira's wedding - QuestMarks client (spec quest-marks, TG65): Eviatar and, while she is
# visibly crossing the Playa, Shira herself, from :asked until the final line.
#===============================================================================

if defined?(QuestMarks)
  QuestMarks.register(:shira) { |map_id| ShiraWeddingRules.marks(ShiraWedding.state, map_id) }
end
