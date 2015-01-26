path        = require 'path'
context     = require './context'
Mocha       = require './mocha'
ResultView  = require './result-view'

mocha = null
resultView = null
currentContext = null

module.exports =

  configDefaults:
    nodeBinaryPath: '/usr/local/bin/node'
    textOnlyOutput: false
    showDebugInformation: false
    options: ''
    debugOptions: '--debug --debug-brk'

  activate: (state) ->
    resultView = new ResultView(state)
    resultView.on 'result-view:close', => @close()
    atom.workspaceView.on 'core:cancel', => @close()
    atom.workspaceView.on 'core:close', => @close()
    atom.workspaceView.command "mocha-test-runner:run", => @run()
    atom.workspaceView.command "mocha-test-runner:debug", => @run(true)
    atom.workspaceView.command "mocha-test-runner:run-previous", => @runPrevious()
    atom.workspaceView.command "mocha-test-runner:debug-previous", => @runPrevious(true)

  deactivate: ->
    if mocha then mocha.stop()
    atom.workspaceView.off 'core:cancel core:close'
    resultView.detach()
    resultView = null

  serialize: ->
    resultView.serialize()

  close: ->
    if mocha then mocha.stop()
    resultView.detach()

  run: (inDebugMode = false) ->
    editor   = atom.workspaceView.getActivePaneItem()
    currentContext = context.find editor
    @execute(inDebugMode)

  runPrevious: (inDebugMode = false) ->
    if currentContext
      @execute(inDebugMode)
    else
      @displayError 'No previous test run'

  execute: (inDebugMode = false) ->

    resultView.reset()
    if not resultView.hasParent()
      atom.workspaceView.prependToBottom resultView

    if atom.config.get 'mocha-test-runner.showContextInformation'
      nodeBinary = atom.config.get 'mocha-test-runner.nodeBinaryPath'
      resultView.addLine "Node binary:    #{nodeBinary}\n"
      resultView.addLine "Root folder:    #{currentContext.root}\n"
      resultView.addLine "Path to mocha:  #{currentContext.mocha}\n"
      resultView.addLine "Debug-Mode:     #{inDebugMode}\n"
      resultView.addLine "Test file:      #{currentContext.test}\n"
      resultView.addLine "Selected test:  #{currentContext.grep}\n\n"

    editor = atom.workspaceView.getActivePaneItem()
    mocha  = new Mocha currentContext, inDebugMode

    mocha.on 'success', -> resultView.success()
    mocha.on 'failure', -> resultView.failure()
    mocha.on 'output', (text) -> resultView.addLine(text)
    mocha.on 'error', (err) ->
      resultView.addLine('Failed to run Mocha\n' + err.message)
      resultView.failure()

    mocha.run()


  displayError: (message) ->
    resultView.reset()
    resultView.addLine message
    resultView.failure()
    if not resultView.hasParent()
      atom.workspaceView.prependToBottom resultView
