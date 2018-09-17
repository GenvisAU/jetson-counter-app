def lerp_color(c1, c2, factor: float):
    """ Linear interpolate two 3-channel colors, using channel based interpolation. """
    assert(len(c1) == len(c2))

    new_color = []
    for i in range(len(c1)):
        new_color.append(int(lerp(c1[i], c2[i], factor)))
    return new_color


def lerp(f1: float, f2: float, factor: float) -> float:
    """ Linearly interpolate between two float values. """
    return f1 + (f2 - f1) * factor

