const subsetFont = require("subset-font");
const fs = require("fs");

const characters = "时间之外我给你一个久久地望着孤月的人的悲哀";

async function run() {
  const lxgw = fs.readFileSync("assets/fonts/LXGWWenKai-Regular.ttf");
  const lxgwSubset = await subsetFont(lxgw, {
    text: characters,
    targetFormat: "truetype",
  });
  fs.writeFileSync("assets/fonts/LXGWWenKai-subset.ttf", lxgwSubset);
  console.log("LXGWWenKai subset:", (lxgwSubset.length / 1024).toFixed(1) + "KB");

  const noto = fs.readFileSync("assets/fonts/NotoSerifSC-VF.ttf");
  const notoSubset = await subsetFont(noto, {
    text: characters,
    targetFormat: "truetype",
  });
  fs.writeFileSync("assets/fonts/NotoSerifSC-subset.ttf", notoSubset);
  console.log("NotoSerifSC subset:", (notoSubset.length / 1024).toFixed(1) + "KB");
}

run().catch((e) => {
  console.error(e);
  process.exit(1);
});
