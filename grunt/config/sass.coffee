module.exports =
  app:
    options:
      sourcemap: 'none'        
    files: [
      expand: true
      cwd: '<%= app.sass.src %>'
      src: [ '**/*.scss' ]
      dest: '<%= app.sass.dest %>'
      ext: '.css'
    ]