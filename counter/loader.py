# -*- coding: utf-8 -*-

"""
Use this class to download models.
"""

import bz2
import os
from tools import pather

__author__ = "Jakrin Juangbhanich"
__copyright__ = "Copyright 2018, GenVis Pty Ltd."
__email__ = "krinj@genvis.co"


class Loader:

    URL_LANDMARK_MODEL = "https://github.com/davisking/dlib-models/raw/master/shape_predictor_5_face_landmarks.dat.bz2"
    LOCAL_LANDMARK_ZIP = "models/landmarks.bz2"
    LOCAL_LANDMARK_MODEL = "models/landmarks.dat"

    URL_FACE_MODEL = "https://github.com/davisking/dlib-models/raw/master/dlib_face_recognition_resnet_model_v1.dat.bz2"
    LOCAL_FACE_ZIP = "models/face.bz2"
    LOCAL_FACE_MODEL = "models/face.dat"

    @classmethod
    def get_face_model(cls):
        cls.prepare_models()
        return cls.LOCAL_FACE_MODEL

    @classmethod
    def get_landmark_model(cls):
        cls.prepare_models()
        return cls.LOCAL_LANDMARK_MODEL

    @classmethod
    def prepare_models(cls):
        cls.download_and_unzip(cls.URL_LANDMARK_MODEL, cls.LOCAL_LANDMARK_ZIP, cls.LOCAL_LANDMARK_MODEL)
        cls.download_and_unzip(cls.URL_FACE_MODEL, cls.LOCAL_FACE_ZIP, cls.LOCAL_FACE_MODEL)

    @classmethod
    def download_and_unzip(cls, url: str, zip_path: str, model_path: str):
        if not os.path.exists(model_path):
            pather.create(model_path)
            if not os.path.exists(zip_path):
                cls.download(url, zip_path)
            cls.unzip(zip_path, model_path)

    @classmethod
    def download(cls, url: str, path: str):
        os.system("wget {} -O {}".format(url, path))

    @classmethod
    def unzip(cls, file_path: str, output_path: str):
        """ Uncompress the BZ2File. """
        zipfile = bz2.BZ2File(file_path)
        data = zipfile.read()
        open(output_path, 'wb').write(data)
