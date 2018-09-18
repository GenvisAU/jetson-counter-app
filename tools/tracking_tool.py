from tools.region import Region
import uuid
from enum import Enum
from typing import List, Tuple
from tools import core
from tools.simple_filter import SimpleFilter
from abc import abstractmethod
import numpy as np
from tools import visual


class TrackingRegion(Region):

    def __init__(self, left=0, right=0, top=0, bottom=0):
        super().__init__(left, right, top, bottom)
        self.confidence = 0.0
        self.label = None
        self.data = {}  # Arbitrary data pointer.

    def clone(self) -> 'TrackingRegion':
        """ Overload the clone function to include all the new data. """
        region = TrackingRegion()
        region.set_rect(self.left, self.right, self.top, self.bottom)
        region.confidence = self.confidence
        region.label = self.label
        region.data = self.data
        return region


class TrackFrame:
    def __init__(self, region: TrackingRegion = None, ratio_lock: float = 0.0, scale_factor: float = 1.0):
        # Basic tracking parameters.
        self.scale_factor = scale_factor
        self.ratio_lock = ratio_lock
        self.frame_index = 0
        self.raw_region = None
        self.display_region = None

        if region is not None:
            self.set_region(region)

    def set_region(self, region: TrackingRegion):
        if region is not None:
            self.raw_region = region
            self.display_region = region.clone()
            if self.ratio_lock != 0:
                self.display_region.expand_to_ratio(self.ratio_lock)
            self.display_region.scale(self.scale_factor)

    @property
    def x(self):
        return self.display_region.x

    @x.setter
    def x(self, value):
        self.display_region.x = int(value)

    @property
    def y(self):
        return self.display_region.y

    @y.setter
    def y(self, value):
        self.display_region.y = int(value)

    @property
    def width(self):
        return self.display_region.width

    @width.setter
    def width(self, value):
        self.display_region.width = int(value)

    @property
    def height(self):
        return self.display_region.height

    @height.setter
    def height(self, value):
        self.display_region.height = int(value)


class VisualState(Enum):
    NORMAL = 1
    SHOWING = 2
    KILLING = 3
    KILLED = 4


class Tracklet:
    # Visual Constants
    _PINK = (80, 30, 255)
    _RED = (0, 0, 255)
    _BLACK = (0, 0, 0)
    _ANIM_SHOW_MAX = 10
    _ANIM_KILL_MAX = 10

    def __repr__(self):

        if self.frame_count == 0:
            return "Tracklet [ID: {} Empty!]".format(self.id)

        desc = "Tracklet [" \
               "ID: {} " \
               "Frames: {}-{} " \
               "Size: {}]".format(
                    self.id,
                    self.first_frame.frame_index,
                    self.last_frame.frame_index,
                    self.frame_count)

        return desc

    def __init__(self, hit_limit: int = 3, miss_limit: int = 7,
                 color: Tuple = (255, 255, 255), red_fade: bool = False):
        self.track_frames = []

        # TODO: We should probably allow this for config passing.

        # Smoothing Filters.
        self.id = uuid.uuid4().hex
        self._position_filter = SimpleFilter(0.5)
        self._size_filter = SimpleFilter(0.5)

        # Consecutive.
        self._hit_counter = 0
        self._miss_counter = 0
        self._hit_limit = hit_limit
        self._miss_limit = miss_limit
        self._activated = False
        self._lost = False
        # TODO: Enum? UNTRACKED, LIVE, LOST?

        # Visual State Information.
        self._anim_show_counter = 0
        self._anim_kill_counter = 0
        self._color = color
        self._red_fade = red_fade  # Fade using the red animation.
        self.visual_state = VisualState.NORMAL

        self.image = None

    # ===================================================================================================
    # Core Public Functions.
    # ===================================================================================================

    def add(self, track_frame: TrackFrame, register_hit: bool = True):
        """ Add a new frame to this Tracklet. Filter the tracklet's display region. """

        self._filter_frame(track_frame)
        self.track_frames.append(track_frame)

        # Also automatically register a hit to this Tracklet.
        if register_hit:
            self.update(True)

    def update(self, hit: bool = True):
        """ This function should be called every frame, to either register a hit or miss. """
        if self._lost:
            self._step_kill_animation()
            return

        self._register(hit)

    # ===================================================================================================
    # Private Functions.
    # ===================================================================================================

    def _filter_frame(self, track_frame: TrackFrame) -> TrackFrame:
        """ Smoothly filter the position and size of the new frame. """
        if len(self.track_frames) > 0:
            pt = self.track_frames[-1]
            track_frame.x = self._position_filter.process(track_frame.x, pt.x)
            track_frame.y = self._position_filter.process(track_frame.y, pt.y)
            track_frame.width = self._size_filter.process(track_frame.width, pt.width)
            track_frame.height = self._size_filter.process(track_frame.height, pt.height)
        return track_frame

    def _register(self, hit: bool = True):
        """ Register a hit or a miss, and update the counters. """
        if hit:
            self._hit_counter += 1
            self._miss_counter = 0
        else:
            self._miss_counter += 1
            self._hit_counter = 0

        self._check_and_activate()
        self._check_and_kill()

    def _check_and_activate(self):
        """ Check the conditions for activating this Tracklet. Execute it if passed. """
        if not self._activated and self._hit_counter >= self._hit_limit:
            self._activated = True

    def _check_and_kill(self):
        """ Check the conditions for losing this Tracklet. Execute it if passed. """
        if not self._lost and self._miss_counter >= self._miss_limit:
            self._lost = True

            # If it has never been activated, kill it immediately.
            if not self._activated:
                self.visual_state = VisualState.KILLED

    # ===================================================================================================
    # Access Properties.
    # ===================================================================================================

    @property
    def is_recent(self) -> bool:
        """ Received a hit in the latest update cycle. """
        return self._hit_counter > 0

    @property
    def is_live(self) -> bool:
        """ Received enough hits to be activated, and has not yet been lost."""
        return self._activated and not self._lost

    @property
    def is_activated(self) -> bool:
        """ Received enough hits to be considered activated. """
        return self._activated

    @property
    def is_lost(self) -> bool:
        """ Received enough misses to be considered lost."""
        return self._lost

    @property
    def is_displayable(self) -> bool:
        """ Received enough misses to be considered lost."""
        return self.is_activated and self.visual_state != VisualState.KILLED

    @property
    def first_frame(self) -> TrackFrame:
        return self.track_frames[0]

    @property
    def last_frame(self) -> TrackFrame:
        return self.track_frames[-1]

    @property
    def miss_limit(self) -> int:
        return self._miss_limit

    @property
    def hit_limit(self) -> int:
        return self._hit_limit

    @property
    def frame_count(self) -> int:
        """ Number of frames in this Tracklet so far. """
        return len(self.track_frames)

    # ======================================================================================================================
    # Visual and animation functions.
    # ======================================================================================================================

    @property
    def raw_region(self):
        """ Get the latest raw region of this Tracklet. """
        return self.last_frame.raw_region.clone()

    @property
    def display_region(self):
        """ Gets the display region to show for this current frame."""
        last_region = self.last_frame.display_region.clone()
        if self.is_lost:
            last_region.data["color"] = self._get_kill_animation_color()
        else:
            last_region.data["color"] = self._color
        return last_region

    def _step_kill_animation(self):
        """ Update the kill animation counter. """
        self._anim_kill_counter += 1
        if self._anim_kill_counter >= self._ANIM_KILL_MAX:
            self.visual_state = VisualState.KILLED

    def _get_kill_animation_color(self) -> Tuple:
        """ Get the current display color for this step of the animation. """
        progress = self._anim_kill_counter / self._ANIM_KILL_MAX
        if self._red_fade:
            if progress < 0.5:
                # Flash the box for a while.
                if self._anim_kill_counter % 2 == 0:
                    return self._PINK
                else:
                    return 0, 0, 100
            else:
                # Fade out.
                return core.lerp_color(self._RED, self._BLACK, progress)
        else:
            # Fade out.
            return core.lerp_color(self._color, self._BLACK, 0.5 + progress * 0.5)


class Tracker:

    def __init__(self):
        self.tracklets = []

    @abstractmethod
    def process(self, regions: List[TrackingRegion], frame_index: int = 0) -> List[Tracklet]:
        """ Process the new regions and return a list of dead tracklets. """
        pass

    # ======================================================================================================================
    # Utility Functions.
    # ======================================================================================================================

    def save_image(self, frame: np.array):
        for tracklet in self.tracklets:
            if tracklet.is_recent and tracklet.image is None and tracklet.is_live:
                tracklet.image = visual.safe_extract_with_region(frame, tracklet.display_region)

    def remove_dead_tracklets(self) -> List[Tracklet]:
        """ Get rid of the tracklets that we don't need anymore. """
        dead_tracklets = [t for t in self.tracklets if t.is_lost and not t.is_displayable]
        self.tracklets = [t for t in self.tracklets if not t.is_lost or t.is_displayable]
        return dead_tracklets

    def reset(self):
        self.tracklets = []

    @staticmethod
    def _convert_to_track_frames(regions: List[TrackingRegion], frame_index: int = 0,
                                 ratio_lock: float = 0.0, scale_factor: float = 1.0) -> List[TrackFrame]:
        """ Convert from TrackingRegions to a list of Tracklets. """
        track_frames = []
        for region in regions:
            track_frame = TrackFrame(region, ratio_lock=ratio_lock, scale_factor=scale_factor)
            track_frame.frame_index = frame_index
            track_frames.append(track_frame)
        return track_frames

    # ======================================================================================================================
    # Convenience Properties.
    # ======================================================================================================================

    @property
    def live_regions(self) -> List[TrackingRegion]:
        """ Regions that have been activated, and is still active. """
        return [t.display_region for t in self.tracklets if t.is_live]

    @property
    def lost_regions(self) -> List[TrackingRegion]:
        """ Regions that were active, but is now lost. """
        return [t.display_region for t in self.tracklets if t.is_lost]

    @property
    def raw_regions(self) -> List[TrackingRegion]:
        """ All raw detector regions. """
        return [t.raw_region for t in self.tracklets if t.is_recent]

    @property
    def tracklet_count(self):
        """ Returns the number of currently active tracklets. """
        return len(self.tracklets)
