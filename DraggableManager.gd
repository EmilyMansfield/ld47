extends Node

class_name DraggableManager

signal drag_start
signal drag_stop
# No static typing for signals because of dynamic connections :(
# https://github.com/godotengine/godot/issues/26045
signal drag_position(draggable, pos)

var active_draggable #: Draggable?
var drag_position: Vector2
# TODO: Use a spatial acceleration structure
var draggables: Array


func add_draggable(drag: Draggable) -> void:
    self.draggables.push_back(drag)
    
    
func refresh_draggables() -> void:
    self.active_draggable = null
    for child in self.get_children():
        if child is Draggable:
            self.draggables.push_back(child)


func find_nearest_draggable(pos: Vector2):
    for drag in self.draggables:
        var aabb = (drag as Draggable).get_aabb()
        var pos3 := Vector3(pos.x, pos.y, 0.0)
        if aabb.has_point(pos3):
            return drag as Draggable
    return null


func find_nearest_draggable_by_dist(pos: Vector2): # -> Draggable?:
    var min_dist_sq := pow(1_000_000.0, 2.0)
    var min_draggable = null
    
    for drag in draggables:
        var dist = pos.distance_squared_to(drag.get_position())
        if dist < min_dist_sq:
            min_draggable = drag
            min_dist_sq = dist

    return min_draggable
        
# Enables overriding the call to _input, which would otherwise be called
# automatically in derived classes
func do_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == BUTTON_LEFT:
            if self.active_draggable:
                self.active_draggable = null
            else:
                self.active_draggable = find_nearest_draggable(event.position)
                if self.active_draggable == null:
                    return
                self.drag_position = self.active_draggable.global_position - event.position
        return
    
    if event is InputEventMouseMotion:
        if self.active_draggable != null:
            var draggable = active_draggable as Draggable
            draggable.set_global_position(event.position - self.drag_position)
    

func _ready() -> void:
    self.refresh_draggables()

func _input(event: InputEvent) -> void:
    do_input(event)
        

func _process(_delta) -> void:
    pass
