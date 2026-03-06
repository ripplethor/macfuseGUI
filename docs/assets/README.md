# macfuseGui Marketing Site Assets

This directory contains the static assets for the `macfuseGui` marketing website hosted on GitHub Pages.

## File Structure

- `site.css`: Custom styles for glassmorphism, gradients, and specific visual tweaks that extend Tailwind.
- `site.js`: Logic for:
  - Theme toggling (Dark/Light) with `localStorage` persistence.
  - Dynamic GitHub repo links (configured via `CONFIG.repo`).
  - Hero release version hydration from the GitHub Releases API (with fallback text).
  - FAQ accordion behavior (ARIA-compliant).
  - Copyright year auto-update.
- `hero-bg.webp`: Local hero background image (Unsplash source, converted to WebP for performance).
- `og-image.webp`: Social preview image in WebP format.

## Configuration

To change the target repository for download/GitHub links, edit `site.js`:

```javascript
const CONFIG = {
  repo: "ripplethor/macfuseGUI"
};
```

## Theme System

The theme system uses a pre-paint script in `index.html` to prevent flashing. It checks `localStorage` first, then system preference.
State is toggled via the button with `id="theme-toggle"`.

## Development

The site stays fully static, but HTML is now generated from structured locale/page content before CSS compilation and minification.
Source and output files:

- `tailwind.input.css`: Tailwind input with the custom dark variant and docs-relative source scanning.
- `tailwind.generated.css`: compiled utility CSS committed alongside the static site output.
- `scripts/docs_content.mjs`: source-of-truth for locale definitions, page definitions, and localized copy.
- `scripts/generate_docs.mjs`: generates the English root pages, locale subdirectories, and multilingual sitemap into `docs/`.

Build order:

1. `npm run docs:generate`
2. `npm run docs:build-css`
3. `npm run docs:minify-html`
4. `npm run docs:check`

Useful commands from the repo root:

```bash
npm install
npm run docs:build
npm run docs:check
```

All asset paths must stay **relative** (e.g., `assets/site.css`, not `/assets/site.css`) so the site works in both:
- custom-domain root hosting (current production: `https://www.macfusegui.app/`)
- GitHub Pages subdirectory previews (for example `/macfuseGui/`)

The same rule applies to locale pages generated under subdirectories such as `docs/ja/` or `docs/pt-br/`.

## Deployment

1. Commit changes to `main`.
2. Go to repository Settings -> Pages.
3. Select Source: `Deploy from a branch`.
4. Branch: `main`, Folder: `/docs`.
5. Save.
