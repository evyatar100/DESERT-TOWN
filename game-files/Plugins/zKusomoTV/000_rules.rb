# Kusomo TV: video id -> base file name under Movies/ (the player adds ".ogv").
module KusomoTVRules
  VIDEOS = {
    :midburn   => "Movies/kusomo_midburn",
    :mushrooms => "Movies/kusomo_mushrooms",
    :grandma   => "Movies/kusomo_grandma",
    :mohel     => "Movies/kusomo_mohel"
  }

  def self.file_for(id)
    return VIDEOS[id.to_sym]
  end
end
