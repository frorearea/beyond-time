import fs from "node:fs";
import {
  NtExecutable,
  NtExecutableResource,
  Resource,
  Data,
} from "resedit";

const exePath = process.argv[2];
const icoPath = process.argv[3];

const exeData = fs.readFileSync(exePath);
const exe = NtExecutable.from(exeData, { ignoreCert: true });
const res = NtExecutableResource.from(exe);

const icoData = fs.readFileSync(icoPath);
const iconFile = Data.IconFile.from(icoData);
const iconItems = iconFile.icons.map((icon) => icon.data);

// Replace all icon-group/icon resources with ours (IDs auto-calculated).
Resource.IconGroupEntry.replaceIconsForResource(res.entries, 1, 0, iconItems);

// Write the resource section back into the executable image in place,
// then write the regenerated PE (which already carries the SEA blob).
res.outputResource(exe);
fs.writeFileSync(exePath, Buffer.from(exe.generate()));
console.log(`Icon applied: ${iconItems.length} icon images`);
