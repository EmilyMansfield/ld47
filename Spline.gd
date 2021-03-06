extends Node2D

class_name Spline

export var line_width: float = 8.0
export var is_closed: bool = false
export var line_color: Color = Color(0.2, 0.7, 0.9)
export var show_intersections: bool = false

#var palette: Array = [
#    Color(1.0, 0.0, 0.0), Color(0.0, 1.0, 0.0), Color(0.0, 0.0, 1.0),
#    Color(0.0, 1.0, 1.0), Color(1.0, 0.0, 1.0), Color(1.0, 1.0, 0.0)
#]

class Crossing:
    var pos: Vector2
        
    var t0: float
    var t1: float
    
    var idx0: int
    var idx1: int
    var lower_idx: int

    func involves(p_idx0: int, p_idx1: int) -> bool:
        return (self.idx0 == p_idx0 and self.idx1 == p_idx1) or (self.idx0 == p_idx1 and self.idx1 == p_idx0)
 
    func get_lower_index() -> int:
        return self.lower_idx
    
    func get_upper_index() -> int:
        return self.idx1 if self.lower_idx == idx0 else self.idx0

    func duplicate() -> Crossing:
        var tmp := Crossing.new()
        tmp.pos = self.pos
        tmp.t0 = self.t0
        tmp.t1 = self.t1
        tmp.idx0 = self.idx0
        tmp.idx1 = self.idx1
        tmp.lower_idx = self.lower_idx
        return tmp


class CrossingMap:
    # Array of all actual crossings, deduplicated
    var crossings: Array = []
    # Array of arrays where element i of the outer array is an array of all
    # crossings involving spline segment i.
    var per_line_crossings: Array = []


var crossing_map: CrossingMap
var invalid_move_normals := [] # Array[Vector2]
var invalid_move_offsets := [] # [Vector2]


# Override in derived classes
func get_lower_idx(crossing: Crossing) -> int:
    return crossing.idx0


# Override in derived classes
func get_par_scores() -> Array:
    return [1_000_000, 1_000_000, 1_000_000]


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


func get_spline_points_avoid_intersection(idx: int, begin: Vector2, end: Vector2) -> Array:
    # Guideline, won't be correct if there are intersections
    var num_points := 16
    var points_collection := []
    var points := PoolVector2Array()

    if self.crossing_map.per_line_crossings.empty():
        return [get_spline_points(begin, end)]

    var crossings := self.crossing_map.per_line_crossings[idx] as Array
    if crossings.empty():
        return [get_spline_points(begin, end)]
    
    var crossing_idx := 0
    var crossing := self.crossing_map.crossings[crossings[crossing_idx]] as Crossing
    var delta_t = 1.0 / (num_points - 1)
    var t := 0.0
    while t <= 1.0:
        var crossing_t := crossing.t0 if idx == crossing.idx0 else crossing.t1
        if t > crossing_t or (t + delta_t < crossing_t):
            var p: Vector2 = interp_spline(begin, end, t)
            points.push_back(p)
        else:
            # crossing_t lies between two steps
            # If we're on top then can just continue
            if crossing.lower_idx == idx:
                # Since want to remove an absolute length but have a t value, need
                # to solve ||f(t0 + eps) - f(t0 - eps)|| = delta where delta is the
                # target gap size world space, t0 is the center of the gap, and
                # eps is the target gap size in parameter space. For non-constant
                # speed parameterizations this probably won't look too great...
                var delta := 4.0 * self.line_width
                var eps := delta / (2.0 * (end - begin).length())
                var p0 := interp_spline(begin, end, crossing_t - eps)
                var p1 := interp_spline(begin, end, crossing_t + eps)
                points.push_back(p0)
                points_collection.push_back(points)
                points = PoolVector2Array()
                points.push_back(p1)
                while (t + delta_t < crossing_t + eps):
                    t += delta_t
            else:
                var p: Vector2 = interp_spline(begin, end, t)
                points.push_back(p)

            if crossing_idx + 1 < crossings.size():
                crossing_idx += 1
                crossing = self.crossing_map.crossings[crossings[crossing_idx]] as Crossing

        t += delta_t
    
    points_collection.push_back(points)
    return points_collection


func draw_spline(begin: Vector2, end: Vector2, color: Color) -> void:
    var points = get_spline_points(begin, end)

    for i in range(points.size() - 1):
        # No named parameters and no inline comments so can't comment name of
        # boolean parameter :(
        # antialias = true
        draw_line(points[i], points[i + 1], color, self.line_width, true)


func draw_spline_avoid_intersection(idx: int, begin: Vector2, end: Vector2, color: Color) -> void:
    var points_collection = get_spline_points_avoid_intersection(idx, begin, end)
    
    for segment in points_collection:
        for i in range(segment.size() - 1):
            draw_line(segment[i], segment[i + 1], color, self.line_width, true)


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
        

func get_segment_begin(idx: int) -> Node2D:
    assert(0 <= idx and idx <= get_segment_count())
    return self.get_child(idx) as Node2D
    
    
func get_segment_end(idx: int) -> Node2D:
    assert(0 <= idx && idx <= get_segment_count())
    if idx < self.get_child_count() - 1:
        return self.get_child(idx + 1) as Node2D
    else:
        assert(self.is_closed)
        return self.get_child(0) as Node2D


# TODO: Customization point for fancy splines
func get_overlapping_segment(pos: Vector2):
    # Check if pos (global position) lies on any of the spline segments
    for i in range(get_segment_count()):
        var c0 := get_segment_begin(i)
        var c1 := get_segment_end(i)
        var p := Geometry.get_closest_point_to_segment_2d(pos, c0.get_global_position(), c1.get_global_position())
        if p.distance_squared_to(pos) <= pow(self.line_width * 2.0, 2.0):
            return [c0, c1]
    return null

    
# TODO: Customization point for fancy splines
func check_crossing(idx0: int, idx1: int):
    if (idx0 + 1) % get_segment_count() == idx1:
        return null
    if (idx1 + 1) % get_segment_count() == idx0:
        return null

    # Segment 0
    var c0 := get_segment_begin(idx0)
    var c1 := get_segment_end(idx0)
    var p0 := c0.get_position()
    var p1 := c1.get_position()
#    p1 = interp_spline(p0, p1, 1.0)

    # Segment 1
    var d0 := get_segment_begin(idx1)
    var d1 := get_segment_end(idx1)
    var q0 := d0.get_position()
    var q1 := d1.get_position()
#    q1 = interp_spline(q0, q1, 1.0)
    
    return Geometry.segment_intersects_segment_2d(p0, p1, q0, q1)

# TODO: Customization point for fancy splines
# pre: pos lies on segment idx
func get_parameter_from_point(idx: int, pos: Vector2) -> float:
    var c0 := get_segment_begin(idx)
    var c1 := get_segment_end(idx)
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
    var c0 := self.get_segment_begin(idx)
    var c1 := self.get_segment_end(idx)
    var p0 := c0.get_position()
    var p1 := c1.get_position()

    return interp_spline(p0, p1, t)


func build_candidate_crossings(crossing: Crossing) -> Array:
    var candidate_crossings := []
    for oc in self.crossing_map.crossings:
        var old_crossing := oc as Crossing
        if old_crossing.idx0 == crossing.idx0 and old_crossing.idx1 == crossing.idx1:
            candidate_crossings.push_back(old_crossing)
        elif old_crossing.idx0 == crossing.idx1 and old_crossing.idx1 == crossing.idx0:
            var tmp_crossing := old_crossing.duplicate()
            # No swap function, and can't write one because
            # references will just be reassigned and builtin types
            # are unconditionally passed by value :(
            var tmp := tmp_crossing.idx0
            tmp_crossing.idx0 = tmp_crossing.idx1
            tmp_crossing.idx1 = tmp
            tmp = tmp_crossing.t0
            tmp_crossing.t0 = tmp_crossing.t1
            tmp_crossing.t1 = tmp
            candidate_crossings.push_back(old_crossing)
    return candidate_crossings


func find_closest_candidate_by_t(candidate_crossings: Array, crossing: Crossing) -> Crossing:
    var candidate_crossing = null
    var min_t_dist := 1_000_000.0
    for candidate in candidate_crossings:
        var t_dist := abs(crossing.t0 - candidate.t0) + abs(crossing.t1 - candidate.t1)
        if t_dist < min_t_dist:
            candidate_crossing = candidate
            min_t_dist = t_dist
    assert(candidate_crossing != null)
    return candidate_crossing


func get_crossings() -> CrossingMap:
   
    # To keep lower indices continuous must identify old crossings with new
    # ones and find which ones have appeared/disappeared. This can only be done
    # after all crossings have been found to avoid ordering issues.
    var deferred_crossings := []
    for i in range(get_segment_count()):
        for j in range(i + 1, get_segment_count()):
            var p = check_crossing(i, j)
            if not (p is Vector2):
                continue
            var t_i := get_parameter_from_point(i, p as Vector2)
            var t_j := get_parameter_from_point(j, p as Vector2)

            var crossing := Crossing.new()
            crossing.idx0 = i
            crossing.idx1 = j
            crossing.t0 = t_i
            crossing.t1 = t_j
            crossing.pos = p as Vector2
            
            deferred_crossings.push_back(crossing)
    
    var resolved_crossings := []
    
    # For each existing crossing, find the deferred crossing that is closest to
    # it and has the same intersections (in any order).
    # Is it true that a new crossing that is closer to any existing crossing
    # than the image of the existing crossing under the move, cannot appear?
    
    if self.crossing_map == null:
        # No crossings yet, assign them from the initial state.
        for dc in deferred_crossings:
            var deferred_crossing := dc as Crossing
            # TODO: Set from initial state
            deferred_crossing.lower_idx = get_lower_idx(deferred_crossing)
            resolved_crossings.push_back(deferred_crossing)
        deferred_crossings.clear()
    else:
        var old_crossings := []
        for oc in self.crossing_map.crossings:
            var old_crossing := oc as Crossing
            var min_t_dist := 1_000_000.0
            var min_crossing = null
            for dc in deferred_crossings:
                var deferred_crossing := dc as Crossing
                var same_indices := old_crossing.idx0 == deferred_crossing.idx0 and old_crossing.idx1 == deferred_crossing.idx1
                var opp_indices := old_crossing.idx0 == deferred_crossing.idx1 and old_crossing.idx1 == deferred_crossing.idx0
                if (not same_indices) and (not opp_indices):
                    continue
                # Same segments contributing to the intersection so this is a
                # candidate
                var t_dist := 0.0
                if same_indices:
                    t_dist = abs(old_crossing.t0 - deferred_crossing.t0) + abs(old_crossing.t1 - deferred_crossing.t1)
                elif opp_indices:
                    t_dist = abs(old_crossing.t0 - deferred_crossing.t1) + abs(old_crossing.t1 - deferred_crossing.t0)
                if t_dist < min_t_dist:
                    min_crossing = deferred_crossing
        
            if min_crossing == null:
                # No match, may have disappeared or gone round a corner. Add it to
                # the list so that end result is old_crossings contains all old
                # crossings that haven't been resolved, basically the set removal
                # below without actually removing anything
                old_crossings.push_back(old_crossing)
            else:
                var i := deferred_crossings.find(min_crossing)
                deferred_crossings.remove(i)
                min_crossing.lower_idx = old_crossing.lower_idx
                resolved_crossings.push_back(min_crossing)
        
        # If old crossings that weren't matched, try to match them up to any 
        # unmatched new crossings by proximinity.
        for oc in old_crossings:
            var old_crossing := oc as Crossing
            var min_dist := 1_000_000
            var min_crossing = null
            for dc in deferred_crossings:
                var deferred_crossing := dc as Crossing
                var dist := deferred_crossing.pos.distance_to(old_crossing.pos)
                if dist < min_dist:
                    min_crossing = deferred_crossing
                    min_dist = dist
                    # TODO: Pretty sure this is broken; what if a new crossing appears
                    #       near the old disappearing crossing and it isn't a corner?
                    #       Can that even happen?
            
            if min_crossing != null:
                # Corner
                var i := deferred_crossings.find(min_crossing)
                deferred_crossings.remove(i)
                # Crossing has moved around a corner so one of the indices
                # should match but the other won't. If the one that matches is
                # the lower index it should stay lower, otherwise it is upper
                # and stays upper.
                if old_crossing.lower_idx == old_crossing.idx0:
                    if min_crossing.idx0 == old_crossing.lower_idx:
                        min_crossing.lower_idx = old_crossing.lower_idx
                    elif min_crossing.idx1 == old_crossing.lower_idx:
                        min_crossing.lower_idx = old_crossing.lower_idx
                    else:
                        var upper_idx := old_crossing.idx1
                        min_crossing.lower_idx = min_crossing.idx1 if min_crossing.idx0 == upper_idx else min_crossing.idx0
                else:
                    if min_crossing.idx0 == old_crossing.lower_idx:
                        min_crossing.lower_idx = old_crossing.lower_idx
                    elif min_crossing.idx1 == old_crossing.lower_idx:
                        min_crossing.lower_idx = old_crossing.lower_idx
                    else:
                        var upper_idx := old_crossing.idx0
                        min_crossing.lower_idx = min_crossing.idx1 if min_crossing.idx0 == upper_idx else min_crossing.idx0

                resolved_crossings.push_back(min_crossing)
    
        # All old crossings have been matched to ones on the same edge, ones around
        # a corner, or have been removed entirely. Any remaining deferred crossings
        # must be new.
        for dc in deferred_crossings:
            var deferred_crossing := dc as Crossing
            # TODO: Set index based on player input, whether new intersection is
            #       above or below
            deferred_crossing.lower_idx = deferred_crossing.idx0
            resolved_crossings.push_back(deferred_crossing)
        deferred_crossings.clear()
    
    assert(deferred_crossings.empty())

    # All crossings resolved, add them
    var crossing_map := CrossingMap.new()
    var crossing_idx := 0
    for _i in range(get_segment_count()):
        crossing_map.per_line_crossings.push_back([])
    
    for crossing in resolved_crossings:
        crossing_map.crossings.push_back(crossing)
        
        crossing_map.per_line_crossings[crossing.idx0].push_back(crossing_idx)
        crossing_map.per_line_crossings[crossing.idx1].push_back(crossing_idx)
        crossing_idx += 1
        
    # Sort the per_line_crossings for each line into increasing t order so that
    # traversal along the line coincides with traversal along the crossings of
    # that line. This helps rendering gaps around crossings.
    for i in range(get_segment_count()):
        var sorter = CrossingSorter.new(i, crossing_map)
        crossing_map.per_line_crossings[i].sort_custom(sorter, "sort")
    
    return crossing_map


class CrossingSorter:
    var idx: int
    var crossing_map: CrossingMap

    func _init(p_idx: int, p_crossing_map: CrossingMap):
        self.idx = p_idx
        self.crossing_map = p_crossing_map

    func sort(a: int, b: int) -> bool:
        var ca: Crossing = self.crossing_map.crossings[a]
        var cb: Crossing = self.crossing_map.crossings[b]
        var ta := ca.t0 if ca.idx0 == self.idx else ca.t1
        var tb := cb.t0 if cb.idx0 == self.idx else cb.t1
        return ta < tb
        

func get_crossing_number() -> int:
    return self.crossing_map.crossings.size()

    

func _ready() -> void:
    self.crossing_map = get_crossings()
    for c in self.crossing_map.crossings:
        print((c as Crossing).idx0, " crosses ", (c as Crossing).idx1, " with ", (c as Crossing).lower_idx, " below")


func _draw():
    for i in range(self.get_child_count() - 1):
        var c0 := self.get_child(i) as Node2D
        var c1 := self.get_child(i + 1) as Node2D
        draw_spline_avoid_intersection(i, c0.get_position(), c1.get_position(), self.line_color)
        draw_circle(c1.get_position(), self.line_width / 2.0, self.line_color)
    
    if self.is_closed and self.get_child_count() > 1:
        var c0 := self.get_children().back() as Node2D
        var c1 := self.get_child(0) as Node2D
        draw_spline_avoid_intersection(self.get_segment_count() - 1, c0.get_position(), c1.get_position(), self.line_color)
        draw_circle(c1.get_position(), self.line_width / 2.0, self.line_color)

    if self.show_intersections:
        var crossing_points := []
        for c in self.crossing_map.crossings:
            crossing_points.push_back(c.pos)
    
        if self.show_intersections:
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


func _on_drag_position(draggable: Draggable, pos: Vector2) -> void:
    var pos0 := draggable.get_global_position()
    var crossing_map0 := self.crossing_map

    draggable.set_global_position(pos)
    if not self.invalid_move_normals.empty() and not self.invalid_move_offsets.empty():
        assert(self.invalid_move_normals.size() == self.invalid_move_offsets.size())
        for i in range(self.invalid_move_normals.size()):
            var normal: Vector2 = self.invalid_move_normals[i]
            var offset: Vector2 = self.invalid_move_offsets[i]
            var q := pos - offset
            if q.dot(normal) <= 0:
                # Invalid move
                draggable.set_global_position(pos0)
                return

    self.crossing_map = get_crossings()

    var num_crossing_points := self.crossing_map.crossings.size()
    for i in range(num_crossing_points):
        var p: Vector2 = self.crossing_map.crossings[i].pos

        for j in range(i + 1, num_crossing_points):
            var q: Vector2 = self.crossing_map.crossings[j].pos

            # Edge can pass over if the same line is above (below) both
            # crossings. That is, either the lower_idxs agree, or they disagree
            # and the remaining indices agree.
            var lower_segments := [
                self.crossing_map.crossings[i].get_lower_index(),
                self.crossing_map.crossings[j].get_lower_index(),
               ]
            var upper_segments := [
                self.crossing_map.crossings[i].get_upper_index(),
                self.crossing_map.crossings[j].get_upper_index(),
               ]
            var same_side: bool = (lower_segments[0] == lower_segments[1]
                                or upper_segments[0] == upper_segments[1])
            
            if not same_side and p.distance_squared_to(q) <= pow(2.0 * self.line_width, 2.0):
                # Points too close, invalid move. Define a union of half-planes
                # symmetric about the current direction of motion that cannot
                # be moved through. Like #/^\# if that makes any sense.
                draggable.set_global_position(pos0)
                self.crossing_map = crossing_map0
                var normal := (pos0 - pos).normalized()
                var offset := pos
                # No idea which way this rotates, but it's symmetric so oh well
                self.invalid_move_normals = [
                    normal.rotated(-0.1),
                    normal.rotated(+0.1),
                   ]
                self.invalid_move_offsets = [
                    offset, offset
                   ]
                return

    # Valid move, can clear exclusion half-space
    self.invalid_move_normals.clear()
    self.invalid_move_offsets.clear()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
#    self.crossing_map = get_crossings()

    self.update()


###############################################################################
# UNUSED!
###############################################################################

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
