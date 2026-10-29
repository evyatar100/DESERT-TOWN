#===============================================================================
# AllaStand - QuestMarks client (spec quest-marks, TG65): the campers still to vote,
# then Alla for the count, the rush and an unclaimed hot dog.
#===============================================================================

if defined?(QuestMarks)
  QuestMarks.register(:alla) { |map_id| AllaRules.marks(AllaStand.state, map_id) }
end
