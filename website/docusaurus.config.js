// @ts-check

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: 'FlowClip',
  tagline: 'Clipboard, built for flow.',
  favicon: 'img/logo.png',

  url: 'https://gityeop.github.io',
  baseUrl: '/FlowClip/',

  organizationName: 'gityeop',
  projectName: 'FlowClip',
  deploymentBranch: 'gh-pages',

  onBrokenLinks: 'throw',
  onBrokenMarkdownLinks: 'warn',

  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  presets: [
    [
      'classic',
      /** @type {import('@docusaurus/preset-classic').Options} */
      ({
        docs: false,
        blog: false,
        theme: {
          customCss: './src/css/custom.css',
        },
      }),
    ],
  ],

  themeConfig:
    /** @type {import('@docusaurus/preset-classic').ThemeConfig} */
    ({
      navbar: {
        title: 'FlowClip',
        logo: {
          alt: 'FlowClip Logo',
          src: 'img/logo.png',
        },
        items: [
          {
            href: 'https://github.com/gityeop/FlowClip',
            label: 'GitHub',
            position: 'right',
          },
        ],
      },
      footer: {
        style: 'dark',
        copyright: `Copyright © ${new Date().getFullYear()} Sang Yeop Lim. Built with Docusaurus.`,
      },
    }),
};

export default config;
