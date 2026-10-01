#!/usr/bin/env node
// Usage: node scripts/generate-usecase.mjs <feature-kebab-name> <action-kebab-name>
// Appends one usecase file under src/features/<feature>/usecases/.
// Mirrors the Flutter template's `mbkh_usecase` brick.
import { mkdirSync, writeFileSync, existsSync } from "node:fs";
import { join } from "node:path";

const feature = process.argv[2];
const action = process.argv[3];
if (!feature || !action) {
  console.error(
    "Usage: node scripts/generate-usecase.mjs <feature-kebab-name> <action-kebab-name>",
  );
  process.exit(1);
}

const featurePascal = feature.replace(/(^|-)(\w)/g, (_, __, c) => c.toUpperCase());
const featureCamel = featurePascal[0].toLowerCase() + featurePascal.slice(1);
const actionPascal = action.replace(/(^|-)(\w)/g, (_, __, c) => c.toUpperCase());
const entitySingular = feature.endsWith("s") ? feature.slice(0, -1) : feature;
const entityPascal = entitySingular.replace(/(^|-)(\w)/g, (_, __, c) =>
  c.toUpperCase(),
);

const featureRoot = join("src", "features", feature);
if (!existsSync(featureRoot)) {
  console.error(`${featureRoot} does not exist — run generate-feature first`);
  process.exit(1);
}

const fileName = `${action}-${entitySingular}.usecase.ts`;
const full = join(featureRoot, "usecases", fileName);
if (existsSync(full)) {
  console.error(`${full} already exists`);
  process.exit(1);
}

const content = `import { ${featureCamel}Repository } from "@/features/${feature}/repositories/${feature}.repository";
import { appErrorMessage, isAppSuccess } from "@/lib/api-types";

export async function ${action}${entityPascal}UseCase() {
  const res = await ${featureCamel}Repository.${action}();
  if (!isAppSuccess(res)) throw new Error(appErrorMessage(res));
  return res.body;
}
`;

mkdirSync(join(full, ".."), { recursive: true });
writeFileSync(full, content);

console.log(`Created ${full} — remember to:`);
console.log(`  1. Add ${featureCamel}Repository.${action}() if it does not exist yet`);
console.log(`  2. Wire the usecase into the feature controller via useQuery/useMutation`);
console.log(`  3. Adjust the function signature / return type for this action`);
