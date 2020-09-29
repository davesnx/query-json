const path = require('path');
const HtmlWebpackPlugin = require('html-webpack-plugin');
const CopyPlugin = require('copy-webpack-plugin');

const isProd = process.env.NODE_ENV === 'production';

module.exports = {
  context: path.resolve('../'),
  entry: './www/src/Index.bs.js',
  mode: isProd ? 'production' : 'development',
  node: {
    fs: 'empty',
    child_process: 'empty',
  },
  plugins: [
    new HtmlWebpackPlugin({
      template: './www/index.html',
      inject: true,
    }),
  ],
  devServer: {
    compress: true,
    contentBase: './www/src',
    port: process.env.PORT || 8000,
    historyApiFallback: true,
  },
};
