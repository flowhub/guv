module.exports = ->
  # Project configuration
  @initConfig
    pkg: @file.readJSON 'package.json'

    yaml:
      schemas:
        files: [
          expand: true
          cwd: 'schemata/'
          src: '*.yaml'
          dest: 'schema/'
        ]

    # BDD tests on Node.js
    mochaTest:
      nodejs:
        src: ['spec/*.coffee']
        options:
          reporter: 'spec'
          grep: process.env['TESTS']

    # Coding standards
    coffeelint:
      components:
        files:
          src: ['spec/*.coffee', 'src/*.coffee']
        options:
          max_line_length:
            value: 100
            level: 'warn'

  # Grunt plugins used for building
  @loadNpmTasks 'grunt-yaml'

  # Grunt plugins used for testing
  @loadNpmTasks 'grunt-mocha-test'
  @loadNpmTasks 'grunt-coffeelint'

  # Our local tasks

  @registerTask 'build', 'Build the chosen target platform', (target = 'all') =>
    @task.run 'yaml'

  @registerTask 'test', 'Build and run automated tests', (target = 'all') =>
    @task.run 'coffeelint'
    @task.run 'build'
    @task.run 'mochaTest'

  @registerTask 'default', ['test']
