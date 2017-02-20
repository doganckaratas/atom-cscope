{allowUnsafeNewFunction} = require 'loophole'
Ractive = require 'ractive'
{CompositeDisposable} = require 'atom'

module.exports =
class AtomCscopeViewModel
  constructor: (@view, @model) ->
    @subscriptions = new CompositeDisposable
    @previousSearch =
      keyword: null
      option: null
      path: null
    @ractive = allowUnsafeNewFunction =>
      new Ractive
        el: @view.target
        data: @model.data
        template: @view.template.toString()

    @view.initilaize()
    @setupEvents()

  setupEvents: () ->
    @model.onDataChange (itemName, newItem) =>
      @ractive.set itemName, newItem
      
    @model.onDataUpdate (itemName, newItem) =>
      @ractive.merge itemName, newItem
      
    @view.onMoveUp (event) =>
      @view.selectPrev()
      
    @view.onMoveDown (event) =>
      @view.selectNext()
      
    @view.onMoveToTop (event) =>
      @view.selectFirst()
      
    @view.onMoveToBottom (event) =>
      @view.selectLast()

    @ractive.on 'search-force', (event) =>
      newSearch = @view.getSearchParams()
      @performSearch newSearch
    @ractive.on 'path-select', (event) =>
      @view.input.focus()

    @view.onConfirm (event) =>
      newSearch = @view.getSearchParams()
      sameAsPrev = @sameAsPreviousSearch newSearch
      if @view.hasSelection() and sameAsPrev
        @openResult @view.currentSelection
      else if !sameAsPrev
        @performSearch newSearch

    @subscriptions.add atom.config.observe 'atom-cscope.LiveSearch', (newValue) =>
      if not newValue
        @liveSearchListener?.dispose()
        return

      @liveSearchListener = @view.input.getModel().onDidStopChanging () =>
        return unless newValue
        newSearch = @view.getSearchParams()
        @performSearch newSearch

  invokeSearch: (option, keyword) ->
    @view.autoFill option, keyword.trim()
    newSearch = @view.getSearchParams()
    @performSearch newSearch

  performSearch: (newSearch) ->
    if @searchCallback?
      @view.startLoading()
      @searchCallback newSearch
      .then () =>
        @view.stopLoading()
        @view.currentSelection = 0
      .catch () =>
        @view.stopLoading()
        @resetSearch()
    else
      console.log "searchCallback not found."
    @previousSearch = newSearch
    @view.input.focus()

  sameAsPreviousSearch: (newSearch) ->
    return false if newSearch.keyword != @previousSearch.keyword || newSearch.option != @previousSearch.option
    return false if newSearch.path.length != @previousSearch.path.length
    for i in [0..newSearch.path.length]
      return false if newSearch.path[i] != @previousSearch.path[i]
    return true

  resetSearch: () ->
    @previousSearch =
      keyword: null
      option: null
      path: null

  openResult: (index) ->
    @resultClickCallback @model.data.results[index]

  onResultClick: (callback) ->
    @resultClickCallback = callback
    @ractive.on 'result-click', (event) =>
      temp = event.resolve().split(".")
      model = @model.data.results[parseInt temp.pop()]
      @resultClickCallback model
      @view.selectItemView
      
  onRefresh: (callback) ->
    @ractive.on 'refresh', (event) =>
      callback event
      @view.input.focus()

  onSearch: (callback) ->
    @searchCallback = callback