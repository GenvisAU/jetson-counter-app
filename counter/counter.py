# -*- coding: utf-8 -*-

"""
<Description>
"""

import os
import random
import uuid

import yaml

from counter.loader import Loader
from counter.session import Session
from counter.vector_extractor import VectorExtractor
from tools import visual, text
from tools.logger import Logger
from tools.region import Region
from tools.resource_manager import ResourceManager
from counter.detector import Detector
from counter.video_reader import VideoReader
import cv2
import time
from datetime import datetime
import numpy as np

__author__ = "Jakrin Juangbhanich"
__copyright__ = "Copyright 2018, GenVis Pty Ltd."
__email__ = "krinj@genvis.co"


class VectorWrapper:
    def __init__(self, vector, region):
        self.value = vector
        self.region = region
        self.session = None
        self.id = uuid.uuid4()


class SessionVectorPair:
    def __init__(self, session, vector, distance):
        self.session = session
        self.vector = vector
        self.distance = distance


class Counter:

    def __init__(self, visualize=False, resource_directory: str = "resource"):

        # Load the core modules to stream the video and detect faces.
        self.detector = Detector()
        self.load_resources(resource_directory)
        self.video_reader = VideoReader()
        self.extractor = VectorExtractor()
        self.extractor.initialize(Loader.get_landmark_model(), Loader.get_face_model())
        self.visualize = visualize if "DISPLAY" in os.environ else False

        # Initialize the app settings.
        self.min_face_size = None
        self.rolling_window_size = None
        self.load_settings()

        # Initialize stateful variables.
        self.sessions = []
        self.timestamp_previous_activity = time.time()

    def load_settings(self):
        """ Load settings from the .yaml file. """
        settings_file = "settings.yaml"
        with open(settings_file, 'r') as f:
            data = yaml.load(f)

        self.min_face_size = data["MIN_FACE_SIZE"]
        Session.ROLLING_WINDOW_SIZE = int(data["ROLLING_WINDOW_SIZE"])
        Session.MAX_VECTOR_LENGTH = int(data["MAX_VECTOR_LENGTH"])
        Session.SESSION_LONG_LIFE_FRAMES = int(data["SESSION_LONG_LIFE_FRAMES"])
        Session.SESSION_SHORT_LIFE_FRAMES = int(data["SESSION_SHORT_LIFE_FRAMES"])

    def load_resources(self, resource_directory: str):
        """ Load the neural net model for face detection. """
        resource_manager = ResourceManager(resource_directory)
        resource_manager.read_manifest(os.path.dirname(os.path.realpath(__file__)))
        model_path = resource_manager.get("ssd_model")
        self.detector.load_model(model_path)

    def visualize_sessions(self, frame, vector_wrappers, invalid_regions):
        """ Draw the visualization window for testing. """

        cap_regions = []
        for r in invalid_regions:
            cap_region = r.clone()
            cap_region.width = self.min_face_size
            cap_region.height = self.min_face_size
            cap_regions.append(cap_region)

        valid_regions = []

        for w in vector_wrappers:
            valid_regions.append(w.region)
            frame = text.label_region(frame, w.session.display_id, w.region, font_size=12)

        overlay = np.zeros_like(frame)
        overlay = visual.draw_regions(overlay, valid_regions, color=(0, 255, 0), thickness=2)
        overlay = visual.draw_regions(overlay, invalid_regions, color=(0, 0, 255), thickness=2)
        overlay = visual.draw_regions(overlay, cap_regions, color=(60, 60, 60), thickness=1)
        frame = cv2.addWeighted(frame, 1.0, overlay, 1.0, 0.0)

        # Show the frame in a window.
        if self.visualize:
            cv2.imshow("window", frame)
            cv2.waitKey(1)

    def process(self, video_path):

        self.video_reader.cap = cv2.VideoCapture(video_path)
        container_region = None
        while self.video_reader.cap is not None:

            self.timestamp_previous_activity = time.time()

            frame = self.video_reader.next_frame()
            if frame is not None:

                if container_region is None:
                    pad = 5
                    container_region = Region(pad, frame.shape[1] - pad, pad, frame.shape[0] - pad)

                regions = self.detector.detect(frame)
                valid_regions = []
                invalid_regions = []

                for r in regions:
                    if r.width >= self.min_face_size:

                        if r.left > container_region.left and r.right < container_region.right and \
                                r.top > container_region.top and r.bottom < container_region.bottom:
                            valid_regions.append(r)
                            continue

                    invalid_regions.append(r)

                frame = self.draw_session_plates(frame)

                vector_wrappers = []
                for r in valid_regions:
                    vector = self.get_vector(frame, r)
                    vector_wrapper = VectorWrapper(vector, r)
                    vector_wrappers.append(vector_wrapper)

                self.add_vectors_to_sessions(vector_wrappers)
                self.process_sessions(1)
                self.visualize_sessions(frame, vector_wrappers, invalid_regions)

    def add_vectors_to_sessions(self, vector_wrappers):

        pairs = []

        for v in vector_wrappers:
            for s in self.sessions:
                d = s.get_distance(v.value)
                if d < 0.5:  # Within Range!
                    pair = SessionVectorPair(s, v, d)
                    pairs.append(pair)

        paired_sessions = {}
        paired_vectors = {}
        pairs.sort(key=lambda x: x.distance)

        # Merge the similar IDs.
        for p in pairs:
            if p.vector.id not in paired_vectors and p.session not in paired_sessions:
                paired_sessions[p.session] = True
                paired_vectors[p.vector.id] = True
                p.session.add_vector(p.vector.value)
                p.vector.session = p.session

        # Create New Sessions.
        for v in vector_wrappers:
            if v.id not in paired_vectors:
                session = Session()
                session.add_vector(v.value)
                v.session = session
                self.sessions.append(session)

    def process_sessions(self, time_delta):
        for session in self.sessions:
            session.update(time_delta)

        ended_sessions = [s for s in self.sessions if s.time_left_percent == 0]
        self.sessions = [s for s in self.sessions if s.time_left_percent > 0]

        for s in ended_sessions:
            if s.is_full:
                s.end()

    def get_vector(self, image, region):
        vector = self.extractor.process(image, [region])
        return vector

    def draw_session_plates(self, frame):
        pad = 2
        unit_height = 30
        unit_width = 128
        bar_height = 2

        for i, session in enumerate(self.sessions):

            if not session.is_full:
                continue

            color = (0, 255, 0) if session.is_active else (255, 255, 255)
            x = pad
            y = pad + (unit_height + pad) * i
            t_height = (unit_height - bar_height)
            t_region = Region(x, x + unit_width, y, y + t_height)
            frame = text.write_into_region(frame, session.display_id, t_region, bg_color=(0, 0, 0), font_size=12,
                                           bg_opacity=0.7, color=color)
            visual.draw_bar(frame, session.display_time_left_percent, x, y + t_height,
                            unit_width, bar_height, bar_color=color)

        return frame
