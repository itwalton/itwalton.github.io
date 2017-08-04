module.exports =
  app:
    options:
      join: true
    files: [
      '<%= app.coffee.dest %>/main.js': [
        '<%= app.coffee.src %>/app.module.coffee'
        '<%= app.coffee.src %>/app.routes.coffee'
        '<%= app.coffee.src %>/components/**/*.module.coffee'
        '<%= app.coffee.src %>/components/**/*.coffee'
      ]
    ]