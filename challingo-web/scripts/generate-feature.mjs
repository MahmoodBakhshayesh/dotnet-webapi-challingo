#!/usr/bin/env node
// Usage: node scripts/generate-feature.mjs <feature-kebab-name>
// Scaffolds src/features/<name>/{repositories,usecases,controllers,views}/ in the
// auth/users reference shape. Mirrors the Flutter template's `mbkh_feat` brick.
import { mkdirSync, writeFileSync, existsSync } from "node:fs";
import { join } from "node:path";

const kebab = process.argv[2];
if (!kebab) {
  console.error("Usage: node scripts/generate-feature.mjs <feature-kebab-name>");
  process.exit(1);
}

const pascal = kebab.replace(/(^|-)(\w)/g, (_, __, c) => c.toUpperCase());
const camel = pascal[0].toLowerCase() + pascal.slice(1);
const root = join("src", "features", kebab);

if (existsSync(root)) {
  console.error(`${root} already exists`);
  process.exit(1);
}

const files = {
  [`repositories/${kebab}.repository.ts`]: `/**
 * Data source: API ${kebab} endpoints.
 * No business rules — transport only.
 */
import { apiJson } from "@/lib/api-client";

export const ${camel}Repository = {
  // list() { return apiJson("/api/${kebab}"); },
};
`,
  [`usecases/list-${kebab}.usecase.ts`]: `import { ${camel}Repository } from "@/features/${kebab}/repositories/${kebab}.repository";
import { appErrorMessage, isAppSuccess } from "@/lib/api-types";

export async function list${pascal}UseCase() {
  const res = await ${camel}Repository.list();
  if (!isAppSuccess(res)) throw new Error(appErrorMessage(res));
  return res.body ?? [];
}
`,
  [`controllers/${kebab}.controller.ts`]: `"use client";

import { useQuery } from "@tanstack/react-query";
import { queryKeys } from "@/lib/query-keys";
import { list${pascal}UseCase } from "@/features/${kebab}/usecases/list-${kebab}.usecase";

export function use${pascal}Controller() {
  const query = useQuery({ queryKey: queryKeys.${camel}, queryFn: list${pascal}UseCase });

  return {
    viewState: { items: query.data ?? [], isLoading: query.isLoading },
    actions: {},
    pending: {},
  };
}

export type ${pascal}ViewModel = ReturnType<typeof use${pascal}Controller>;
`,
  [`views/${kebab}-list.view.tsx`]: `/** Presentational: reads only \`viewState\` + invokes \`actions\`. No repos / use cases. */
import type { ${pascal}ViewModel } from "@/features/${kebab}/controllers/${kebab}.controller";

export function ${pascal}ListView({ viewState }: ${pascal}ViewModel) {
  return <div>{/* TODO: render viewState.items */}</div>;
}
`,
};

for (const [rel, content] of Object.entries(files)) {
  const full = join(root, rel);
  mkdirSync(join(full, ".."), { recursive: true });
  writeFileSync(full, content);
}

console.log(`Created src/features/${kebab}/ — remember to:`);
console.log(`  1. Add queryKeys.${camel} to src/lib/query-keys.ts`);
console.log(`  2. Fill in the repository's real endpoints`);
console.log(`  3. Wire a route page to render <${pascal}ListView {...use${pascal}Controller()} />`);
