import { defineConfig } from 'vite'
import reactPlugin from '@vitejs/plugin-react'
import resolve from "@rollup/plugin-node-resolve";
import { createHtmlPlugin } from 'vite-plugin-html'
import MonacoEditorPlugin from 'vite-plugin-monaco-editor';
import polyfillNode from "rollup-plugin-polyfill-node"
import vitePluginRequire from "vite-plugin-require"
import replace from '@rollup/plugin-replace'

const isProd = process.env.NODE_ENV === 'production';

const monacoEditorPlugin = MonacoEditorPlugin({
  languages: ['json'],
  languageWorkers: ['json']
});

/**
 * @type { import('vite').UserConfig }
 */
const config = {
  entry: "_build/default/website/website/website/Website.re.js",
  mode: isProd ? 'production' : 'development',
  optimizeDeps: {
    include: ["@monaco-editor/react", "react", "react-dom", "react-dom/client"],
  },
  build: {
    rollupOptions: {
      external: ["react-dom/client", "react"],
    },
  },
  /* build: {
    commonjsOptions: {
      transformMixedEsModules: true
    }
  }, */
  plugins: [
    reactPlugin(),
    replace({
      preventAssignment: true,
      "process.env.NODE_ENV": JSON.stringify("development")
    }),
    polyfillNode(),
    vitePluginRequire({
      translateType: "importMetaUrl"
    }),
    monacoEditorPlugin,
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
