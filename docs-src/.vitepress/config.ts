import { writeFileSync } from 'node:fs';
import { join } from 'node:path';

import { defineConfig } from 'vitepress';

import { referenceSidebar } from '../registry/.sidebar.js';

// Deployed to https://honeyhiveai.github.io/semantic-conventions/ via GitHub Pages
// project-pages on the synced public repo. `base` must match the repo name
// so asset URLs resolve correctly.

export default defineConfig({
  title: 'HoneyHive Semantic Conventions',
  description: 'Canonical attribute schema for HoneyHive AI observability.',
  // Note: this matches the repo name for https://github.com/honeyhiveai/semantic-conventions,
  // since it will be hosted on GitHub Pages at honeyhiveai.github.io/semantic-conventions/
  base: '/semantic-conventions/',
  lang: 'en-US',
  cleanUrls: true,

  // Override VitePress's default outDir (docs-src/.vitepress/dist) so the build
  // artifact lands at the package root in docs/. Resolved from srcDir.
  outDir: '../docs',

  // GitHub Pages serves /docs from main via "Deploy from a branch", which runs
  // Jekyll over the output and breaks VitePress's asset paths. .nojekyll opts
  // out. TypeDoc emits this for api-client automatically; VitePress doesn't.
  buildEnd(siteConfig) {
    writeFileSync(join(siteConfig.outDir, '.nojekyll'), '');
  },

  themeConfig: {
    nav: [
      { text: 'Home', link: '/' },
      { text: 'Getting Started', link: '/getting-started' },
      { text: 'Registry', link: '/registry/' },
    ],
    sidebar: [
      {
        text: 'Introduction',
        items: [
          { text: 'Overview', link: '/' },
          { text: 'Getting Started', link: '/getting-started' },
        ],
      },
      ...referenceSidebar,
    ],
    socialLinks: [{ icon: 'github', link: 'https://github.com/honeyhiveai/semantic-conventions' }],
  },
});
