module.exports = (grunt) ->
  grunt.registerTask 'build', [ 'coffee', 'uglify', 'sass', 'cssmin' ]