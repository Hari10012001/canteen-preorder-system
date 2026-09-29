/* =========================================================
   KIOT Canteen Pre-Order System - Frontend (vanilla JS)
   ========================================================= */
(function () {
  'use strict';

  /* ---------------- state ---------------- */
  var CATEGORIES = ['All', 'Rice', 'Biryani', 'Noodles', 'Parotta', 'Dosa', 'Idli', 'Tiffin'];

  var state = {
    token: localStorage.getItem('kiot_token') || null,
    user: null,
    foods: [],
    cart: loadCart(),
    category: 'All',
    search: '',
    currentFood: null,
    pickup: { date: null, slot: null },
    payment: 'UPI',
    lastOrder: null,
    slots: [],
    maxAdvanceDays: 7
  };

  function loadCart() {
    try {
      var raw = localStorage.getItem('kiot_cart');
      var parsed = raw ? JSON.parse(raw) : [];
      return Array.isArray(parsed) ? parsed : [];
    } catch (e) { return []; }
  }
  function saveCart() {
    localStorage.setItem('kiot_cart', JSON.stringify(state.cart));
  }

  /* ---------------- dom helpers ---------------- */
  function $(sel) { return document.querySelector(sel); }
  function $all(sel) { return Array.prototype.slice.call(document.querySelectorAll(sel)); }

  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function inr(n) { return '₹' + Number(n || 0).toFixed(2); }
  function money(n) { return Number(n || 0).toFixed(2); }

  /* ---------------- api ---------------- */
  function api(path, options) {
    options = options || {};
    var headers = { 'Content-Type': 'application/json' };
    if (state.token) { headers['X-Auth-Token'] = state.token; }
    return fetch(path, {
      method: options.method || 'GET',
      headers: headers,
      body: options.body ? JSON.stringify(options.body) : undefined
    }).then(function (res) {
      if (res.status === 204) { return null; }
      var ct = res.headers.get('content-type') || '';
      if (ct.indexOf('application/json') === -1) {
        if (!res.ok) { throw new Error('Request failed (' + res.status + ')'); }
        return res;
      }
      return res.json().then(function (data) {
        if (!res.ok) { throw new Error(data && data.message ? data.message : 'Request failed (' + res.status + ')'); }
        return data;
      });
    });
  }

  /* ---------------- toast ---------------- */
  function toast(message, kind) {
    var wrap = $('#toast-wrap');
    var el = document.createElement('div');
    el.className = 'toast ' + (kind === 'err' ? 'err' : 'ok');
    el.textContent = message;
    wrap.appendChild(el);
    setTimeout(function () {
      el.style.transition = 'opacity .25s ease, transform .25s ease';
      el.style.opacity = '0';
      el.style.transform = 'translateX(20px)';
      setTimeout(function () { el.remove(); }, 260);
    }, 2600);
  }

  /* ---------------- cart ops ---------------- */
  function cartCount() {
    return state.cart.reduce(function (n, i) { return n + i.quantity; }, 0);
  }
  function cartTotal() {
    return state.cart.reduce(function (n, i) { return n + i.price * i.quantity; }, 0);
  }
  function inCart(id) {
    for (var i = 0; i < state.cart.length; i++) {
      if (state.cart[i].id === id) { return state.cart[i]; }
    }
    return null;
  }
  function addToCart(food, qty) {
    qty = qty || 1;
    if (!food.available) { toast('This item is currently unavailable', 'err'); return; }
    var line = inCart(food.id);
    if (line) { line.quantity += qty; }
    else {
      state.cart.push({
        id: food.id, name: food.name, price: Number(food.price),
        imageUrl: food.imageUrl, veg: food.veg, quantity: qty
      });
    }
    saveCart();
    updateCartBadge();
    toast(food.name + ' added to cart');
  }
  function setQty(id, qty) {
    var line = inCart(id);
    if (!line) { return; }
    if (qty <= 0) { removeLine(id); return; }
    line.quantity = qty;
    saveCart();
    updateCartBadge();
  }
  function removeLine(id) {
    state.cart = state.cart.filter(function (i) { return i.id !== id; });
    saveCart();
    updateCartBadge();
  }
  function clearCart() {
    state.cart = [];
    saveCart();
    updateCartBadge();
  }
  function updateCartBadge() {
    var badge = $('#cart-count');
    var n = cartCount();
    badge.textContent = n > 99 ? '99+' : String(n);
    badge.hidden = n === 0;
  }

  /* ---------------- shared markup ---------------- */
  function thumbHtml(food, cls) {
    var label = esc(food.name);
    var img = food.imageUrl
      ? '<img src="' + esc(food.imageUrl) + '" alt="' + label + '" loading="lazy" onerror="this.style.display=\'none\'">'
      : '';
    return '<div class="' + cls + '"><span class="thumb-fallback" aria-hidden="true">' + label + '</span>' + img + '</div>';
  }

  function stepperHtml(food) {
    var line = inCart(food.id);
    if (!food.available) {
      return '<button class="btn btn-ghost btn-sm" disabled>Unavailable</button>';
    }
    if (!line) {
      return '<button class="btn btn-primary btn-sm" data-action="add" data-id="' + food.id + '">Add</button>';
    }
    return '<span class="stepper">' +
      '<button data-action="dec" data-id="' + food.id + '" aria-label="Decrease quantity">&minus;</button>' +
      '<span class="qty">' + line.quantity + '</span>' +
      '<button data-action="inc" data-id="' + food.id + '" aria-label="Increase quantity">+</button>' +
      '</span>';
  }

  function foodCardHtml(food) {
    var cls = 'food-card' + (food.available ? '' : ' unavailable');
    return '<article class="' + cls + '" data-food="' + food.id + '">' +
      thumbHtml(food, 'thumb') +
      '<div class="food-body">' +
        '<div class="food-top"><h3 class="food-name">' + esc(food.name) + '</h3></div>' +
        '<p class="food-desc">' + esc(food.description || '') + '</p>' +
        '<div class="food-meta">' +
          '<span class="tag ' + (food.veg ? 'tag-veg' : 'tag-nonveg') + '">' + (food.veg ? 'VEG' : 'NON-VEG') + '</span>' +
          '<span class="tag tag-cat">' + esc(food.category) + '</span>' +
          '<span>' + food.prepTimeMins + ' min</span>' +
        '</div>' +
        '<div class="food-foot">' +
          '<div class="price">' + inr(food.price) + '<small>per plate</small></div>' +
          stepperHtml(food) +
        '</div>' +
      '</div>' +
    '</article>';
  }

  function filteredFoods() {
    var q = state.search.trim().toLowerCase();
    return state.foods.filter(function (f) {
      if (state.category !== 'All' && f.category.toLowerCase() !== state.category.toLowerCase()) { return false; }
      if (!q) { return true; }
      return (f.name + ' ' + (f.description || '')).toLowerCase().indexOf(q) !== -1;
    });
  }

  function statusPill(status) {
    return '<span class="pill-status pill-' + status.toLowerCase() + '">' + esc(status) + '</span>';
  }

  /* ---------------- views ---------------- */
  function show(view) {
    $all('.screen').forEach(function (s) {
      if (s.id === 'view-login') { return; }
      s.hidden = s.getAttribute('data-view') !== view;
    });
    $all('[data-nav]').forEach(function (a) {
      a.classList.toggle('active', a.getAttribute('data-nav') === view);
    });
    if (view === 'menu') { renderMenu(); }
    if (view === 'home') { renderHome(); }
    if (view === 'details') { renderDetails(state.currentFoodId); }
    if (view === 'cart') { renderCart(); }
    if (view === 'pickup') { renderPickup(); }
    if (view === 'payment') { renderPayment(); }
    if (view === 'orders') { loadOrders(); }
    window.scrollTo({ top: 0, behavior: 'auto' });
  }

  function renderHome() {
    var grid = $('#home-popular');
    var featured = state.foods.filter(function (f) { return f.available; }).slice(0, 4);
    grid.innerHTML = featured.length
      ? featured.map(foodCardHtml).join('')
      : '<div class="empty"><strong>Menu unavailable</strong><p class="muted">Please refresh.</p></div>';

    var cats = $('#home-categories');
    cats.innerHTML = state.foods.length
      ? CATEGORIES.slice(1).map(function (c) {
          var n = state.foods.filter(function (f) { return f.category === c; }).length;
          return '<button class="cat-card" data-cat="' + esc(c) + '">' +
            '<span class="cat-icon">' + esc(c.slice(0, 2).toUpperCase()) + '</span>' +
            '<span><strong>' + esc(c) + '</strong><em>' + n + ' items</em></span>' +
          '</button>';
        }).join('')
      : '';
  }

  function renderMenu() {
    var list = filteredFoods();
    $('#menu-grid').innerHTML = list.map(foodCardHtml).join('');
    $('#menu-empty').hidden = list.length > 0;

    var chips = $('#category-chips');
    if (!chips.dataset.built) {
      chips.innerHTML = CATEGORIES.map(function (c) {
        return '<button class="chip" data-cat="' + esc(c) + '">' + esc(c) + '</button>';
      }).join('');
      chips.dataset.built = '1';
    }
    $all('#category-chips .chip').forEach(function (c) {
      c.classList.toggle('active', c.getAttribute('data-cat') === state.category);
    });
  }

  function renderDetails(id) {
    var food = null;
    for (var i = 0; i < state.foods.length; i++) { if (state.foods[i].id === id) { food = state.foods[i]; } }
    if (!food) { toast('Item not found', 'err'); go('menu'); return; }
    state.currentFood = food;

    var line = inCart(food.id);
    $('#detail-card').innerHTML =
      '<div class="detail-hero"><span class="thumb-fallback" aria-hidden="true">' + esc(food.name) + '</span>' +
        (food.imageUrl ? '<img src="' + esc(food.imageUrl) + '" alt="' + esc(food.name) + '" onerror="this.style.display=\'none\'">' : '') +
      '</div>' +
      '<div class="detail-body">' +
        '<div class="detail-head">' +
          '<div><h2>' + esc(food.name) + '</h2>' +
            '<div class="detail-sub">' +
              '<span class="tag ' + (food.veg ? 'tag-veg' : 'tag-nonveg') + '">' + (food.veg ? 'VEGETARIAN' : 'NON-VEGETARIAN') + '</span>' +
              '<span class="tag tag-cat">' + esc(food.category) + '</span>' +
              (food.available ? '' : '<span class="tag tag-out">SOLD OUT</span>') +
            '</div>' +
          '</div>' +
          '<div class="detail-price">' + inr(food.price) + '</div>' +
        '</div>' +
        '<div class="info-row">' +
          '<span class="info-pill">Prep time <strong>' + food.prepTimeMins + ' mins</strong></span>' +
          '<span class="info-pill">Category <strong>' + esc(food.category) + '</strong></span>' +
          '<span class="info-pill">Pickup <strong>Today or later</strong></span>' +
        '</div>' +
        '<p class="detail-desc">' + esc(food.description || '') + '</p>' +
        '<div class="detail-actions">' +
          '<div class="stepper-lg">' +
            '<span class="stepper">' +
              '<button data-action="dec" data-id="' + food.id + '" aria-label="Decrease">−</button>' +
              '<span class="qty" id="detail-qty">' + (line ? line.quantity : 0) + '</span>' +
              '<button data-action="inc" data-id="' + food.id + '" aria-label="Increase">+</button>' +
            '</span>' +
          '</div>' +
          '<button class="btn btn-primary btn-lg" data-action="add-detail" data-id="' + food.id + '" ' + (food.available ? '' : 'disabled') + '>' +
            (food.available ? 'Add to cart' : 'Unavailable') +
          '</button>' +
          (line ? '<button class="btn btn-ghost btn-lg" data-nav="cart">View cart (' + line.quantity + ')</button>' : '') +
        '</div>' +
      '</div>';
  }

  function renderCart() {
    var box = $('#cart-body');
    if (!state.cart.length) {
      box.innerHTML = '<div class="card empty"><strong>Your cart is empty</strong>' +
        '<p class="muted">Browse the menu and add your favourite tiffin items.</p>' +
        '<div style="margin-top:18px"><a class="btn btn-primary" data-nav="menu">Browse menu</a></div></div>';
      return;
    }

    var rows = state.cart.map(function (i) {
      return '<div class="cart-row">' +
        thumbHtml(i, 'cart-thumb') +
        '<div class="cart-info"><strong>' + esc(i.name) + '</strong><em>' + inr(i.price) + ' each</em></div>' +
        '<div class="cart-actions">' +
          '<span class="stepper">' +
            '<button data-action="dec" data-id="' + i.id + '" aria-label="Decrease">−</button>' +
            '<span class="qty">' + i.quantity + '</span>' +
            '<button data-action="inc" data-id="' + i.id + '" aria-label="Increase">+</button>' +
          '</span>' +
          '<span class="cart-line">' + inr(i.price * i.quantity) + '</span>' +
          '<button class="cart-remove" data-action="remove" data-id="' + i.id + '" aria-label="Remove item">' +
            '<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M3 6h18M8 6V4h8v2M19 6l-1 14H6L5 6"/></svg>' +
          '</button>' +
        '</div>' +
      '</div>';
    }).join('');

    box.innerHTML = '<div class="cart-layout">' +
      '<div class="card cart-list">' + rows + '</div>' +
      '<div class="card summary">' +
        '<h3>Order summary</h3>' +
        '<div class="sum-row"><span>' + cartCount() + ' item' + (cartCount() === 1 ? '' : 's') + '</span><strong>' + inr(cartTotal()) + '</strong></div>' +
        '<div class="sum-row"><span>Canteen charges</span><strong>Included</strong></div>' +
        '<div class="sum-row"><span>Pickup</span><strong>Free</strong></div>' +
        '<div class="sum-total"><span>Total</span><span>' + inr(cartTotal()) + '</span></div>' +
        '<p class="sum-note">No delivery charge &mdash; this is a pre-order pickup at the campus canteen.</p>' +
        '<button class="btn btn-primary btn-block btn-lg" data-action="to-pickup">Choose pickup time</button>' +
      '</div>' +
    '</div>';
  }

  function dateLabel(iso) {
    var d = new Date(iso + 'T00:00:00');
    return {
      dow: d.toLocaleDateString('en-GB', { weekday: 'short' }),
      day: d.getDate(),
      mon: d.toLocaleDateString('en-GB', { month: 'short' }),
      full: d.toLocaleDateString('en-GB', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' })
    };
  }

  function renderPickup() {
    if (!state.cart.length) { go('cart'); return; }

    var today = new Date();
    var dates = [];
    for (var i = 0; i < Math.min(state.maxAdvanceDays, 7) + 1; i++) {
      var d = new Date(today);
      d.setDate(today.getDate() + i);
      dates.push(d);
    }

    var dateHtml = dates.map(function (d) {
      var iso = d.toISOString().slice(0, 10);
      var l = dateLabel(iso);
      var active = state.pickup.date === iso;
      return '<button class="date-opt' + (active ? ' active' : '') + '" data-date="' + iso + '">' +
        '<strong>' + l.day + ' ' + l.mon + '</strong><em>' + l.dow + '</em></button>';
    }).join('');

    var slotHtml = state.slots.map(function (s) {
      var active = state.pickup.slot === s;
      return '<button class="slot-opt' + (active ? ' active' : '') + '" data-slot="' + esc(s) + '">' + esc(s) + '</button>';
    }).join('');

    $('#pickup-card').innerHTML =
      '<label class="form-label">Select pickup date</label>' +
      '<div class="date-grid">' + dateHtml + '</div>' +
      '<label class="form-label">Select pickup time slot</label>' +
      '<div class="slot-grid">' + slotHtml + '</div>' +
      (state.pickup.date && state.pickup.slot ? '' : '<p class="form-error-inline">Please select both a date and a time slot to continue.</p>') +
      '<div class="sum-total" style="margin-top:22px"><span>Order total</span><span>' + inr(cartTotal()) + '</span></div>' +
      '<button class="btn btn-primary btn-block btn-lg" style="margin-top:16px" data-action="to-payment"' +
        (state.pickup.date && state.pickup.slot ? '' : ' disabled') + '>Proceed to payment</button>';
  }

  function renderPayment() {
    if (!state.cart.length || !state.pickup.date || !state.pickup.slot) { go('pickup'); return; }

    var methods = [
      { id: 'UPI', name: 'UPI', desc: 'Pay instantly via any UPI app', status: 'PAID' },
      { id: 'CARD', name: 'Card', desc: 'Debit or credit card (demo)', status: 'PAID' },
      { id: 'CASH', name: 'Cash at counter', desc: 'Pay when you collect your order', status: 'PENDING' }
    ];

    var icons = {
      UPI: '<path d="M4 8h16M4 12h10M4 16h7"/><rect x="2.5" y="4.5" width="19" height="15" rx="2.5"/>',
      CARD: '<rect x="2.5" y="5" width="19" height="14" rx="2.5"/><path d="M2.5 10h19"/>',
      CASH: '<rect x="2.5" y="6" width="19" height="12" rx="2.5"/><circle cx="12" cy="12" r="2.6"/>'
    };

    var opts = methods.map(function (m) {
      return '<button class="pay-opt' + (state.payment === m.id ? ' active' : '') + '" data-pay="' + m.id + '">' +
        '<span class="pay-ico"><svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">' + icons[m.id] + '</svg></span>' +
        '<span class="pay-txt"><strong>' + esc(m.name) + '</strong><em>' + esc(m.desc) + '</em></span>' +
        '<span class="pay-radio"></span>' +
      '</button>';
    }).join('');

    var d = dateLabel(state.pickup.date);
    $('#payment-body').innerHTML = '<div class="pay-layout">' +
      '<div class="card pay-methods">' +
        '<h3>Choose a payment method</h3>' + opts +
        '<div class="demo-notice">' +
          '<svg viewBox="0 0 24 24" width="17" height="17" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="12" cy="12" r="9.5"/><path d="M12 8h.01M11 12h1v4h1"/></svg>' +
          '<span><strong>Demo payment.</strong> This is a prototype. No banking details are collected and no real transaction is processed. UPI and Card are marked <strong>PAID</strong>; Cash at counter is marked <strong>PENDING</strong>.</span>' +
        '</div>' +
      '</div>' +
      '<div class="card summary">' +
        '<h3>Order summary</h3>' +
        '<div class="info-list">' +
          state.cart.map(function (i) {
            return '<div><span>' + esc(i.name) + ' &times; ' + i.quantity + '</span><dd>' + inr(i.price * i.quantity) + '</dd></div>';
          }).join('') +
        '</div>' +
        '<div class="sum-total"><span>Total</span><span>' + inr(cartTotal()) + '</span></div>' +
        '<div class="info-list" style="margin-top:14px">' +
          '<div><dt>Pickup date</dt><dd>' + esc(d.full) + '</dd></div>' +
          '<div><dt>Pickup slot</dt><dd>' + esc(state.pickup.slot) + '</dd></div>' +
          '<div><dt>Method</dt><dd>' + esc(state.payment) + '</dd></div>' +
        '</div>' +
        '<button class="btn btn-accent btn-block btn-lg" style="margin-top:16px" data-action="place-order" id="place-order-btn">' +
          'Pay ' + inr(cartTotal()) + ' &amp; place order</button>' +
      '</div>' +
    '</div>';
  }

  function renderConfirmation(order) {
    var d = dateLabel(order.pickupDate);
    var paid = order.paymentStatus === 'PAID';
    var chips = order.items.map(function (i) {
      return '<span class="item-chip">' + esc(i.name) + ' <strong>&times;' + i.quantity + '</strong></span>';
    }).join('');

    $('#confirmation-body').innerHTML = '<div class="confirm-wrap">' +
      '<div class="card confirm-banner">' +
        '<div class="confirm-check"><svg viewBox="0 0 24 24" width="30" height="30" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6L9 17l-5-5"/></svg></div>' +
        '<h2>Order confirmed</h2>' +
        '<p>Your pre-order is placed. Show the QR code at the canteen counter to collect.</p>' +
        '<div class="order-code">' + esc(order.orderCode) + '</div>' +
        '<div class="order-pills" style="justify-content:center;margin-top:14px">' +
          statusPill(order.orderStatus) +
          '<span class="pill-status ' + (paid ? 'pill-paid' : 'pill-pending') + '">Payment: ' + esc(order.paymentStatus) + '</span>' +
        '</div>' +
      '</div>' +
      '<div class="confirm-grid">' +
        '<div class="card order-panel">' +
          '<h3>Pickup details</h3>' +
          '<div class="info-list">' +
            '<div><dt>Student</dt><dd>' + esc(order.user.name) + '</dd></div>' +
            '<div><dt>Student ID</dt><dd>' + esc(order.user.studentId || '—') + '</dd></div>' +
            '<div><dt>Pickup date</dt><dd>' + esc(d.full) + '</dd></div>' +
            '<div><dt>Pickup slot</dt><dd>' + esc(order.pickupSlot) + '</dd></div>' +
            '<div><dt>Payment method</dt><dd>' + esc(order.paymentMethod) + '</dd></div>' +
            '<div><dt>Items</dt><dd>' + order.itemCount + '</dd></div>' +
            '<div><dt>Total paid</dt><dd>' + inr(order.totalAmount) + '</dd></div>' +
          '</div>' +
          '<div class="item-chips" style="margin-top:14px">' + chips + '</div>' +
        '</div>' +
        '<div class="card qr-panel">' +
          '<h3 style="margin-bottom:14px">Pickup QR</h3>' +
          '<div class="qr-frame"><img id="confirm-qr-img" alt="Pickup QR code for ' + esc(order.orderCode) + '"></div>' +
          '<p class="qr-hint"><strong>Scan at the counter</strong>Contains order ID, student ID, pickup time and status.</p>' +
        '</div>' +
      '</div>' +
      '<div class="confirm-actions">' +
        '<button class="btn btn-primary btn-lg" data-nav="orders">View my orders</button>' +
        '<a class="btn btn-ghost btn-lg" href="#menu" data-nav="menu">Order something else</a>' +
      '</div>' +
    '</div>';

    attachQr($('#confirm-qr-img'), order.id);
  }

  function orderCardHtml(o) {
    var paid = o.paymentStatus === 'PAID';
    var items = o.items.map(function (i) {
      return '<div class="order-item-row"><span><b>' + esc(i.name) + '</b> &times; ' + i.quantity + '</span>' +
             '<span>' + inr(i.lineTotal) + '</span></div>';
    }).join('');

    return '<article class="card order-card">' +
      '<div class="order-card-head">' +
        '<div><div class="order-code-sm">' + esc(o.orderCode) + '</div>' +
          '<div class="order-date">Placed ' + new Date(o.createdAt).toLocaleString('en-GB', { dateStyle: 'medium', timeStyle: 'short' }) + '</div></div>' +
        '<div class="order-pills">' + statusPill(o.orderStatus) +
          '<span class="pill-status ' + (paid ? 'pill-paid' : 'pill-pending') + '">' + esc(o.paymentStatus) + '</span></div>' +
      '</div>' +
      '<div class="order-card-body">' +
        '<div class="order-items">' + items + '</div>' +
        '<div class="order-foot">' +
          '<div><div class="muted small">Pickup: ' + esc(dateLabel(o.pickupDate).full) + ' &middot; ' + esc(o.pickupSlot) + '</div>' +
            '<div class="order-total">' + inr(o.totalAmount) + '</div></div>' +
          '<div class="order-foot-actions">' +
            '<span class="muted small" style="align-self:center">' + esc(o.paymentMethod) + '</span>' +
            '<button class="btn btn-ghost btn-sm" data-qr="' + o.id + '" data-code="' + esc(o.orderCode) + '">View QR</button>' +
          '</div>' +
        '</div>' +
      '</div>' +
    '</article>';
  }

  function loadOrders() {
    var box = $('#orders-body');
    box.innerHTML = '<div class="food-grid">' +
      '<div class="skeleton sk-card"></div><div class="skeleton sk-card"></div></div>';
    api('/api/orders/my')
      .then(function (orders) {
        if (!orders.length) {
          box.innerHTML = '<div class="card empty"><strong>No orders yet</strong>' +
            '<p class="muted">Your pre-orders will appear here once you place your first order.</p>' +
            '<div style="margin-top:18px"><a class="btn btn-primary" data-nav="menu">Browse menu</a></div></div>';
          return;
        }
        box.innerHTML = orders.map(orderCardHtml).join('');
      })
      .catch(function (e) {
        box.innerHTML = '<div class="card empty"><strong>Could not load orders</strong><p class="muted">' + esc(e.message) + '</p></div>';
      });
  }

  /* ---------------- QR ----------------
     The QR endpoint requires the X-Auth-Token header, which a plain <img src>
     cannot send. So fetch it with auth and hand the <img> a blob URL. */
  var qrUrls = {};

  function loadQrUrl(orderId) {
    if (qrUrls[orderId]) { return Promise.resolve(qrUrls[orderId]); }
    return fetch('/api/orders/' + orderId + '/qr', { headers: { 'X-Auth-Token': state.token } })
      .then(function (res) {
        if (!res.ok) { throw new Error('QR unavailable (' + res.status + ')'); }
        return res.blob();
      })
      .then(function (blob) {
        qrUrls[orderId] = URL.createObjectURL(blob);
        return qrUrls[orderId];
      });
  }

  function attachQr(imgEl, orderId) {
    if (!imgEl) { return; }
    loadQrUrl(orderId)
      .then(function (url) { imgEl.src = url; })
      .catch(function () {
        imgEl.alt = 'QR code unavailable';
        imgEl.removeAttribute('src');
      });
  }

  function openQr(orderId, code) {
    var modal = $('#qr-modal');
    var img = $('#qr-modal-img');
    img.removeAttribute('src');
    $('#qr-modal-title').textContent = 'QR · ' + code;
    $('#qr-modal-sub').textContent = 'Show this at the canteen counter to collect your order.';
    modal.hidden = false;
    attachQr(img, orderId);
  }

  /* ---------------- actions ---------------- */
  function placeOrder() {
    var btn = $('#place-order-btn');
    if (btn) { btn.disabled = true; btn.textContent = 'Placing order…'; }

    var payload = {
      items: state.cart.map(function (i) { return { foodItemId: i.id, quantity: i.quantity }; }),
      pickupDate: state.pickup.date,
      pickupSlot: state.pickup.slot,
      paymentMethod: state.payment
    };

    api('/api/orders', { method: 'POST', body: payload })
      .then(function (order) {
        state.lastOrder = order;
        clearCart();
        state.pickup = { date: null, slot: null };
        renderConfirmation(order);
        go('confirmation');
        toast('Order ' + order.orderCode + ' confirmed');
      })
      .catch(function (e) {
        toast(e.message, 'err');
        if (btn) { btn.disabled = false; btn.textContent = 'Retry'; }
      });
  }

  /* ---------------- navigation ---------------- */
  function go(view) {
    if (location.hash !== '#' + view) {
      location.hash = view;
      return; // hashchange handler takes over
    }
    show(view);
  }

  function onHashChange() {
    if (!state.user) { return; }
    var view = (location.hash || '#home').slice(1);
    var known = ['home', 'menu', 'details', 'cart', 'pickup', 'payment', 'confirmation', 'orders'];
    if (known.indexOf(view) === -1) { view = 'home'; }
    show(view);
  }

  function setLoggedIn(user) {
    state.user = user;
    $('#user-name').textContent = user.name;
    $('#user-id').textContent = user.studentId || user.email;
    $('#user-initials').textContent = (user.name || 'S').trim().charAt(0).toUpperCase();
    $('#user-chip').title = user.email;
    $('#app-shell').hidden = false;
    $('#view-login').hidden = true;
    updateCartBadge();
  }

  function logout() {
    api('/api/auth/logout', { method: 'POST' }).catch(function () { /* best effort */ });
    state.token = null;
    state.user = null;
    state.lastOrder = null;
    Object.keys(qrUrls).forEach(function (k) { URL.revokeObjectURL(qrUrls[k]); });
    qrUrls = {};
    localStorage.removeItem('kiot_token');
    $('#app-shell').hidden = true;
    $('#view-login').hidden = false;
    $('#login-password').value = '';
    location.hash = '';
  }

  /* ---------------- boot ---------------- */
  function loadFoods() {
    return api('/api/foods').then(function (foods) {
      state.foods = foods;
    });
  }

  function loadConfig() {
    return api('/api/foods/pickup-config').then(function (cfg) {
      state.slots = cfg.slots || [];
      state.maxAdvanceDays = cfg.maxAdvanceDays || 7;
    });
  }

  function boot() {
    if (!state.token) { return; }
    Promise.all([api('/api/auth/me'), loadFoods(), loadConfig()])
      .then(function (res) {
        setLoggedIn(res[0]);
        if (!location.hash || location.hash === '#') { location.hash = 'home'; }
        show(onHashView());
      })
      .catch(function () { logout(); });
  }

  function onHashView() {
    var v = (location.hash || '#home').slice(1);
    var known = ['home', 'menu', 'details', 'cart', 'pickup', 'payment', 'confirmation', 'orders'];
    return known.indexOf(v) === -1 ? 'home' : v;
  }

  /* ---------------- events ---------------- */
  document.addEventListener('DOMContentLoaded', function () {

    // login
    $('#login-form').addEventListener('submit', function (e) {
      e.preventDefault();
      var email = $('#login-email').value.trim();
      var password = $('#login-password').value;
      var err = $('#login-error');
      var btn = $('#login-submit');
      err.hidden = true;

      if (!email || !password) { err.textContent = 'Enter both email and password'; err.hidden = false; return; }
      btn.disabled = true; btn.textContent = 'Signing in…';

      api('/api/auth/login', { method: 'POST', body: { email: email, password: password } })
        .then(function (res) {
          state.token = res.token;
          localStorage.setItem('kiot_token', res.token);
          return Promise.all([res.user, loadFoods(), loadConfig()]);
        })
        .then(function (res) {
          setLoggedIn(res[0]);
          $('#login-password').value = '';
          location.hash = 'home';
          show('home');
        })
        .catch(function (e2) {
          err.textContent = e2.message || 'Login failed';
          err.hidden = false;
        })
        .then(function () {
          btn.disabled = false; btn.textContent = 'Sign in';
        });
    });

    // demo account shortcuts
    $all('.demo-row').forEach(function (b) {
      b.addEventListener('click', function () {
        $('#login-email').value = b.getAttribute('data-email');
        $('#login-password').value = b.getAttribute('data-pass');
        $('#login-form').dispatchEvent(new Event('submit', { cancelable: true }));
      });
    });

    // search
    var searchTimer;
    $('#menu-search').addEventListener('input', function (e) {
      clearTimeout(searchTimer);
      searchTimer = setTimeout(function () {
        state.search = e.target.value;
        renderMenu();
      }, 160);
    });

    // delegated clicks
    document.addEventListener('click', function (e) {
      var el;

      if ((el = e.target.closest('[data-nav]'))) {
        e.preventDefault();
        go(el.getAttribute('data-nav'));
        return;
      }

      if ((el = e.target.closest('[data-action]'))) {
        var action = el.getAttribute('data-action');
        var id = parseInt(el.getAttribute('data-id'), 10);

        if (action === 'add' || action === 'add-detail') {
          var food = null;
          for (var i = 0; i < state.foods.length; i++) { if (state.foods[i].id === id) { food = state.foods[i]; } }
          if (food) {
            addToCart(food, 1);
            if (action === 'add-detail') {
              var q = $('#detail-qty'); if (q) { q.textContent = inCart(id).quantity; }
            } else {
              renderMenu();
            }
          }
        }
        if (action === 'inc') {
          var l1 = inCart(id); if (l1) { setQty(id, l1.quantity + 1); refreshQuantities(id); }
        }
        if (action === 'dec') {
          var l2 = inCart(id); if (l2) { setQty(id, l2.quantity - 1); refreshQuantities(id); }
        }
        if (action === 'remove') {
          removeLine(id);
          if (location.hash === '#cart') { renderCart(); } else { refreshQuantities(id); }
        }
        if (action === 'to-pickup') { go('pickup'); }
        if (action === 'to-payment') { go('payment'); }
        if (action === 'place-order') { placeOrder(); }
        return;
      }

      if ((el = e.target.closest('[data-cat]'))) {
        state.category = el.getAttribute('data-cat');
        location.hash = 'menu';
        show('menu');
        return;
      }

      if ((el = e.target.closest('[data-pay]'))) {
        state.payment = el.getAttribute('data-pay');
        renderPayment();
        return;
      }

      if ((el = e.target.closest('[data-date]'))) {
        state.pickup.date = el.getAttribute('data-date');
        renderPickup();
        return;
      }

      if ((el = e.target.closest('[data-slot]'))) {
        state.pickup.slot = el.getAttribute('data-slot');
        renderPickup();
        return;
      }

      if ((el = e.target.closest('[data-qr]'))) {
        openQr(el.getAttribute('data-qr'), el.getAttribute('data-code'));
        return;
      }

      if (e.target.closest('#cart-btn')) { go('cart'); return; }
      if (e.target.closest('#logout-btn')) { logout(); return; }
      if (e.target.closest('[data-close-modal]')) { $('#qr-modal').hidden = true; return; }

      // food card -> details
      var card = e.target.closest('.food-card');
      if (card && !e.target.closest('button')) {
        state.currentFoodId = parseInt(card.getAttribute('data-food'), 10);
        go('details');
      }
    });

    window.addEventListener('hashchange', onHashChange);
    document.addEventListener('keydown', function (e) {
      if (e.key === 'Escape') { $('#qr-modal').hidden = true; }
    });

    boot();
  });

  function refreshQuantities(id) {
    var line = inCart(id);
    var view = onHashView();
    if (view === 'menu' || view === 'home') { renderMenu(); renderHome(); }
    if (view === 'details') { renderDetails(id); }
    if (view === 'cart') { renderCart(); }
  }

})();
