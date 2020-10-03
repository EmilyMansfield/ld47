extends Node2D

export var line_width: float = 8.0
export var is_closed: bool = false
export var line_color: Color = Color(0.2, 0.7, 0.9)

# TODO: Get fancy and use Kochanek-Bartels, probably
func get_spline_points(begin: Vector2, end: Vector2) -> PoolVector2Array:
    var num_points := 16
    # No way of reserving memory for given size?
    var points := PoolVector2Array()

    for i in range(num_points):
        var p: Vector2 = lerp(begin, end, float(i) / (num_points - 1))
        points.push_back(p)
    assert(points.size() == num_points)
    return points
    

func draw_spline(begin: Vector2, end: Vector2, color: Color) -> void:
    var points = get_spline_points(begin, end)

    for i in range(points.size() - 1):
        # No named parameters and no inline comments so can't comment name of
        # boolean parameter :(
        # antialias = true
        draw_line(points[i], points[i + 1], color, self.line_width, true)


func get_poly_spline_points() -> PoolVector2Array:
    var points: PoolVector2Array

    var last_drop_index = self.get_child_count() - 2
    if self.is_closed:
        ++last_drop_index

    for i in range(self.get_child_count() - 1):
        var c0 := self.get_child(i) as Node2D
        var c1 := self.get_child(i + 1) as Node2D
        var new_points = get_spline_points(c0.get_position(), c1.get_position())
        if i <= last_drop_index:
            new_points.remove(new_points.size() - 1)
        points.append_array(new_points)
    
    if self.is_closed and self.get_child_count() > 1:
        var c0 := self.get_children().back() as Node2D
        var c1 := self.get_child(0) as Node2D
        var new_points = get_spline_points(c0.get_position(), c1.get_position())
#        new_points.remove(new_points.size() - 1)
        points.append_array(new_points)

    return points


func _draw():
#    var points = get_poly_spline_points()
#    draw_polyline(points, self.line_color, self.line_width, true)
    for i in range(self.get_child_count() - 1):
        var c0 := self.get_child(i) as Node2D
        var c1 := self.get_child(i + 1) as Node2D
        draw_spline(c0.get_position(), c1.get_position(), self.line_color)
        draw_circle(c1.get_position(), self.line_width / 2.0, self.line_color)
    
    if self.is_closed and self.get_child_count() > 1:
        var c0 := self.get_children().back() as Node2D
        var c1 := self.get_child(0) as Node2D
        draw_spline(c0.get_position(), c1.get_position(), self.line_color)
        draw_circle(c1.get_position(), self.line_width / 2.0, self.line_color)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
    self.update()
