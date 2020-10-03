extends Node2D

var spline_begin: Vector2
var spline_end: Vector2
export var line_width: float = 8.0

# TODO: Get fancy and use Kochanek-Bartels, probably
func draw_spline(begin: Vector2, end: Vector2, color: Color) -> void:
    var num_points := 16
    # No way of reserving memory for given size?
    var points := PoolVector2Array()

    for i in range(num_points):
        var p: Vector2 = lerp(begin, end, float(i) / (num_points - 1))
        points.push_back(p)

    assert(points.size() == num_points)

    for i in range(num_points - 1):
        # No named parameters and no inline comments so can't comment name of
        # boolean parameter :(
        # antialias = true
        draw_line(points[i], points[i + 1], color, self.line_width, true)


func _draw():
    draw_spline(self.spline_begin, self.spline_end, Color(1.0, 0.0, 0.0))


# Called when the node enters the scene tree for the first time.
func _ready():
    self.spline_begin = ($SplineBegin as Node2D).get_position()
    self.spline_end = ($SplineEnd as Node2D).get_position()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
    # TODO: Use signals don't do this every frame
    self.spline_begin = ($SplineBegin as Node2D).get_position()
    self.spline_end = ($SplineEnd as Node2D).get_position()

    self.update()
