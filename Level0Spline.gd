extends Spline

func get_lower_idx(crossing: Spline.Crossing) -> int:
    return crossing.idx0


func get_par_scores() -> Array:
    return [1, 2, 3]
    
    
func get_target_crossing_number() -> int:
    return 0
