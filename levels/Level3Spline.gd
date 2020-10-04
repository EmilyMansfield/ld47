extends Spline

func get_lower_idx(crossing: Spline.Crossing) -> int:
    if crossing.involves(0, 7):
        return 7
    if crossing.involves(0, 3):
        return 3
    if crossing.involves(0, 9):
        return 9
    if crossing.involves(1, 6):
        return 1
    if crossing.involves(3, 6):
        return 6
    if crossing.involves(3, 9):
        return 9
    if crossing.involves(4, 8):
        return 8
    if crossing.involves(6, 9):
        return 9
    return crossing.idx0


func get_par_scores() -> Array:
    return [2, 3, 4]


func get_target_crossing_number() -> int:
    return 3
