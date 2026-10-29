#===============================================================================
# Bags - QuestMarks client (spec quest-marks, TG65, dec:tg-41): Inbar once her count is in;
# while short, all three bag sources (cowboy, Toga before his gift, Pixel when payable).
#===============================================================================

if defined?(QuestMarks)
  QuestMarks.register(:bags) do |map_id|
    ctx = { count: Bags.inbar_count, payable: !!$bag && !BagsRules.payable($bag).empty? }
    BagsRules.marks(Bags.state, map_id, ctx)
  end
end
