# -*- coding: utf-8 -*-

"""
This tool will maintain a list (manifest) of external or heavy resource needed by a script.
It will then facilitate searching for it locally, or loading in the resource externally.
"""

import json
import os
from tools.logger import Logger
from tools import pather

__author__ = "Jakrin Juangbhanich"
__copyright__ = "Copyright 2018, GenVis Pty Ltd."
__email__ = "krinj@genvis.co"


class UnknownResourceException(Exception):
    def __init__(self, *args, **kwargs):
        Exception.__init__(self, *args, **kwargs)


class ResourceManager:
    def __init__(self, root_storage_path: str=None):

        # Initialize the storage path. Create it if it doesn't exist.
        self.root_storage_path = "resource" if root_storage_path is None else root_storage_path
        pather.create(self.root_storage_path)

        # Dict of resources. Key: Resource Name,
        self.resources = {}

    def get(self, key: str):
        """ Get the full path of the key resource. If it doesn't exist, load it. """
        if not self._check_resource(key):
            self.load_resource(key)
        return self._local_path(key)

    def add(self, key: str, remote_path: str):
        """ Add a new key/remote pair to this resource Manager. """
        self.resources[key] = remote_path

    def write_manifest(self, path: str = ".", file_name: str= "resource_manifest.json"):
        """ Write the manifest to a json file on disk. """
        pather.create(path)
        resource_path = os.path.join(path, file_name)
        with open(resource_path, "w") as f:
            json.dump(self.resources, f, indent=1)

    def read_manifest(self, path: str, file_name: str= "resource_manifest.json") -> dict:
        """ Load a manifest from file into this RM's memory. """
        resource_path = os.path.join(path, file_name)
        if not os.path.exists(resource_path):
            pass
        with open(resource_path, "r") as f:
            data = json.load(f)

        # Show the details of the loaded manifest.
        Logger.header("Loaded Manifest")
        for k in self.resources:
            Logger.field(k, self.resources[k])

        self.resources = data
        return self.resources

    def load_all_resources(self, force_update: bool=False):
        """ Check and load all resources. If force_update is True, it will download even if
        the resource already exists locally. """
        for k in self.resources:
            if force_update or not self._check_resource(k):
                self.load_resource(k)

    def load_resource(self, key: str):
        local_path = self._local_path(key)
        remote_path = self.resources[key]
        os.system("wget -O {} {}".format(local_path, remote_path))

    def _local_path(self, key: str) -> str:
        return os.path.join(self.root_storage_path, key)

    def _check_resource(self, key: str) -> bool:
        """ Check if the resource has been loaded from remote. """
        if key not in self.resources:
            raise UnknownResourceException(
                "Resource key '{}' does not exist in ResourceManager. Did you load the manifest? [See: read_manifest()]"
                .format(key)
            )
        return os.path.exists(self._local_path(key))