extends DraggableManager

const Spline = preload("res://Spline.gd")

var active_draggable_segment
var segment_drag_position0: Vector2
var segment_drag_position1: Vector2


func find_nearest_line(pos: Vector2):
    # Children are Splines, which are not Draggable (though their children are),
    # but nonetheless can be dragged in groups. This design is terrible, but
    # what can you expect?
    for child in self.get_children():
        if not child is Spline:
            continue
        var spline := child as Spline
        var segment = spline.get_overlapping_segment(pos)
        if segment == null:
            continue
        assert ((segment as Array).size() == 2)
        return segment

    return null

    

func do_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == BUTTON_LEFT:
            if self.active_draggable or self.active_draggable_segment:
                emit_signal("drag_stop")
                self.active_draggable = null
                self.active_draggable_segment = null
            elif event.pressed:
                self.active_draggable = find_nearest_draggable(event.position)
                if self.active_draggable != null:
                    self.drag_position = event.position - self.active_draggable.global_position
                    emit_signal("drag_start")
                    return
                # No draggable, but if on a line then move the entire line
                # instead
                self.active_draggable_segment = self.find_nearest_line(event.position)
                if self.active_draggable_segment != null:
                    self.segment_drag_position0 = event.position - self.active_draggable_segment[0].get_global_position()
                    self.segment_drag_position1 = event.position - self.active_draggable_segment[1].get_global_position() 
                    emit_signal("drag_start")
                    return
        return
    
    if event is InputEventMouseMotion:
        if self.active_draggable != null:
            var draggable = active_draggable as Draggable
            emit_signal("drag_position", draggable, event.position - self.drag_position)
            # draggable.set_global_position(event.position - self.drag_position)
            return
        if self.active_draggable_segment != null:
            var c0 := self.active_draggable_segment[0] as Draggable
            var c1 := self.active_draggable_segment[1] as Draggable
            emit_signal("drag_position", c0, event.position - self.segment_drag_position0)
            emit_signal("drag_position", c1, event.position - self.segment_drag_position1)
            #c0.set_global_position(event.position - self.segment_drag_position0)
            #c1.set_global_position(event.position - self.segment_drag_position1)
            return
        
