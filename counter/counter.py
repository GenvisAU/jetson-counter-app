# -*- coding: utf-8 -*-

"""
<Description>
"""

import os
import random

import yaml

from counter.loader import Loader
from counter.session import Session
from counter.vector_extractor import VectorExtractor
from tools import visual
from tools.logger import Logger
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


class SessionVectorPair:
    def __init__(self, session, vector, distance):
        self.session = session
        self.vector = vector
        self.distance = distance


class Counter:

    def __init__(self, visualize=False, resource_directory: str="resource"):

        # Load the core modules to stream the video and detect faces.
        self.detector = Detector()
        self.load_resources(resource_directory)
        self.video_reader = VideoReader()
        self.extractor = VectorExtractor()
        self.extractor.initialize(Loader.get_landmark_model(), Loader.get_face_model())
        self.visualize = visualize if "DISPLAY" in os.environ else False

        # Initialize the app settings.
        self.min_face_size = None
        self.session_timeout_sec = None
        self.session_activation_sec = None
        self.rolling_window_size = None
        self.load_settings()
        Session.ROLLING_WINDOW_SIZE = self.rolling_window_size
        Session.SESSION_ACTIVATION_SEC = self.session_activation_sec

        # Initialize stateful variables.
        self.sessions = []
        self.timestamp_previous_activity = time.time()

    def load_settings(self):
        """ Load settings from the .yaml file. """
        settings_file = "settings.yaml"
        with open(settings_file, 'r') as f:
            data = yaml.load(f)

        self.min_face_size = data["MIN_FACE_SIZE"]
        self.session_timeout_sec = data["SESSION_TIMEOUT_SEC"]
        self.session_activation_sec = data["SESSION_ACTIVATION_SEC"]
        self.rolling_window_size = data["ROLLING_WINDOW_SIZE"]

    def load_resources(self, resource_directory: str):
        """ Load the neural net model for face detection. """
        resource_manager = ResourceManager(resource_directory)
        resource_manager.read_manifest(os.path.dirname(os.path.realpath(__file__)))
        model_path = resource_manager.get("ssd_model")
        self.detector.load_model(model_path)

    # def start_session(self):
    #     self.session = Session()
    #     Logger.field("Session Started", datetime.now().ctime())
    #
    # def end_session(self):
    #     self.session.end()
    #     Logger.field("Session Ended", datetime.now().ctime())
    #     self.session = None

    def visualize_regions(self, frame, valid_regions, invalid_regions):
        """ Draw the visualization window for testing. """

        # Draw the recording indicator for the session. Green = active, Red = inactive.
        # cv2.rectangle(frame, (3, 3), (37, 37), (0, 0, 0), thickness=-1)
        # if self.session is not None:
        #     recording_color = (0, 255, 50) if self.session.is_active else (0, 180, 255)
        # else:
        #     recording_color = (0, 50, 255)
        # cv2.rectangle(frame, (5, 5), (35, 35), recording_color, thickness=-1)

        cap_regions = []
        for r in invalid_regions:
            cap_region = r.clone()
            cap_region.width = self.min_face_size
            cap_region.height = self.min_face_size
            cap_regions.append(cap_region)

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
        while self.video_reader.cap is not None:

            frame = self.video_reader.next_frame()
            if frame is not None:

                regions = self.detector.detect(frame)
                valid_regions = [r for r in regions if r.width >= self.min_face_size]
                invalid_regions = [r for r in regions if r.width < self.min_face_size]
                n_faces = len(valid_regions)

                vectors = [self.get_vector(frame, r) for r in valid_regions]
                self.add_vectors_to_sessions(vectors)
                self.process_sessions()


                # if n_faces > 0:
                #     self.timestamp_previous_activity = time.time()
                #     if self.session is None:
                #         self.start_session()
                #     else:
                #         self.session.register_number_of_faces(n_faces)

                self.visualize_regions(frame, valid_regions, invalid_regions)

                # if self.session is not None:
                #     if time.time() - self.timestamp_previous_activity > self.session_timeout_sec:
                #         self.end_session()

    def add_vectors_to_sessions(self, vectors):

        pairs = []
        for v in vectors:
            for s in self.sessions:
                d = self.get_session_vector_distance(s, v)
                if d < 0.5:  # Within Range!
                    pair = SessionVectorPair(s, v, self.get_session_vector_distance(s, v))

        paired_sessions = {}
        paired_vectors = {}
        pairs.sort(key=lambda x: x.distance)

        # Merge the similar IDs.
        for p in pairs:
            if p.vector not in paired_vectors and p.session not in paired_sessions:
                paired_sessions[p.session] = True
                paired_vectors[p.vector] = True
                # Fuse the pairs.

        # Create New Sessions.
        for v in vectors:
            if v not in paired_vectors:
                pass

    def process_sessions(self):
        pass

    def get_vector(self, image, region):
        vector = self.extractor.process(image, [region])
        print(vector)

    def get_session_vector_distance(self, session, vector):
        d = random()
        return d

