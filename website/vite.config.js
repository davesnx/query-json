import Vite from "vite";
import Node_resolution from "@rollup/plugin-node-resolve";
import * as Html from "vite-plugin-html";
import replace from "@rollup/plugin-replace";
import { viteStaticCopy as copy } from "vite-plugin-static-copy";
import URL from 'url';
import Path from 'path';

const __filename = URL.fileURLToPath(import.meta.url);
const __dirname = Path.dirname(__filename);
const workspaceRoot = Path.resolve(__dirname, '..');

const isProd = process.env.NODE_ENV === "production";

/**
 * @type { import('vite').UserConfig }
 */
const config = {
  entry: "_build/default/website/website/website/Index.ml.js",
  mode: isProd ? "production" : "development",
  resolve: {
    alias: {
      "@monaco-editor/loader": Path.resolve(workspaceRoot, "node_modules/@monaco-editor/loader"),
      "@monaco-editor/react": Path.resolve(workspaceRoot, "node_modules/@monaco-editor/react"),
      "monaco-editor": Path.resolve(workspaceRoot, "node_modules/monaco-editor"),
    },
  },
  optimizeDeps: {
    include: ["react", "react-dom", "react-dom/client"],
    exclude: ["monaco-editor", "@monaco-editor/react", "@monaco-editor/loader"],
  },
  server: {
    watch: {
      ignored: ['**/_opam/**', '**/.git/**'],
    },
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
      "process.env.NODE_ENV": JSON.stringify(isProd ? "production" : "development"),
    }),
    Node_resolution(),
    Html.createHtmlPlugin({
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

export default Vite.defineConfig(config);
