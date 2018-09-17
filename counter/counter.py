# -*- coding: utf-8 -*-

"""
<Description>
"""
import os
from tools.resource_manager import ResourceManager
from counter.detector import Detector
from counter.video_reader import VideoReader
from tools.logger import Logger
import cv2
import uuid
import time
import json
from datetime import date

__author__ = "Jakrin Juangbhanich"
__copyright__ = "Copyright 2018, GenVis Pty Ltd."
__email__ = "krinj@genvis.co"


class Counter:
    def __init__(self, resource_directory: str="resource"):
        self.detector = Detector()
        self.load_resources(resource_directory)
        self.video_reader = VideoReader()
        self.counter = 0
        self.output_path = str(date.today())
        if not os.path.exists(os.path.join(os.getcwd(), self.output_path)):
            os.mkdir(os.path.join(os.getcwd(), self.output_path))
        self.max_number_person = 0

    def load_resources(self, resource_directory: str):
        resource_manager = ResourceManager(resource_directory)
        resource_manager.read_manifest(os.path.dirname(os.path.realpath(__file__)))
        model_path = resource_manager.get("ssd_model")
        self.detector.load_model(model_path)

    def reset(self):
        self.counter = 0
        self.max_number_person = 0

    def process(self, video_path, max_wait_seconds=10):
        self.video_reader.cap = cv2.VideoCapture(video_path)
        re_session_flag = True
        wait_count = 0
        while self.video_reader.cap is not None:
            frame_rate = int(self.video_reader.cap.get(cv2.CAP_PROP_FPS))
            frame = self.video_reader.next_frame()
            if frame is not None:
                regions = self.detector.detect(frame)
                if len(regions) > 0 and re_session_flag:
                    re_session_flag = False
                    wait_count = 0
                    file_id = os.path.join(self.output_path, uuid.uuid4().hex)
                    self.reset()
                    # self.write_output()
                    output_data = self.write_to_json(file_id, data={})
                    start_time = time.time()
                if len(regions) == 0 and re_session_flag is False:
                    wait_count += 1

                self.max_number_person = max(len(regions), self.max_number_person)

                if wait_count >= frame_rate * max_wait_seconds and re_session_flag is False:
                    self.write_output(start=False, max_value=self.max_number_person, duration=int(time.time() - start_time))
                    self.write_to_json(file_id, start=False, max_value=self.max_number_person,
                                       duration=int(time.time() - start_time), data=output_data)
                    re_session_flag = True
                    wait_count = 0

        if re_session_flag is False:
            self.write_output(start=False, max_value=self.max_number_person, duration=int(time.time() - start_time))
            self.write_to_json(file_id, start=False, max_value=self.max_number_person,
                               duration=int(time.time() - start_time), data=output_data)

    @staticmethod
    def write_output(start=True, max_value=0, duration=0):

        if start:
            Logger.log('Session Start')
        else:

            Logger.field('Max Number of People', max_value)
            Logger.field("Session Duration (seconds)", duration)
            Logger.log('Session End')

    @staticmethod
    def _get_readable_time(time_object):
        day = str(time_object.tm_mday).zfill(2)
        date_str = "{}/{}".format(day, time_object.tm_mon)
        hour = str(time_object.tm_hour).zfill(2)
        minute = str(time_object.tm_min).zfill(2)
        time_str = "{}:{}".format(hour, minute)
        final_str = " {} {} ".format(date_str, time_str)
        return final_str

    def write_to_json(self, file_path, start=True, max_value=0, duration=0, data=None):
        if start:
            data["session_start"] = self._get_readable_time(time.localtime())
            return data
        else:
            data["max_count"] = max_value
            data["session_duration"] = duration
            data["session_end"] = self._get_readable_time(time.localtime())
            with open(file_path, "w") as f:
                json.dump(data, f, indent=1)



