#===============================================================================
# Burning Man Bag - Key Items Only & Custom Bag Behavior
#===============================================================================

class PokemonBag
  KEY_ITEMS_POCKET = 8

  alias burningman_reset_last_selections reset_last_selections
  def reset_last_selections
    burningman_reset_last_selections
    @last_viewed_pocket = KEY_ITEMS_POCKET
  end

  alias burningman_last_viewed_pocket last_viewed_pocket
  def last_viewed_pocket
    return KEY_ITEMS_POCKET
  end
end

class PokemonBag_Scene
  KEY_ITEMS_POCKET = 8

  alias burningman_pbStartScene pbStartScene
  def pbStartScene(bag, choosing = false, filterproc = nil, resetpocket = true)
    BurningManBag.ensure_single_starter_items(bag) if defined?(BurningManBag)
    bag.last_viewed_pocket = KEY_ITEMS_POCKET if bag
    burningman_pbStartScene(bag, choosing, filterproc, resetpocket)
    @bag.last_viewed_pocket = KEY_ITEMS_POCKET if @bag
    if @sprites["itemlist"]
      @sprites["itemlist"].pocket = KEY_ITEMS_POCKET
    end
    if @sprites["leftarrow"]
      @sprites["leftarrow"].visible = false
    end
    if @sprites["rightarrow"]
      @sprites["rightarrow"].visible = false
    end
    pbRefresh
  end

  alias burningman_pbRefresh pbRefresh
  def pbRefresh
    if @bag
      @bag.last_viewed_pocket = KEY_ITEMS_POCKET
    end
    if @sprites && @sprites["itemlist"]
      @sprites["itemlist"].pocket = KEY_ITEMS_POCKET
    end
    burningman_pbRefresh
    if @sprites
      if @sprites["leftarrow"]
        @sprites["leftarrow"].visible = false
      end
      if @sprites["rightarrow"]
        @sprites["rightarrow"].visible = false
      end
      if @sprites["pocketicon"] && @sprites["pocketicon"].bitmap
        @sprites["pocketicon"].bitmap.clear
        pocket_idx = KEY_ITEMS_POCKET - 1
        @sprites["pocketicon"].bitmap.blt(
          2 + (pocket_idx * 22), 2, @pocketbitmap.bitmap,
          Rect.new(pocket_idx * 28, 0, 28, 28)
        )
      end
    end
  end

  def pbChooseItem
    @sprites["helpwindow"].visible = false
    itemwindow = @sprites["itemlist"]
    itemwindow.pocket = KEY_ITEMS_POCKET
    thispocket = @bag.pockets[KEY_ITEMS_POCKET]
    swapinitialpos = -1
    pbActivateWindow(@sprites, "itemlist") do
      loop do
        oldindex = itemwindow.index
        Graphics.update
        Input.update
        pbUpdate
        if itemwindow.sorting && itemwindow.index >= thispocket.length
          itemwindow.index = (oldindex == thispocket.length - 1) ? 0 : thispocket.length - 1
        end
        if itemwindow.index != oldindex
          if itemwindow.sorting
            thispocket.insert(itemwindow.index, thispocket.delete_at(oldindex))
          end
          @bag.set_last_viewed_index(KEY_ITEMS_POCKET, itemwindow.index)
          pbRefresh
        end
        if itemwindow.sorting
          if Input.trigger?(Input::ACTION) || Input.trigger?(Input::USE)
            itemwindow.sorting = false
            pbPlayDecisionSE
            pbRefresh
          elsif Input.trigger?(Input::BACK)
            thispocket.insert(swapinitialpos, thispocket.delete_at(itemwindow.index))
            itemwindow.index = swapinitialpos
            itemwindow.sorting = false
            pbPlayCancelSE
            pbRefresh
          end
        else
          if Input.trigger?(Input::ACTION)
            if !@choosing && itemwindow.index < thispocket.length
              if thispocket.length > 1
                itemwindow.sorting = true
                swapinitialpos = itemwindow.index
                pbPlayDecisionSE
                pbRefresh
              end
            end
          elsif Input.trigger?(Input::BACK)
            return nil
          elsif Input.trigger?(Input::USE)
            pbPlayDecisionSE
            return itemwindow.item
          end
        end
      end
    end
  end
end

#===============================================================================
# Window_PokemonBag - Item Quantity & Display
#===============================================================================
class Window_PokemonBag < Window_DrawableCommand
  alias burningman_drawItem drawItem unless method_defined?(:burningman_drawItem)

  def drawItem(index, _count, rect)
    textpos = []
    rect = Rect.new(rect.x + 16, rect.y + 16, rect.width - 16, rect.height)
    thispocket = @bag.pockets[@pocket]
    if index == self.itemCount - 1
      textpos.push([_INTL("CLOSE BAG"), rect.x, rect.y + 2, :left, self.baseColor, self.shadowColor])
    else
      item = (@filterlist) ? thispocket[@filterlist[@pocket][index]][0] : thispocket[index][0]
      baseColor   = self.baseColor
      shadowColor = self.shadowColor
      if @sorting && index == self.index
        baseColor   = Color.new(224, 0, 0)
        shadowColor = Color.new(248, 144, 144)
      end
      textpos.push(
        [@adapter.getDisplayName(item), rect.x, rect.y + 2, :left, baseColor, shadowColor]
      )
      item_data = GameData::Item.get(item)
      qty = (@filterlist) ? thispocket[@filterlist[@pocket][index]][1] : thispocket[index][1]
      show_qty = item_data.show_quantity? || qty > 1

      if show_qty
        qtytext = _ISPRINTF("x{1: 3d}", qty)
        xQty    = rect.x + rect.width - self.contents.text_size(qtytext).width - 16
        textpos.push([qtytext, xQty, rect.y + 2, :left, baseColor, shadowColor])
      end

      if item_data.is_important?
        reg_x = rect.x + rect.width - 72
        reg_x -= (self.contents.text_size(qtytext).width + 4) if show_qty
        if @bag.registered?(item)
          pbDrawImagePositions(
            self.contents,
            [[_INTL("Graphics/UI/Bag/icon_register"), reg_x, rect.y + 8, 0, 0, -1, 24]]
          )
        elsif pbCanRegisterItem?(item)
          pbDrawImagePositions(
            self.contents,
            [[_INTL("Graphics/UI/Bag/icon_register"), reg_x, rect.y + 8, 0, 24, -1, 24]]
          )
        end
      end
    end
    pbDrawTextPositions(self.contents, textpos)
  end
end

#===============================================================================
# PokemonBagScreen - Prevent Tossing Key / Important Items
#===============================================================================
class PokemonBagScreen
  def pbStartScreen
    @scene.pbStartScene(@bag)
    item = nil
    loop do
      item = @scene.pbChooseItem
      break if !item
      itm = GameData::Item.get(item)
      cmdRead     = -1
      cmdUse      = -1
      cmdRegister = -1
      cmdGive     = -1
      cmdToss     = -1
      cmdDebug    = -1
      commands = []
      # Generate command list
      commands[cmdRead = commands.length] = _INTL("Read") if itm.is_mail?
      if ItemHandlers.hasOutHandler(item) || (itm.is_machine? && $player.party.length > 0)
        if ItemHandlers.hasUseText(item)
          commands[cmdUse = commands.length]    = ItemHandlers.getUseText(item)
        else
          commands[cmdUse = commands.length]    = _INTL("Use")
        end
      end
      commands[cmdGive = commands.length]       = _INTL("Give") if $player.pokemon_party.length > 0 && itm.can_hold?
      # Key items and important items CAN NEVER BE THROWN AWAY
      commands[cmdToss = commands.length]       = _INTL("Toss") if !itm.is_important? && !itm.is_key_item?
      if @bag.registered?(item)
        commands[cmdRegister = commands.length] = _INTL("Deselect")
      elsif pbCanRegisterItem?(item)
        commands[cmdRegister = commands.length] = _INTL("Register")
      end
      commands[cmdDebug = commands.length]      = _INTL("Debug") if $DEBUG
      commands[commands.length]                 = _INTL("Cancel")
      # Show commands generated above
      itemname = itm.name
      command = @scene.pbShowCommands(_INTL("{1} is selected.", itemname), commands)
      if cmdRead >= 0 && command == cmdRead   # Read mail
        pbFadeOutIn do
          pbDisplayMail(Mail.new(item, "", ""))
        end
      elsif cmdUse >= 0 && command == cmdUse   # Use item
        ret = pbUseItem(@bag, item, @scene)
        break if ret == 2   # End screen
        @scene.pbRefresh
        next
      elsif cmdGive >= 0 && command == cmdGive   # Give item to Pokémon
        if $player.pokemon_count == 0
          @scene.pbDisplay(_INTL("There is no Pokémon."))
        elsif itm.is_important? || itm.is_key_item?
          @scene.pbDisplay(_INTL("The {1} can't be held.", itm.portion_name))
        else
          pbFadeOutIn do
            sscene = PokemonParty_Scene.new
            sscreen = PokemonPartyScreen.new(sscene, $player.party)
            sscreen.pbPokemonGiveScreen(item)
            @scene.pbRefresh
          end
        end
      elsif cmdToss >= 0 && command == cmdToss   # Toss item
        if itm.is_important? || itm.is_key_item?
          @scene.pbDisplay(_INTL("That's too important to toss out!"))
          next
        end
        qty = @bag.quantity(item)
        if qty > 1
          helptext = _INTL("Toss out how many {1}?", itm.portion_name_plural)
          qty = @scene.pbChooseNumber(helptext, qty)
        end
        if qty > 0
          itemname = (qty > 1) ? itm.portion_name_plural : itm.portion_name
          if pbConfirm(_INTL("Is it OK to throw away {1} {2}?", qty, itemname))
            pbDisplay(_INTL("Threw away {1} {2}.", qty, itemname))
            qty.times { @bag.remove(item) }
            @scene.pbRefresh
          end
        end
      elsif cmdRegister >= 0 && command == cmdRegister   # Register item
        if @bag.registered?(item)
          @bag.unregister(item)
        else
          @bag.register(item)
        end
        @scene.pbRefresh
      elsif cmdDebug >= 0 && command == cmdDebug   # Debug
        command = 0
        loop do
          command = @scene.pbShowCommands(_INTL("Do what with {1}?", itemname),
                                          [_INTL("Change quantity"),
                                           _INTL("Make Mystery Gift"),
                                           _INTL("Cancel")], command)
          case command
          when -1, 2
            break
          when 0
            qty = @bag.quantity(item)
            itemmax = @bag.max_per_slot(item)
            qty = @scene.pbChooseNumber(_INTL("Choose new quantity (max. {1}).", itemmax), itemmax, qty)
            if qty <= 0
              @bag.remove(item, @bag.quantity(item))
              break
            elsif qty > 0
              @bag.set_quantity(item, qty)
              break
            end
          when 1
            pbCreateMysteryGift(1, item)
          end
        end
        @scene.pbRefresh
      end
    end
    @scene.pbEndScene
  end
end

#===============================================================================
# Starter Items (Single Instance Guarantee)
#===============================================================================
module BurningManBag
  STARTER_ITEMS = [:WHITEWATERBOTTLE, :USBDISK]

  def self.ensure_single_starter_items(bag)
    return if !bag
    STARTER_ITEMS.each do |item_id|
      next unless GameData::Item.exists?(item_id)
      # Remove duplicate slots/quantities if more than 1 exists
      while bag.quantity(item_id) > 1
        bag.remove(item_id, 1)
      end
      # Add exactly one if player has none
      bag.add(item_id) if bag.quantity(item_id) == 0
    end
  end
end

module Game
  class << self
    alias burningman_start_new start_new
    def start_new
      burningman_start_new
      BurningManBag.ensure_single_starter_items($bag)
    end

    alias burningman_load load
    def load(save_data)
      burningman_load(save_data)
      BurningManBag.ensure_single_starter_items($bag)
    end
  end
end


