import { defineConfig } from 'vitepress'

export default defineConfig({
  title: 'HoneyHive Semantic Conventions',
  description: 'Canonical attribute schema for HoneyHive observability',
  base: '/semantic-conventions/',
  outDir: '../docs',
  ignoreDeadLinks: true,
  themeConfig: {
    nav: [
      { text: 'Registry', link: '/registry/' },
    ]
  }
})
