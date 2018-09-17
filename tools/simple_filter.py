"""
A simple filter to smooth out the transition between two values.
"""

__author__ = "Jakrin Juangbhanich"
__email__ = "juangbhanich.k@gmail.com"


class SimpleFilter:
    def __init__(self, factor: float = 0.5):
        assert(0.0 <= factor <= 1.0)

        self.factor = factor
        self.r_factor = 1 - factor

    def process(self, new_value, old_value):
        return new_value * self.factor + old_value * self.r_factor

