$(function() {
    let editMode = false;
    let currentShopId = null;
    let positionCounter = 0;
    let itemCounter = 0;
    let serverItems = [];
    let allShops = [];
    let currentPage = 1;
    const itemsPerPage = 10;
    let isDarkTheme = true;
    let selectedServerItems = []; // Track items selected from server

    // Custom notification system
    function showNotification(message, type = "error") {
        const icons = {
            error: "✕",
            success: "✓",
            warning: "⚠",
            info: "ℹ"
        };

        const icon = icons[type] || icons.error;

        const notification = $(`
            <div class="notification ${type}">
                <div class="notification-icon">${icon}</div>
                <div class="notification-message">${message}</div>
            </div>
        `);

        $("#notification-container").append(notification);

        setTimeout(() => {
            notification.fadeOut(300, function() {
                $(this).remove();
            });
        }, 3000);
    }

    // Custom confirmation modal
    function showConfirm(title, message, onConfirm) {
        $("#confirm-title").text(title);
        $("#confirm-message").text(message);
        $("#confirm-modal").fadeIn(200);

        $("#confirm-ok").off("click").on("click", function() {
            $("#confirm-modal").fadeOut(200);
            if (onConfirm) onConfirm();
        });

        $("#confirm-cancel").off("click").on("click", function() {
            $("#confirm-modal").fadeOut(200);
        });

        $(".modal-overlay").off("click").on("click", function(e) {
            if (e.target === this) {
                $(this).parent().fadeOut(200);
            }
        });
    }

    // Function to update dashboard statistics
    function updateDashboard() {
        if (!allShops || allShops.length === 0) {
            $("#total-shops").text("0");
            $("#total-items").text("0");
            $("#total-locations").text("0");
            $("#shops-chart").html('<div class="no-data">No shop data available</div>');
            return;
        }

        const totalShops = allShops.length;
        let totalItems = 0;
        let totalLocations = 0;

        allShops.forEach(shop => {
            if (shop.Items) totalItems += shop.Items.length;
            if (shop.Pos) totalLocations += shop.Pos.length;
        });

        $("#total-shops").text(totalShops);
        $("#total-items").text(totalItems);
        $("#total-locations").text(totalLocations);

        // Request analytics data from server
        $.post("https://flake_shops/requestAllShopsAnalytics", JSON.stringify({}));

        const shopsByItems = allShops
            .map(shop => ({
                name: shop.ShopLogo ? shop.ShopLogo.replace('.png', '').replace(/[_-]/g, ' ') : shop.name,
                items: shop.Items ? shop.Items.length : 0
            }))
            .sort((a, b) => b.items - a.items)
            .slice(0, 5);

        if (shopsByItems.length === 0 || shopsByItems.every(s => s.items === 0)) {
            $("#shops-chart").html('<div class="no-data">No item data available</div>');
            return;
        }

        const maxItems = Math.max(...shopsByItems.map(s => s.items));

        let chartHTML = '<div class="chart-bar-wrapper">';
        shopsByItems.forEach(shop => {
            const percentage = maxItems > 0 ? (shop.items / maxItems) * 100 : 0;
            chartHTML += `
                <div class="chart-bar-item">
                    <div class="chart-bar-label">${shop.name}</div>
                    <div class="chart-bar-bg">
                        <div class="chart-bar-fill" style="width: ${percentage}%">${shop.items} items</div>
                    </div>
                </div>
            `;
        });
        chartHTML += '</div>';

        $("#shops-chart").html(chartHTML);
    }

    

    // Listen for analytics response
    window.addEventListener("message", function(event) {
        const data = event.data;

        if (data.type === "openShopAdmin") {
            editMode = data.editMode || false;
            currentShopId = data.shopId || null;

            $("#admin-wrapper").fadeIn();

            if (data.playerName) $("#user-name").text(data.playerName);
            if (data.playerId) $("#user-id").text(data.playerId);
            if (data.playerAvatar) $("#user-avatar").attr("src", data.playerAvatar);

            $.post("https://flake_shops/requestShops", JSON.stringify({}), function(shops) {
                allShops = shops || [];
                renderShopsTable();
                updateDashboard();
            });

            if (editMode && data.shopData) {
                openShopModal(data.shopData);
            }
        } else if (data.type === "closeShopAdmin") {
            $("#admin-wrapper").fadeOut();
        } else if (data.type === "analyticsData") {
            updateAnalyticsDisplay(data.analytics);
        }
         else if (data.type === "showAnalytics") {
            showShopAnalyticsModal(data.analytics);
        }
    });

    // Theme toggle
    $("#theme-toggle").on("click", function() {
        isDarkTheme = !isDarkTheme;

        if (isDarkTheme) {
            $(this).html('<i class="fas fa-moon"></i>');
            $(this).removeClass("light");
            $("body").removeClass("light-theme");
        } else {
            $(this).html('<i class="fas fa-sun"></i>');
            $(this).addClass("light");
            $("body").addClass("light-theme");
        }
    });

    // Render shops table with analytics
    function renderShopsTable() {
        const tbody = $("#shops-table-body");
        tbody.empty();

        if (!allShops || allShops.length === 0) {
            tbody.append('<tr><td colspan="4" class="no-data">No shops found. Click "Create New Shop" to get started.</td></tr>');
            return;
        }

        const start = (currentPage - 1) * itemsPerPage;
        const end = start + itemsPerPage;
        const paginatedShops = allShops.slice(start, end);

        paginatedShops.forEach(shop => {
            const itemCount = shop.Items ? shop.Items.length : 0;
            const shopLabel = shop.ShopLogo ? shop.ShopLogo.replace('.png', '').replace(/[_-]/g, ' ') : shop.name;

            const row = $(`
                <tr>
                    <td>${shop.name}</td>
                    <td>${shopLabel}</td>
                    <td>${itemCount}</td>
                    <td>
                        <div class="table-actions">
                            <button class="action-btn analytics" data-shop-name="${shop.name}">
                                <i class="fas fa-chart-bar"></i> Analytics
                            </button>
                            <button class="action-btn edit" data-shop='${JSON.stringify(shop).replace(/'/g, "&#39;")}'>Edit</button>
                            <button class="action-btn delete" data-shop-name="${shop.name}">Delete</button>
                        </div>
                    </td>
                </tr>
            `);
            tbody.append(row);
        });

        $("#current-page").text(currentPage);
        $("#prev-page").prop("disabled", currentPage === 1);
        $("#next-page").prop("disabled", end >= allShops.length);
    }

    // Analytics button handler
    $("body").on("click", ".action-btn.analytics", function() {
        const shopName = $(this).attr("data-shop-name");
        openAnalyticsModal(shopName);
    });

    // Open analytics modal
    function openAnalyticsModal(shopName) {
        // Request analytics from server
        $.post("https://flake_shops/requestShopAnalytics", JSON.stringify({ shopName: shopName }));
        
        // Show loading modal
        showNotification(`Loading analytics for ${shopName}...`, "info");
    }

    // Search shops
    $("#shops-search").on("input", function() {
        const searchTerm = $(this).val().toLowerCase();
        if (!searchTerm) {
            renderShopsTable();
            return;
        }

        const filteredShops = allShops.filter(shop => {
            return shop.name.toLowerCase().includes(searchTerm) ||
                   (shop.ShopLogo && shop.ShopLogo.toLowerCase().includes(searchTerm));
        });

        const tbody = $("#shops-table-body");
        tbody.empty();

        if (filteredShops.length === 0) {
            tbody.append('<tr><td colspan="4" class="no-data">No shops match your search.</td></tr>');
            return;
        }

        filteredShops.forEach(shop => {
            const itemCount = shop.Items ? shop.Items.length : 0;
            const shopLabel = shop.ShopLogo ? shop.ShopLogo.replace('.png', '').replace(/[_-]/g, ' ') : shop.name;

            const row = $(`
                <tr>
                    <td>${shop.name}</td>
                    <td>${shopLabel}</td>
                    <td>${itemCount}</td>
                    <td>
                        <div class="table-actions">
                            <button class="action-btn analytics" data-shop-name="${shop.name}">
                                <i class="fas fa-chart-bar"></i> Analytics
                            </button>
                            <button class="action-btn edit" data-shop='${JSON.stringify(shop).replace(/'/g, "&#39;")}'>Edit</button>
                            <button class="action-btn delete" data-shop-name="${shop.name}">Delete</button>
                        </div>
                    </td>
                </tr>
            `);
            tbody.append(row);
        });
    });

    // Pagination
    $("#prev-page").on("click", function() {
        if (currentPage > 1) {
            currentPage--;
            renderShopsTable();
        }
    });

    $("#next-page").on("click", function() {
        const maxPages = Math.ceil(allShops.length / itemsPerPage);
        if (currentPage < maxPages) {
            currentPage++;
            renderShopsTable();
        }
    });

    // Table actions
    $("body").on("click", ".action-btn.edit", function() {
        const shopData = JSON.parse($(this).attr("data-shop"));
        openShopModal(shopData);
    });

    $("body").on("click", ".action-btn.delete", function() {
        const shopName = $(this).attr("data-shop-name");
        showConfirm(
            "Delete Shop",
            `Are you sure you want to permanently delete "${shopName}"? This action cannot be undone.`,
            function() {
                $.post("https://flake_shops/deleteShop", JSON.stringify({ shopName: shopName }), function() {
                    showNotification(`Shop "${shopName}" deleted successfully!`, "success");
                    $.post("https://flake_shops/requestShops", JSON.stringify({}), function(shops) {
                        allShops = shops || [];
                        renderShopsTable();
                        updateDashboard();
                    });
                });
            }
        );
    });

    // Sidebar navigation
    $(".nav-item").on("click", function(e) {
        e.preventDefault();
        const page = $(this).attr("data-page");

        $(".nav-item").removeClass("active");
        $(this).addClass("active");

        $(".content-page").removeClass("active");
        $(`#${page}-page`).addClass("active");
    });

    // Create new shop button
    $("#create-new-shop").on("click", function() {
        openShopModal(null);
    });

    // Open shop modal
    function openShopModal(shopData) {
        resetForm();
        selectedServerItems = [];

        if (shopData) {
            editMode = true;
            currentShopId = shopData.name;
            $("#modal-title").text("Edit Shop");
            $("#delete-shop").show();
            loadShopData(shopData);
        } else {
            editMode = false;
            currentShopId = null;
            $("#modal-title").text("Create New Shop");
            $("#delete-shop").hide();
        }

        $("#shop-modal").fadeIn(200);
    }

    // Close modals
    $("#close-modal, #cancel-modal").on("click", function() {
        $("#shop-modal").fadeOut(200);
    });

    $("#close-item-selector").on("click", function() {
        $("#item-selector-modal").fadeOut(200);
    });

    // Tab switching
    $(".tab-btn").on("click", function() {
        const tab = $(this).attr("data-tab");

        $(".tab-btn").removeClass("active");
        $(this).addClass("active");

        $(".tab-pane").removeClass("active");
        $(`.tab-pane[data-tab="${tab}"]`).addClass("active");
    });

    // Items tabs
    $(".items-tab-btn").on("click", function() {
        const tab = $(this).attr("data-items-tab");

        $(".items-tab-btn").removeClass("active");
        $(this).addClass("active");

        $(".items-tab-pane").removeClass("active");
        $(`.items-tab-pane[data-items-tab="${tab}"]`).addClass("active");
    });

    // Reset form
    function resetForm() {
        $("#shop-name").val("").prop("disabled", false);
        $("#shop-logo").val("blackmarket.png");
        $("#positions-list").empty();
        $("#items-list").empty();
        $(".currency-check").prop("checked", false);
        $("#use-pickup").prop("checked", false);
        $("#use-ped").prop("checked", false);
        $("#use-blip").prop("checked", false);
        $("#blip-settings").hide();
        positionCounter = 0;
        itemCounter = 0;

        $(".tab-btn").removeClass("active");
        $(".tab-btn[data-tab='basic']").addClass("active");
        $(".tab-pane").removeClass("active");
        $(".tab-pane[data-tab='basic']").addClass("active");
    }

    // Load shop data for editing
    function loadShopData(shopData) {
        $("#shop-name").val(shopData.name).prop("disabled", true);
        $("#shop-logo").val(shopData.ShopLogo || "blackmarket.png");

        if (shopData.Pos && shopData.Pos.length > 0) {
            shopData.Pos.forEach(pos => {
                addPositionEntry(pos.x, pos.y, pos.z);
            });
        }

        if (shopData.Items && shopData.Items.length > 0) {
            shopData.Items.forEach(item => {
                addItemEntry(item.label, item.item, item.price);
            });
        }

        if (shopData.Currency && shopData.Currency.length > 0) {
            shopData.Currency.forEach(currency => {
                $(`.currency-check[value="${currency}"]`).prop("checked", true);
            });
        }

        $("#use-pickup").prop("checked", shopData.UsePickup || false);
        $("#use-ped").prop("checked", shopData.UsePed || false);

        if (shopData.ShopPed) {
            $("#ped-model").val(shopData.ShopPed.model || "");
            $("#ped-heading").val(shopData.ShopPed.heading || 0);
            $("#ped-scenario").val(shopData.ShopPed.scenario || "");
        }

        if (shopData.Blip) {
            $("#use-blip").prop("checked", true);
            $("#blip-settings").show();
            $("#blip-name").val(shopData.Blip.name || "");
            $("#blip-sprite").val(shopData.Blip.sprite || 52);
            $("#blip-colour").val(shopData.Blip.colour || 2);
            $("#blip-scale").val(shopData.Blip.scale || 0.7);
            $("#blip-shortrange").prop("checked", shopData.Blip.shortRange !== false);
        }
    }

    // Add position entry
    function addPositionEntry(x = "", y = "", z = "") {
        positionCounter++;
        const html = `
            <div class="position-entry" data-id="${positionCounter}">
                <div style="display: flex; gap: 12px; align-items: flex-end; flex-wrap: wrap;">
                    <div style="flex: 1; min-width: 150px;">
                        <label>X Coordinate</label>
                        <input type="number" class="pos-x" placeholder="0.0000" value="${x}" step="0.0001" />
                    </div>
                    <div style="flex: 1; min-width: 150px;">
                        <label>Y Coordinate</label>
                        <input type="number" class="pos-y" placeholder="0.0000" value="${y}" step="0.0001" />
                    </div>
                    <div style="flex: 1; min-width: 150px;">
                        <label>Z Coordinate</label>
                        <input type="number" class="pos-z" placeholder="0.0000" value="${z}" step="0.0001" />
                    </div>
                    <button class="btn-remove remove-position">Remove</button>
                </div>
            </div>
        `;
        $("#positions-list").append(html);
    }

    // Add item entry
    function addItemEntry(label = "", item = "", price = "") {
        itemCounter++;
        const html = `
            <div class="item-entry" data-id="${itemCounter}">
                <div style="margin-bottom: 12px;">
                    <label>Item Display Name</label>
                    <input type="text" class="item-label" placeholder="e.g., Water Bottle" value="${label}" />
                </div>
                <div style="display: flex; gap: 12px; align-items: flex-end; flex-wrap: wrap;">
                    <div style="flex: 2; min-width: 200px;">
                        <label>Item Spawn Name</label>
                        <input type="text" class="item-name" placeholder="e.g., water" value="${item}" style="font-family: 'Courier New', monospace;" />
                    </div>
                    <div style="flex: 1; min-width: 120px;">
                        <label>Price ($)</label>
                        <input type="number" class="item-price" placeholder="100" value="${price}" />
                    </div>
                    <button class="btn-remove remove-item">Remove</button>
                </div>
            </div>
        `;
        $("#items-list").append(html);
    }

    // Event handlers
    $("#add-position").on("click", function() {
        addPositionEntry();
    });

    $("#add-current-position").on("click", function() {
        $.post("https://flake_shops/getCurrentPosition", JSON.stringify({}), function(pos) {
            if (pos && pos.x) {
                addPositionEntry(pos.x, pos.y, pos.z);
                showNotification("Current position added!", "success");
            }
        });
    });

    $("#add-item").on("click", function() {
        addItemEntry();
    });

    // IMPROVED: Item selector from server with multi-select
    $("#add-item-from-list").on("click", function() {
        const modal = $("#item-selector-modal");
        const loading = $("#item-selector-loading");
        const list = $("#item-selector-list");

        list.hide();
        loading.show();
        modal.fadeIn(200);

        $.post("https://flake_shops/requestItems", JSON.stringify({}), function(items) {
            serverItems = items;
            showItemSelector(items);
            loading.hide();
            list.show();
        });
    });

    function showItemSelector(items) {
        const list = $("#item-selector-list");
        list.empty();

        // Add header with selected count and add button
        const header = $(`
            <div class="item-selector-header-actions">
                <div class="selected-count">Selected: <span id="selected-count">0</span> items</div>
                <div class="header-buttons">
                    <button id="clear-selection" class="btn-secondary">Clear All</button>
                    <button id="add-selected-items" class="btn-add">Add Selected Items</button>
                </div>
            </div>
        `);
        list.append(header);

        // Create items grid
        const itemsGrid = $('<div class="items-grid"></div>');

        items.forEach(item => {
            if (!item || !item.name || !item.label) return;

            let imageSrc = '';
            if (item.image && (item.image.startsWith('http://') || item.image.startsWith('https://'))) {
                imageSrc = item.image;
            } else if (item.image) {
                imageSrc = item.imagePath || `nui://ox_inventory/web/images/${item.image}`;
            } else {
                imageSrc = 'img/placeholder.svg';
            }

            const escapedLabel = $('<div>').text(item.label).html();
            const escapedName = $('<div>').text(item.name).html();

            const itemCard = $(`
                <div class="item-card selectable" data-item-name="${escapedName}" data-item-label="${escapedLabel}">
                    <div class="selection-checkbox">
                        <input type="checkbox" class="item-checkbox" />
                    </div>
                    <img src="${imageSrc}" onerror="this.onerror=null; this.src='img/placeholder.svg';" loading="lazy" />
                    <div class="item-card-info">
                        <div class="item-card-label">${escapedLabel}</div>
                        <div class="item-card-name">${escapedName}</div>
                    </div>
                </div>
            `);
            
            itemsGrid.append(itemCard);
        });

        list.append(itemsGrid);

        // Handle item selection
        list.off("click").on("click", ".item-card", function(e) {
            if ($(e.target).is('input[type="checkbox"]')) return;
            
            const checkbox = $(this).find('.item-checkbox');
            checkbox.prop('checked', !checkbox.prop('checked'));
            $(this).toggleClass('selected');
            
            updateSelectedCount();
        });

        list.on("change", ".item-checkbox", function() {
            $(this).closest('.item-card').toggleClass('selected');
            updateSelectedCount();
        });

        // Clear selection
        list.on("click", "#clear-selection", function() {
            $('.item-checkbox').prop('checked', false);
            $('.item-card').removeClass('selected');
            updateSelectedCount();
        });

        // Add selected items
        list.on("click", "#add-selected-items", function() {
            const selectedCards = $('.item-card.selected');
            
            if (selectedCards.length === 0) {
                showNotification("No items selected!", "warning");
                return;
            }

            selectedCards.each(function() {
                const itemName = $(this).attr("data-item-name");
                const itemLabel = $(this).attr("data-item-label");
                addItemEntry(itemLabel, itemName, 100);
            });

            showNotification(`Added ${selectedCards.length} items to shop!`, "success");
            $("#item-selector-modal").fadeOut(200);
        });
    }

    function updateSelectedCount() {
        const count = $('.item-checkbox:checked').length;
        $('#selected-count').text(count);
    }

    // Optimized search
    let searchTimeout;
    $("#item-search").on("input", function() {
        clearTimeout(searchTimeout);
        const searchTerm = $(this).val().toLowerCase();

        searchTimeout = setTimeout(function() {
            const cards = document.querySelectorAll(".item-card");

            requestAnimationFrame(() => {
                cards.forEach(card => {
                    const itemName = (card.getAttribute("data-item-name") || "").toLowerCase();
                    const itemLabel = (card.getAttribute("data-item-label") || "").toLowerCase();

                    if (itemName.includes(searchTerm) || itemLabel.includes(searchTerm)) {
                        card.style.display = "flex";
                    } else {
                        card.style.display = "none";
                    }
                });
            });
        }, 100);
    });

    $("body").on("click", ".remove-position", function() {
        $(this).closest(".position-entry").remove();
    });

    $("body").on("click", ".remove-item", function() {
        $(this).closest(".item-entry").remove();
    });

    $("#use-blip").on("change", function() {
        if ($(this).is(":checked")) {
            $("#blip-settings").slideDown();
        } else {
            $("#blip-settings").slideUp();
        }
    });

    $("#add-custom-currency").on("click", function() {
        const customCurrency = $("#custom-currency").val().trim();
        if (customCurrency) {
            const exists = $(`.currency-check[value="${customCurrency}"]`).length > 0;
            if (!exists) {
                $("#currency-list").append(`
                    <label><input type="checkbox" class="currency-check" value="${customCurrency}" checked> ${customCurrency}</label>
                `);
                $("#custom-currency").val("");
                showNotification(`Added currency: ${customCurrency}`, "success");
            }
        }
    });

    // Save shop
    $("#save-shop").on("click", function() {
        const shopName = $("#shop-name").val().trim();

        if (!shopName) {
            showNotification("Please enter a shop name!", "error");
            return;
        }

        const positions = [];
        $(".position-entry").each(function() {
            const x = parseFloat($(this).find(".pos-x").val());
            const y = parseFloat($(this).find(".pos-y").val());
            const z = parseFloat($(this).find(".pos-z").val());
            if (!isNaN(x) && !isNaN(y) && !isNaN(z)) {
                positions.push({x, y, z});
            }
        });

        if (positions.length === 0) {
            showNotification("Please add at least one position!", "error");
            return;
        }

        const items = [];
        $(".item-entry").each(function() {
            const label = $(this).find(".item-label").val().trim();
            const item = $(this).find(".item-name").val().trim();
            const price = parseFloat($(this).find(".item-price").val());
            if (label && item && !isNaN(price)) {
                items.push({label, item, price});
            }
        });

        if (items.length === 0) {
            showNotification("Please add at least one item!", "error");
            return;
        }

        const currencies = [];
        $(".currency-check:checked").each(function() {
            currencies.push($(this).val());
        });

        if (currencies.length === 0) {
            showNotification("Please select at least one currency!", "error");
            return;
        }

        const shopData = {
            name: shopName,
            Items: items,
            Pos: positions,
            Currency: currencies,
            UsePickup: $("#use-pickup").is(":checked"),
            UsePed: $("#use-ped").is(":checked"),
            ShopLogo: $("#shop-logo").val().trim() || "blackmarket.png"
        };

        if (shopData.UsePed) {
            shopData.ShopPed = {
                model: $("#ped-model").val().trim() || "mp_m_shopkeep_01",
                heading: parseFloat($("#ped-heading").val()) || 0.0,
                scenario: $("#ped-scenario").val().trim() || "WORLD_HUMAN_STAND_IMPATIENT"
            };
        }

        if ($("#use-blip").is(":checked")) {
            shopData.Blip = {
                name: $("#blip-name").val().trim() || "Shop",
                sprite: parseInt($("#blip-sprite").val()) || 52,
                colour: parseInt($("#blip-colour").val()) || 2,
                scale: parseFloat($("#blip-scale").val()) || 0.7,
                display: 4,
                shortRange: $("#blip-shortrange").is(":checked")
            };
        }

        $.post("https://flake_shops/saveShop", JSON.stringify({
            shopData: shopData,
            editMode: editMode
        }), function() {
            showNotification(`Shop "${shopName}" saved successfully!`, "success");
            $("#shop-modal").fadeOut(200);

            $.post("https://flake_shops/requestShops", JSON.stringify({}), function(shops) {
                allShops = shops || [];
                renderShopsTable();
                updateDashboard();
            });
        });
    });

    // Delete shop
    $("#delete-shop").on("click", function() {
        const shopName = $("#shop-name").val().trim();
        showConfirm(
            "Delete Shop",
            `Are you sure you want to permanently delete "${shopName}"? This action cannot be undone.`,
            function() {
                $.post("https://flake_shops/deleteShop", JSON.stringify({ shopName: shopName }), function() {
                    showNotification(`Shop "${shopName}" deleted successfully!`, "success");
                    $("#shop-modal").fadeOut(200);

                    $.post("https://flake_shops/requestShops", JSON.stringify({}), function(shops) {
                        allShops = shops || [];
                        renderShopsTable();
                        updateDashboard();
                    });
                });
            }
        );
    });

    // Close admin
    function closeAdmin() {
        $("#admin-wrapper").fadeOut();
        $.post("https://flake_shops/closeAdmin", JSON.stringify({}));
    }

    document.addEventListener('keyup', function(event) {
        if (event.which === 27) {
            if ($("#shop-modal").is(":visible")) {
                $("#shop-modal").fadeOut(200);
            } else if ($("#item-selector-modal").is(":visible")) {
                $("#item-selector-modal").fadeOut(200);
            } else if ($("#admin-wrapper").is(":visible")) {
                closeAdmin();
            }
        }
    });

    $("#admin-wrapper").on("click", function(e) {
        if (e.target === this) {
            closeAdmin();
        }
    });
});