#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
Use this script to continously run the counter app.
"""

import argparse
from tools.logger import Logger
from counter.counter import Counter


__author__ = "Jakrin Juangbhanich"
__copyright__ = "Copyright 2018, GenVis Pty Ltd."
__email__ = "krinj@genvis.co"
__version__ = "0.0.1"


def get_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('-v', '--visualize', action="store_true", help="Whether or not to visualize the results.")
    return parser.parse_args()


args = get_args()
visualize = args.visualize


if __name__ == "__main__":
    Logger.field("Running", "Counter App")
    counter = Counter(visualize)
    counter.process("/dev/video1")






