import { readdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { minify } from "html-minifier-terser";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, "..");
const docsDir = path.join(repoRoot, "docs");

const minifyOptions = {
  caseSensitive: true,
  collapseBooleanAttributes: true,
  collapseWhitespace: true,
  continueOnParseError: true,
  decodeEntities: true,
  keepClosingSlash: true,
  minifyCSS: true,
  minifyJS: true,
  preserveLineBreaks: false,
  processConditionalComments: false,
  removeAttributeQuotes: false,
  removeComments: true,
  removeEmptyAttributes: false,
  removeOptionalTags: false,
  removeRedundantAttributes: true,
  removeScriptTypeAttributes: true,
  removeStyleLinkTypeAttributes: true,
  sortAttributes: true,
  useShortDoctype: true
};

const htmlFiles = (await readdir(docsDir))
  .filter((name) => name.endsWith(".html"))
  .sort();

if (htmlFiles.length === 0) {
  throw new Error(`No HTML files found in ${docsDir}`);
}

for (const fileName of htmlFiles) {
  const filePath = path.join(docsDir, fileName);
  const source = await readFile(filePath, "utf8");
  const minified = await minify(source, minifyOptions);
  await writeFile(filePath, `${minified}\n`, "utf8");
  console.log(`Minified ${path.relative(repoRoot, filePath)}`);
}
