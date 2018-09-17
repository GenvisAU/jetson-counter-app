# -*- coding: utf-8 -*-

"""
Use this tool to log stuff with pre-formatted margins, indents, line breaks, fields, and colors.
Also has the option to log output to the terminal and to a file.
"""

import os
import time
import sys
from tools import pather

__author__ = "Jakrin Juangbhanich"
__email__ = "juangbhanich.k@gmail.com"


class Logger:

    # Character constants (tab, ruler, etc).
    INDENT_CHAR = "   "
    RULER_CHAR = "-"
    PROGRESS_BLANK = "▯"
    PROGRESS_FILL = "▮"

    # Color definitions.
    RED = '\33[31m'
    GREEN = '\33[32m'
    YELLOW = '\33[33m'
    BLUE = '\33[34m'
    DEFAULT_COLOR = '\33[0m'
    COLORS = [RED, GREEN, YELLOW, BLUE, DEFAULT_COLOR]

    # Singleton instance.
    _INSTANCE = None

    # ======================================================================================================================
    # Reflected Static Methods.
    # ======================================================================================================================

    @staticmethod
    def instance() -> 'Logger':
        if Logger._INSTANCE is None:
            Logger._INSTANCE = Logger()
        return Logger._INSTANCE

    @staticmethod
    def log(message: str):
        Logger.instance()._log(message)

    @staticmethod
    def field(field_name: str, value, red: bool=False, extra_indent: int=1):
        Logger.instance()._field(field_name, value, red, extra_indent)

    @staticmethod
    def special(message: str, with_gap: bool=True):
        Logger.instance()._special(message, with_gap)

    @staticmethod
    def header(message: str, with_gap: bool = True):
        Logger.instance()._header(message, with_gap)

    @staticmethod
    def error(message: str):
        Logger.instance()._error(message)

    @staticmethod
    def ruler(length: int=60):
        Logger.instance()._ruler(length)

    @staticmethod
    def line_break():
        Logger.instance()._line_break()

    @staticmethod
    def indent():
        Logger.instance()._indent()

    @staticmethod
    def unindent():
        Logger.instance()._unindent()

    @staticmethod
    def clear_indent():
        Logger.instance()._clear_indent()

    @staticmethod
    def attach_file_handler(path: str, main_name: str = "output", error_name: str = "error"):
        Logger.instance()._attach_file_handler(path, main_name, error_name)

    @staticmethod
    def add_action(tag: str, action):
        Logger.instance()._add_action(tag, action)

    @staticmethod
    def clear_actions():
        Logger.instance()._clear_actions()

    # ==================================================================================================================
    # Constructor
    # ==================================================================================================================

    def __init__(self):

        self._indent_level = 0

        # Re-bind all of the static methods to our instances ones.
        self.log = self._log
        self.field = self._field
        self.header = self._header
        self.special = self._special
        self.error = self._error

        self.ruler = self._ruler
        self.line_break = self._line_break

        self.indent = self._indent
        self.unindent = self._unindent
        self.clear_indent = self._clear_indent

        self.attach_file_handler = self._attach_file_handler
        self.add_action = self._add_action

        # Custom logging attachments.
        self.actions = {}

    # ======================================================================================================================
    # Core logging methods.
    # ======================================================================================================================
        
    def _log(self, message: str):
        self._write(message)

    def _field(self, field_name, value, red=False, extra_indent=1):
        field_name = self._set_color("{}:".format(field_name), self.BLUE)
        if red:
            value = self._set_color(str(value), Logger.RED)
        message = "{} {}".format(field_name, value)
        self._write(message, extra_indent=extra_indent)

    def _special(self, message, with_gap: bool=True):
        """ Logs a special (colored) message at the indent level. """
        if with_gap:
            self._line_break()
        self._log(self._set_color(message, self.GREEN))

    def _header(self, message, with_gap=True):
        """ Logs a special (colored) message at the indent level. """
        if with_gap:
            self._line_break()
        self._log(self._set_color(message, self.YELLOW))

    def _error(self, message: str):
        self._write(self._set_color(message, self.RED), is_error=True)

    # ======================================================================================================================
    # Supporting logging methods.
    # ======================================================================================================================

    def _line_break(self):
        self._clear_indent()
        self._log("")

    def _ruler(self, length: int=60):
        self._line_break()
        self._log(self._set_color(Logger.RULER_CHAR * length, self.BLUE))
        self._line_break()

    def _clear_indent(self):
        self._indent_level = 0

    def _indent(self):
        self._indent_level += 1

    def _unindent(self):
        self._indent_level = max(0, self._indent_level - 1)

    # ======================================================================================================================
    # I/O Methods.
    # ======================================================================================================================

    def _write(self, message: str, is_error: bool=False, extra_indent: int = 0):

        # Add the message header and the indents.
        message = self._add_format(message, extra_indent)

        # Write the message to Python standard print.
        if is_error:
            print(message, file=sys.stderr)
            sys.stderr.flush()
        else:
            print(message)
            sys.stdout.flush()

        # Clear the colors and write the message to all the custom actions.
        message = self._strip_colors(message)
        for k in self.actions:
            action = self.actions[k]
            action(message, is_error)

    def _attach_file_handler(self, path: str, main_name: str="output", error_name: str="error"):

        # Create the file if it doesn't exist.
        pather.create(path)
        main_path = os.path.join(path, "{}.log".format(main_name))
        error_path = os.path.join(path, "{}.log".format(error_name))

        if os.path.exists(main_path):
            os.remove(main_path)

        if os.path.exists(error_path):
            os.remove(error_path)

        # If it does, then open and append to it (unless clear is specified).
        def write_to_file(message: str, is_error: bool):
            write_path = error_path if is_error else main_path

            # Lazy create the path if it doesn't exist.
            pather.create(write_path, clear=False)
            with open(write_path, "a+") as f:
                f.write(message + "\n")

        self._add_action(main_path, write_to_file)

    def _add_action(self, tag: str, action):
        self.actions[tag] = action

    def _clear_actions(self):
        self.actions.clear()

    # ======================================================================================================================
    # Formatting Methods.
    # ======================================================================================================================

    def _add_format(self, message: str, extra_indent: int=0) -> str:
        message = self._add_indent(message, extra_indent)
        message = self._add_header(message)
        return message

    def _add_indent(self, message: str, extra_indent: int) -> str:
        return (extra_indent + self._indent_level) * self.INDENT_CHAR + message

    def _add_header(self, message: str) -> str:
        header = "{} | ".format(self._get_readable_time(time.localtime()))
        header = self._set_color(header, self.BLUE)
        return header + message

    @staticmethod
    def _get_readable_time(time_object):
        day = str(time_object.tm_mday).zfill(2)
        date_str = "{}/{}".format(day, time_object.tm_mon)
        hour = str(time_object.tm_hour).zfill(2)
        minute = str(time_object.tm_min).zfill(2)
        time_str = "{}:{}".format(hour, minute)
        final_str = " {} {} ".format(date_str, time_str)
        return final_str

    def _set_color(self, message: str, color_code: str):
        """ Add color tags to a message. """
        return "{}{}{}".format(color_code, message, self.DEFAULT_COLOR)

    def _strip_colors(self, message: str) -> str:
        """ Remove all of the color tags from this message. """
        for c in self.COLORS:
            message = message.replace(c, "")
        return message
