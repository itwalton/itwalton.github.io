module.exports =
  coffee:
    files: '<%= app.coffee.src %>/**/*.coffee'
    tasks: [ 'newer:coffee', 'uglify' ]
  sass:
    files: '<%= app.sass.src %>/**/*.scss'
    tasks: [ 'sass', 'cssmin' ]