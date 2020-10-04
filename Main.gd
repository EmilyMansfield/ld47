extends Node

export var show_debug_menu: bool = OS.is_debug_build()

const levels = [
    "res://levels/Level0Spline.tscn",
    "res://levels/Level1Spline.tscn",
    "res://levels/Level2Spline.tscn",
    "res://levels/Level3Spline.tscn",
   ]

const palette: Array = [
    Color("51e5ff"), Color("440381"), Color("ec368d"), Color("ffa5a5"), Color("ffd6c0")
   ]

var level_spline = null
var is_level_done := false
var num_moves := 0
var num_total_moves := 0
var is_started := false
var current_level := 0


func bump_total_moves() -> void:
    self.num_total_moves += self.num_moves


func set_num_moves(num: int) -> void:
    self.num_moves = num
    $CanvasLayer/MovesLabel.text = String(self.num_total_moves + self.num_moves)
    

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
    level_spline.line_color = self.palette[3]
    $SplineDraggableManager.add_child(level_spline)
    $SplineDraggableManager.refresh_draggables()
    self.level_spline = level_spline
    self.set_num_moves(0)
    self.is_level_done = false

    if self.level_spline.get_target_crossing_number() == 0:
        $CanvasLayer/InstructionLabel.text = "untie the knot"
    else:
        $CanvasLayer/InstructionLabel.text = "make " + String(self.level_spline.get_target_crossing_number()) + " crossings"

    var spline_nodes = self.level_spline.get_children()
    for spline_node in spline_nodes:
        assert (spline_node is Draggable)
        $SplineDraggableManager.add_draggable(spline_node)

    $SplineDraggableManager.connect("drag_position", level_spline, "_on_drag_position")

func start():
    $CanvasLayer/ResetButton.show()
    $CanvasLayer/InstructionLabel.text = "untie the knot"
    $CanvasLayer/MovesLabel.show()
    $CanvasLayer/MovesCaption.show()
    $CanvasLayer/Title.hide()

    self.is_started = true
    reset_spline(self.current_level)
    if show_debug_menu:
        $CanvasLayer/DebugMenu.show()

func _ready():
    $CanvasLayer/DebugMenu.hide()
    $CanvasLayer/ResetButton.hide()
    $CanvasLayer/InstructionLabel.text = "click to start"
    $CanvasLayer/MovesLabel.hide()
    $CanvasLayer/MovesCaption.hide()
    $CanvasLayer/NextButton.hide()


func _on_ResetButton_pressed():
    reset_spline(self.current_level)


func _on_PrintCrossingsButton_pressed():
    var spline := $SplineDraggableManager.get_child(0) as Spline
    var crossing_map := spline.crossing_map
    for c in crossing_map.crossings:
        print((c as Spline.Crossing).idx0, " crosses ", (c as Spline.Crossing).idx1, " with ", (c as Spline.Crossing).lower_idx, " below")


func _on_ToggleDebugButton_pressed():
    var spline := $SplineDraggableManager.get_child(0) as Spline
    spline.show_intersections = !spline.show_intersections


func _on_SplineDraggableManager_drag_start():
    self.set_num_moves(1 + self.num_moves)


func _on_SplineDraggableManager_drag_stop():
    if self.level_spline:
        var s := self.level_spline as Spline
        if self.is_level_done:
            return
        if s.get_crossing_number() == s.get_target_crossing_number():
            self.level_done()

func _input(event: InputEvent) -> void:
    if self.is_started:
        return
    if event is InputEventMouseButton:
        if event.button_index == BUTTON_LEFT:
            self.start()

# pre: self.level_spline != null
func level_done() -> void:
    if self.is_level_done:
        return

    var s := self.level_spline as Spline
    var par_scores := s.get_par_scores()
    assert(par_scores.size() == 3)
    if self.num_moves <= par_scores[0]:
        s.line_color = self.palette[0]
        $Success1Sound.play()
    elif self.num_moves <= par_scores[1]:
        s.line_color = self.palette[1]
        $Success2Sound.play()
    else:
        s.line_color = self.palette[2]
        $Success3Sound.play()

    self.is_level_done = true
    $CanvasLayer/NextButton.show()


func _on_NextButton_pressed():
    self.bump_total_moves()
    self.is_level_done = false
    self.current_level += 1
    if self.current_level < self.levels.size():
        reset_spline(self.current_level)
    else:
        print("Done")
