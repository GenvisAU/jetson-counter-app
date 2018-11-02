# -*- coding: utf-8 -*-

"""
<Description>
"""

import json
import os
import time
import uuid

import numpy as np

from tools import pather
from tools.logger import Logger

__author__ = "Jakrin Juangbhanich"
__copyright__ = "Copyright 2018, GenVis Pty Ltd."
__email__ = "krinj@genvis.co"


class Session:

    SESSION_FILE = "session_index.txt"
    OUTPUT_DIR = "output"
    Z_FILL_INDEX = 7
    ROLLING_WINDOW_SIZE = 10000  # This is how many session files we will keep.
    MAX_VECTOR_LENGTH = 10
    SESSION_LONG_LIFE_FRAMES = 150  # How long to keep a session pending for, before ending it.
    SESSION_SHORT_LIFE_FRAMES = 5  # How long to keep a session pending for (until it is full).
    DISPLAY_TIME_LEFT_LIMIT = 0.9

    VECTOR_COMPARE_LENGTH = 3

    def __init__(self):
        self.session_id = self.get_session_id()
        self.face_id = uuid.uuid4().hex
        self.timestamp_start = time.time()
        self.timestamp_end = 0
        self.local_time_start = time.localtime()
        self.vectors = []
        self.time_left = self.SESSION_SHORT_LIFE_FRAMES
        self.has_activated = False

    @property
    def display_id(self):
        return "{}: {}".format(self.session_id, self.face_id[:6].upper())

    def add_vector(self, vector):
        self.vectors.append(vector)
        if len(self.vectors) > self.MAX_VECTOR_LENGTH:
            self.vectors.pop(0)

        if not self.has_activated:
            if self.is_full:
                self.has_activated = True
                Logger.field("Session Activated", "{}".format(self.display_id))

        self.timestamp_end = time.time()
        self.time_left = self.SESSION_LONG_LIFE_FRAMES if self.is_full else self.SESSION_SHORT_LIFE_FRAMES

    @property
    def is_full(self):
        return len(self.vectors) == self.MAX_VECTOR_LENGTH

    def update(self, time_delta):
        self.time_left = max(0, self.time_left - time_delta)

    @property
    def time_left_percent(self):
        return self.time_left/self.SESSION_LONG_LIFE_FRAMES

    @property
    def display_time_left_percent(self):
        return min(1.0, self.time_left_percent / self.DISPLAY_TIME_LEFT_LIMIT)

    def get_distance(self, vector):
        distance_total = 0
        cmp_length = min(len(self.vectors), self.VECTOR_COMPARE_LENGTH)
        compare_vectors = self.vectors[:cmp_length]
        for v in compare_vectors:
            distance_total += np.linalg.norm(v - vector)
        distance_total /= len(self.vectors)
        return distance_total

    def end(self):
        """ End the session and write the results to a file. """
        Logger.field("Session Ended", "{}".format(self.display_id))
        self.create_results_data()

    @property
    def is_active(self):
        return self.time_left_percent > self.DISPLAY_TIME_LEFT_LIMIT

    def create_results_data(self):
        """ Create a dictionary of the results. """
        data = {
            "session_id": self.session_id,
            "face_id": self.face_id,
            "timestamp_start": int(self.timestamp_start),
            "timestamp_end": int(self.timestamp_end),
            "duration_in_seconds": round(self.timestamp_end - self.timestamp_start, 2),
            "date": self._get_readable_date(time.localtime()),
            "readable_time_start": self._get_readable_time(self.local_time_start),
            "readable_time_end": self._get_readable_time(time.localtime())
        }

        # Write the results data to disk.
        file_name = "session_{}.json".format(str(self.session_id).zfill(self.Z_FILL_INDEX))
        file_path = os.path.join(self.OUTPUT_DIR, file_name)
        pather.create(self.OUTPUT_DIR)
        with open(file_path, "w") as f:
            json.dump(data, f, indent=2)

        self._execute_rolling_window(self.ROLLING_WINDOW_SIZE)
        return data

    # ======================================================================================================================
    # Private file I/O Support functions.
    # ======================================================================================================================

    def _execute_rolling_window(self, rolling_window_size=5):
        """ Clean up the directory to fit within the rolling window size. """
        session_files = os.listdir(self.OUTPUT_DIR)
        if len(session_files) > rolling_window_size:
            session_files.sort()

        # Delete the first n files from the session folder.
        excess = len(session_files) - rolling_window_size
        Logger.field("File Storage", "{}/{}".format(len(session_files), rolling_window_size))
        if excess > 0:
            prune_files = session_files[:excess]
            for f in prune_files:
                Logger.field("Pruning File", "{}".format(f))
                file_path = os.path.join(self.OUTPUT_DIR, f)
                os.remove(file_path)

    def _create_session_file(self):
        """ Create the session file if it doesn't yet exist. """
        if not os.path.exists(self.SESSION_FILE):
            self._write_session_id(0)

    def _read_session_id(self):
        """ Read the session ID from the file. """
        self._create_session_file()
        with open(self.SESSION_FILE, "r") as f:
            session_id = int(f.read())
        return session_id

    def _write_session_id(self, new_id=0):
        """ Write the new session ID into the file. """
        with open(self.SESSION_FILE, "w") as f:
            f.write(str(new_id))

    def get_session_id(self):
        """ Get the next incremental session ID. """
        current_session_id = self._read_session_id()
        current_session_id += 1
        self._write_session_id(current_session_id)
        return current_session_id

    @staticmethod
    def _get_readable_date(time_object):
        day = str(time_object.tm_mday).zfill(2)
        date_str = "{}/{}/{}".format(day, time_object.tm_mon, time_object.tm_year)
        return date_str

    @staticmethod
    def _get_readable_time(time_object):
        hour = str(time_object.tm_hour).zfill(2)
        minute = str(time_object.tm_min).zfill(2)
        time_str = "{}:{}".format(hour, minute)
        return time_str


