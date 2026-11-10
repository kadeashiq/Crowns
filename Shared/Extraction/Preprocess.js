// Crowns page extractor.
//
// Runs in two places:
//   1. Safari share-sheet preprocessing (ExtensionPreprocessingJS below), which
//      reads the live page the user is looking at. This is how we see eBay and
//      other sites that block a plain fetch.
//   2. A hidden WKWebView, for shares that arrive as a bare URL (other apps)
//      and for links pasted inside the app.
//
// It only collects raw facts from the DOM and returns them as one JSON string.
// All interpretation (brand, reference, price parsing) happens in Swift, in
// ListingInterpreter, so both paths behave identically.

var CrownsExtractor = (function () {
  var MAX_TEXT = 8000;
  var MAX_IMAGES = 24;
  var MAX_SPECS = 80;

  function clean(s) {
    if (s === null || s === undefined) return "";
    return String(s).replace(/\s+/g, " ").trim();
  }

  function absolute(u) {
    if (!u) return "";
    u = String(u).trim();
    if (!u || u.indexOf("data:") === 0 || u.indexOf("blob:") === 0) return "";
    try {
      return new URL(u, document.baseURI).href;
    } catch (e) {
      return "";
    }
  }

  // Largest candidate from a srcset attribute.
  function bestFromSrcset(srcset) {
    if (!srcset) return "";
    var best = "";
    var bestW = -1;
    String(srcset)
      .split(",")
      .forEach(function (part) {
        var bits = part.trim().split(/\s+/);
        if (!bits[0]) return;
        var w = 1;
        if (bits[1]) {
          var n = parseFloat(bits[1]);
          if (!isNaN(n)) w = bits[1].indexOf("x") > -1 ? n * 1000 : n;
        }
        if (w > bestW) {
          bestW = w;
          best = bits[0];
        }
      });
    return best;
  }

  function meta() {
    var out = {};
    var images = [];
    var nodes = document.querySelectorAll("meta[property], meta[name], meta[itemprop]");
    for (var i = 0; i < nodes.length; i++) {
      var m = nodes[i];
      var key = (m.getAttribute("property") || m.getAttribute("name") || m.getAttribute("itemprop") || "").toLowerCase();
      var val = clean(m.getAttribute("content"));
      if (!key || !val) continue;
      if (key === "og:image" || key === "og:image:url" || key === "og:image:secure_url" || key === "twitter:image") {
        var abs = absolute(val);
        if (abs && images.indexOf(abs) === -1) images.push(abs);
      }
      if (!(key in out)) out[key] = val.slice(0, 600);
    }
    return { meta: out, images: images };
  }

  // Collect every node in the JSON-LD graph whose @type looks like a product.
  function jsonld() {
    var products = [];
    var scripts = document.querySelectorAll('script[type="application/ld+json"]');
    function isProduct(node) {
      var t = node["@type"];
      var types = Array.isArray(t) ? t : [t];
      for (var i = 0; i < types.length; i++) {
        var s = String(types[i] || "").toLowerCase();
        if (s === "product" || s === "productgroup" || s === "individualproduct" || s === "productmodel") return true;
      }
      return false;
    }
    function walk(node, depth) {
      if (!node || typeof node !== "object" || depth > 6 || products.length >= 6) return;
      if (Array.isArray(node)) {
        for (var i = 0; i < node.length; i++) walk(node[i], depth + 1);
        return;
      }
      if (isProduct(node)) {
        products.push(node);
        return;
      }
      if (node["@graph"]) walk(node["@graph"], depth + 1);
      if (node.mainEntity) walk(node.mainEntity, depth + 1);
      if (node.itemListElement) walk(node.itemListElement, depth + 1);
      if (node.item) walk(node.item, depth + 1);
    }
    for (var i = 0; i < scripts.length; i++) {
      var raw = scripts[i].textContent || "";
      if (raw.length > 400000) continue;
      raw = raw.replace(/^\s*<!--/, "").replace(/-->\s*$/, "").replace(/\/\*<!\[CDATA\[\*\//g, "").replace(/\/\*\]\]>\*\//g, "");
      var parsed = null;
      try {
        parsed = JSON.parse(raw);
      } catch (e) {
        try {
          // Common breakage: raw newlines/tabs inside strings, trailing commas.
          parsed = JSON.parse(raw.replace(/[\u0000-\u001F]+/g, " ").replace(/,\s*([}\]])/g, "$1"));
        } catch (e2) {
          parsed = null;
        }
      }
      if (parsed) walk(parsed, 0);
    }
    return products;
  }

  // Shopify themes embed the product as JSON. Recognise it by shape.
  function shopify() {
    var scripts = document.querySelectorAll('script[type="application/json"], script[data-product-json], script[id^="ProductJson"]');
    for (var i = 0; i < scripts.length; i++) {
      var raw = scripts[i].textContent || "";
      if (raw.length < 20 || raw.length > 500000) continue;
      if (raw.indexOf("variants") === -1 || raw.indexOf("vendor") === -1) continue;
      var obj = null;
      try {
        obj = JSON.parse(raw);
      } catch (e) {
        continue;
      }
      var p = obj && obj.product ? obj.product : obj;
      if (p && typeof p === "object" && p.vendor !== undefined && Array.isArray(p.variants)) {
        var images = [];
        (p.images || []).forEach(function (img) {
          var src = typeof img === "string" ? img : img && (img.src || img.url);
          var abs = absolute(src);
          if (abs) images.push(abs);
        });
        if (!images.length && p.featured_image) images.push(absolute(typeof p.featured_image === "string" ? p.featured_image : p.featured_image.src));
        var v = p.variants[0] || {};
        return {
          title: clean(p.title),
          vendor: clean(p.vendor),
          type: clean(p.type || p.product_type),
          price: typeof p.price === "number" ? p.price : typeof v.price === "number" ? v.price : null,
          priceString: typeof v.price === "string" ? v.price : typeof p.price === "string" ? p.price : null,
          sku: clean(v.sku),
          images: images.slice(0, MAX_IMAGES),
          description: clean(String(p.description || "").replace(/<[^>]+>/g, " ")).slice(0, 2000),
        };
      }
    }
    return null;
  }

  function microdata() {
    var out = {};
    ["price", "priceCurrency", "brand", "name", "model", "mpn", "sku"].forEach(function (prop) {
      var el = document.querySelector('[itemprop="' + prop + '"]');
      if (!el) return;
      var v = el.getAttribute("content") || el.getAttribute("value") || el.textContent;
      v = clean(v);
      if (v && v.length < 200) out[prop] = v;
    });
    return out;
  }

  // Words that mark text as a watch specification. Includes hidden text, so
  // specs inside closed dropdowns and tabs are found too.
  var SPEC_WORD = /\b(size|diameter|dimensions?|width|thickness|height|depth|lugs?|lug-to-lug|case|dial|bezel|crystal|glass|movement|calibre|caliber|winding|energy|power reserve|frequency|jewels?|components|water|waterproof\w*|strap|bracelet|band|clasp|buckle|material|colou?r|year|weight|lume|luminous|complications?|functions?|reference)\b/i;
  var MEASUREMENT = /\d\s?(mm|atm|bar|m\b|metres|meters|hours?|h\b|jewels)/i;

  function inChrome(el) {
    return !!el.closest("nav, footer");
  }

  // Help buttons and tooltips beside a label: "Jewels  Discover more…",
  // "Between lugs  Open Case Measurement Modal".
  var EXTRA = "button, [role=tooltip], [class*='tooltip' i], [class*='popover' i], [class*='sr-only' i], [class*='visually-hidden' i], [class*='screen-reader' i], [class~='hidden'], [class*='info-icon' i]";

  function isExtra(el) {
    return el.matches(EXTRA);
  }

  function textOf(el) {
    if (!el.querySelector(EXTRA)) return clean(el.textContent);
    var copy = el.cloneNode(true);
    copy.querySelectorAll(EXTRA).forEach(function (x) {
      x.remove();
    });
    return clean(copy.textContent);
  }

  function childCount(el) {
    var n = 0;
    for (var c = el.firstElementChild; c; c = c.nextElementSibling) if (!isExtra(c)) n++;
    return n;
  }

  function nextOf(el) {
    var n = el.nextElementSibling;
    while (n && isExtra(n)) n = n.nextElementSibling;
    return n;
  }

  // The heading a spec sits under: its tab, its accordion's button, a summary.
  function sectionOf(el) {
    var node = el.parentElement;
    for (var d = 0; node && node !== document.body && d < 10; d++, node = node.parentElement) {
      var id = node.getAttribute("aria-labelledby");
      if (id && node.getAttribute("role") === "tabpanel") {
        var tab = document.getElementById(id.split(" ")[0]);
        if (tab) return clean(tab.textContent);
      }
      if (node.tagName === "DETAILS") {
        var summary = node.querySelector("summary");
        if (summary) return clean(summary.textContent);
      }
      var prev = node.previousElementSibling;
      for (var k = 0; prev && k < 2; k++, prev = prev.previousElementSibling) {
        var name = typeof prev.className === "string" ? prev.className : "";
        if (/^(H[1-6]|BUTTON|SUMMARY|LEGEND)$/.test(prev.tagName) || /title|heading|header/i.test(name)) {
          var t = clean(prev.textContent);
          if (t && t.length <= 40) return t;
        }
      }
    }
    return "";
  }

  // Labelled values run together: "Type of lug: Curved edges, Lug width: 21mm"
  // or "Stainless steel Diameter: 39 mm Thickness: 9.3mm". A label starts at
  // its last capitalised word, or is all capitals. Returns the text before the
  // first label, and the pairs.
  function splitPairs(text) {
    var re = /(^|[,;|]\s*|\s)((?:[A-Za-z][A-Za-z\-]*)(?: [A-Za-z\-]+){0,3})\s*[:：]\s*/g;
    var marks = [];
    var m;
    while ((m = re.exec(text))) {
      var words = m[2].split(" ");
      var from = 0;
      if (m[2] !== m[2].toUpperCase()) {
        for (var w = words.length - 1; w >= 0; w--) {
          if (/^[A-Z]/.test(words[w])) {
            from = w;
            break;
          }
        }
      }
      var label = words.slice(from).join(" ");
      var start = m.index + m[1].length + m[2].length - label.length;
      marks.push({ label: label, start: start, end: re.lastIndex });
    }
    var out = [];
    for (var i = 0; i < marks.length; i++) {
      var value = text.slice(marks[i].end, i + 1 < marks.length ? marks[i + 1].start : text.length).replace(/[,;|\s]+$/, "");
      if (value) out.push([marks[i].label, value]);
    }
    return { lead: marks.length ? text.slice(0, marks[0].start).replace(/[,;|\s]+$/, "") : text, pairs: out };
  }

  // A label where a value should be, or help text behind an info button.
  var NOT_A_VALUE = /^(thickness|diameter|case|dial|movement|power reserve|jewels|water resistance|lug width|(discover|learn|find out|read) more\b.*)$/i;

  function specs() {
    var pairs = [];
    var seen = {};
    function add(label, value, inner, el) {
      label = clean(label).replace(/[:：]\s*$/, "");
      // The same words mean different things under different headings.
      if (el && label) {
        var section = sectionOf(el);
        if (/calib|movement|mouvement/i.test(section) && !/calib|movement/i.test(label)) {
          if (/^(reference|ref\.?|name|number|model)$/i.test(label)) label = "Calibre";
          else if (/^(diameter|thickness|height|dimensions?)$/i.test(label)) label = "Movement " + label.toLowerCase();
        } else if (/strap|bracelet|band|buckle|clasp/i.test(section) && /^(type of )?(material|colou?r)$/i.test(label)) {
          label = "Bracelet " + label.replace(/^type of /i, "").toLowerCase();
        }
      }
      value = clean(value)
        .replace(/\s*Read more.*$/i, "")
        .replace(/\s*See all condition definitions.*$/i, "")
        .replace(/\s*opens in a new window or tab.*$/i, "");
      // A value holding labelled values of its own gives each its own pair.
      if (!inner && /[:：]/.test(value)) {
        var split = splitPairs(value);
        var specPairs = split.pairs.filter(function (p) {
          return SPEC_WORD.test(p[0]);
        });
        if (specPairs.length) {
          specPairs.forEach(function (p) {
            add(p[0], p[1], true, el);
          });
          value = split.lead;
        }
      }
      if (!label || !value || label.length > 48 || value.length > 160 || NOT_A_VALUE.test(value)) return;
      if (label.toLowerCase() === value.toLowerCase()) return;
      var key = label.toLowerCase();
      if (seen[key]) return;
      seen[key] = true;
      if (pairs.length < MAX_SPECS) pairs.push([label, value]);
    }
    // eBay item specifics (both current and older layouts).
    var ebay = document.querySelectorAll(".ux-labels-values");
    for (var i = 0; i < ebay.length; i++) {
      var l = ebay[i].querySelector(".ux-labels-values__labels");
      var v = ebay[i].querySelector(".ux-labels-values__values");
      if (l && v) add(l.textContent, v.textContent);
    }
    // Definition lists.
    var dts = document.querySelectorAll("dl dt");
    for (var j = 0; j < dts.length; j++) {
      var dd = dts[j].nextElementSibling;
      while (dd && dd.tagName !== "DD" && dd.tagName !== "DT") dd = dd.nextElementSibling;
      if (dd && dd.tagName === "DD") add(textOf(dts[j]), textOf(dd), false, dts[j]);
    }
    // Two-cell table rows.
    var rows = document.querySelectorAll("table tr");
    for (var k = 0; k < rows.length && k < 400; k++) {
      var cells = rows[k].querySelectorAll("th, td");
      if (cells.length === 2) add(textOf(cells[0]), textOf(cells[1]), false, rows[k]);
    }
    // Options chosen on the page, such as the strap.
    var selects = document.querySelectorAll("select");
    for (var s = 0; s < selects.length && s < 20; s++) {
      var select = selects[s];
      var option = select.options[select.selectedIndex];
      var name = (select.labels && select.labels[0] && select.labels[0].textContent) || select.getAttribute("aria-label") || "";
      if (option && option.value && SPEC_WORD.test(name) && !inChrome(select)) add(name, option.textContent);
    }
    var radios = document.querySelectorAll("input[type=radio]:checked");
    for (var r = 0; r < radios.length && r < 20; r++) {
      var radio = radios[r];
      var legend = radio.closest("fieldset") && radio.closest("fieldset").querySelector("legend");
      var group = legend ? legend.textContent : "";
      var choice = (radio.labels && radio.labels[0] && radio.labels[0].textContent) || radio.value;
      if (SPEC_WORD.test(group) && !inChrome(radio)) add(group, choice);
    }
    // Any other markup: a label beside its value, or "Label: value".
    var nodes = document.querySelectorAll("li, p, div, span, strong, b, h2, h3, h4, h5, h6, label");
    for (var n = 0; n < nodes.length && n < 8000; n++) {
      var el = nodes[n];
      if (isExtra(el) || el.closest(EXTRA) || childCount(el) > 1) continue;
      var text = textOf(el);
      if (!text || text.length > 170) continue;
      if (/[:：]/.test(text)) {
        var inline = splitPairs(text).pairs.filter(function (p) {
          return SPEC_WORD.test(p[0]);
        });
        if (inline.length) {
          if (!inChrome(el))
            inline.forEach(function (p) {
              add(p[0], p[1], false, el);
            });
          continue;
        }
      }
      if (childCount(el) || text.length > 40 || !SPEC_WORD.test(text) || /[.!?]$/.test(text)) continue;
      var next = nextOf(el);
      var holder = el.parentElement;
      if (!next && holder && childCount(holder) === 1) next = nextOf(holder);
      var value = next ? textOf(next) : "";
      if (!next && holder && textOf(holder).indexOf(text) === 0) value = textOf(holder).slice(text.length);
      if (!value || inChrome(el)) continue;
      // Two labels in a row: the "value" is really the next label.
      if (next && el.className && next.tagName === el.tagName && next.className === el.className) continue;
      add(text, value, false, el);
    }
    return pairs;
  }

  // Short lines stating a measurement, for specs written as sentences.
  function specLines() {
    var out = [];
    var nodes = document.querySelectorAll("li, p, dd, td, div, span");
    for (var i = 0; i < nodes.length && i < 8000 && out.length < 60; i++) {
      var el = nodes[i];
      if (el.children.length > 2) continue;
      var t = clean(el.textContent);
      if (t.length < 8 || t.length > 220 || !MEASUREMENT.test(t) || !SPEC_WORD.test(t) || inChrome(el)) continue;
      if (out.indexOf(t) === -1) out.push(t);
    }
    return out;
  }

  // Short lines naming a calibre ("Jaeger-LeCoultre Caliber 925"), from the
  // page's own content: menus advertise other calibres.
  function calibres() {
    var out = [];
    var nodes = document.querySelectorAll("h1, h2, h3, h4, h5, h6, p, li, dd, td, span, strong, div");
    for (var i = 0; i < nodes.length && i < 8000 && out.length < 12; i++) {
      var el = nodes[i];
      if (el.children.length > 2) continue;
      var t = clean(el.textContent);
      if (t.length < 6 || t.length > 90 || !/\b(calibre|caliber|cal\.|movement)\s*[A-Z]{0,4}[ \-]?\d/i.test(t)) continue;
      if (inChrome(el) || region(el) === "skip" || el.closest("[class*='mega-menu' i], [class*='megamenu' i], [role=navigation], [role=menu]")) continue;
      if (out.indexOf(t) === -1) out.push(t);
    }
    return out;
  }

  var CURRENCY_HINT = /[£$€¥]|\b(GBP|USD|EUR|CHF|JPY|AUD|CAD|HKD|SGD)\b/;

  function priceTexts() {
    var out = [];
    var selectors = [
      ".x-price-primary",
      '[itemprop="price"]',
      "[data-testid*='price' i]",
      "[data-price]",
      ".price__current",
      ".product__price",
      ".price-item--sale",
      ".price-item--regular",
      ".price",
      "[class*='price' i]",
    ];
    for (var s = 0; s < selectors.length && out.length < 12; s++) {
      var nodes;
      try {
        nodes = document.querySelectorAll(selectors[s]);
      } catch (e) {
        continue;
      }
      for (var i = 0; i < nodes.length && out.length < 12; i++) {
        var el = nodes[i];
        // A crossed-out price is what it used to cost.
        if (el.closest("s, del, strike, [class*='compare' i], [class*='was-price' i], [class*='old-price' i], [class*='line-through' i]")) continue;
        var t = clean(el.getAttribute("content") || el.textContent);
        if (!t || t.length > 60 || !/\d/.test(t)) continue;
        if (!CURRENCY_HINT.test(t) && !el.getAttribute("content")) continue;
        if (out.indexOf(t) === -1) out.push(t);
      }
    }
    // Nothing marked as a price: a line that is only an amount, outside
    // menus and other products, such as Tudor's "£4,160".
    if (!out.length) {
      var leaves = document.querySelectorAll("span, p, div, strong");
      for (var k = 0; k < leaves.length && k < 6000 && out.length < 3; k++) {
        var leaf = leaves[k];
        if (leaf.children.length) continue;
        var amount = clean(leaf.textContent);
        if (!/^(£|\$|€|CHF|GBP|USD|EUR)\s?\d[\d,.'’ ]*$/.test(amount)) continue;
        if (inChrome(leaf) || region(leaf) === "skip" || leaf.closest("s, del, strike")) continue;
        if (out.indexOf(amount) === -1) out.push(amount);
      }
    }
    return out;
  }

  var JUNK_IMAGE = /(logo|icon|sprite|badge|avatar|flag|payment|placeholder|spinner|loader|pixel|tracking|1x1|blank\.)/i;
  // Parts of a product page that show other things: other products, press,
  // reviews, pop-ups, colour choices.
  var NOT_PRODUCT = /(recommend|related|upsell|cross-?sell|also-?like|you-?may|recently|similar|complete-the-look|product-?tile|product-?card|press|review|testimonial|instagram|swatch|payment|newsletter|modal|popup)/i;
  // The product's own photos.
  var GALLERY = /(gallery|carousel|slider|swiper|slick|zoom|product-?media|product__media|product-?image|product-?photo|pdp-?image|primary-image|thumbnails?)/i;
  var IMAGE_FILE = /\.(jpe?g|png|webp|avif|heic)(\?|#|$)/i;

  // "gallery", "page", or "skip" for an image, from the blocks it sits in.
  function region(img) {
    var gallery = false;
    var el = img.parentElement;
    for (var depth = 0; el && el !== document.body && depth < 14; depth++, el = el.parentElement) {
      var tag = el.tagName;
      if (tag === "NAV" || tag === "DIALOG") return "skip";
      // The site's header and footer, not a product header inside the page.
      if ((tag === "HEADER" || tag === "FOOTER") && !el.closest("main, article")) return "skip";
      if (el.getAttribute("role") === "dialog" || el.getAttribute("aria-modal") === "true") return "skip";
      var name = (typeof el.className === "string" ? el.className : "") + " " + (el.id || "");
      if (NOT_PRODUCT.test(name)) return "skip";
      if (GALLERY.test(name)) gallery = true;
    }
    return gallery ? "gallery" : "page";
  }

  // The full-size image a thumbnail links to, "" for a plain image, or null
  // when it links to another page (another product, an article).
  function linkedImage(img) {
    var a = img.closest("a[href]");
    if (!a) return "";
    var href = a.getAttribute("href") || "";
    if (!href || href.charAt(0) === "#" || /^javascript:/i.test(href)) return "";
    var abs = absolute(href);
    if (!abs) return "";
    if (IMAGE_FILE.test(abs) || /\/dw\/image\//.test(abs)) return abs;
    return abs.split("#")[0] === document.URL.split("#")[0] ? "" : null;
  }

  // The product's photos first, in the order the page shows them, then any
  // other large images, biggest first.
  function images() {
    var found = {};
    var gallery = [];
    var rest = [];
    function add(src, w, h, alt, inGallery) {
      var abs = absolute(src);
      if (!abs || /\.svg(\?|$)/i.test(abs) || JUNK_IMAGE.test(abs)) return;
      if (w && h && (w < 200 || h < 200)) return;
      if (found[abs]) {
        var existing = found[abs];
        existing.w = Math.max(existing.w, w || 0);
        existing.h = Math.max(existing.h, h || 0);
        return;
      }
      var item = { src: abs, w: w || 0, h: h || 0, alt: clean(alt).slice(0, 120) };
      if (inGallery) item.g = true;
      found[abs] = item;
      (inGallery ? gallery : rest).push(item);
    }
    var imgs = document.querySelectorAll("img");
    for (var i = 0; i < imgs.length && i < 600; i++) {
      var img = imgs[i];
      var where = region(img);
      var linked = linkedImage(img);
      if (where === "skip" || linked === null) continue;
      var w = img.naturalWidth || parseInt(img.getAttribute("width"), 10) || 0;
      var h = img.naturalHeight || parseInt(img.getAttribute("height"), 10) || 0;
      var alt = img.getAttribute("alt") || "";
      var zoom = img.getAttribute("data-zoom-src") || img.getAttribute("data-zoom-image") || img.getAttribute("data-zoom") || img.getAttribute("data-large_image");
      var srcset = bestFromSrcset(img.getAttribute("srcset") || img.getAttribute("data-srcset"));
      var src = zoom || linked || srcset || img.getAttribute("data-src") || img.currentSrc || img.getAttribute("src");
      // A thumbnail that opens a larger image stands for that image, whatever its own size.
      if (zoom || linked) {
        w = 0;
        h = 0;
      }
      add(src, w, h, alt, where === "gallery");
    }
    var sources = document.querySelectorAll("picture source[srcset]");
    for (var j = 0; j < sources.length && j < 200; j++) {
      if (region(sources[j]) !== "skip") add(bestFromSrcset(sources[j].getAttribute("srcset")), 0, 0, "", false);
    }
    rest.sort(function (a, b) {
      return b.w * b.h - a.w * a.h;
    });
    return gallery.concat(rest).slice(0, MAX_IMAGES);
  }

  function pageText() {
    var root = document.querySelector("main, [role=main], #mainContent, #MainContent, article") || document.body;
    if (!root) return "";
    var t = root.innerText || root.textContent || "";
    if (t.length < 400 && document.body && root !== document.body) t = document.body.innerText || document.body.textContent || t;
    return clean(t).slice(0, MAX_TEXT);
  }

  function canonical() {
    var link = document.querySelector('link[rel="canonical"]');
    return link ? absolute(link.getAttribute("href")) : "";
  }

  // What each dropdown showed while it was open. Some sites close one when
  // the next opens and drop what it showed.
  var gathered = { specs: [], specLines: [], calibres: [] };

  function gather() {
    try {
      gathered.specs = gathered.specs.concat(specs());
      gathered.specLines = gathered.specLines.concat(specLines());
      gathered.calibres = gathered.calibres.concat(calibres());
    } catch (e) {}
  }

  // Adds what the dropdowns showed to what the page shows now, keeping the
  // first value for each label.
  function withGathered(now, extra, key) {
    var out = now.slice();
    var seen = {};
    now.forEach(function (item) {
      seen[key(item)] = true;
    });
    extra.forEach(function (item) {
      var k = key(item);
      if (!seen[k]) {
        seen[k] = true;
        out.push(item);
      }
    });
    return out;
  }

  // Opens the page's spec dropdowns, which some sites only fill in once
  // opened, one at a time so each has a moment to render, then calls done.
  var SPEC_SECTION = /(spec|technical|detail|feature|characteristic|movement|calib|caliber|case|dial|strap|bracelet|dimension|information|watch)/i;
  function expand(done) {
    var details = document.querySelectorAll("details:not([open])");
    for (var i = 0; i < details.length && i < 20; i++) {
      if (!details[i].closest("nav, header, footer")) details[i].open = true;
    }
    var targets = [];
    var toggles = document.querySelectorAll("[aria-expanded='false']");
    for (var j = 0; j < toggles.length && targets.length < 12; j++) {
      var t = toggles[j];
      if (t.closest("nav, header, footer, form, [role=dialog], [role=menu], [role=navigation], [class*='mega-menu' i], [class*='cookie' i], [id*='cookie' i], [class*='consent' i]")) continue;
      var label = clean(t.textContent);
      if (label && label.length <= 40 && SPEC_SECTION.test(label)) targets.push(t);
    }
    var next = 0;
    (function openNext() {
      if (next >= targets.length) {
        setTimeout(function () {
          done(targets.length);
        }, targets.length ? 600 : 0);
        return;
      }
      try {
        if (targets[next].getAttribute("aria-expanded") === "false") targets[next].click();
      } catch (e) {}
      next++;
      setTimeout(function () {
        gather();
        openNext();
      }, 250);
    })();
  }

  function snapshot() {
    var out = { v: 1, url: document.URL, title: clean(document.title), lang: document.documentElement.getAttribute("lang") || "" };
    function attempt(key, fn) {
      try {
        out[key] = fn();
      } catch (e) {
        out.errors = (out.errors || []).concat(key + ": " + String(e));
      }
    }
    attempt("canonical", canonical);
    attempt("h1", function () {
      var h = document.querySelector("h1");
      if (!h) return "";
      // A heading's lines run together in textContent. The name is its first
      // lines, up to one that lists details ("Oyster, 41 mm, Oystersteel").
      var lines = String(h.innerText || "").split(/\n+/).map(clean).filter(Boolean);
      var name = [];
      for (var i = 0; i < lines.length && !/\d\s?mm\b|,/.test(lines[i]); i++) name.push(lines[i]);
      return (name.length ? name.join(" ") : clean(h.textContent)).slice(0, 300);
    });
    attempt("meta", function () {
      var m = meta();
      out.metaImages = m.images;
      return m.meta;
    });
    attempt("jsonld", jsonld);
    attempt("shopify", shopify);
    attempt("microdata", microdata);
    attempt("specs", function () {
      return withGathered(specs(), gathered.specs, function (p) {
        return p[0].toLowerCase();
      });
    });
    attempt("specLines", function () {
      return withGathered(specLines(), gathered.specLines, String).slice(0, 80);
    });
    attempt("calibres", function () {
      return withGathered(calibres(), gathered.calibres, String).slice(0, 12);
    });
    attempt("priceTexts", priceTexts);
    attempt("images", images);
    attempt("text", pageText);
    return JSON.stringify(out);
  }

  return { snapshot: snapshot, expand: expand };
})();

// Safari share-sheet entry point. Must be a top-level var with this name.
var ExtensionPreprocessingJS = {
  run: function (args) {
    function finish() {
      var result;
      try {
        result = CrownsExtractor.snapshot();
      } catch (e) {
        result = JSON.stringify({ v: 1, url: document.URL, title: document.title, errors: [String(e)] });
      }
      args.completionFunction({ snapshot: result });
    }
    try {
      CrownsExtractor.expand(finish);
    } catch (e) {
      finish();
    }
  },
  finalize: function (args) {},
};
