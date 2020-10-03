extends Node2D

export var line_width: float = 8.0
export var is_closed: bool = false
export var line_color: Color = Color(0.2, 0.7, 0.9)


class Crossing:
    var pos: Vector2
        
    var t0: float
    var t1: float
    
    var idx0: int
    var idx1: int
    var lower_idx: int


class CrossingMap:
    # Array of all actual crossings, deduplicated
    var crossings: Array = []
    # Array of arrays where element i of the outer array is an array of all
    # crossings involving spline segment i.
    var per_line_crossings: Array = []


var crossing_map: CrossingMap

# TODO: Get fancy and use Kochanek-Bartels, probably
func get_spline_points(begin: Vector2, end: Vector2) -> PoolVector2Array:
    var num_points := 16
    # No way of reserving memory for given size?
    var points := PoolVector2Array()

    for i in range(num_points):
        var p: Vector2 = interp_spline(begin, end, float(i) / (num_points - 1))
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
    var points := PoolVector2Array()

    var last_drop_index = self.get_child_count() - 2
    if self.is_closed:
        last_drop_index += 1

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


func interp_spline(begin: Vector2, end: Vector2, t: float) -> Vector2:
    return lerp(begin, end, t)


func get_spline_tangent(begin: Vector2, end: Vector2, _t: float) -> Vector2:
    return (end - begin).normalized()


func get_spline_normal(begin: Vector2, end: Vector2, _t: float) -> Vector2:
    # Can't use tangent() since direction is not specified.
    # Rotate 90 degrees ac
    var tangent := end - begin
    var normal := Vector2(-tangent.y, tangent.x)
    return normal.normalized()


func get_segment_count() -> int:
    if self.is_closed:
        return self.get_child_count()
    else:
        return self.get_child_count() - 1
        

# TODO: Customization point for fancy splines
func check_crossing(idx0: int, idx1: int):
    # Segment 0
    var c0 := self.get_child(idx0) as Node2D
    var c1: Node2D
    if idx0 < self.get_child_count() - 1:
        c1 = self.get_child(idx0 + 1) as Node2D
    else:
        assert(self.is_closed)
        c1 = self.get_child(0) as Node2D
    var p0 := c0.get_position()
    var p1 := c1.get_position()
    p1 = interp_spline(p0, p1, 0.99)

    # Segment 1
    var d0 := self.get_child(idx1) as Node2D
    var d1: Node2D
    if idx1 < self.get_child_count() - 1:
        d1 = self.get_child(idx1 + 1) as Node2D
    else:
        assert(self.is_closed)
        d1 = self.get_child(0) as Node2D
    var q0 := d0.get_position()
    var q1 := d1.get_position()
    q1 = interp_spline(q0, q1, 0.99)
    
    return Geometry.segment_intersects_segment_2d(p0, p1, q0, q1)

# TODO: Customization point for fancy splines
# pre: pos lies on segment idx
func get_parameter_from_point(idx: int, pos: Vector2) -> float:
    var c0 := self.get_child(idx) as Node2D
    var c1: Node2D
    if idx < self.get_child_count() - 1:
        c1 = self.get_child(idx + 1) as Node2D
    else:
        assert(self.is_closed)
        c1 = self.get_child(0) as Node2D
    var p0 := c0.get_position()
    var p1 := c1.get_position()
    
    var delta := p1 - p0
    if abs(delta.x) >= abs(delta.y):
        var t := (pos.x - p0.x) / delta.x
        return t
    else:
        var t := (pos.y - p0.y) / delta.y
        return t
        
# TODO: Customization point for fancy splines
func get_point_from_parameter(idx: int, t: float) -> Vector2:
    var c0 := self.get_child(idx) as Node2D
    var c1: Node2D
    if idx < self.get_child_count() - 1:
        c1 = self.get_child(idx + 1) as Node2D
    else:
        assert(self.is_closed)
        c1 = self.get_child(0) as Node2D
    var p0 := c0.get_position()
    var p1 := c1.get_position()

    return interp_spline(p0, p1, t)


func get_crossings() -> CrossingMap:
    var crossing_map := CrossingMap.new()

    for _i in range(get_segment_count()):
        crossing_map.per_line_crossings.push_back([])

    for i in range(get_segment_count()):
        for j in range(i + 1, get_segment_count()):
            var p = check_crossing(i, j)
            if not (p is Vector2):
                continue
            var t_i := get_parameter_from_point(i, p as Vector2)
            var t_j := get_parameter_from_point(j, p as Vector2)
            
            var crossing_idx := crossing_map.crossings.size()
            var crossing := Crossing.new()
            crossing.idx0 = i
            crossing.idx1 = j
            crossing.t0 = t_i
            crossing.t1 = t_j
            crossing.pos = p as Vector2
            # TODO: Lower indx!
            crossing.lower_idx = 0
            crossing_map.crossings.push_back(crossing)
            
            crossing_map.per_line_crossings[i].push_back(crossing_idx)
            crossing_map.per_line_crossings[j].push_back(crossing_idx)

    return crossing_map

func get_crossing_number() -> int:
    return self.crossing_map.crossings.size()

func _ready() -> void:
    self.crossing_map = CrossingMap.new()

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

    var crossing_points := []
    for c in self.crossing_map.crossings:
        crossing_points.push_back(c.pos)

    for p in crossing_points:
        draw_circle(p, self.line_width / 2.0, Color(1.0, 1.0, 1.0))
    
    var num_crossing_points := crossing_points.size()
    for i in range(num_crossing_points):
        var p: Vector2 = crossing_points[i]
        for j in range(i + 1, num_crossing_points):
            var q: Vector2 = crossing_points[j]
            var dist2 := p.distance_squared_to(q)
            if dist2 <= pow(2.0 * self.line_width, 2.0):
                draw_circle((p + q) / 2.0, 2.0 * self.line_width, Color(1.0, 0.2, 0.3))


    
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
    var cols := [Color(1.0, 0.0, 0.0), Color(0.0, 1.0, 0.0), Color(0.0, 0.0, 1.0),
                 Color(0.0, 1.0, 1.0), Color(1.0, 0.0, 1.0), Color(1.0, 1.0, 0.0)]
    self.crossing_map = get_crossings()
    
    #self.line_color = cols[self.get_crossing_number() % 6]
    self.update()


###############################################################################
# UNUSED!
###############################################################################

# UNUSED!
func check_crossing_circle(idx: int, t: float, radius: float) -> int:
    assert (0 <= t and t <= 1)
    var c0 := self.get_child(idx) as Node2D
    var c1: Node2D
    if idx < self.get_child_count() - 1:
        c1 = self.get_child(idx + 1) as Node2D
    else:
        assert(self.is_closed)
        c1 = self.get_child(0) as Node2D
    
    var p0 := c0.get_position()
    var p1 := c1.get_position()
    var pos := interp_spline(p0, p1, t)
    
    for i in range(get_segment_count()):
        if i == idx:
            continue
            
        var s := spline_intersects_circle(i, pos, radius)
        if s >= 0.0 and s <= 1.0:
            return i

    return -1
    

# Use dumbbell construction at t along line idx with separation sep and dumbbell
# size dims to check for crossing point, returning the number of intersections
# of the dumbbells with the lines.
# UNUSED!
func check_crossing_db(idx: int, t: float, sep: float, dims: Vector2) -> int:
    assert (0 <= t and t <= 1)
    var c0 := self.get_child(idx) as Node2D
    var c1: Node2D
    if idx < self.get_child_count() - 1:
        c1 = self.get_child(idx) as Node2D
    else:
        assert(self.is_closed)
        c1 = self.get_child(0) as Node2D
    
    var p0 := c0.get_position()
    var p1 := c1.get_position()
    var pos := interp_spline(p0, p1, t)
    
    # Both dumbbells have the same orientation, to make the aabbs need to rotate
    # the world so that the tangent lies along an axis. By construction spline
    # tangent is normalized so
    var tangent := get_spline_tangent(p0, p1, t)
    var trans := Transform2D(Vector2(tangent.x, -tangent.y),
                             Vector2(tangent.y, tangent.x),
                             Vector2(0.0, 0.0))
    var aabb_a := AABB(Vector3(pos.x - dims.x / 2.0, pos.y + sep / 2.0, 0.0),
                       Vector3(dims.x, dims.y, 100.0))
    var aabb_b := AABB(Vector3(pos.x - dims.x / 2.0, pos.y - sep / 2.0 - dims.y, 0.0),
                       Vector3(dims.x, dims.y, 100.0))
    
    # TODO: Improve the t step to be unit length with dims size

    for i in range(self.get_child_count() - 1):
        var d0 := self.get_child(i) as Node2D
        var d1 := self.get_child(i + 1) as Node2D
        var q0 := d0.get_position()
        var q1 := d1.get_position()
        
        var entered_a := false
        var entered_b := false
        var s := 0.0
        while (s <= 1.0):
            var q := interp_spline(q0, q1, s)
            var q_p := trans * q
            var q_p3 := Vector3(q_p.x, q_p.y, 0.0)
            if aabb_a.has_point(q_p3):
                entered_a = true
            elif aabb_b.has_point(q_p3):
                entered_b = true
            s += 0.1
        
        return (1 if entered_a else 0) + (1 if entered_b else 0)
    return 0
    

# UNUSED!
func spline_intersects_circle(idx: int, pos: Vector2, r: float) -> float:
    var c0 := self.get_child(idx) as Node2D
    var c1: Node2D
    if idx < self.get_child_count() - 1:
        c1 = self.get_child(idx + 1) as Node2D
    else:
        assert(self.is_closed)
        c1 = self.get_child(0) as Node2D

    return Geometry.segment_intersects_circle(c0.get_position(),
                                              c1.get_position(),
                                              pos, r)
