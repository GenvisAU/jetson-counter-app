# -*- coding: utf-8 -*-

"""
Video reader simply reads in a video in any format, and outputs a CV2 BGR image.
"""

import os
import cv2
from tools.logger import Logger

__author__ = "Jakrin Juangbhanich"
__copyright__ = "Copyright 2018, GenVis Pty Ltd."
__email__ = "krinj@genvis.co"


class VideoReader:
    def __init__(self):
        self.cap = None

    def start_capture(self, input_path: str) -> (int, int):
        """ Begin the video capture, returning the estimated frame length and rate. """

        if not os.path.exists(input_path):
            message = "The specified input file {} does not exist.".format(input_path)
            Logger.error(message)
            raise FileNotFoundError(message)

        self.cap = cv2.VideoCapture(input_path)
        self.cap.set(cv2.CAP_PROP_POS_FRAMES, 0)
        frame_length = int(self.cap.get(cv2.CAP_PROP_FRAME_COUNT))
        frame_rate = int(self.cap.get(cv2.CAP_PROP_FPS))
        return frame_length, frame_rate

    def get_width_and_height(self) -> (int, int):
        frame = self.next_frame()
        if frame is not None:
            w = frame.shape[1]
            h = frame.shape[0]

            # Set the frame back, since we read a frame already.
            current_frame_index = int(self.cap.get(cv2.CAP_PROP_POS_FRAMES))
            self.cap.set(cv2.CAP_PROP_POS_FRAMES, current_frame_index - 1)
            return w, h
        else:
            return None, None

    def set_capture_frame(self, frame_index: int):
        self.cap.set(cv2.CAP_PROP_POS_FRAMES, frame_index)

    def end_capture(self):
        self.cap.release()
        self.cap = None

    def next_frame(self):
        """ Get the next frame of the video. """
        _, frame = self.cap.read()
        if frame is None or frame.shape[0] == 0 or frame.shape[1] == 0:
            self.end_capture()
            return None
        else:
            return frame

