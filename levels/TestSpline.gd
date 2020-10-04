extends Spline

func get_lower_idx(crossing: Spline.Crossing) -> int:
    if crossing.involves(0, 2):
        return 0
    if crossing.involves(0, 4):
        return 4
    if crossing.involves(2, 5):
        return 2
    return crossing.idx0

func get_par_scores() -> Array:
    return [3, 4, 5]
