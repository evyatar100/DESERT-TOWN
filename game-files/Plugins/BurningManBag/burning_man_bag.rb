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

