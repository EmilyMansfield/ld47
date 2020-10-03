extends Node

const levels = [
    "res://levels/TestSpline.tscn"
   ]

func reset_spline(level_idx: int):
    assert(0 <= level_idx and level_idx <= levels.size())
    
    for child in $SplineDraggableManager.get_children():
        child.queue_free()

    var level_name: String = self.levels[level_idx]
    var level_spline: Spline = load(level_name).instance()
    level_spline.position = get_viewport().size / 2.0
    level_spline.is_closed = true
    $SplineDraggableManager.add_child(level_spline)
    $SplineDraggableManager.refresh_draggables()

    var spline_nodes = level_spline.get_children()
    for spline_node in spline_nodes:
        assert (spline_node is Draggable)
        $SplineDraggableManager.add_draggable(spline_node)

    $SplineDraggableManager.connect("drag_position", level_spline, "_on_drag_position")


func _ready():
    reset_spline(0)


func _on_ResetButton_pressed():
    reset_spline(0)
