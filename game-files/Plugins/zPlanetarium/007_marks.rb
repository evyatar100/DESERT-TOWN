#===============================================================================
# Planetarium - QuestMarks client (spec quest-marks, TG65): Hagar for the ram,
# then Eyal to deliver it and to start the show.
#===============================================================================

if defined?(QuestMarks)
  QuestMarks.register(:planet) { |map_id| PlanetRules.marks(Planet.state, map_id, PlanetRules.has?($bag)) }
end
