extends Spline

func get_lower_idx(crossing: Spline.Crossing) -> int:
    if crossing.involves(0, 5):
        return 5
    if crossing.involves(2, 0):
        return 2
    if crossing.involves(3, 5):
        return 3
    if crossing.involves(3, 8):
        return 8
    if crossing.involves(6, 8):
        return 6
    return crossing.idx0


func get_par_scores() -> Array:
    return [2, 3, 4]


func get_target_crossing_number() -> int:
    return 3
