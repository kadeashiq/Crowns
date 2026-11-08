// Runs Shared/Extraction/Preprocess.js against each fixture page in jsdom,
// checks the raw snapshot, and writes it to CrownsTests/Fixtures so the Swift
// interpreter tests run on exactly what the extractor produces.
//
//   cd Tools/extractor && npm install && npm test
import { JSDOM } from "jsdom";
import fs from "node:fs";
import path from "node:path";
import assert from "node:assert/strict";

const root = path.resolve(import.meta.dirname, "../..");
const script = fs.readFileSync(path.join(root, "Shared/Extraction/Preprocess.js"), "utf8");
const outDir = path.join(root, "CrownsTests/Fixtures");
fs.mkdirSync(outDir, { recursive: true });

const pages = {
  "ebay-uk": "https://www.ebay.co.uk/itm/325512345678?hash=item4bc&var=0",
  "ebay-us-no-jsonld": "https://www.ebay.com/itm/226600000001",
  shopify: "https://northerntime.example/products/tudor-black-bay-58-m79030n",
  "brand-site": "https://www.omegawatches.com/en-gb/watch-omega-seamaster-diver-300m-21030422003001",
};

function snapshot(name, url) {
  const html = fs.readFileSync(path.join(import.meta.dirname, "fixtures", name + ".html"), "utf8");
  const dom = new JSDOM(html, { url, runScripts: "outside-only" });
  dom.window.eval(script);
  // Exercise the Safari entry point, not just the inner function.
  let result;
  dom.window.eval("ExtensionPreprocessingJS").run({ completionFunction: (r) => (result = r) });
  assert.ok(result && typeof result.snapshot === "string", name + ": completionFunction got no snapshot");
  return JSON.parse(result.snapshot);
}

const checks = {
  "ebay-uk"(s) {
    assert.equal(s.jsonld.length, 1);
    assert.equal(s.jsonld[0].mpn, "126610LN");
    const specs = Object.fromEntries(s.specs);
    assert.equal(specs["Reference Number"], "126610LN");
    assert.equal(specs["Model"], "Submariner Date");
    assert.match(specs["Condition"], /^Pre-owned/);
    assert.doesNotMatch(specs["Condition"], /Read more/);
    assert.ok(s.priceTexts.includes("£12,950.00"));
    assert.ok(s.images.some((i) => i.src.endsWith("s-l1600.jpg")), "zoom image preferred");
    assert.ok(!s.images.some((i) => /logo/.test(i.src)), "logos dropped");
    assert.equal(s.canonical, "https://www.ebay.co.uk/itm/325512345678");
  },
  "ebay-us-no-jsonld"(s) {
    assert.equal(s.jsonld.length, 0);
    assert.equal(s.priceTexts[0], "US $4,250.00");
    assert.equal(Object.fromEntries(s.specs)["Reference Number"], "311.30.42.30.01.005");
  },
  shopify(s) {
    assert.equal(s.shopify.vendor, "Tudor");
    assert.equal(s.shopify.price, 315000);
    assert.equal(s.shopify.images[0], "https://northerntime.example/cdn/shop/files/bb58-front.jpg?v=1700000000");
    assert.equal(s.meta["og:price:amount"], "3,150.00");
    assert.equal(s.metaImages.length, 2);
    assert.equal(Object.fromEntries(s.specs)["Power reserve"], "70 hours");
    assert.ok(s.images[0].src.includes("width=1500"), "largest srcset entry");
  },
  "brand-site"(s) {
    assert.equal(s.jsonld.length, 0);
    assert.equal(s.shopify, null);
    assert.ok(s.priceTexts.includes("£5,900"));
    assert.ok(s.text.includes("210.30.42.20.03.001"));
    assert.equal(s.images[0].src, "https://www.omegawatches.com/media/catalog/product/o/m/omega-seamaster-diver-300m-21030422003001-l.png");
    assert.ok(!s.images.some((i) => i.src.endsWith(".svg")));
    assert.equal(Object.fromEntries(s.specs)["Case diameter"], "42 mm");
  },
};

let failed = 0;
for (const [name, url] of Object.entries(pages)) {
  try {
    const s = snapshot(name, url);
    assert.equal(s.errors, undefined, "extractor errors: " + JSON.stringify(s.errors));
    checks[name](s);
    fs.writeFileSync(path.join(outDir, name + ".snapshot.json"), JSON.stringify(s, null, 2) + "\n");
    console.log("ok   " + name);
  } catch (e) {
    failed++;
    console.log("FAIL " + name + "\n     " + e.message);
  }
}
process.exit(failed ? 1 : 0);
