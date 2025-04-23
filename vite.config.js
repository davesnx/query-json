import { defineConfig } from "vite";
import NodeResolution from "@rollup/plugin-node-resolve";
import { createHtmlPlugin } from "vite-plugin-html";
import replace from "@rollup/plugin-replace";

const isProd = process.env.NODE_ENV === "production";

/**
 * @type { import('vite').UserConfig }
 */
const config = {
  entry: "_build/default/website/website/website/Website.re.js",
  mode: isProd ? "production" : "development",
  optimizeDeps: {
    include: ["@monaco-editor/react", "react", "react-dom", "react-dom/client"],
  },
  build: {
    rollupOptions: {
      external: ["react-dom/client", "react"],
    },
    commonjsOptions: {
      transformMixedEsModules: true,
    },
  },
  plugins: [
    replace({
      preventAssignment: true,
      "process.env.NODE_ENV": JSON.stringify("development"),
    }),
    NodeResolution(),
    createHtmlPlugin({
      inject: {
        data: {
          title: "query-json playground",
        },
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
