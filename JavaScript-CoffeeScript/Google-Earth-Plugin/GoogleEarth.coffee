class GoogleEarth
    LAYER_ROADS: "LAYER_ROADS"
    LAYER_BORDERS: "LAYER_BORDERS"
    LAYER_BUILDINGS: "LAYER_BUILDINGS"
    LAYER_BUILDINGS_LOW_RESOLUTION: "LAYER_BUILDINGS_LOW_RESOLUTION"
    LAYER_TERRAIN: "LAYER_TERRAIN"
    LAYER_TREES: "LAYER_TREES "
    
    _divId: null
    _div:  null
    _ge: null
    _layersState: {}
    _kmlList: {}
    _singleKmlHash: null
    
    constructor: (@_divId, forceInit = false, callback = null) ->
        @_div = document.getElementById(@_divId)
        @init callback if forceInit is true
    
    init: (callback = null) ->
        google.earth.createInstance @_divId, (instance) => 
            @_ge = instance
            @_ge.getWindow().setVisibility(true)
            callback() if typeof callback is "function"
        , (errorCode) ->
            console.log errorCode
    
    destroy: -> 
        @disableAllLayer()
        delete @_ge
        @_div.innerHTML = ""
        
    getDiv: -> _div
    
    enableLayer: (layerName) -> 
        @_ge.getLayerRoot().enableLayerById @_ge[layerName], true
        @_setLayerState layerName, true
        
    disableLayer: (layerName) -> 
        @_ge.getLayerRoot().enableLayerById @_ge[layerName], false
        @_setLayerState layerName, false
    
    toggleLayer: (layerName, newState) ->
        newState = !@_getLayerState(layerName) if !newState?
        @_ge.getLayerRoot().enableLayerById @_ge[layerName], newState
        @_setLayerState layerName, newState
        
    disableAllLayer: -> 
        for layer, state of @_layersState
            @disableLayer layer
            @_setLayerState layer, false
        true
    
    enableScaleLegend: -> @_ge.getOptions().setScaleLegendVisibility true
    disableScaleLegend: -> @_ge.getOptions().setScaleLegendVisibility false
    toggleScaleLegend: -> @_ge.getOptions().setScaleLegendVisibility !@_ge.getOptions().getScaleLegendVisibility()
    
    enableStatusBar: -> @_ge.getOptions().setStatusBarVisibility true
    disableStatusBar: -> @_ge.getOptions().setStatusBarVisibility false
    toggleStatusBar: -> @_ge.getOptions().setStatusBarVisibility !@_ge.getOptions().getStatusBarVisibility()
    
    enableOverviewMap: -> @_ge.getOptions().setOverviewMapVisibility true
    disableOverviewMap: -> @_ge.getOptions().setOverviewMapVisibility false
    toggleOverviewMap: -> @_ge.getOptions().setOverviewMapVisibility !@_ge.getOptions().getOverviewMapVisibility()
    
    enableGrid: -> @_ge.getOptions().setGridVisibility true
    disableGrid: -> @_ge.getOptions().setGridVisibility false
    toggleGrid: -> @_ge.getOptions().setGridVisibility !@_ge.getOptions().getGridVisibility()
        
    enableNavigationControl: -> @_ge.getNavigationControl().setVisibility @_ge.VISIBILITY_SHOW
    disableNavigationControl: -> @_ge.getNavigationControl().setVisibility @_ge.VISIBILITY_HIDE
    toggleNavigationControl: -> @_ge.getNavigationControl().setVisibility(if @_ge.getNavigationControl().getVisibility() is @_ge.VISIBILITY_SHOW then @_ge.VISIBILITY_HIDE else @_ge.VISIBILITY_SHOW)
    
    addKml: (url, forceLookAt = false) ->
        link = @_ge.createLink("")
        link.setHref url
        networkLink = @_ge.createNetworkLink("")
        networkLink.set link, true, forceLookAt
        hash = randomHash()
        @_kmlList[hash] = @_ge.getFeatures().appendChild networkLink
        hash
     
    addSingleKml: (url, forceLookAt = false) ->
        @removeKml @_singleKmlHash if @_singleKmlHash?
        @_singleKmlHash = @addKml url, forceLookAt
        
    removeKml: (hash) ->
        return false if !@_kmlList[hash]?
        @_kmlList[hash] = @_ge.getFeatures().removeChild @_kmlList[hash]
        delete @_kmlList[hash]
    
    removeAllKml: ->
        @removeKml hash for hash, _ of @_kmlList
        delete @_singleKmlHash
        
    lookAt: (latitude, longitude, altitude, tilt = 0, roll = 0, speed = 2.5) ->
        look = @_ge.createCamera('')
        look.setLatitude latitude
        look.setLongitude longitude
        look.setAltitude altitude
        look.setTilt tilt
        look.setRoll roll
        @_ge.getOptions().setFlyToSpeed(if speed > 0.0 then speed else @_ge.SPEED_TELEPORT)
        @_ge.getView().setAbstractView look
        
    _setLayerState: (layerName, newState) -> @_layersState[layerName] = newState
    _getLayerState: (layerName) -> if @_layersState[layerName]? then @_layersState[layerName] else false
