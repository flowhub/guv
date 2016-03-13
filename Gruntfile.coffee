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
          src: ['spec/*.coffee', 'src/*.coffee', 'ui/*.coffee']
        options:
          max_line_length:
            value: 100
            level: 'warn'

    # Browser build
    browserify:
      options:
        transform: [
          ['coffeeify']
        ]
        browserifyOptions:
          extensions: ['.coffee']
          fullPaths: false
      src:
        files:
          'browser/guv.js': ['index.js']
        options:
          watch: true

  # Grunt plugins used for building
  @loadNpmTasks 'grunt-yaml'
  @loadNpmTasks 'grunt-browserify'

  # Grunt plugins used for testing
  @loadNpmTasks 'grunt-mocha-test'
  @loadNpmTasks 'grunt-coffeelint'

  # Our local tasks

  @registerTask 'build', 'Build the chosen target platform', (target = 'all') =>
    @task.run 'yaml'
    @task.run 'browserify'

  @registerTask 'test', 'Build and run automated tests', (target = 'all') =>
    @task.run 'coffeelint'
    @task.run 'build'
    @task.run 'mochaTest'

  @registerTask 'default', ['test']
