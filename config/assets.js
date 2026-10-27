import * as assets from "hanami-assets";

await assets.run({
  esbuildOptionsFn: (_args, options) => ({ ...options, format: "esm", splitting: true }),
});
