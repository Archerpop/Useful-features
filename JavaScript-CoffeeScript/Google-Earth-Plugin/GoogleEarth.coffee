class GoogleEarth    
    _divId: null
    _div:  null
    _ge: null    
    _modulesList: ["point", "polygon", "camera", "kml", "yardstick", "layer"]
    
    # Конструктор.
    # {_divId} string - Id блока-обертки для карты.
    # {forceInit} bool - Если true - сразу инициализирует карту, без необходимости вызывать self::init(). По умолчанию false.
    # {callback} function - @see self::init()
    constructor: (@_divId, forceInit = false, callback = null) ->
        @_div = document.getElementById(@_divId)
        google.load "earth", 1, callback: =>
            @init callback if forceInit is true
    
    # Инициализирует объект карты.
    #{callback} function - функция, которая будет вызвана по окончанию загрузки карты.
    init: (callback = null) ->
        google.earth.createInstance @_divId, (instance) => 
            @_ge = instance
            @_ge.getWindow().setVisibility true
            @[module].self = @ for module in @_modulesList
            callback() if typeof callback is "function"
        , (errorCode) ->
            console.log errorCode
        
    # Возвращает DOM-элемент, в котором находится карта.
    getDiv: -> _div
    
    # Удаляет карту.
    # Отключает все слои, удаляет все нанесенные объекты, очищает содержимое обертки карты (@see getDiv()) и уничтожает объект карты.
    destroy: -> 
        @layer.disableAll()
        @clearAll()
        @_div.innerHTML = ""
        delete @_ge
    
    # Очищает карту от нанесенных на нее элементов.
    # Вызывает метод removeAll() для каждого модуля у которого этот метод описан.
    clearAll: ->  @[module].removeAll() for module in @_modulesList when typeof @[module].removeAll is "function"
    
    # Работа со слоями.
    layer:
        # Дороги.
        LAYER_ROADS: "LAYER_ROADS"
        # Границы.
        LAYER_BORDERS: "LAYER_BORDERS"
        # 3D-здания.
        LAYER_BUILDINGS: "LAYER_BUILDINGS"
        # 3D-ланшафт.
        LAYER_TERRAIN: "LAYER_TERRAIN"
        # 3D-деревья.
        LAYER_TREES: "LAYER_TREES"        
        
        _layersState: {}
        
        # Добавляет на карту указанный слой.
        # {layerName} - Название слоя. Необходимо передать одну из вышеперечисленных констант.
        enable: (layerName) -> 
            @self._ge.getLayerRoot().enableLayerById @self._ge[layerName], true
            @_setState layerName, true

        # Удаляет с карты указанный слой.
        # {layerName} - Название слоя. Необходимо передать одну из вышеперечисленных констант.
        disable: (layerName) -> 
            @self._ge.getLayerRoot().enableLayerById @self._ge[layerName], false
            @_setState layerName, false

        # Удаляет или добавляет на карту указанный слой.
        # {layerName} - Название слоя. Необходимо передать одну из вышеперечисленных констант.
        # {newState} bool - Если true - слой будет добавлен, если false - удален. По умолчанию принимает значение, противоположное текущему.
        toggle: (layerName, newState = !@_getState(layerName)) ->
            @self._ge.getLayerRoot().enableLayerById @self._ge[layerName], newState
            @_setState layerName, newState

        # Удаляет с карты все включенные слои.
        disableAll: -> 
            for layer, state of @_layersState
                @disable layer
                @_setState layer, false
            true
            
        _setState: (layerName, newState) -> @_layersState[layerName] = newState
        _getState: (layerName) -> if @_layersState[layerName]? then @_layersState[layerName] else false
    
    # Работа с метками.
    point: 
        _pointsList: {}
        
        # Добавляет на карту метку.
        # {latitude} float - Широта.
        # {longitude} float - Долгота.
        # {name} string - Название метки. По умолчанию null.
        # {iconUrl} string - url-адрес для иконки. Если null - используется стандартная иконка. По умолчанию null.
        add: (latitude, longitude, name = null, iconUrl = null) ->
            placemark = @self._ge.createPlacemark ""
            placemark.setName name if name?
            
            if iconUrl?
                icon = @self._ge.createIcon ""
                icon.setHref iconUrl
                style = @self._ge.createStyle ""
                style.getIconStyle().setIcon icon
                placemark.setStyleSelector style
            
            point = @self._ge.createPoint ""
            point.setLatitude latitude
            point.setLongitude longitude
            placemark.setGeometry point
            
            hash = @self._randomHash()
            @_pointsList[hash] = @self._ge.getFeatures().appendChild placemark
            hash
            
        # Удаляет метку с карты по ее хешу.
        # {hash} string - Хэш метки.
        remove: (hash) ->
            return false if !@_pointsList[hash]?
            @_pointsList[hash] = @self._ge.getFeatures().removeChild @_pointsList[hash]
            delete @_pointsList[hash]
        
        # Удаляет с карты все метки.
        removeAll: -> @remove hash for hash, _ of @_pointsList
        
    # Работа с полигонами.
    polygon: 
        _polygonsList: {}
        
        # Добавляет на карту окружность.
        # {latitude} float - Широта цетра окружности.
        # {longitude} float - Долгота центра окружности.
        # {radius} float - Радиус окружности.
        # {countPoint} int - Колличество точек, используемое дял рисования окружностию Чем больше точек, тем плавнее будет линия.
        # По умолчанию 100.
        # {style} object - Стиль линии рисования. @see self::addLine(). По умолчанию null.
        # Возвращает хэш окружности.
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

        # Добавляет на карту ломанную линию.
        # {pointsList] array - массив точек, по которым будет рисоваться линия. Каждая точка должна быть представленна массивом [latitude, longitude].
        # Где latitude - широта, а longitude - долгота.
        # {style} object - Стиль рисования линии. Должен иметь вид:
        # {
        #     {width} int - толщина линии,
        #     {color} string - цвет линии в формате aabbggrr. (Да,да. Вот такой калечный формат у плагина).
        # }
        # Каждое свойство не обязательно. По умолчанию все свойства пусты.
        # Возвращает хэш линии.
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

        # Удаляет фигуру с карты по ее хешу.
        # {hash} string - Хэш фигуры.
        remove: (hash) ->
            return false if !@_polygonsList[hash]?
            @_polygonsList[hash] = @self._ge.getFeatures().removeChild @_polygonsList[hash]
            delete @_polygonsList[hash]

        # Удаляет с карты все фигуры.
        removeAll: -> @remove hash for hash, _ of @_polygonsList
    
    # Работа с камерой (видом).
    camera: 
        # Возвращает текущее растоложение камеры. 
        # Возвращает объект вида:
        # {
        #     {latitude} float - широта,
        #     {longitude} float - долгота,
        #     {altitude float - высота над поверхностью земли,
        #     {titl} int - наклон камеры относитьльно оси z,
        #     {roll} int - поворот камеры вокруг своей оси,
        #     {speed} float - текущая скорость преемещения камеры,
        # }
        get: ->
            look = @self._ge.getView().copyAsCamera @self._ge.ALTITUDE_RELATIVE_TO_GROUND
            res = 
                latitude: @self._roundCoordinates look.getLatitude()
                longitude: @self._roundCoordinates look.getLongitude()
                altitude: @self._roundCoordinates look.getAltitude()
                titl: look.getTilt()
                roll: look.getRoll()
                speed: @self._ge.getOptions().getFlyToSpeed()
            
        # Устанавливает положение камеры.
        # {latitude} float - дирота.
        # {longitude} float - долгота.
        # {altitude} float - высота над поверхностью земли.
        # {tilt} int - накло камеры относитьльно оси z в градусах. По умолчанию 0.
        # {roll} int - поворот камеры вокруг своей оси в градусах. По умолчанию 0.
        # {speed} float - скорость движения камеры (от 0 до 5.0). По умолчанию 2.5.
        set: (latitude, longitude, altitude, tilt = 0, roll = 0, speed = 2.5) ->
            look = @self._ge.createCamera ""
            look.setLatitude latitude
            look.setLongitude longitude
            look.setAltitude altitude
            look.setTilt tilt
            look.setRoll roll
            @self._ge.getOptions().setFlyToSpeed(if speed > 0.0 then speed else @_ge.SPEED_TELEPORT)
            @self._ge.getView().setAbstractView look
    
    # Работа с kml-файлами.
    kml: 
        _kmlList: {}
        _singleKmlHash: null
        
        # Добавляет на карту содержимое kml-файла.
        # {url} string - ссылка на файл.
        # {forceLookAt} bool - Если true, камера автоматически передвинется на указанное в файле мастоположение. По умолчанию false.
        # Возвращает хэш файла.
        add: (url, forceLookAt = false) ->
            link = @self._ge.createLink ""
            link.setHref url
            networkLink = @self._ge.createNetworkLink ""
            networkLink.set link, true, forceLookAt
            hash = @self._randomHash()
            @_kmlList[hash] = @self._ge.getFeatures().appendChild networkLink
            hash

        # Добавляет на карту содержимое kml-файла. @see self::add().
        # При этом содержимое предыдущего файла, добавленного этим методом, будет удалено с карты.
        # Возвращает хэш файла.
        addSingle: (url, forceLookAt = false) ->
            @remove @_singleKmlHash if @_singleKmlHash?
            @_singleKmlHash = @add url, forceLookAt

        # Удаляет с карты содержимое файла по его хэшу.
        # {hash} string - хэш файла.
        remove: (hash) ->
            return false if !@_kmlList[hash]?
            @_kmlList[hash] = @_ge.getFeatures().removeChild @_kmlList[hash]
            delete @_kmlList[hash]

        # Удаляет с карты содержимое всех файлов.
        removeAll: ->
            @remove hash for hash, _ of @_kmlList
            delete @_singleKmlHash
         
    # Работа с линейкой.
    # Чертит на поверхности земли ломанную линию по указанным координатам и покахывает суммарное расстояние между точками в километрах.
    yardstick:
        _pointsList: []
        _lineHash: null
        _placemark: null
        
        # Добавляет новую точку в конец линиии.
        # {latitude} float - широта.
        # {longitude} float - долгота.
        addPoint: (latitude, longitude) ->
            @_removePlacemark()
            @_pointsList.push [latitude, longitude]
            @_redrawLine()
            @_createPlacemark latitude, longitude
            
        # Очищает линейку.
        clear: ->
            @self.polygon.remove @_lineHash if @_lineHash?
            delete @_lineHash
            @_pointsList = []
            @_removePlacemark()
            
        # Возвращает общую длинну линейки в километрах.
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
        
    # Включает масштабную линейку карты.
    enableScaleLegend: -> @_ge.getOptions().setScaleLegendVisibility true
    # Выключает масштабную линейку карты.
    disableScaleLegend: -> @_ge.getOptions().setScaleLegendVisibility false
    # Включает или выключает шасштабную линейку карты.
    # {newValue} bool Если true - линейка будет включена, если false - выключение. По умолчанию принимает значение противоположное текущему.
    toggleScaleLegend: (newValue = !@_ge.getOptions().getScaleLegendVisibility()) -> @_ge.getOptions().setScaleLegendVisibility newValue
    
    # Включает строку состояния.
    enableStatusBar: -> @_ge.getOptions().setStatusBarVisibility true
    # Выключает строку состояния.
    disableStatusBar: -> @_ge.getOptions().setStatusBarVisibility false
    # Включает или выключает строку состояния.
    # {newValue} bool Если true - строка состояния будет включена, если false - выключение. По умолчанию принимает значение противоположное текущему.
    toggleStatusBar: (newValue = !@_ge.getOptions().getStatusBarVisibility()) -> @_ge.getOptions().setStatusBarVisibility newValue
  
    # Включает миникарту.
    enableOverviewMap: -> @_ge.getOptions().setOverviewMapVisibility true
    # Выключает миникарту.
    disableOverviewMap: -> @_ge.getOptions().setOverviewMapVisibility false
    # Включает или выключает миникарту.
    # {newValue} bool Если true - миникарта будет включена, если false - выключение. По умолчанию принимает значение противоположное текущему.
    toggleOverviewMap: (newValue = !@_ge.getOptions().getOverviewMapVisibility()) -> @_ge.getOptions().setOverviewMapVisibility newValue
    
    # Включает координатную сетку.
    enableGrid: -> @_ge.getOptions().setGridVisibility true
    # Выключает координатную сетку.
    disableGrid: -> @_ge.getOptions().setGridVisibility false
    # Включает или выключает координатную сетку.
    # {newValue} bool Если true - координатная сетка будет включена, если false - выключение. По умолчанию принимает значение противоположное текущему.
    toggleGrid: (newValue = !@_ge.getOptions().getGridVisibility()) -> @_ge.getOptions().setGridVisibility newValue
        
    # Включает элементы навигации. 
    enableNavigationControl: -> @_ge.getNavigationControl().setVisibility @_ge.VISIBILITY_SHOW
    # Выключает элементы навигации. 
    disableNavigationControl: -> @_ge.getNavigationControl().setVisibility @_ge.VISIBILITY_HIDE
    # Включает или выключает элементы навигации.
    # {newValue} bool Если true - элементы навигации будen включены, если false - выключение. По умолчанию принимает значение противоположное текущему.
    toggleNavigationControl: -> @_ge.getNavigationControl().setVisibility(if @_ge.getNavigationControl().getVisibility() is @_ge.VISIBILITY_SHOW then @_ge.VISIBILITY_HIDE else @_ge.VISIBILITY_SHOW)
    
    # Считает расстояние между двумя точками в километрах.
    # {point1, point2} array - точки, между которыми считается расстояние. Каждая точка должна быть представлена в виде [latitude, longitude].
    # Где latitude - широта, а longitude - долгота.
    # Возвращает расстояние в километрах.
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
