#===============================================================================
# DesertScreens (TG57) - one short Desert Town splash instead of the two stock ones.
# Only the scene's two constants change; fades, skip-on-C and the title are stock.
#===============================================================================

class IntroEventScene
  remove_const(:SPLASH_IMAGES)
  SPLASH_IMAGES = DesertScreens::SPLASH_IMAGES
  remove_const(:SECONDS_PER_SPLASH)
  SECONDS_PER_SPLASH = DesertScreens::SPLASH_HOLD_SECONDS
end
