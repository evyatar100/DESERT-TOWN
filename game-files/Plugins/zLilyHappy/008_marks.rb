#===============================================================================
# LilyHappy - QuestMarks client (spec quest-marks D8, lily-happy D5a): a "!" over every
# unheard complainer in :asked, and over Lily once the survey is ready and in :wheeled.
#===============================================================================

module LilyHappy
  MARKS = true   # false removes Lily's marks only
end

if defined?(QuestMarks)
  QuestMarks.register(:lily) do |map_id|
    LilyHappy::MARKS ? LilyHappyRules.marks(LilyHappy.state, map_id) : {}
  end
end
