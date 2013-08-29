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
    
    constructor: (@_divId) ->
        @_div = document.getElementById(@_divId)
        google.earth.createInstance @_divId, (instance) => 
            @_ge = instance
            @_ge.getWindow().setVisibility(true)
    
    destroy: -> 
        @disableAllLayer()
        delete @_ge
        @_div.innerHTML = ""
        
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
    
    getDiv: -> _div
    
    _setLayerState: (layerName, newState) -> @_layersState[layerName] = newState
    _getLayerState: (layerName) -> if @_layersState[layerName]? then @_layersState[layerName] else false
