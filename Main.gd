extends Node


func _ready():
    var spline_nodes = $SplineDraggableManager/Spline.get_children()
    for spline_node in spline_nodes:
        assert (spline_node is Draggable)
        $SplineDraggableManager.add_draggable(spline_node)
