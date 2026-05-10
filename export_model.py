#!/usr/bin/env python3
"""Export a torchvision model to TorchScript.

Default model: MobileNetV2 with ImageNet weights.
If the pretrained weights cannot be downloaded, the script falls back to a
randomly initialized MobileNetV2 so the TorchScript export still works.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import torch
import torchvision.models as models


DEFAULT_LABELS = [f"class_{i}" for i in range(1000)]


def build_model(use_pretrained: bool = True):
    """Create MobileNetV2 and return (model, categories)."""
    if use_pretrained:
        try:
            weights = models.MobileNet_V2_Weights.DEFAULT
            model = models.mobilenet_v2(weights=weights)
            categories = weights.meta.get("categories", DEFAULT_LABELS)
            print("Loaded MobileNetV2 with pretrained ImageNet weights.")
            return model, categories
        except Exception as exc:  # noqa: BLE001 - fallback is intentional for offline runs
            print(f"Could not load pretrained weights: {exc}")
            print("Falling back to randomly initialized MobileNetV2.")

    model = models.mobilenet_v2(weights=None)
    return model, DEFAULT_LABELS


def export_torchscript(output_path: Path, labels_path: Path, no_pretrained: bool) -> None:
    model, categories = build_model(use_pretrained=not no_pretrained)
    model.eval()

    dummy_input = torch.randn(1, 3, 224, 224)
    with torch.no_grad():
        traced_model = torch.jit.trace(model, dummy_input)

    traced_model.save(str(output_path))
    labels_path.write_text("\n".join(categories) + "\n", encoding="utf-8")

    print(f"Saved TorchScript model to: {output_path}")
    print(f"Saved labels to: {labels_path}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Export MobileNetV2 to TorchScript")
    parser.add_argument("--output", default="model.pt", type=Path, help="Output .pt path")
    parser.add_argument(
        "--labels",
        default="imagenet_classes.txt",
        type=Path,
        help="Output labels file path",
    )
    parser.add_argument(
        "--no-pretrained",
        action="store_true",
        help="Do not download pretrained ImageNet weights",
    )
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    export_torchscript(args.output, args.labels, args.no_pretrained)