# Add Examples

## Dry run (preview before cloning)

```bash
/qmd:add vercel/next.js --dry-run
```

## Basic

```bash
/qmd:add https://github.com/tobi/qmd
/qmd:add denoland/deno
```

## Custom mask

```bash
/qmd:add vercel/next.js --mask "**/*.{md,mdx}"
```

## Custom name

```bash
/qmd:add https://github.com/some-org/very-long-repo-name --name short
```

## Custom destination

```bash
/qmd:add vercel/next.js --dest ~/work/refs
```

## Full clone (with history)

```bash
/qmd:add rust-lang/rust --full
```

## Batch add (defer embedding)

```bash
/qmd:add vercel/next.js --defer-embed
/qmd:add facebook/react --defer-embed
/qmd:add sveltejs/svelte --defer-embed
/qmd:update
```
