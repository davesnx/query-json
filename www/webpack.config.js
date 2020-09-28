const path = require('path');
const HtmlWebpackPlugin = require('html-webpack-plugin');

const isProd = process.env.NODE_ENV === 'production';

module.exports = {
  entry: './src/Index.bs.js',
  mode: isProd ? 'production' : 'development',
  resolve: {
    extensions: ['.js'],
    modules: [
      'node_modules',
      path.resolve(__dirname, '../../_build/default/js'),
    ],
    alias: {
      'query-json': path.resolve(
        __dirname,
        '..',
        '..',
        '_build',
        'default',
        'js',
        'Js.bs.js'
      ),
    },
  },
  node: {
    fs: 'empty',
    child_process: 'empty',
  },
  plugins: [
    new HtmlWebpackPlugin({
      template: './index.html',
      inject: false,
    }),
  ],
  devServer: {
    compress: true,
    contentBase: './',
    port: process.env.PORT || 8000,
    historyApiFallback: true,
  },
};
