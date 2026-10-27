"""Unit tests for the share page geometry helpers: python -m pytest share-page/test_share_page.py"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import share_pictures as pics  # noqa: E402


def test_union_outline_of_one_rect_is_its_corners():
    assert pics.union_outline([(2, 3, 4, 5)]) == [(2, 3), (6, 3), (6, 8), (2, 8)]


def test_union_outline_l_shape_drops_inner_edges():
    pts = pics.union_outline([(0, 0, 4, 2), (0, 2, 2, 2)])
    assert sorted(pts) == sorted([(0, 0), (4, 0), (4, 2), (2, 2), (2, 4), (0, 4)])


def test_union_outline_deep_playa_layout_is_one_shape():
    rects = [(276, 57, 28, 31), (244, 57, 32, 27), (304, 57, 38, 31), (342, 57, 33, 31), (265, 29, 39, 28),
             (304, 29, 38, 28), (342, 29, 33, 28), (342, 1, 33, 28), (304, 1, 38, 28), (265, 1, 39, 28)]
    pts = pics.union_outline(rects)
    assert (244, 57) in pts and (244, 84) in pts and (276, 88) in pts and (375, 1) in pts
    assert len(pts) == 8


def test_bounds():
    assert pics.bounds([(1, 2, 3, 4), (10, 0, 2, 2)]) == (1, 0, 11, 6)
