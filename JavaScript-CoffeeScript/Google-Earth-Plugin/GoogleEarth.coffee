class GoogleEarth
    LAYER_ROADS: "LAYER_ROADS"
    LAYER_BORDERS: "LAYER_BORDERS"
    LAYER_BUILDINGS: "LAYER_BUILDINGS"
    LAYER_BUILDINGS_LOW_RESOLUTION: "LAYER_BUILDINGS_LOW_RESOLUTION"
    LAYER_TERRAIN: "LAYER_TERRAIN"
    LAYER_TREES: "LAYER_TREES"
    
    _divId: null
    _div:  null
    _ge: null
    _layersState: {}
    _kmlList: {}
    _singleKmlHash: null
    _polygonsList: {}
    
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
    
    toggleLayer: (layerName, newState = !@_getLayerState(layerName)) ->
        @_ge.getLayerRoot().enableLayerById @_ge[layerName], newState
        @_setLayerState layerName, newState
        
    disableAllLayer: -> 
        for layer, state of @_layersState
            @disableLayer layer
            @_setLayerState layer, false
        true
    
    enableScaleLegend: -> @_ge.getOptions().setScaleLegendVisibility true
    disableScaleLegend: -> @_ge.getOptions().setScaleLegendVisibility false
    toggleScaleLegend: (newValue = !@_ge.getOptions().getScaleLegendVisibility()) -> @_ge.getOptions().setScaleLegendVisibility newValue
    
    enableStatusBar: -> @_ge.getOptions().setStatusBarVisibility true
    disableStatusBar: -> @_ge.getOptions().setStatusBarVisibility false
    toggleStatusBar: (newValue = !@_ge.getOptions().getStatusBarVisibility()) -> @_ge.getOptions().setStatusBarVisibility newValue
  
    enableOverviewMap: -> @_ge.getOptions().setOverviewMapVisibility true
    disableOverviewMap: -> @_ge.getOptions().setOverviewMapVisibility false
    toggleOverviewMap: (newValue = !@_ge.getOptions().getOverviewMapVisibility()) -> @_ge.getOptions().setOverviewMapVisibility newValue
    
    enableGrid: -> @_ge.getOptions().setGridVisibility true
    disableGrid: -> @_ge.getOptions().setGridVisibility false
    toggleGrid: (newValue = !@_ge.getOptions().getGridVisibility()) -> @_ge.getOptions().setGridVisibility newValue
        
    enableNavigationControl: -> @_ge.getNavigationControl().setVisibility @_ge.VISIBILITY_SHOW
    disableNavigationControl: -> @_ge.getNavigationControl().setVisibility @_ge.VISIBILITY_HIDE
    toggleNavigationControl: -> @_ge.getNavigationControl().setVisibility(if @_ge.getNavigationControl().getVisibility() is @_ge.VISIBILITY_SHOW then @_ge.VISIBILITY_HIDE else @_ge.VISIBILITY_SHOW)
    
    addKml: (url, forceLookAt = false) ->
        link = @_ge.createLink ""
        link.setHref url
        networkLink = @_ge.createNetworkLink ""
        networkLink.set link, true, forceLookAt
        hash = @_randomHash()
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
        look = @_ge.createCamera ""
        look.setLatitude latitude
        look.setLongitude longitude
        look.setAltitude altitude
        look.setTilt tilt
        look.setRoll roll
        @_ge.getOptions().setFlyToSpeed(if speed > 0.0 then speed else @_ge.SPEED_TELEPORT)
        @_ge.getView().setAbstractView look
        
    addCircle: (latitude, longitude, radius, countPoints = 100) ->
        diameter = radius / 6378.8
        rLatitude = diameter * (180 / Math.PI)
        rLongitude = rLatitude / (Math.cos(latitude * (Math.PI / 180)))
        createPointsList = ->
            for i in [0..countPoints]
                rad = (360 / countPoints * i) * (Math.PI / 180)
                y = latitude + (rLatitude * Math.sin(rad))
                x = longitude + (rLongitude * Math.cos(rad))
                [y, x]
        @addLine createPointsList()
        
    addLine: (pointsList = []) ->
        placemark = @_ge.createPlacemark ""
        line = @_ge.createLineString ""
        placemark.setGeometry line
        line.getCoordinates().pushLatLngAlt point[0], point[1], 0 for point in pointsList
        hash = @_randomHash()
        @_polygonsList[hash] = @_ge.getFeatures().appendChild placemark   
        hash
        
    removePolygon: (hash) ->
        return false if !@_polygonsList[hash]?
        @_polygonsList[hash] = @_ge.getFeatures().removeChild @_polygonsList[hash]
        delete @_polygonsList[hash]
    
    removeAllPolygons: ->@removePolygon hash for hash, _ of @_polygonsList
        
    _setLayerState: (layerName, newState) -> @_layersState[layerName] = newState
    _getLayerState: (layerName) -> if @_layersState[layerName]? then @_layersState[layerName] else false
    
    _randomHash: (length = 32) ->
        letters = "AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890"
        result = ""
        result += letters[Math.floor(Math.random() * letters.length)] for i in [0...length]
        result
