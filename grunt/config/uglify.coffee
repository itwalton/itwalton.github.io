module.exports =
  app:
    options:
      screwIE8: true
      drop_console: true
    files:
      '<%= app.coffee.dest %>/main.min.js': '<%= app.coffee.dest %>/main.js'