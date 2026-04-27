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
    let detectedFramework = "esx"; // updated when server responds

    // ── Virtual-scroll state ──────────────────────────────────
    let vsItems    = [];
    let vsSelected = new Set();
    const VS_ITEM_H  = 96;   // px height per row
    const VS_COLS    = 4;
    const VS_OVERSCAN = 3;

    // ── Notifications ─────────────────────────────────────────
    function showNotification(message, type = "error") {
        const icons = { error: "✕", success: "✓", warning: "⚠", info: "ℹ" };
        const notification = $(`
            <div class="notification ${type}">
                <div class="notification-icon">${icons[type] || icons.error}</div>
                <div class="notification-message">${message}</div>
            </div>
        `);
        $("#notification-container").append(notification);
        setTimeout(() => notification.fadeOut(300, function() { $(this).remove(); }), 3000);
    }

    // ── Confirmation modal ────────────────────────────────────
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
    }

    // ── Dashboard ─────────────────────────────────────────────
    function updateDashboard() {
        if (!allShops || allShops.length === 0) {
            $("#total-shops, #total-items, #total-locations").text("0");
            return;
        }
        let totalItems = 0, totalLocations = 0;
        allShops.forEach(shop => {
            if (shop.Items) totalItems += shop.Items.length;
            if (shop.Pos)   totalLocations += shop.Pos.length;
        });
        $("#total-shops").text(allShops.length);
        $("#total-items").text(totalItems);
        $("#total-locations").text(totalLocations);
        $.post("https://flake_shops/requestAllShopsAnalytics", JSON.stringify({}));
    }

    // ── NUI message listener ──────────────────────────────────
    window.addEventListener("message", function(event) {
        const data = event.data;
        if (data.type === "openShopAdmin") {
            editMode = data.editMode || false;
            currentShopId = data.shopId || null;
            $("#admin-wrapper").fadeIn();
            if (data.playerName) $("#user-name").text(data.playerName);
            if (data.playerId)   $("#user-id").text(data.playerId);
            if (data.playerAvatar) $("#user-avatar").attr("src", data.playerAvatar);
            $.post("https://flake_shops/requestShops", JSON.stringify({}), function(shops) {
                allShops = shops || [];
                renderShopsTable();
                updateDashboard();
            });
            $.post("https://flake_shops/getFramework", JSON.stringify({}));
            if (editMode && data.shopData) openShopModal(data.shopData);
        } else if (data.type === "closeShopAdmin") {
            $("#admin-wrapper").fadeOut();
        } else if (data.type === "frameworkDetected") {
            detectedFramework = data.framework || "esx";
        } else if (data.type === "analyticsData") {
            updateAnalyticsDisplay(data.analytics);
        } else if (data.type === "showAnalytics") {
            showShopAnalyticsModal(data.analytics);
        }
    });

    // ── Theme toggle ──────────────────────────────────────────
    $("#theme-toggle").on("click", function() {
        isDarkTheme = !isDarkTheme;
        if (isDarkTheme) {
            $(this).html('<i class="fas fa-moon"></i>').removeClass("light");
            $("body").removeClass("light-theme");
        } else {
            $(this).html('<i class="fas fa-sun"></i>').addClass("light");
            $("body").addClass("light-theme");
        }
    });

    // ── Shops table ───────────────────────────────────────────
    function renderShopsTable() {
        const tbody = $("#shops-table-body");
        tbody.empty();
        if (!allShops || allShops.length === 0) {
            tbody.append('<tr><td colspan="4" class="no-data">No shops found. Click "Create New Shop" to get started.</td></tr>');
            return;
        }
        const start = (currentPage - 1) * itemsPerPage;
        const end   = start + itemsPerPage;
        allShops.slice(start, end).forEach(shop => {
            const itemCount = shop.Items ? shop.Items.length : 0;
            const shopLabel = shop.ShopLogo ? shop.ShopLogo.replace('.png','').replace(/[_-]/g,' ') : shop.name;
            tbody.append(`
                <tr>
                    <td>${shop.name}</td>
                    <td>${shopLabel}</td>
                    <td>${itemCount}</td>
                    <td>
                        <div class="table-actions">
                            <button class="action-btn analytics" data-shop-name="${shop.name}">
                                <i class="fas fa-chart-bar"></i> Analytics
                            </button>
                            <button class="action-btn goto" data-pos='${JSON.stringify(shop.Pos && shop.Pos[0] ? shop.Pos[0] : {}).replace(/'/g,"&#39;")}'>
                                <i class="fas fa-location-arrow"></i> Goto
                            </button>
                            <button class="action-btn edit" data-shop='${JSON.stringify(shop).replace(/'/g,"&#39;")}'>Edit</button>
                            <button class="action-btn delete" data-shop-name="${shop.name}">Delete</button>
                        </div>
                    </td>
                </tr>
            `);
        });
        $("#current-page").text(currentPage);
        $("#prev-page").prop("disabled", currentPage === 1);
        $("#next-page").prop("disabled", end >= allShops.length);
    }

    $("body").on("click", ".action-btn.analytics", function() {
        const shopName = $(this).attr("data-shop-name");
        $.post("https://flake_shops/requestShopAnalytics", JSON.stringify({ shopName }));
        showNotification(`Loading analytics for ${shopName}...`, "info");
    });

    $("body").on("click", ".action-btn.goto", function() {
        try {
            const pos = JSON.parse($(this).attr("data-pos").replace(/&#39;/g, "'"));
            if (pos && pos.x !== undefined) {
                $.post("https://flake_shops/gotoShopPosition", JSON.stringify({ x: pos.x, y: pos.y, z: pos.z }));
                showNotification("Teleporting to shop location...", "info");
            } else {
                showNotification("No position set for this shop.", "error");
            }
        } catch(e) {
            showNotification("Could not parse shop position.", "error");
        }
    });

    $("#shops-search").on("input", function() {
        const term = $(this).val().toLowerCase();
        const tbody = $("#shops-table-body");
        tbody.empty();
        const filtered = term
            ? allShops.filter(s => s.name.toLowerCase().includes(term) ||
                (s.ShopLogo && s.ShopLogo.toLowerCase().includes(term)))
            : allShops;
        if (!filtered.length) {
            tbody.append('<tr><td colspan="4" class="no-data">No shops match your search.</td></tr>');
            return;
        }
        filtered.forEach(shop => {
            const itemCount = shop.Items ? shop.Items.length : 0;
            const shopLabel = shop.ShopLogo ? shop.ShopLogo.replace('.png','').replace(/[_-]/g,' ') : shop.name;
            tbody.append(`
                <tr>
                    <td>${shop.name}</td>
                    <td>${shopLabel}</td>
                    <td>${itemCount}</td>
                    <td>
                        <div class="table-actions">
                            <button class="action-btn analytics" data-shop-name="${shop.name}">
                                <i class="fas fa-chart-bar"></i> Analytics
                            </button>
                            <button class="action-btn goto" data-pos='${JSON.stringify(shop.Pos && shop.Pos[0] ? shop.Pos[0] : {}).replace(/'/g,"&#39;")}'>
                                <i class="fas fa-location-arrow"></i> Goto
                            </button>
                            <button class="action-btn edit" data-shop='${JSON.stringify(shop).replace(/'/g,"&#39;")}'>Edit</button>
                            <button class="action-btn delete" data-shop-name="${shop.name}">Delete</button>
                        </div>
                    </td>
                </tr>
            `);
        });
    });

    $("#prev-page").on("click", function() { if (currentPage > 1) { currentPage--; renderShopsTable(); } });
    $("#next-page").on("click", function() {
        if (currentPage < Math.ceil(allShops.length / itemsPerPage)) { currentPage++; renderShopsTable(); }
    });

    $("body").on("click", ".action-btn.edit", function() {
        openShopModal(JSON.parse($(this).attr("data-shop")));
    });
    $("body").on("click", ".action-btn.delete", function() {
        const shopName = $(this).attr("data-shop-name");
        showConfirm("Delete Shop", `Permanently delete "${shopName}"? This cannot be undone.`, function() {
            $.post("https://flake_shops/deleteShop", JSON.stringify({ shopName }), function() {
                showNotification(`Shop "${shopName}" deleted!`, "success");
                $.post("https://flake_shops/requestShops", JSON.stringify({}), function(shops) {
                    allShops = shops || [];
                    renderShopsTable();
                    updateDashboard();
                });
            });
        });
    });

    // ── Sidebar nav ───────────────────────────────────────────
    $(".nav-item").on("click", function(e) {
        e.preventDefault();
        const page = $(this).attr("data-page");
        $(".nav-item").removeClass("active");
        $(this).addClass("active");
        $(".content-page").removeClass("active");
        $(`#${page}-page`).addClass("active");
    });

    // ── Shop modal ────────────────────────────────────────────
    $("#create-new-shop").on("click", function() { openShopModal(null); });

    function openShopModal(shopData) {
        resetForm();
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

    $("#close-modal, #cancel-modal").on("click", function() { $("#shop-modal").fadeOut(200); });

    $(".tab-btn").on("click", function() {
        const tab = $(this).attr("data-tab");
        $(".tab-btn").removeClass("active");
        $(this).addClass("active");
        $(".tab-pane").removeClass("active");
        $(`.tab-pane[data-tab="${tab}"]`).addClass("active");
    });

    $(".items-tab-btn").on("click", function() {
        const tab = $(this).attr("data-items-tab");
        $(".items-tab-btn").removeClass("active");
        $(this).addClass("active");
        $(".items-tab-pane").removeClass("active");
        $(`.items-tab-pane[data-items-tab="${tab}"]`).addClass("active");
    });

    function resetForm() {
        $("#shop-name").val("").prop("disabled", false);
        $("#shop-logo").val("blackmarket.png");
        $("#positions-list, #items-list").empty();
        $(".currency-check").prop("checked", false);
        $("#use-pickup, #use-ped, #use-blip").prop("checked", false);
        $("#blip-settings").hide();
        positionCounter = itemCounter = 0;
        $(".tab-btn").removeClass("active");
        $(".tab-btn[data-tab='basic']").addClass("active");
        $(".tab-pane").removeClass("active");
        $(".tab-pane[data-tab='basic']").addClass("active");
        renderCurrencyOptions();
    }

    function renderCurrencyOptions() {
        const fwMap = {
            qbcore: [
                { value: "cash",         label: "Cash" },
                { value: "bank",         label: "Bank" },
                { value: "crypto",       label: "Crypto" },
                { value: "black_money",  label: "Black Money" },
                { value: "blackdiamond", label: "Black Diamond" },
            ],
            esx: [
                { value: "money",        label: "Cash" },
                { value: "bank",         label: "Bank" },
                { value: "black_money",  label: "Black Money" },
                { value: "blackdiamond", label: "Black Diamond" },
            ],
        };
        const currencies = fwMap[detectedFramework] || fwMap.esx;
        const html = currencies.map(c =>
            `<label><input type="checkbox" class="currency-check" value="${c.value}"> ${c.label}</label>`
        ).join('');
        $("#currency-list").html(html);
    }

    function loadShopData(shopData) {
        $("#shop-name").val(shopData.name).prop("disabled", true);
        $("#shop-logo").val(shopData.ShopLogo || "blackmarket.png");
        if (shopData.Pos) shopData.Pos.forEach(pos => addPositionEntry(pos.x, pos.y, pos.z));
        if (shopData.Items) shopData.Items.forEach(item => addItemEntry(item.label, item.item, item.price));
        if (shopData.Currency) shopData.Currency.forEach(c => $(`.currency-check[value="${c}"]`).prop("checked", true));
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

    function addPositionEntry(x = "", y = "", z = "") {
        positionCounter++;
        $("#positions-list").append(`
            <div class="position-entry" data-id="${positionCounter}">
                <div style="display:flex;gap:12px;align-items:flex-end;flex-wrap:wrap;">
                    <div style="flex:1;min-width:150px;"><label>X Coordinate</label>
                        <input type="number" class="pos-x" placeholder="0.0000" value="${x}" step="0.0001"/></div>
                    <div style="flex:1;min-width:150px;"><label>Y Coordinate</label>
                        <input type="number" class="pos-y" placeholder="0.0000" value="${y}" step="0.0001"/></div>
                    <div style="flex:1;min-width:150px;"><label>Z Coordinate</label>
                        <input type="number" class="pos-z" placeholder="0.0000" value="${z}" step="0.0001"/></div>
                    <button class="btn-remove remove-position">Remove</button>
                </div>
            </div>
        `);
    }

    function addItemEntry(label = "", item = "", price = "") {
        itemCounter++;
        $("#items-list").append(`
            <div class="item-entry" data-id="${itemCounter}">
                <div style="margin-bottom:12px;"><label>Item Display Name</label>
                    <input type="text" class="item-label" placeholder="e.g., Water Bottle" value="${label}"/></div>
                <div style="display:flex;gap:12px;align-items:flex-end;flex-wrap:wrap;">
                    <div style="flex:2;min-width:200px;"><label>Item Spawn Name</label>
                        <input type="text" class="item-name" placeholder="e.g., water" value="${item}" style="font-family:'Courier New',monospace;"/></div>
                    <div style="flex:1;min-width:120px;"><label>Price ($)</label>
                        <input type="number" class="item-price" placeholder="100" value="${price}"/></div>
                    <button class="btn-remove remove-item">Remove</button>
                </div>
            </div>
        `);
    }

    $("#add-position").on("click", function() { addPositionEntry(); });
    $("#add-current-position").on("click", function() {
        $.post("https://flake_shops/getCurrentPosition", JSON.stringify({}), function(pos) {
            if (pos && pos.x) { addPositionEntry(pos.x, pos.y, pos.z); showNotification("Current position added!", "success"); }
        });
    });
    $("#add-item").on("click", function() { addItemEntry(); });

    $("body").on("click", ".remove-position", function() { $(this).closest(".position-entry").remove(); });
    $("body").on("click", ".remove-item",     function() { $(this).closest(".item-entry").remove(); });

    $("#use-blip").on("change", function() {
        $(this).is(":checked") ? $("#blip-settings").slideDown() : $("#blip-settings").slideUp();
    });

    $("#add-custom-currency").on("click", function() {
        const val = $("#custom-currency").val().trim();
        if (val && !$(`.currency-check[value="${val}"]`).length) {
            $("#currency-list").append(`<label><input type="checkbox" class="currency-check" value="${val}" checked> ${val}</label>`);
            $("#custom-currency").val("");
            showNotification(`Added currency: ${val}`, "success");
        }
    });

    // ── Save / delete shop ────────────────────────────────────
    $("#save-shop").on("click", function() {
        const shopName = $("#shop-name").val().trim();
        if (!shopName) { showNotification("Please enter a shop name!", "error"); return; }

        const positions = [];
        $(".position-entry").each(function() {
            const x = parseFloat($(this).find(".pos-x").val()),
                  y = parseFloat($(this).find(".pos-y").val()),
                  z = parseFloat($(this).find(".pos-z").val());
            if (!isNaN(x) && !isNaN(y) && !isNaN(z)) positions.push({x, y, z});
        });
        if (!positions.length) { showNotification("Please add at least one position!", "error"); return; }

        const items = [];
        $(".item-entry").each(function() {
            const label = $(this).find(".item-label").val().trim(),
                  item  = $(this).find(".item-name").val().trim(),
                  price = parseFloat($(this).find(".item-price").val());
            if (label && item && !isNaN(price)) items.push({label, item, price});
        });
        if (!items.length) { showNotification("Please add at least one item!", "error"); return; }

        const currencies = [];
        $(".currency-check:checked").each(function() { currencies.push($(this).val()); });
        if (!currencies.length) { showNotification("Please select at least one currency!", "error"); return; }

        const shopData = {
            name: shopName, Items: items, Pos: positions, Currency: currencies,
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

        $.post("https://flake_shops/saveShop", JSON.stringify({ shopData, editMode }), function() {
            showNotification(`Shop "${shopName}" saved!`, "success");
            $("#shop-modal").fadeOut(200);
            $.post("https://flake_shops/requestShops", JSON.stringify({}), function(shops) {
                allShops = shops || [];
                renderShopsTable();
                updateDashboard();
            });
        });
    });

    $("#delete-shop").on("click", function() {
        const shopName = $("#shop-name").val().trim();
        showConfirm("Delete Shop", `Permanently delete "${shopName}"? This cannot be undone.`, function() {
            $.post("https://flake_shops/deleteShop", JSON.stringify({ shopName }), function() {
                showNotification(`Shop "${shopName}" deleted!`, "success");
                $("#shop-modal").fadeOut(200);
                $.post("https://flake_shops/requestShops", JSON.stringify({}), function(shops) {
                    allShops = shops || [];
                    renderShopsTable();
                    updateDashboard();
                });
            });
        });
    });

    // ═══════════════════════════════════════════════════════════
    //  ITEM SELECTOR  –  virtual scroll + grid + selection bar
    // ═══════════════════════════════════════════════════════════

    function escHtml(str) {
        return String(str)
            .replace(/&/g,"&amp;").replace(/</g,"&lt;")
            .replace(/>/g,"&gt;").replace(/"/g,"&quot;");
    }

    function updateSelectorBar() {
        const n = vsSelected.size;
        $("#vs-selected-count").text(n);
        const btn = $("#vs-confirm-btn");
        if (n > 0) { btn.removeClass("disabled").prop("disabled", false); }
        else        { btn.addClass("disabled").prop("disabled", true); }
    }

    function updateTotalCount(n) {
        $("#vs-total-count").text(n.toLocaleString());
    }

    // Virtual grid painter
    function paintVirtualGrid(items, viewport, container) {
        const rows   = Math.ceil(items.length / VS_COLS);
        const totalH = rows * VS_ITEM_H;
        container.style.height   = totalH + "px";
        container.style.position = "relative";

        const scrollTop  = viewport.scrollTop;
        const viewH      = viewport.clientHeight;
        const firstRow   = Math.max(0, Math.floor(scrollTop / VS_ITEM_H) - VS_OVERSCAN);
        const lastRow    = Math.min(rows - 1, Math.ceil((scrollTop + viewH) / VS_ITEM_H) + VS_OVERSCAN);
        const firstIdx   = firstRow * VS_COLS;
        const lastIdx    = Math.min(items.length - 1, (lastRow + 1) * VS_COLS - 1);

        // Remove out-of-range cards
        container.querySelectorAll(".vs-card").forEach(card => {
            const idx = parseInt(card.dataset.idx, 10);
            if (idx < firstIdx || idx > lastIdx) card.remove();
        });

        const existing = new Set(
            [...container.querySelectorAll(".vs-card")].map(c => parseInt(c.dataset.idx, 10))
        );

        for (let i = firstIdx; i <= lastIdx; i++) {
            if (existing.has(i)) continue;
            const item = items[i];
            if (!item) continue;

            const col = i % VS_COLS;
            const row = Math.floor(i / VS_COLS);

            let imgSrc = "img/placeholder.svg";
            if (item.image) {
                if (item.image.startsWith("http://") || item.image.startsWith("https://")) {
                    imgSrc = item.image;
                } else {
                    imgSrc = item.imagePath || `nui://ox_inventory/web/images/${item.image}`;
                }
            }

            const isSel = vsSelected.has(item.name);
            const card  = document.createElement("div");
            card.className   = "vs-card" + (isSel ? " selected" : "");
            card.dataset.idx   = i;
            card.dataset.name  = item.name;
            card.dataset.label = item.label;
            card.style.cssText = `
                position: absolute;
                top: ${row * VS_ITEM_H + 4}px;
                left: calc(${col} / ${VS_COLS} * 100%);
                width: calc(100% / ${VS_COLS} - 8px);
                margin: 0 4px;
                box-sizing: border-box;
            `;
            card.innerHTML = `
                <div class="vs-check ${isSel ? "checked" : ""}">
                    <svg viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                        <polyline points="1.5,6 4.5,9 10.5,3"/>
                    </svg>
                </div>
                <div class="vs-img-wrap">
                    <img src="${imgSrc}" loading="lazy"
                         onerror="this.src='img/placeholder.svg'" alt="${escHtml(item.label)}"/>
                </div>
                <div class="vs-info">
                    <div class="vs-label">${escHtml(item.label)}</div>
                    <div class="vs-name">${escHtml(item.name)}</div>
                </div>
            `;
            card.addEventListener("click", function () {
                const name = this.dataset.name;
                if (vsSelected.has(name)) {
                    vsSelected.delete(name);
                    this.classList.remove("selected");
                    this.querySelector(".vs-check").classList.remove("checked");
                } else {
                    vsSelected.add(name);
                    this.classList.add("selected");
                    this.querySelector(".vs-check").classList.add("checked");
                }
                updateSelectorBar();
            });
            container.appendChild(card);
        }
    }

    function renderVirtualGrid(items) {
        const viewport  = document.getElementById("vs-viewport");
        const container = document.getElementById("vs-grid-container");
        if (!viewport || !container) return;

        // Clear existing cards
        container.innerHTML = "";

        if (items.length === 0) {
            container.style.height = "120px";
            container.innerHTML = '<div style="color:#6b7280;text-align:center;padding:40px;font-size:14px;">No items found</div>';
            updateTotalCount(0);
            return;
        }

        const rows   = Math.ceil(items.length / VS_COLS);
        const totalH = rows * VS_ITEM_H;
        container.style.height = totalH + "px";

        let rafPending = false;
        function onScroll() {
            if (!rafPending) {
                rafPending = true;
                requestAnimationFrame(function() {
                    paintVirtualGrid(items, viewport, container);
                    rafPending = false;
                });
            }
        }

        // Replace scroll listener
        viewport.onscroll = onScroll;
        viewport.scrollTop = 0;

        paintVirtualGrid(items, viewport, container);
        updateTotalCount(items.length);
        updateSelectorBar();
    }

    // Open item selector
    $("#add-item-from-list").on("click", function() {
        vsSelected = new Set();
        updateSelectorBar();
        $("#item-selector-loading").show();
        $("#vs-viewport").hide();
        $("#vs-selection-bar").hide();
        $("#item-search").val("");
        $("#item-selector-modal").fadeIn(200);

        $.post("https://flake_shops/requestItems", JSON.stringify({}), function(items) {
            serverItems = items.filter(i => i && i.name && i.label);
            vsItems = serverItems;

            $("#item-selector-loading").hide();
            $("#vs-viewport").show();
            $("#vs-selection-bar").show();

            renderVirtualGrid(vsItems);
        });
    });

    // Search
    let vsSearchTimeout;
    $("#item-search").on("input", function() {
        clearTimeout(vsSearchTimeout);
        const term = this.value.toLowerCase().trim();
        vsSearchTimeout = setTimeout(function() {
            vsItems = term
                ? serverItems.filter(i =>
                    i.name.toLowerCase().includes(term) ||
                    i.label.toLowerCase().includes(term))
                : serverItems;

            const vp = document.getElementById("vs-viewport");
            if (vp) vp.scrollTop = 0;
            renderVirtualGrid(vsItems);
        }, 150);
    });

    // Confirm add
    $(document).on("click", "#vs-confirm-btn", function() {
        if (vsSelected.size === 0) return;
        const itemMap = {};
        serverItems.forEach(i => { itemMap[i.name] = i; });
        vsSelected.forEach(name => {
            const item = itemMap[name];
            if (item) addItemEntry(item.label, item.name, 100);
        });
        showNotification(`Added ${vsSelected.size} item${vsSelected.size !== 1 ? "s" : ""} to shop!`, "success");
        $("#item-selector-modal").fadeOut(200);
        vsSelected = new Set();
        updateSelectorBar();
    });

    // Clear selection
    $(document).on("click", "#vs-clear-btn", function() {
        vsSelected = new Set();
        document.querySelectorAll(".vs-card.selected").forEach(c => {
            c.classList.remove("selected");
            const chk = c.querySelector(".vs-check");
            if (chk) chk.classList.remove("checked");
        });
        updateSelectorBar();
    });

    // Close
    $("#close-item-selector").on("click", function() { $("#item-selector-modal").fadeOut(200); });

    // ── Misc ──────────────────────────────────────────────────
    function closeAdmin() {
        $("#admin-wrapper").fadeOut();
        $.post("https://flake_shops/closeAdmin", JSON.stringify({}));
    }

    document.addEventListener("keyup", function(event) {
        if (event.which === 27) {
            if ($("#shop-modal").is(":visible"))          { $("#shop-modal").fadeOut(200); }
            else if ($("#item-selector-modal").is(":visible")) { $("#item-selector-modal").fadeOut(200); }
            else if ($("#admin-wrapper").is(":visible"))  { closeAdmin(); }
        }
    });

    $("#admin-wrapper").on("click", function(e) {
        if (e.target === this) closeAdmin();
    });

    // ── Analytics dashboard cards (all shops overview) ────────
    function updateAnalyticsDisplay(analytics) {
        if (!analytics || !Array.isArray(analytics)) return;

        let totalRevenue = 0, totalTransactions = 0, totalCustomers = 0;
        analytics.forEach(function(row) {
            totalRevenue      += parseFloat(row.total_revenue)      || 0;
            totalTransactions += parseFloat(row.total_transactions) || 0;
            totalCustomers    += parseFloat(row.unique_customers)   || 0;
        });

        if ($("#total-revenue").length)      $("#total-revenue").text("$" + totalRevenue.toLocaleString());
        if ($("#total-transactions").length) $("#total-transactions").text(totalTransactions.toLocaleString());
        if ($("#total-customers").length)    $("#total-customers").text(totalCustomers.toLocaleString());

        const container = $("#analytics-cards");
        if (!container.length) return;
        container.empty();
        if (!analytics.length) {
            container.html('<p style="color:#6b7280;text-align:center;padding:20px;">No analytics data yet. Data is collected when players make purchases.</p>');
            return;
        }
        analytics.forEach(function(row) {
            container.append(`
                <div class="shop-analytics-card">
                    <div class="shop-analytics-header">
                        <h4>${row.shop_name || "Unknown"}</h4>
                    </div>
                    <div class="shop-analytics-stats">
                        <div><span class="stat-label">Revenue</span><span class="stat-value">$${(parseFloat(row.total_revenue)||0).toLocaleString()}</span></div>
                        <div><span class="stat-label">Transactions</span><span class="stat-value">${(parseFloat(row.total_transactions)||0).toLocaleString()}</span></div>
                        <div><span class="stat-label">Customers</span><span class="stat-value">${(parseFloat(row.unique_customers)||0).toLocaleString()}</span></div>
                    </div>
                    <div class="shop-analytics-footer">
                        <button class="action-btn analytics" data-shop-name="${row.shop_name}">
                            <i class="fas fa-chart-bar"></i> View Details
                        </button>
                    </div>
                </div>
            `);
        });
    }

    // ── Analytics detail modal (single shop) ──────────────────
    function showShopAnalyticsModal(analytics) {
        if (!analytics) return;

        let modal = $("#analytics-modal");
        if (!modal.length) {
            $("body").append(`
                <div id="analytics-modal" style="display:none;position:fixed;inset:0;background:rgba(0,0,0,0.85);z-index:99999;display:none;align-items:center;justify-content:center;">
                    <div class="analytics-modal-container" style="background:#1a1a1a;border:1px solid #2a2a2a;border-radius:12px;width:820px;max-width:90vw;max-height:85vh;display:flex;flex-direction:column;box-shadow:0 25px 80px rgba(0,0,0,0.8);">
                        <div style="display:flex;justify-content:space-between;align-items:center;padding:20px 24px;border-bottom:1px solid #2a2a2a;flex-shrink:0;">
                            <h2 id="analytics-modal-title" style="margin:0;color:#e5e7eb;font-size:16px;font-weight:600;font-family:'Inter','Segoe UI',sans-serif;letter-spacing:0.02em;">Shop Analytics</h2>
                            <button id="close-analytics-modal" style="background:#1f1f1f;border:1px solid #2a2a2a;border-radius:6px;color:#9ca3af;font-size:18px;cursor:pointer;line-height:1;padding:4px 10px;transition:all 0.15s;">&times;</button>
                        </div>
                        <div id="analytics-modal-body" style="padding:24px;overflow-y:auto;flex:1;"></div>
                    </div>
                </div>
            `);
            modal = $("#analytics-modal");
            $("body").on("click", "#close-analytics-modal", function() { modal.fadeOut(200); });
            modal.on("click", function(e) { if (e.target === this) modal.fadeOut(200); });
        }

        $("#analytics-modal-title").text("Analytics: " + analytics.shopName);

        const totalRevenue      = parseFloat(analytics.totalRevenue)      || 0;
        const totalTransactions = parseFloat(analytics.totalTransactions)  || 0;
        const uniqueCustomers   = parseFloat(analytics.uniqueCustomers)    || 0;
        const avgOrder          = totalTransactions > 0 ? (totalRevenue / totalTransactions).toFixed(0) : 0;

        const cardStyle = "background:#0d0d0d;border:1px solid #2a2a2a;border-radius:10px;padding:18px 16px;text-align:center;";
        const labelStyle = "color:#6b7280;font-size:11px;text-transform:uppercase;letter-spacing:.07em;margin-bottom:6px;font-family:'Inter','Segoe UI',sans-serif;";
        const valueStyle = "color:#e5e7eb;font-size:22px;font-weight:700;font-family:'Inter','Segoe UI',sans-serif;";
        const iconStyle  = "font-size:18px;margin-bottom:8px;";

        function buildTable(cols, rows, emptyMsg) {
            if (!rows || !rows.length) return `<p style="color:#6b7280;font-size:13px;font-family:'Inter','Segoe UI',sans-serif;">${emptyMsg}</p>`;
            return `<table style="width:100%;border-collapse:collapse;font-size:13px;font-family:'Inter','Segoe UI',sans-serif;">
                <thead><tr style="color:#6b7280;text-align:left;border-bottom:1px solid #2a2a2a;text-transform:uppercase;letter-spacing:0.05em;font-size:11px;">
                    ${cols.map(c => `<th style="padding:8px ${c.pl||'8px'} 8px 0;font-weight:500;">${c.label}</th>`).join('')}
                </tr></thead>
                <tbody>${rows.map(r => `<tr style="border-bottom:1px solid #1f1f1f;">${cols.map(c => `<td style="padding:9px ${c.pl||'8px'} 9px 0;color:${c.color||'#9ca3af'};">${r[c.key]}</td>`).join('')}</tr>`).join('')}</tbody>
            </table>`;
        }

        const topItemsData = (analytics.topItems||[]).map(i => ({
            item_label: i.item_label,
            total_sold: i.total_sold,
            total_revenue: "$" + (parseFloat(i.total_revenue)||0).toLocaleString()
        }));

        const recentData = (analytics.recentPurchases||[]).map(p => ({
            player_name: p.player_name,
            item_label: p.item_label,
            quantity: p.quantity,
            total_cost: "$" + (parseFloat(p.total_cost)||0).toLocaleString(),
            currency_type: p.currency_type
        }));

        const revenueData = (analytics.recentRevenue||[]).map(r => ({
            date: r.date,
            total_revenue: "$" + (parseFloat(r.total_revenue)||0).toLocaleString(),
            total_transactions: r.total_transactions
        }));

        $("#analytics-modal-body").html(`
            <div style="display:grid;grid-template-columns:repeat(4,1fr);gap:12px;margin-bottom:24px;">
                <div style="${cardStyle}">
                    <div style="${iconStyle}color:#10b981;"><i class="fas fa-dollar-sign"></i></div>
                    <div style="${labelStyle}">Total Revenue</div>
                    <div style="${valueStyle}">$${totalRevenue.toLocaleString()}</div>
                </div>
                <div style="${cardStyle}">
                    <div style="${iconStyle}color:#3b82f6;"><i class="fas fa-shopping-cart"></i></div>
                    <div style="${labelStyle}">Transactions</div>
                    <div style="${valueStyle}">${totalTransactions.toLocaleString()}</div>
                </div>
                <div style="${cardStyle}">
                    <div style="${iconStyle}color:#8b5cf6;"><i class="fas fa-users"></i></div>
                    <div style="${labelStyle}">Unique Customers</div>
                    <div style="${valueStyle}">${uniqueCustomers.toLocaleString()}</div>
                </div>
                <div style="${cardStyle}">
                    <div style="${iconStyle}color:#f59e0b;"><i class="fas fa-chart-line"></i></div>
                    <div style="${labelStyle}">Avg Order Value</div>
                    <div style="${valueStyle}">$${parseFloat(avgOrder).toLocaleString()}</div>
                </div>
            </div>

            <div style="margin-bottom:20px;">
                <h3 style="color:#e5e7eb;font-size:13px;font-weight:600;margin:0 0 12px;display:flex;align-items:center;gap:8px;font-family:'Inter','Segoe UI',sans-serif;letter-spacing:0.02em;text-transform:uppercase;">
                    <i class="fas fa-fire" style="color:#f59e0b;"></i> Top Selling Items
                </h3>
                ${buildTable(
                    [{label:"Item",key:"item_label",color:"#f9fafb",pl:"0"},{label:"Sold",key:"total_sold",color:"#10b981"},{label:"Revenue",key:"total_revenue",color:"#3b82f6"}],
                    topItemsData, "No item sales data yet."
                )}
            </div>

            <div style="margin-bottom:20px;">
                <h3 style="color:#e5e7eb;font-size:13px;font-weight:600;margin:0 0 12px;display:flex;align-items:center;gap:8px;font-family:'Inter','Segoe UI',sans-serif;letter-spacing:0.02em;text-transform:uppercase;">
                    <i class="fas fa-calendar" style="color:#3b82f6;"></i> Last 7 Days Revenue
                </h3>
                ${buildTable(
                    [{label:"Date",key:"date",color:"#f9fafb",pl:"0"},{label:"Revenue",key:"total_revenue",color:"#10b981"},{label:"Transactions",key:"total_transactions",color:"#3b82f6"}],
                    revenueData, "No revenue data in the last 7 days."
                )}
            </div>

            <div>
                <h3 style="color:#e5e7eb;font-size:13px;font-weight:600;margin:0 0 12px;display:flex;align-items:center;gap:8px;font-family:'Inter','Segoe UI',sans-serif;letter-spacing:0.02em;text-transform:uppercase;">
                    <i class="fas fa-clock" style="color:#10b981;"></i> Recent Purchases
                </h3>
                ${buildTable(
                    [{label:"Player",key:"player_name",color:"#f9fafb",pl:"0"},{label:"Item",key:"item_label",color:"#d1d5db"},{label:"Qty",key:"quantity",color:"#d1d5db"},{label:"Total",key:"total_cost",color:"#10b981"},{label:"Currency",key:"currency_type",color:"#9ca3af"}],
                    recentData, "No recent purchases."
                )}
            </div>
        `);

        modal.css("display", "flex").hide().fadeIn(200);
    }

});