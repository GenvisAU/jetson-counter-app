# -*- coding: utf-8 -*-

"""
This is a wrapper for dlib's feature encoder. We use this to create feature vectors for each image.
"""

import numpy as np
import dlib

__author__ = "Jakrin Juangbhanich"
__copyright__ = "Copyright 2018, GenVis Pty Ltd"
__email__ = "juangbhanich.k@gmail.com"


class VectorExtractor:
    def __init__(self):
        self.face_detector = None
        self.pose_predictor_5_point = None
        self.face_encoder = None

    def initialize(self,
                   predictor_5_point_model,
                   face_recognition_model):

        self.face_detector = dlib.get_frontal_face_detector()
        self.pose_predictor_5_point = dlib.shape_predictor(predictor_5_point_model)
        self.face_encoder = dlib.face_recognition_model_v1(face_recognition_model)

    def process(self, sample):
        """ Takes in an image, and a face-region for that image and finds the feature vector.

        Returns:
            np.array: The 128 byte feature vector if successful, otherwise None.
        """
        vector = self._face_encodings(sample.image, None)
        if len(vector) > 0:
            return vector[0]
        else:
            return None

    def face_landmarks(self, face_image, face_locations=None):
        """ Get the raw face landmarks for the image."""
        landmarks = self._raw_face_landmarks(face_image, face_locations, True)
        landmarks_as_tuples = [[(p.x, p.y) for p in landmark.parts()] for landmark in landmarks]
        return [{
            "chin": points[0:17],
            "left_eyebrow": points[17:22],
            "right_eyebrow": points[22:27],
            "nose_bridge": points[27:31],
            "nose_tip": points[31:36],
            "left_eye": points[36:42],
            "right_eye": points[42:48],
            "top_lip": points[48:55] + [points[64]] + [points[63]] + [points[62]] + [points[61]] + [points[60]],
            "bottom_lip": points[54:60] + [points[48]] + [points[60]] + [points[67]] + [points[66]] + [points[65]] + [
                points[64]]
        } for points in landmarks_as_tuples]

    def _face_encodings(self, face_image, known_face_locations=None, num_jitters=1):
        raw_landmarks = self._raw_face_landmarks(face_image, known_face_locations)
        return [np.array(self.face_encoder.compute_face_descriptor(face_image, raw_landmark_set, num_jitters)) for
                raw_landmark_set in raw_landmarks]

    def _raw_face_landmarks(self, face_image, face_locations=None):

        if face_locations is None:
            face_locations = self.face_detector(face_image, 1)
        else:
            face_locations = [self._css_to_rect(face_location) for face_location in face_locations]

        return [self.pose_predictor_5_point(face_image, face_location) for face_location in face_locations]

    @staticmethod
    def _css_to_rect(css):
        return dlib.rectangle(css[0], css[2], css[1], css[3])
