#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
Use this script to download all of the models needed by dlib to run face recognition.
"""

from counter.loader import Loader

__author__ = "Jakrin Juangbhanich"
__copyright__ = "Copyright 2018, GenVis Pty Ltd."
__email__ = "krinj@genvis.co"

if __name__ == "__main__":
    print("Downloading DLIB models...")
    Loader.prepare_models()
