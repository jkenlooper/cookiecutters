/*
{{ cookiecutter.template_file_comment }}
Version: {{ cookiecutter._version }}
*/
const isProduction = process.env.NODE_ENV === 'production';

module.exports = {
  plugins: [
    require('postcss-import')({}),
    isProduction &&
    require('cssnano')({
      preset: 'default',
    }),
  ],
};
