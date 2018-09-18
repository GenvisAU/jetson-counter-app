# -*- coding: utf-8 -*-

"""
<Description>
"""

__author__ = "Jakrin Juangbhanich"
__copyright__ = "Copyright 2018, GenVis Pty Ltd."
__email__ = "krinj@genvis.co"

from typing import List
import cv2
import tensorflow as tf
import os
import numpy as np
from tools.tracking_tool import TrackingRegion


class Detector:
    def __init__(self, min_score=0.5, use_gpu=True):
        self._gpu_fraction = 0.5
        self._gpu_count = 1

        # Minimum score to consider as a detection.
        self.score_min = min_score

        # Tensorflow attributes.
        self._detection_graph = None
        self._session = None

        # Tensors.
        self._image_tensor = None
        self._detection_boxes = None
        self._detection_scores = None
        self._detection_classes = None
        self._num_detections = None

        # Disable or enable GPU.
        if not use_gpu:
            os.environ["CUDA_VISIBLE_DEVICES"] = ""

    def detect(self, image) -> List[TrackingRegion]:
        """ Classify the input image and return the detections.
        Returns:
            tuple: Boxes (rect), scores (float), and classes (int).
        """

        # Cannot do a detection without the model being loaded.
        if not self.is_ready:
            raise Exception("Detection Classifier Error", "Classifier model has not been loaded. Please load the model"
                                                          "before using the classifier.")

        cvt_image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
        image_np_expanded = np.expand_dims(cvt_image, axis=0)
        (boxes, scores, classes, num) = self._session.run(
            [self._detection_boxes, self._detection_scores, self._detection_classes, self._num_detections],
            feed_dict={self._image_tensor: image_np_expanded})

        width = image.shape[1]
        height = image.shape[0]
        regions = []

        for i in range(len(boxes[0])):
            box = boxes[0][i]
            score = scores[0][i]

            if score > self.score_min:
                y_min, x_min, y_max, x_max = box
                face_region = TrackingRegion()

                # Get the absolute x and y limits for each box.
                face_region.set_rect(
                    left=int(x_min * width),
                    right=int(x_max * width),
                    top=int(y_min * height),
                    bottom=int(y_max * height)
                )
                regions.append(face_region)

        for r in regions:
            r.expand_to_ratio(1)

        return regions

    def load_model(self, path_to_model):
        """ Load a TensorFlow frozen inference graph. This should only be used once."""

        if self.is_ready:
            raise Exception("Detection Classifier Error",
                            "The intelligence model has already been loaded into this classifier. "
                            "It cannot be loaded twice.")

        self._detection_graph = tf.Graph()
        with self._detection_graph.as_default():
            od_graph_def = tf.GraphDef()
            with tf.gfile.GFile(path_to_model, 'rb') as fid:
                serialized_graph = fid.read()
                od_graph_def.ParseFromString(serialized_graph)
                tf.import_graph_def(od_graph_def, name='')

        gpu_options = tf.GPUOptions(per_process_gpu_memory_fraction=self._gpu_fraction)
        config_proto = tf.ConfigProto(gpu_options=gpu_options, device_count={'GPU': self._gpu_count})

        self._session = tf.Session(graph=self._detection_graph, config=config_proto)
        self._image_tensor = self._detection_graph.get_tensor_by_name('image_tensor:0')
        self._detection_boxes = self._detection_graph.get_tensor_by_name('detection_boxes:0')
        self._detection_scores = self._detection_graph.get_tensor_by_name('detection_scores:0')
        self._detection_classes = self._detection_graph.get_tensor_by_name('detection_classes:0')
        self._num_detections = self._detection_graph.get_tensor_by_name('num_detections:0')

    @property
    def is_ready(self):
        return self._session is not None


