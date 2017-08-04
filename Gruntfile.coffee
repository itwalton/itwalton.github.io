module.exports = (grunt) ->
  require('load-grunt-config') grunt,
    configPath: require('path').join(process.cwd(), 'grunt/config')
    jitGrunt:
      customTasksDir: 'grunt/tasks'
    data:
      app:
        coffee:
          src: 'app',
          dest: 'public/js'
        sass:
          src: 'app/css'
          dest: 'public/css'

  require('time-grunt')(grunt)