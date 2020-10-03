extends Node


func _ready():
    var spline_nodes = $DraggableManager/Spline.get_children()
    for spline_node in spline_nodes:
        assert (spline_node is Draggable)
        $DraggableManager.add_draggable(spline_node)
