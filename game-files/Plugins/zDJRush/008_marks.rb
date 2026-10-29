#===============================================================================
# DJ Rush Hour - QuestMarks client (spec quest-marks, TG65): the art car (boards, the
# meeting, a bag reissue), then Johnny on the Playa once the Music Bag is held.
#===============================================================================

if defined?(QuestMarks)
  QuestMarks.register(:djrush) { |map_id| DJRushRules.marks(DJRush.state, map_id, DJRushRules.held?($bag)) }
end
