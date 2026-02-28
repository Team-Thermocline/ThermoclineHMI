const rules = require('./webpack.rules');
const path = require('path');

rules.push({
  test: /\.css$/,
  use: [{ loader: 'style-loader' }, { loader: 'css-loader' }],
});

module.exports = {
  // Put your normal webpack config below here
  module: {
    rules,
  },
  resolve: {
    extensions: ['.mjs', '.js', '.svelte'],
    modules: [
      path.resolve(__dirname, 'src'),
      path.resolve(__dirname, 'team-thermocline.github.io/src'),
      path.resolve(__dirname, 'node_modules'),
      'node_modules',
    ],
  },
};
