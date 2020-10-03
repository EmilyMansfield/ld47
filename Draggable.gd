extends Node2D

class_name Draggable

export var draggable_dims := Vector2(16.0, 16.0)

func get_aabb() -> AABB:
    var aabb := AABB()
    var center := Vector3(self.global_position.x, self.global_position.y, 0.0)
    var dims := Vector3(self.draggable_dims.x, self.draggable_dims.y, 100.0)
    aabb.position = center - dims / 2.0
    aabb.size = dims

    return aabb
