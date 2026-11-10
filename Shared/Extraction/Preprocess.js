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
  var SPEC_WORD = /\b(size|diameter|width|thickness|height|depth|lug|lug-to-lug|case|dial|bezel|crystal|glass|movement|calibre|caliber|winding|power reserve|jewels?|water|strap|bracelet|band|clasp|material|colou?r|year|weight|lume|luminous|complications?|functions?)\b/i;
  var MEASUREMENT = /\d\s?(mm|atm|bar|m\b|metres|meters|hours?|h\b|jewels)/i;

  function inChrome(el) {
    return !!el.closest("nav, footer");
  }

  function specs() {
    var pairs = [];
    var seen = {};
    function add(label, value) {
      label = clean(label).replace(/[:：]\s*$/, "");
      value = clean(value)
        .replace(/\s*Read more.*$/i, "")
        .replace(/\s*See all condition definitions.*$/i, "")
        .replace(/\s*opens in a new window or tab.*$/i, "");
      if (!label || !value || label.length > 48 || value.length > 160) return;
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
      if (dd && dd.tagName === "DD") add(dts[j].textContent, dd.textContent);
    }
    // Two-cell table rows.
    var rows = document.querySelectorAll("table tr");
    for (var k = 0; k < rows.length && k < 400; k++) {
      var cells = rows[k].querySelectorAll("th, td");
      if (cells.length === 2) add(cells[0].textContent, cells[1].textContent);
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
      if (el.children.length > 1) continue;
      var text = clean(el.textContent);
      if (!text || text.length > 170) continue;
      var inline = text.match(/^([^:：]{2,40})[:：]\s*(.{1,120})$/);
      if (inline && SPEC_WORD.test(inline[1])) {
        if (!inChrome(el)) add(inline[1], inline[2]);
        continue;
      }
      if (el.children.length || text.length > 40 || !SPEC_WORD.test(text) || /[.!?]$/.test(text)) continue;
      var next = el.nextElementSibling;
      var holder = el.parentElement;
      if (!next && holder && holder.children.length === 1) next = holder.nextElementSibling;
      var value = next ? clean(next.textContent) : "";
      if (!next && holder && clean(holder.textContent).indexOf(text) === 0) value = clean(holder.textContent).slice(text.length);
      if (!value || inChrome(el)) continue;
      // Two labels in a row: the "value" is really the next label.
      if (next && el.className && next.tagName === el.tagName && next.className === el.className) continue;
      add(text, value);
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
      return h ? clean(h.textContent).slice(0, 300) : "";
    });
    attempt("meta", function () {
      var m = meta();
      out.metaImages = m.images;
      return m.meta;
    });
    attempt("jsonld", jsonld);
    attempt("shopify", shopify);
    attempt("microdata", microdata);
    attempt("specs", specs);
    attempt("specLines", specLines);
    attempt("priceTexts", priceTexts);
    attempt("images", images);
    attempt("text", pageText);
    return JSON.stringify(out);
  }

  return { snapshot: snapshot };
})();

// Safari share-sheet entry point. Must be a top-level var with this name.
var ExtensionPreprocessingJS = {
  run: function (args) {
    var result;
    try {
      result = CrownsExtractor.snapshot();
    } catch (e) {
      result = JSON.stringify({ v: 1, url: document.URL, title: document.title, errors: [String(e)] });
    }
    args.completionFunction({ snapshot: result });
  },
  finalize: function (args) {},
};
