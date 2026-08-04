const sharp = require("sharp");
const fs = require("fs");

async function run() {
  const src = "assets/images/ereta-cropped-display.png";
  const out = "assets/images/ereta-cropped-display.webp";

  const before = fs.statSync(src).size;

  const buf = await sharp(src)
    .resize({ width: 800, withoutEnlargement: true })
    .webp({ quality: 82 })
    .toBuffer();

  fs.writeFileSync(out, buf);
  const after = buf.length;
  console.log(`before: ${(before / 1024).toFixed(0)}KB -> after: ${(after / 1024).toFixed(0)}KB (${Math.round((1 - after / before) * 100)}% smaller)`);
}

run().catch((e) => {
  console.error(e);
  process.exit(1);
});
