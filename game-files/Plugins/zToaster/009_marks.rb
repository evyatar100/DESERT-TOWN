#===============================================================================
# Toaster - QuestMarks client (spec quest-marks, TG65): HaNoodles / Yonik / the altar,
# whichever is the next step. Reads the bag only for the two held flags.
#===============================================================================

if defined?(QuestMarks)
  QuestMarks.register(:toaster) do |map_id|
    ctx = { permit: ToasterRules.held?($bag, ToasterRules::PERMIT),
            toaster: ToasterRules.held?($bag, ToasterRules::TOASTER) }
    ToasterRules.marks(Toaster.state, map_id, ctx)
  end
end
