#!/usr/bin/env python3
"""Strip Jitter-style corner watermarks from Lottie JSON exports.

Jitter free exports often bake a small outlined badge (vector paths, not text
layers) into the bottom-right corner, parented under a null near (right, bottom).
This tool detects that precomp, removes it (and orphan null parents), then GCs
unreferenced assets.

Usage:
  python tool/strip_lottie_jitter_watermark.py assets/Scene.json
  python tool/strip_lottie_jitter_watermark.py assets/Scene.json -o out.json
  python tool/strip_lottie_jitter_watermark.py assets/Scene.json --in-place
  python tool/strip_lottie_jitter_watermark.py assets/Scene.json --dry-run
"""

from __future__ import annotations

import argparse
import json
import sys
from copy import deepcopy
from pathlib import Path
from typing import Any


def _first_vec(k: Any) -> list[float] | None:
    """Return a static [x, y, ...] or the first keyframe's `s` value."""
    if k is None:
        return None
    if isinstance(k, list) and k and isinstance(k[0], (int, float)):
        return [float(v) for v in k]
    if isinstance(k, list) and k and isinstance(k[0], dict):
        s = k[0].get("s")
        if isinstance(s, list) and s and isinstance(s[0], (int, float)):
            return [float(v) for v in s]
    return None


def _layer_local_pos(layer: dict[str, Any]) -> tuple[float, float]:
    ks = layer.get("ks") or {}
    p = _first_vec((ks.get("p") or {}).get("k"))
    if p and len(p) >= 2:
        return p[0], p[1]
    return 0.0, 0.0


def _layer_map(layers: list[dict[str, Any]]) -> dict[Any, dict[str, Any]]:
    return {L["ind"]: L for L in layers if "ind" in L}


def _abs_pos(
    layer: dict[str, Any],
    by_ind: dict[Any, dict[str, Any]],
    cache: dict[Any, tuple[float, float]],
) -> tuple[float, float]:
    ind = layer.get("ind")
    if ind in cache:
        return cache[ind]
    x, y = _layer_local_pos(layer)
    parent_id = layer.get("parent")
    if parent_id is not None and parent_id in by_ind:
        px, py = _abs_pos(by_ind[parent_id], by_ind, cache)
        x, y = x + px, y + py
    if ind is not None:
        cache[ind] = (x, y)
    return x, y


def _precomp_size(layer: dict[str, Any]) -> tuple[float, float] | None:
    if layer.get("ty") != 0:
        return None
    w, h = layer.get("w"), layer.get("h")
    if isinstance(w, (int, float)) and isinstance(h, (int, float)):
        return float(w), float(h)
    return None


def find_watermark_layers(
    data: dict[str, Any],
    *,
    right_frac: float = 0.45,
    bottom_frac: float = 0.70,
    max_w_frac: float = 0.55,
    max_h_frac: float = 0.20,
) -> list[dict[str, Any]]:
    """Find top-level precomps that look like a bottom-right watermark badge."""
    w = float(data.get("w") or 0)
    h = float(data.get("h") or 0)
    if w <= 0 or h <= 0:
        return []

    layers = list(data.get("layers") or [])
    by_ind = _layer_map(layers)
    cache: dict[Any, tuple[float, float]] = {}
    hits: list[dict[str, Any]] = []

    for layer in layers:
        size = _precomp_size(layer)
        if size is None:
            continue
        pw, ph = size
        # Watermarks are small corner badges, not the main title block.
        if pw > w * max_w_frac or ph > h * max_h_frac:
            continue
        ax, ay = _abs_pos(layer, by_ind, cache)
        # Position is usually the precomp origin; require it sits in BR region.
        if ax < w * right_frac or ay < h * bottom_frac:
            continue
        hits.append(
            {
                "ind": layer.get("ind"),
                "refId": layer.get("refId"),
                "parent": layer.get("parent"),
                "abs_pos": (ax, ay),
                "size": (pw, ph),
            }
        )
    return hits


def _collect_asset_refs(layers: list[dict[str, Any]] | None, out: set[str]) -> None:
    for layer in layers or []:
        ref = layer.get("refId")
        if ref is not None:
            out.add(str(ref))


def _asset_closure(assets: list[dict[str, Any]], roots: set[str]) -> set[str]:
    by_id = {str(a.get("id")): a for a in assets if a.get("id") is not None}
    keep: set[str] = set()
    stack = list(roots)
    while stack:
        aid = str(stack.pop())
        if aid in keep:
            continue
        if aid not in by_id:
            continue
        keep.add(aid)
        refs: set[str] = set()
        _collect_asset_refs(by_id[aid].get("layers"), refs)
        stack.extend(refs)
    return keep


def _orphan_null_inds(
    layers: list[dict[str, Any]],
    removed: set[Any],
) -> set[Any]:
    """Null layers (ty=3) that no longer have any children after removals."""
    remaining = [L for L in layers if L.get("ind") not in removed]
    parents_with_kids = {
        L.get("parent") for L in remaining if L.get("parent") is not None
    }
    orphans: set[Any] = set()
    for layer in remaining:
        if layer.get("ty") != 3:
            continue
        ind = layer.get("ind")
        if ind is None or ind in parents_with_kids:
            continue
        # Only drop nulls that were part of the watermark parent chain:
        # they must have been parents of something we already removed.
        if any(
            (L.get("parent") == ind and L.get("ind") in removed)
            or False
            for L in layers
        ):
            # Walk: if this null only existed to host removed layers, drop it.
            # Safer: drop null if it has zero remaining children (already true)
            # AND it previously had children in the removed set.
            had_removed_child = any(
                L.get("parent") == ind and L.get("ind") in removed for L in layers
            )
            if had_removed_child:
                orphans.add(ind)
    # Cascade: null whose only children were other orphan nulls
    changed = True
    while changed:
        changed = False
        remaining = [L for L in layers if L.get("ind") not in removed | orphans]
        parents_with_kids = {
            L.get("parent") for L in remaining if L.get("parent") is not None
        }
        for layer in remaining:
            if layer.get("ty") != 3:
                continue
            ind = layer.get("ind")
            if ind is None or ind in parents_with_kids:
                continue
            # Only cascade-nulls that sit under a still-used tree if they became empty
            # after watermark removal. Avoid deleting root structural nulls that never
            # had children removed — require they parented something in removed|orphans.
            if any(L.get("parent") == ind and L.get("ind") in (removed | orphans) for L in layers):
                if ind not in orphans:
                    orphans.add(ind)
                    changed = True
    return orphans


def strip_watermark(
    data: dict[str, Any],
    *,
    force_inds: list[int] | None = None,
) -> tuple[dict[str, Any], dict[str, Any]]:
    """Return (cleaned_data, report)."""
    out = deepcopy(data)
    layers: list[dict[str, Any]] = list(out.get("layers") or [])
    report: dict[str, Any] = {
        "generator": (out.get("meta") or {}).get("g"),
        "comp": {"w": out.get("w"), "h": out.get("h")},
        "candidates": [],
        "removed_layers": [],
        "removed_assets": [],
    }

    if force_inds:
        to_remove = set(force_inds)
        report["candidates"] = [{"ind": i, "forced": True} for i in force_inds]
    else:
        candidates = find_watermark_layers(out)
        report["candidates"] = candidates
        to_remove = {c["ind"] for c in candidates if c.get("ind") is not None}

    if not to_remove:
        report["changed"] = False
        report["note"] = "No bottom-right watermark precomp detected."
        return out, report

    orphans = _orphan_null_inds(layers, to_remove)
    to_remove |= orphans

    removed_layers = [L for L in layers if L.get("ind") in to_remove]
    report["removed_layers"] = [
        {
            "ind": L.get("ind"),
            "ty": L.get("ty"),
            "refId": L.get("refId"),
            "parent": L.get("parent"),
            "pos": _layer_local_pos(L),
            "size": _precomp_size(L),
        }
        for L in removed_layers
    ]
    out["layers"] = [L for L in layers if L.get("ind") not in to_remove]

    # GC assets no longer referenced from root layers.
    root_refs: set[str] = set()
    _collect_asset_refs(out.get("layers"), root_refs)
    keep = _asset_closure(list(out.get("assets") or []), root_refs)
    assets = list(out.get("assets") or [])
    removed_assets = [a for a in assets if str(a.get("id")) not in keep]
    report["removed_assets"] = [a.get("id") for a in removed_assets]
    out["assets"] = [a for a in assets if str(a.get("id")) in keep]

    report["changed"] = True
    report["remaining_layers"] = len(out["layers"])
    report["remaining_assets"] = len(out.get("assets") or [])
    return out, report


def _dump_minified(data: dict[str, Any]) -> str:
    # Match typical Jitter export: single-line compact JSON.
    return json.dumps(data, ensure_ascii=False, separators=(",", ":"))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Remove Jitter bottom-right watermark precomps from Lottie JSON."
    )
    parser.add_argument("input", type=Path, help="Path to Scene.json / Lottie JSON")
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        default=None,
        help="Output path (default: <input> with .nowm.json suffix)",
    )
    parser.add_argument(
        "--in-place",
        action="store_true",
        help="Overwrite the input file",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Detect and report only; do not write",
    )
    parser.add_argument(
        "--force-ind",
        type=int,
        action="append",
        default=None,
        help="Force-remove top-level layer ind (repeatable). Skips auto-detect.",
    )
    parser.add_argument(
        "--pretty",
        action="store_true",
        help="Pretty-print JSON instead of minified",
    )
    args = parser.parse_args(argv)

    src: Path = args.input
    if not src.is_file():
        print(f"error: file not found: {src}", file=sys.stderr)
        return 1

    raw = src.read_text(encoding="utf-8")
    try:
        data = json.loads(raw)
    except json.JSONDecodeError as e:
        print(f"error: invalid JSON: {e}", file=sys.stderr)
        return 1

    cleaned, report = strip_watermark(data, force_inds=args.force_ind)

    print(f"input: {src}")
    print(f"comp:  {report['comp']['w']}x{report['comp']['h']}")
    print(f"meta.g: {report.get('generator')}")
    print(f"candidates: {len(report.get('candidates') or [])}")
    for c in report.get("candidates") or []:
        print(f"  - {c}")
    print(f"removed layers ({len(report.get('removed_layers') or [])}):")
    for L in report.get("removed_layers") or []:
        print(f"  - {L}")
    print(f"removed assets: {report.get('removed_assets')}")

    if not report.get("changed"):
        print(report.get("note") or "No changes.")
        return 2

    if args.dry_run:
        print("dry-run: no file written")
        return 0

    if args.in_place:
        dst = src
    elif args.output is not None:
        dst = args.output
    else:
        dst = src.with_suffix(src.suffix + ".nowm.json")
        # e.g. Scene.json -> Scene.json.nowm.json is ugly; prefer Scene.nowm.json
        dst = src.with_name(src.stem + ".nowm" + src.suffix)

    text = (
        json.dumps(cleaned, ensure_ascii=False, indent=2)
        if args.pretty
        else _dump_minified(cleaned)
    )
    dst.write_text(text, encoding="utf-8")
    print(f"wrote: {dst} ({dst.stat().st_size} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
