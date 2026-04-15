--#Notifications
Config.Notify = function(message, type)
  -- Try ox_lib first
  if GetResourceState('ox_lib') ~= 'missing' then
    local oxType = type == 'success' and 'success' or type == 'error' and 'error' or type == 'warning' and 'warning' or 'inform'
    exports.ox_lib:notify({
      title = 'Shop',
      description = message,
      type = oxType,
      position = 'top'
    })
  else
    -- Fallback to custom notification for shop menu UI
    SendNUIMessage({
      type = 'notify',
      message = message,
      notifType = type
    })
  end
end

Config.Notifications = {
  press_menu    = "Press [E] to open",
  shops         = "Shop",
  bought        = "I appreciate the good business, have a good day!",
  direct_purchase = "Transaction complete! Items added to your inventory.",
  not_enough    = "You are missing $%s",
  pick_up_blip  = "Order Pickup",
  order_placed  = "Order placed! Pick up once it's ready. Head to the pickup location to get your items.",
  items_ready   = "Your items are ready for pickup!",
  not_ready =  'Your order is not ready yet!',
  pickup_prompt = 'Press [E] to pick up your items'
}
