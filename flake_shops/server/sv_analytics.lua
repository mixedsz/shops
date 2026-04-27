-- ============================================
-- SERVER-SIDE ANALYTICS TRACKING
-- Add this to your server/sv_analytics.lua (NEW FILE)
-- ============================================

local QBCore, ESX = nil, nil

-- Framework Detection
Citizen.CreateThread(function()
    if GetResourceState(Config.QBCoreGetCoreObject) ~= "missing" then
        QBCore = exports[Config.QBCoreGetCoreObject]:GetCoreObject()
    elseif GetResourceState(Config.ESXgetSharedObject) ~= "missing" then
        ESX = exports[Config.ESXgetSharedObject]:getSharedObject()
    end
end)

-- Helper to get player identifier
local function GetPlayerIdentifier(source)
    if QBCore then
        return QBCore.Functions.GetPlayer(source).PlayerData.citizenid
    elseif ESX then
        return ESX.GetPlayerFromId(source).identifier
    end
    return tostring(source)
end

-- Track when player opens shop
RegisterNetEvent('flake_shops:trackShopVisit')
AddEventHandler('flake_shops:trackShopVisit', function(shopName)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    local playerName = GetPlayerName(src)
    
    MySQL.Async.execute('INSERT INTO shop_visits (shop_name, player_identifier, player_name) VALUES (@shop, @id, @name)', {
        ['@shop'] = shopName,
        ['@id'] = identifier,
        ['@name'] = playerName
    })
end)

-- Track purchases for analytics
RegisterNetEvent('flake_shops:trackPurchase')
AddEventHandler('flake_shops:trackPurchase', function(playerId, shopName, cart, totalCost, payMethod)
    local src = playerId
    local identifier = GetPlayerIdentifier(src)
    local playerName = GetPlayerName(src)
    
    -- Update shop visit with purchase info
    MySQL.Async.execute([[
        UPDATE shop_visits 
        SET made_purchase = 1, total_spent = @total 
        WHERE shop_name = @shop 
        AND player_identifier = @id 
        ORDER BY visit_date DESC 
        LIMIT 1
    ]], {
        ['@shop'] = shopName,
        ['@id'] = identifier,
        ['@total'] = totalCost
    })
    
    -- Track individual item purchases
    for _, item in ipairs(cart) do
        -- Insert purchase record
        MySQL.Async.execute([[
            INSERT INTO shop_purchases 
            (shop_name, player_identifier, player_name, item_name, item_label, quantity, price_per_item, total_cost, currency_type) 
            VALUES (@shop, @id, @name, @item, @label, @qty, @price, @total, @currency)
        ]], {
            ['@shop'] = shopName,
            ['@id'] = identifier,
            ['@name'] = playerName,
            ['@item'] = item.item,
            ['@label'] = item.label,
            ['@qty'] = item.count,
            ['@price'] = item.price,
            ['@total'] = item.price * item.count,
            ['@currency'] = payMethod
        })
        
        -- Update popular items
        MySQL.Async.execute([[
            INSERT INTO shop_popular_items (shop_name, item_name, item_label, total_sold, total_revenue, last_sold)
            VALUES (@shop, @item, @label, @qty, @revenue, NOW())
            ON DUPLICATE KEY UPDATE 
                total_sold = total_sold + @qty,
                total_revenue = total_revenue + @revenue,
                last_sold = NOW()
        ]], {
            ['@shop'] = shopName,
            ['@item'] = item.item,
            ['@label'] = item.label,
            ['@qty'] = item.count,
            ['@revenue'] = item.price * item.count
        })
    end
    
    -- Update daily revenue
    MySQL.Async.execute([[
        INSERT INTO shop_daily_revenue (shop_name, date, total_revenue, total_transactions, unique_customers)
        VALUES (@shop, CURDATE(), @revenue, 1, 1)
        ON DUPLICATE KEY UPDATE 
            total_revenue = total_revenue + @revenue,
            total_transactions = total_transactions + 1
    ]], {
        ['@shop'] = shopName,
        ['@revenue'] = totalCost
    })
end)

-- Get shop analytics
RegisterNetEvent('flake_shops:getShopAnalytics')
AddEventHandler('flake_shops:getShopAnalytics', function(shopName)
    local src = source
    
    -- Get total revenue (all time)
    MySQL.Async.fetchScalar('SELECT COALESCE(SUM(total_revenue), 0) FROM shop_daily_revenue WHERE shop_name = @shop', {
        ['@shop'] = shopName
    }, function(totalRevenue)
        
        -- Get total transactions
        MySQL.Async.fetchScalar('SELECT COALESCE(SUM(total_transactions), 0) FROM shop_daily_revenue WHERE shop_name = @shop', {
            ['@shop'] = shopName
        }, function(totalTransactions)
            
            -- Get unique customers
            MySQL.Async.fetchScalar('SELECT COUNT(DISTINCT player_identifier) FROM shop_visits WHERE shop_name = @shop AND made_purchase = 1', {
                ['@shop'] = shopName
            }, function(uniqueCustomers)
                
                -- Get top selling items
                MySQL.Async.fetchAll('SELECT item_label, total_sold, total_revenue FROM shop_popular_items WHERE shop_name = @shop ORDER BY total_sold DESC LIMIT 5', {
                    ['@shop'] = shopName
                }, function(topItems)
                    
                    -- Get last 7 days revenue
                    MySQL.Async.fetchAll([[
                        SELECT date, total_revenue, total_transactions 
                        FROM shop_daily_revenue 
                        WHERE shop_name = @shop 
                        AND date >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
                        ORDER BY date DESC
                    ]], {
                        ['@shop'] = shopName
                    }, function(recentRevenue)
                        
                        -- Get recent purchases
                        MySQL.Async.fetchAll([[
                            SELECT player_name, item_label, quantity, total_cost, currency_type, purchase_date
                            FROM shop_purchases 
                            WHERE shop_name = @shop 
                            ORDER BY purchase_date DESC 
                            LIMIT 10
                        ]], {
                            ['@shop'] = shopName
                        }, function(recentPurchases)
                            
                            TriggerClientEvent('flake_shops:receiveShopAnalytics', src, {
                                shopName = shopName,
                                totalRevenue = totalRevenue,
                                totalTransactions = totalTransactions,
                                uniqueCustomers = uniqueCustomers,
                                topItems = topItems,
                                recentRevenue = recentRevenue,
                                recentPurchases = recentPurchases
                            })
                        end)
                    end)
                end)
            end)
        end)
    end)
end)

-- Get all shops analytics (for dashboard)
RegisterNetEvent('flake_shops:getAllShopsAnalytics')
AddEventHandler('flake_shops:getAllShopsAnalytics', function()
    local src = source
    
    MySQL.Async.fetchAll([[
        SELECT 
            s.shop_name,
            COALESCE(SUM(dr.total_revenue), 0) as total_revenue,
            COALESCE(SUM(dr.total_transactions), 0) as total_transactions,
            COUNT(DISTINCT v.player_identifier) as unique_customers
        FROM shops s
        LEFT JOIN shop_daily_revenue dr ON s.shop_name = dr.shop_name
        LEFT JOIN shop_visits v ON s.shop_name = v.shop_name AND v.made_purchase = 1
        GROUP BY s.shop_name
    ]], {}, function(results)
        TriggerClientEvent('flake_shops:receiveAllShopsAnalytics', src, results)
    end)
end)