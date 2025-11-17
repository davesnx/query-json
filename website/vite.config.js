import { defineConfig } from "vite";
import NodeResolution from "@rollup/plugin-node-resolve";
import { createHtmlPlugin } from "vite-plugin-html";
import replace from "@rollup/plugin-replace";
import { viteStaticCopy as copy } from "vite-plugin-static-copy";
import { fileURLToPath } from 'url';
import { dirname, resolve } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const workspaceRoot = resolve(__dirname, '..');

const isProd = process.env.NODE_ENV === "production";

/**
 * @type { import('vite').UserConfig }
 */
const config = {
  entry: "_build/default/website/website/website/Website.re.js",
  mode: isProd ? "production" : "development",
  resolve: {
    alias: {
      "@monaco-editor/loader": resolve(workspaceRoot, "node_modules/@monaco-editor/loader"),
      "@monaco-editor/react": resolve(workspaceRoot, "node_modules/@monaco-editor/react"),
      "monaco-editor": resolve(workspaceRoot, "node_modules/monaco-editor"),
    },
  },
  optimizeDeps: {
    include: ["react", "react-dom", "react-dom/client"],
    exclude: ["monaco-editor", "@monaco-editor/react", "@monaco-editor/loader"],
  },
  worker: {
    format: "es",
  },
  build: {
    commonjsOptions: {
      esmExternals: true,
    },
    rollupOptions: {
      external: (id) => {
        return id.includes('js.bc.js');
      },
      output: {
        manualChunks: undefined,
      },
    },
  },
  plugins: [
    copy({
      targets: [
        {
          src: "_build/default/js/js.bc.js",
          dest: "_build/default/js",
        },
      ],
    }),
    replace({
      preventAssignment: true,
      "process.env.NODE_ENV": JSON.stringify("development"),
    }),
    NodeResolution(),
    createHtmlPlugin({
      inject: {
        tags: [
          {
            injectTo: "body-prepend",
            tag: "div",
            attrs: {
              id: "root",
            },
          },
        ],
      },
    }),
  ],
};

export default defineConfig(config);
