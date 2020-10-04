extends Node

export var show_debug_menu: bool = OS.is_debug_build()

const levels = [
    "res://levels/TestSpline.tscn"
   ]

func reset_spline(level_idx: int):
    assert(0 <= level_idx and level_idx <= levels.size())

    var show_intersections := false
    if $SplineDraggableManager.get_child_count() > 0:
        var spline := $SplineDraggableManager.get_child(0) as Spline
        show_intersections = spline.show_intersections

    for child in $SplineDraggableManager.get_children():
        child.queue_free()

    var level_name: String = self.levels[level_idx]
    var level_spline: Spline = load(level_name).instance()
    level_spline.position = get_viewport().size / 2.0
    level_spline.is_closed = true
    level_spline.show_intersections = show_intersections
    $SplineDraggableManager.add_child(level_spline)
    $SplineDraggableManager.refresh_draggables()

    var spline_nodes = level_spline.get_children()
    for spline_node in spline_nodes:
        assert (spline_node is Draggable)
        $SplineDraggableManager.add_draggable(spline_node)

    $SplineDraggableManager.connect("drag_position", level_spline, "_on_drag_position")


func _ready():
    reset_spline(0)
    
    if not show_debug_menu:
        $CanvasLayer/DebugMenu.hide()


func _on_ResetButton_pressed():
    reset_spline(0)


func _on_PrintCrossingsButton_pressed():
    var spline := $SplineDraggableManager.get_child(0) as Spline
    var crossing_map := spline.crossing_map
    for c in crossing_map.crossings:
        print((c as Spline.Crossing).idx0, " crosses ", (c as Spline.Crossing).idx1, " with ", (c as Spline.Crossing).lower_idx, " below")


func _on_ToggleDebugButton_pressed():
    var spline := $SplineDraggableManager.get_child(0) as Spline
    spline.show_intersections = !spline.show_intersections
