# Kusomo TV: video id -> base file name(s) under Movies/ (the player adds ".ogv").
# A list plays its parts back to back (TG49: mushrooms is split in two).
module KusomoTVRules
  VIDEOS = {
    :midburn   => "Movies/kusomo_midburn",
    :mushrooms => ["Movies/kusomo_mushrooms_1", "Movies/kusomo_mushrooms_2"],
    :grandma   => "Movies/kusomo_grandma",
    :mohel     => "Movies/kusomo_mohel"
  }

  def self.file_for(id)
    return VIDEOS[id.to_sym]
  end

  # Every base file of a video as an array (empty for an unknown id).
  def self.parts_for(id)
    return Array(VIDEOS[id.to_sym])
  end
end
