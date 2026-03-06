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
  minifyJS: false,
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

async function collectHtmlFiles(dirPath) {
  const entries = await readdir(dirPath, { withFileTypes: true });
  const files = [];

  for (const entry of entries) {
    const entryPath = path.join(dirPath, entry.name);
    if (entry.isDirectory()) {
      files.push(...(await collectHtmlFiles(entryPath)));
      continue;
    }
    if (entry.name.endsWith(".html")) {
      files.push(entryPath);
    }
  }

  return files.sort();
}

const htmlFiles = await collectHtmlFiles(docsDir);

if (htmlFiles.length === 0) {
  throw new Error(`No HTML files found in ${docsDir}`);
}

for (const filePath of htmlFiles) {
  const source = await readFile(filePath, "utf8");
  const minified = await minify(source, minifyOptions);
  await writeFile(filePath, `${minified}\n`, "utf8");
  console.log(`Minified ${path.relative(repoRoot, filePath)}`);
}
