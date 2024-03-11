import { defineConfig } from 'vite'
import reactPlugin from '@vitejs/plugin-react'
import resolve from "@rollup/plugin-node-resolve";
import { createHtmlPlugin } from 'vite-plugin-html'
import MonacoEditorPlugin from 'vite-plugin-monaco-editor';
import polyfillNode from "rollup-plugin-polyfill-node"
import vitePluginRequire from "vite-plugin-require"

const isProd = process.env.NODE_ENV === 'production';
const monacoEditorPlugin = MonacoEditorPlugin({
  languages: ['json'],
  languageWorkers: ['json']
});

/**
 * @type { import('vite').UserConfig }
 */
const config = {
  entry: "_build/default/website/Website.bc.js",
  jsx: 'react',
  mode: isProd ? 'production' : 'development',
  optimizeDeps: {
    include: ["@monaco-editor/react", "@emotion/css", "react", "react-dom"],
  },
  /* build: {
    commonjsOptions: {
      transformMixedEsModules: true
    }
  }, */
  plugins: [
    reactPlugin(),
    polyfillNode(),
    /* viteCommonjs(), */
    vitePluginRequire({
      translateType: "importMetaUrl"
    }),
    /* requireSupport(), */
    /* requireTransform(), */
    /* commonjsPlugin(), */
    /* monacoEditorPlugin, */
    resolve({
      browser : true,
    }),
    createHtmlPlugin({
      inject: {
          data: {
            title: 'query-json playground'
          },
          tags: [
            {
              injectTo: 'body-prepend',
              tag: 'div',
              attrs: {
                id: 'root',
              },
            },
          ],
        },
    })
  ],
}

export default defineConfig(config)
