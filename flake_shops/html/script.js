$(function() {


    function calculateTotal(t, a) {
        let total = 0;
        const textareas = document.getElementsByClassName("textareas");

        for (let i = 0; i < textareas.length; i++) {
            const value = parseInt(textareas[i].value);
            if (!isNaN(value) && value !== 0 && textareas[i].value !== "") {
                const price = parseInt($("#" + textareas[i].id).attr("price")) || 0;
                total += (price * value);
            }
        }

        if (t && a) {
            total -= t * a;
        }

        $(".total").html('TOTAL: <span class="price">$' + total + "</span>");
    }

    let itemCount = 0;
    let shopData  = null; // store "data" from event for re-use

    // Listen for NUI messages from client.lua
    window.addEventListener("message", function(event) {
        const data = event.data;
        if (data.type === "shop") {
            shopData = data;
            $("#wrapper, #menuwrap, #bg").fadeIn();
            $("#shopname").html(data.name);
            // Use custom logo if provided, otherwise default to blackmarket.png
            const logoImage = data.shopLogo || "blackmarket.png";
            // Support URLs or local files
            let logoSrc = '';
            if (logoImage.startsWith('http://') || logoImage.startsWith('https://')) {
                logoSrc = logoImage;
            } else {
                logoSrc = 'img/' + logoImage;
            }
            $("#menuwrap").prepend('<div class="logo"><img src="' + logoSrc + '" height="80px" onerror="this.src=\'img/blackmarket.png\'" /></div>');

            const baseUrl = data.imageBaseUrl;
            const SHOP_RESULT = data.result || [];
            let s = 750;

            if (SHOP_RESULT.length > 10) {
                s += Math.ceil((SHOP_RESULT.length - 10) / 5) * 375;
            }

            $("#itembox").empty();

            SHOP_RESULT.forEach((item, index) => {
                if (item && item.label && item.item) {
                    $("#itembox").append(`
                        <div class="image"
                             id="${item.item}"
                             label="${item.label}"
                             price="${item.price}">
                            <div class="itemimg">
                                <img src="nui://${baseUrl}/${item.item}.png" width="120px"/>
                            </div>
                            <div class="textwrap">
                                <h3 class="h4">${item.label}</h3>
                                <h4 class="price">$${item.price} ${item.currencyLabel || data.currencyLabel || ""}</h4>
                            </div>
                        </div>
                    `);
                }
            });

            if ($("#itembox").html()) {
                $("#status").html('<span style="color:#00FF00">OPEN</span>');
            } else {
                $("#status").html('<span style="color:#FF0000">CLOSED</span>');
            }

            // Clicking an item to add it to the cart
            $(".image").on("click", function() {
                const $this     = $(this);
                $("#cart").load(location.href + " #cart");
                $(".carticon").fadeIn();
                itemCount += 1;

                const itemId    = $this.attr("id");
                const itemLabel = $this.attr("label");
                const itemPrice = $this.attr("price");

                $("#cartCount").html(itemCount + " ITEMS");
                $this.hide();

                $.post("https://flake_shops/putcart", JSON.stringify({
                    item:  itemId,
                    price: itemPrice,
                    label: itemLabel,
                    id:    s
                }), function(cartData) {
                    $("#cart").html('<div id="cart_inner"></div>');

                    cartData.forEach((cartItem) => {
                        $("#cart_inner").append(`
                            <div class="cartitem"
                                 item="${cartItem.item}"
                                 price="${cartItem.price}">
                                <span class="remove" item="${cartItem.item}">
                                  <img src="img/delete.png" height="16px"/>
                                </span>
                                <h4 class="cartlabel">${cartItem.label} -
                                    <span class="priceperitem">$${cartItem.price}</span>
                                </h4>
                                <div class="quantity">
                                  <input type="text"
                                         id="${cartItem.item}"
                                         class="textareas"
                                         placeholder=""
                                         price="${cartItem.price}"
                                         value="1"/>
                                </div>
                            </div>
                        `);
                    });

                    // Payment buttons for each currency
                    const paymentButtons = data.currencies.map(currency => {
                        return `
                            <button class="purchase"
                                    id="buybutton"
                                    data-method="${currency.name}">
                                Pay with ${currency.label}
                            </button>
                        `;
                    }).join('');

                    $("#cart").append(`
                        <div id="buy">
                            <div class="total"></div>
                            ${paymentButtons}
                        </div>
                    `);

                    $("#cart_inner").children(":last").hide().slideDown();

                    // Remove item from cart
                    $(".remove").on("click", function() {
                        const itemToRemove  = $(this).attr("item");
                        const itemPrice     = $(".cartitem[item=" + itemToRemove + "]").attr("price");
                        const itemQuantity  = $(".textareas#" + itemToRemove).val();

                        if (itemCount > 0) {
                            itemCount -= 1;
                        }

                        $("#cartCount").html(itemCount + " ITEMS");
                        $("#" + itemToRemove).show();

                        $(".cartitem[item=" + itemToRemove + "]").slideUp(200, function() {
                            calculateTotal(itemPrice, itemQuantity);
                            $(this).remove();
                            $.post("https://flake_shops/removecart", JSON.stringify({
                                item: itemToRemove
                            }));
                        });
                    });

                    calculateTotal();
                });
            });

            // Back button logic (if you have one, e.g. <button id="back">)
            $("body").on("click", "#back", function() {
                $("#cart").fadeOut();
                $("#wrapper").fadeIn();
                $(".carticon").fadeIn();
                $("#bg").fadeIn();
            });

            // The "Pay" button => single server call with the entire cart
            $("body").on("click", "#buybutton", function() {
                const paymentMethod = $(this).data("method");
                const shopName      = data.name;
                const textareas     = document.getElementsByClassName("textareas");

                let cartItems      = [];
                let allItemsValid  = true;

                for (let i = 0; i < textareas.length; i++) {
                    const value = parseInt(textareas[i].value);
                    if (value > 0 && !isNaN(value)) {
                        const itemId    = textareas[i].id;
                        const itemPrice = parseInt($("#" + itemId).attr("price")) || 0;
                        const itemLabel = $(`.cartitem[item="${itemId}"] .cartlabel`).text() || "Unknown";

                        cartItems.push({
                            item:  itemId,
                            count: value,
                            price: itemPrice,
                            label: itemLabel
                        });
                    } else {
                        allItemsValid = false;
                    }
                }

                if (!allItemsValid) {
                    $.post("https://flake_shops/notify", JSON.stringify({
                        msg: "One of the items does not have enough stock or the amount is invalid."
                    }));
                    return;
                }

                // Close the UI and send the entire cart to server
                $.post("https://flake_shops/escape", JSON.stringify({}));
                location.reload(true);
                $("#wrapper").fadeOut();
                $("#payment").fadeOut();
                $("#cart").fadeOut();

                $.post("https://flake_shops/buyCart", JSON.stringify({
                    Zone:      shopName,
                    payMethod: paymentMethod,
                    Cart:      cartItems
                }));
            });
        }
    });

    // Recalc total if quantity changes
    $("body").on("keyup", ".textareas", function() {
        calculateTotal();
    });

    // Live search
    $("#search").on("input", function() {
        const searchFor = $(this).val().toLowerCase();
        $(".image").each(function() {
            const label = $(this).attr("label");
            if (label && label.toLowerCase().indexOf(searchFor) < 0) {
                $(this).hide();
            } else {
                $(this).show();
            }
        });
    });

    // ESC key => close everything - use addEventListener to avoid conflicts
    document.addEventListener('keyup', function(event) {
        if (event.which === 27 && $("#wrapper").is(":visible")) {
            $.post("https://flake_shops/escape", JSON.stringify({}));
            location.reload(true);
            $.post("https://flake_shops/emptycart", JSON.stringify({}));
            $("#wrapper, #menuwrap, #bg, #payment, #cart").fadeOut();
        }
    });
});
