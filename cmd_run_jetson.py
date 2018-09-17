#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
<Description>
"""

from tools.logger import Logger
from counter.counter import Counter


__author__ = "Jakrin Juangbhanich"
__copyright__ = "Copyright 2018, GenVis Pty Ltd."
__email__ = "krinj@genvis.co"
__version__ = "0.0.1"


if __name__ == "__main__":
    print("Running Counter App")
    Logger.field("Running", "Counter App")
    counter = Counter()
    counter.process("/dev/video1")
    # counter.process('/media/haoxue/WD/wt-engine/input/small_london.mp4')
    # counter.write_output()





