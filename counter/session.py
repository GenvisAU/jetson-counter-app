# -*- coding: utf-8 -*-

"""
<Description>
"""

import json
import os
import time
from tools import pather

__author__ = "Jakrin Juangbhanich"
__copyright__ = "Copyright 2018, GenVis Pty Ltd."
__email__ = "krinj@genvis.co"


class Session:

    SESSION_FILE = "session_index.txt"
    OUTPUT_DIR = "output"
    Z_FILL_INDEX = 7
    ROLLING_WINDOW_SIZE = 10000  # This is how many session files we will keep.
    SESSION_ACTIVATION_SEC = 0  # How many seconds before a session is counted as active.

    def __init__(self):
        self.max_number_faces = 0
        self.timestamp_start = time.time()
        self.timestamp_end = 0

    def register_number_of_faces(self, number_of_faces):
        """ Compare the current number of faces value and register it to. """
        self.max_number_faces = max(number_of_faces, self.max_number_faces)

    def end(self):
        """ End the session and write the results to a file. """
        self.timestamp_end = time.time()
        self.create_results_data()

    @property
    def is_active(self):
        return time.time() - self.timestamp_start >= self.SESSION_ACTIVATION_SEC

    def create_results_data(self):
        """ Create a dictionary of the results. """
        if not self.is_active:
            return

        session_id = self.get_session_id()
        data = {
            "session_id": session_id,
            "timestamp_start": self.timestamp_start,
            "timestamp_end": self.timestamp_end,
            "duration_in_seconds": self.timestamp_end - self.timestamp_start,
            "max_faces": self.max_number_faces,
            "date": self._get_readable_date(time.localtime()),
            "readable_time_end": self._get_readable_time(time.localtime())
        }

        # Write the results data to disk.
        file_name = "session_{}.json".format(str(session_id).zfill(self.Z_FILL_INDEX))
        file_path = os.path.join(self.OUTPUT_DIR, file_name)
        pather.create(self.OUTPUT_DIR)
        with open(file_path, "w") as f:
            json.dump(data, f, indent=2)

        self._execute_rolling_window(self.ROLLING_WINDOW_SIZE)

        return data

    def _execute_rolling_window(self, rolling_window_size=5):
        """ Clean up the directory to fit within the rolling window size. """
        session_files = os.listdir(self.OUTPUT_DIR)
        if len(session_files) > rolling_window_size:
            session_files.sort()

        # Delete the first n files from the session folder.
        excess = len(session_files) - rolling_window_size
        prune_files = session_files[:excess]
        for f in prune_files:
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


