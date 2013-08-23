Ext.define "App.base.mixins.CheckTree",
    
    # Change ckecked of {node} and all him child nodes to {checked}-value
    # If {checked}-value is false - all parent nodes will uncheck too.
    changeChecked: (node, checked) ->
        @_checkChildNodes node, checked
        @_uncheckParentNodes node if checked is false
     
    # Uncheck {rootNode} and all him child nodes.   
    clearChecked: (rootNode) ->
        @checkChildNodes rootNode, false
        
    # Return all checked nodes in {node}.
    # Return only leaf nodes if {onliLeaf} is true (by default).
    getCheckedNodes: (node, onlyLeaf = true) ->
        result = []
        result.push node if node.get("checked") is true and (node.get("leaf") is true or onlyLeaf is false)
        result = result.concat @getCheckedNodes(childNode, onlyLeaf) for childNode in node.childNodes
        result
           
    # Check all nodes in {node} which {fieldName} value is in {values} list.
    # Expand parent nodes if {forceExpand} is true (by default).
    checkNodesByFieldValues: (node, fieldName, values = [], forceExpand = true) ->
        if node.get("checked")? and values.indexOf(node.get fieldName) > -1
            node.set("checked", true) 
            @_expandParentNodes node if forceExpand is true
        @checkNodesByFieldValues childNode, fieldName, values, forceExpand for childNode in node.childNodes
    
    _checkChildNodes: (node, checked) ->
        node.set "checked", checked
        @_checkChildNodes(childNode, checked) for childNode in node.childNodes when node.childNodes.length > 0
    
    _uncheckParentNodes: (node) ->
        node.set("checked", false) if node.get("checked") isnt null
        @_uncheckParentNodes node.parentNode if node.parentNode isnt null
        
    _expandParentNodes: (node) ->
        node.expand()
        @_expandParentNodes node.parentNode if node.parentNode isnt null
    
