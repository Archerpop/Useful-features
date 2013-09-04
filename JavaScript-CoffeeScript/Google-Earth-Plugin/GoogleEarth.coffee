class GoogleEarth    
    _divId: null
    _div:  null
    _ge: null
    
    constructor: (@_divId, forceInit = false, callback = null) ->
        @_div = document.getElementById(@_divId)
        @init callback if forceInit is true
    
    init: (callback = null) ->
        google.earth.createInstance @_divId, (instance) => 
            @_ge = instance
            @_ge.getWindow().setVisibility true
            @layer.self = @
            @polygon.self = @
            @camera.self = @
            @kml.self = @
            @yardstick.self = @
            callback() if typeof callback is "function"
        , (errorCode) ->
            console.log errorCode
    
    destroy: -> 
        @disableAllLayer()
        delete @_ge
        @_div.innerHTML = ""
    
    clearAll: ->
        @removeAllKml()
        @removeAllPolygons()
        
    getDiv: -> _div
    
    layer:
        LAYER_ROADS: "LAYER_ROADS"
        LAYER_BORDERS: "LAYER_BORDERS"
        LAYER_BUILDINGS: "LAYER_BUILDINGS"
        LAYER_BUILDINGS_LOW_RESOLUTION: "LAYER_BUILDINGS_LOW_RESOLUTION"
        LAYER_TERRAIN: "LAYER_TERRAIN"
        LAYER_TREES: "LAYER_TREES"        
        _layersState: {}
        
        enable: (layerName) -> 
            @self._ge.getLayerRoot().enableLayerById @self._ge[layerName], true
            @_setState layerName, true

        disable: (layerName) -> 
            @self._ge.getLayerRoot().enableLayerById @self._ge[layerName], false
            @_setState layerName, false

        toggle: (layerName, newState = !@_getState(layerName)) ->
            @self._ge.getLayerRoot().enableLayerById @self._ge[layerName], newState
            @_setState layerName, newState

        disableAll: -> 
            for layer, state of @_layersState
                @disable layer
                @_setState layer, false
            true
            
        _setState: (layerName, newState) -> @_layersState[layerName] = newState
        _getState: (layerName) -> if @_layersState[layerName]? then @_layersState[layerName] else false
    
    polygon: 
        _polygonsList: {}
        
        addCircle: (latitude, longitude, radius, countPoints = 100, style = null) ->
            diameter = radius / 6378.8
            rLatitude = diameter * (180 / Math.PI)
            rLongitude = rLatitude / (Math.cos(latitude * (Math.PI / 180)))
            createPointsList = ->
                for i in [0..countPoints]
                    rad = (360 / countPoints * i) * (Math.PI / 180)
                    y = latitude + (rLatitude * Math.sin(rad))
                    x = longitude + (rLongitude * Math.cos(rad))
                    [y, x]
            @addLine createPointsList(), style

        addLine: (pointsList = [], style = null) ->
            placemark = @self._ge.createPlacemark ""
            line = @self._ge.createLineString ""
            placemark.setGeometry line
            line.getCoordinates().pushLatLngAlt point[0], point[1], 0 for point in pointsList
            if style?
                placemark.setStyleSelector @self._ge.createStyle ""
                placemarkStyle = placemark.getStyleSelector().getLineStyle()
                placemarkStyle.setWidth style.width if style.width?
                placemarkStyle.getColor().set style.color if style.color?
            hash = @self._randomHash()
            @_polygonsList[hash] = @self._ge.getFeatures().appendChild placemark   
            hash

        remove: (hash) ->
            return false if !@_polygonsList[hash]?
            @_polygonsList[hash] = @self._ge.getFeatures().removeChild @_polygonsList[hash]
            delete @_polygonsList[hash]

        removeAll: -> @remove hash for hash, _ of @_polygonsList
    
    camera: 
        get: ->
            look = @self._ge.getView().copyAsCamera @self._ge.ALTITUDE_RELATIVE_TO_GROUND
            res = 
                latitude: @self._roundCoordinates look.getLatitude()
                longitude: @self._roundCoordinates look.getLongitude()
                altitude: @self._roundCoordinates look.getAltitude()
                titl: look.getTilt()
                roll: look.getRoll()
                speed: @self._ge.getOptions().getFlyToSpeed()
            
        set: (latitude, longitude, altitude, tilt = 0, roll = 0, speed = 2.5) ->
            look = @self._ge.createCamera ""
            look.setLatitude latitude
            look.setLongitude longitude
            look.setAltitude altitude
            look.setTilt tilt
            look.setRoll roll
            @self._ge.getOptions().setFlyToSpeed(if speed > 0.0 then speed else @_ge.SPEED_TELEPORT)
            @self._ge.getView().setAbstractView look
    
    kml: 
        _kmlList: {}
        _singleKmlHash: null
        
        add: (url, forceLookAt = false) ->
            link = @self._ge.createLink ""
            link.setHref url
            networkLink = @self._ge.createNetworkLink ""
            networkLink.set link, true, forceLookAt
            hash = @self._randomHash()
            @_kmlList[hash] = @self._ge.getFeatures().appendChild networkLink
            hash

        addSingle: (url, forceLookAt = false) ->
            @remove @_singleKmlHash if @_singleKmlHash?
            @_singleKmlHash = @add url, forceLookAt

        remove: (hash) ->
            return false if !@_kmlList[hash]?
            @_kmlList[hash] = @_ge.getFeatures().removeChild @_kmlList[hash]
            delete @_kmlList[hash]

        removeAll: ->
            @remove hash for hash, _ of @_kmlList
            delete @_singleKmlHash
         
    yardstick:
        _pointsList: []
        _lineHash: null
        _placemark: null
        
        addPoint: (latitude, longitude) ->
            @_removePlacemark()
            @_pointsList.push [latitude, longitude]
            @_redrawLine()
            @_createPlacemark latitude, longitude
            
        clear: ->
            @self.polygon.remove @_lineHash if @_lineHash?
            delete @_lineHash
            @_pointsList = []
            @_removePlacemark()
            
        getSummaryLength: ->
            res = 0
            res += @self.countDistance @_pointsList[i], @_pointsList[i+1] for i in [0...@_pointsList.length-1]
            res.toFixed 3
            
        _redrawLine: ->
            @self.polygon.remove @_lineHash if @_lineHash?
            @_lineHash = @self.polygon.addLine @_pointsList
           
        _createPlacemark: (latitude, longitude) ->
            placemark = @self._ge.createPlacemark ""
            placemark.setName "#{@getSummaryLength()}"
            
            icon = @self._ge.createIcon ""
            icon.setHref "https://maps.google.com/mapfiles/kml/shapes/placemark_circle.png"
            style = @self._ge.createStyle ""
            style.getIconStyle().setIcon icon
            style.getIconStyle().setScale 0.1
            placemark.setStyleSelector style
            
            point = @self._ge.createPoint ""
            point.setLatitude latitude
            point.setLongitude longitude
            placemark.setGeometry point
            
            @_placemark =  @self._ge.getFeatures().appendChild placemark
            
        _removePlacemark: -> @self._ge.getFeatures().removeChild @_placemark if @_placemark?
        
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
    
    countDistance: (point1, point2) ->
        lat1 = point1[0]
        lng1 = point1[1]
        lat2 = point2[0]
        lng2 = point2[1]        
        degToRad = (val) -> val * 0.017453292519943295
        radToDeg = (val) -> val * 57.29577951308232
        
        dist = radToDeg Math.acos((Math.sin(degToRad lat1) * Math.sin(degToRad lat2)) + (Math.cos(degToRad lat1) * Math.cos(degToRad lat2) * Math.cos(degToRad(lng1 - lng2))))
        miles = dist * 60 * 1.1515
        kilometers = (miles * 1.609344).toFixed(3) * 1
        
    _randomHash: (length = 32) ->
        letters = "AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890"
        result = ""
        result += letters[Math.floor(Math.random() * letters.length)] for i in [0...length]
        result
        
    _roundCoordinates: (val) -> val.toFixed(4) * 1
