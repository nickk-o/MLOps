#!/usr/bin/env python3
"""Run top-3 image classification using a TorchScript model."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Sequence

import torch
from PIL import Image


IMAGENET_MEAN = torch.tensor([0.485, 0.456, 0.406]).view(3, 1, 1)
IMAGENET_STD = torch.tensor([0.229, 0.224, 0.225]).view(3, 1, 1)


def load_labels(path: Path | None) -> list[str]:
    if path and path.exists():
        return [line.strip() for line in path.read_text(encoding="utf-8").splitlines()]
    return [f"class_{i}" for i in range(1000)]


def resize_shorter_side(image: Image.Image, size: int = 256) -> Image.Image:
    width, height = image.size
    if width < height:
        new_width = size
        new_height = round(height * size / width)
    else:
        new_height = size
        new_width = round(width * size / height)
    return image.resize((new_width, new_height), Image.Resampling.BILINEAR)


def center_crop(image: Image.Image, crop_size: int = 224) -> Image.Image:
    width, height = image.size
    left = (width - crop_size) // 2
    top = (height - crop_size) // 2
    right = left + crop_size
    bottom = top + crop_size
    return image.crop((left, top, right, bottom))


def preprocess(image_path: Path) -> torch.Tensor:
    image = Image.open(image_path).convert("RGB")
    image = resize_shorter_side(image, 256)
    image = center_crop(image, 224)

    # PIL RGB image -> torch tensor with shape [C, H, W] and values in [0, 1].
    byte_tensor = torch.tensor(list(image.tobytes()), dtype=torch.uint8)
    tensor = byte_tensor.view(image.height, image.width, 3).permute(2, 0, 1).float() / 255.0
    tensor = (tensor - IMAGENET_MEAN) / IMAGENET_STD
    return tensor.unsqueeze(0)


def predict_topk(
    model_path: Path,
    image_path: Path,
    labels: Sequence[str],
    top_k: int = 3,
) -> list[dict[str, object]]:
    model = torch.jit.load(str(model_path), map_location="cpu")
    model.eval()

    input_tensor = preprocess(image_path)
    with torch.no_grad():
        output = model(input_tensor)
        probabilities = torch.nn.functional.softmax(output[0], dim=0)
        top_probabilities, top_indices = torch.topk(probabilities, k=top_k)

    predictions: list[dict[str, object]] = []
    for probability, class_index in zip(top_probabilities, top_indices):
        class_id = int(class_index.item())
        class_name = labels[class_id] if class_id < len(labels) else f"class_{class_id}"
        predictions.append(
            {
                "class_id": class_id,
                "class_name": class_name,
                "probability": round(float(probability.item()), 6),
            }
        )
    return predictions


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="TorchScript image classifier inference")
    parser.add_argument("image", type=Path, help="Path to an input image")
    parser.add_argument("--model", default=Path("model.pt"), type=Path, help="Path to TorchScript .pt model")
    parser.add_argument(
        "--labels",
        default=Path("imagenet_classes.txt"),
        type=Path,
        help="Path to ImageNet class labels",
    )
    parser.add_argument("--top-k", default=3, type=int, help="Number of classes to print")
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    labels = load_labels(args.labels)
    result = predict_topk(args.model, args.image, labels, args.top_k)
    print(json.dumps({"image": str(args.image), "top_k": result}, indent=2, ensure_ascii=False))