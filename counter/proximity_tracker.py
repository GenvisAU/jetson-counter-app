from typing import List
from tools.tracking_tool import Tracker, TrackingRegion, TrackFrame, Tracklet
from tools.region import Region

__author__ = "Jakrin Juangbhanich"
__email__ = "juangbhanich.k@gmail.com"


class TrackletPair:
    def __init__(self, tracklet: Tracklet, new_frame: TrackFrame, distance: float):
        self.tracklet = tracklet
        self.new_frame = new_frame
        self.distance = distance


class ProximityTracker(Tracker):

    def __init__(self, ratio_lock: float=1.0, scale_factor: float=1.5, reach: float=1.5):
        self.ratio_lock = ratio_lock
        self.scale_factor = scale_factor
        self.reach = reach
        super().__init__()

    def process(self, regions: List[TrackingRegion], frame_index: int = 0) -> List[Tracklet]:
        new_frames = self._convert_to_track_frames(regions, frame_index, self.ratio_lock, self.scale_factor)

        # Compare each detection to each other, and make a list of them.
        tracklet_pairs = []
        for tracklet in self.tracklets:

            if tracklet.is_lost:
                continue

            old_t = tracklet.track_frames[-1]
            for new_t in new_frames:
                distance = Region.distance(new_t.raw_region, old_t.raw_region)
                reach = new_t.raw_region.biggest_edge * self.reach
                if distance < reach:
                    t_pair = TrackletPair(tracklet, new_t, distance)
                    tracklet_pairs.append(t_pair)

        # For each valid pair, merge them.
        tracklet_pairs.sort(key=lambda x: x.distance)
        merged = {}

        for pair in tracklet_pairs:
            if pair.new_frame not in merged and pair.tracklet not in merged:
                merged[pair.new_frame] = True
                merged[pair.tracklet] = True
                pair.tracklet.add(pair.new_frame)

        # TODO: This loop is probably not efficient.
        # Decay the non-hit tracklets.
        for tracklet in self.tracklets:
            if tracklet not in merged:
                tracklet.update(hit=False)

        # Add all the un-merged detections.
        for frame in new_frames:
            if frame not in merged:
                tracklet = Tracklet(color=(255, 150, 30), red_fade=True)
                tracklet.add(frame)
                self.tracklets.append(tracklet)

        # Prune the list of all the tracks.
        return self.remove_dead_tracklets()
