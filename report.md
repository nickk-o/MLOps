# Звіт: порівняння Docker-образів для PyTorch inference

## Мета

Мета роботи — створити inference-сервіс для TorchScript-моделі PyTorch і порівняти два Docker-образи:

1. **Fat image** — простий, але великий образ з повним Python base image, системними залежностями та debug-інструментами.
2. **Slim image** — оптимізований multi-stage образ, у фінальний етап якого потрапляють лише Python-залежності, `inference.py`, `model.pt` і файл класів.

## Використана модель

Для завдання використано `torchvision.models.mobilenet_v2`.
Модель експортовано у TorchScript командою:

```bash
python3 export_model.py
```

Для inference використовується команда:

```bash
python3 inference.py example.jpg --model model.pt --labels imagenet_classes.txt
```

Скрипт `inference.py`:

- завантажує TorchScript-модель через `torch.jit.load`;
- відкриває зображення через `Pillow`;
- виконує resize, center crop і ImageNet-нормалізацію;
- повертає top-3 класи у JSON-форматі.

## Команди збірки

```bash
docker build -f Dockerfile.fat -t lesson3-pytorch-fat .
docker build -f Dockerfile.slim -t lesson3-pytorch-slim .
```

## Команди запуску

```bash
docker run --rm -v "$PWD/example.jpg:/app/example.jpg:ro" lesson3-pytorch-fat /app/example.jpg
docker run --rm -v "$PWD/example.jpg:/app/example.jpg:ro" lesson3-pytorch-slim /app/example.jpg
```

## Порівняння образів

| Параметр | Fat image | Slim image |
|---|---:|---:|
| Назва образу | `lesson3-pytorch-fat` | `lesson3-pytorch-slim` |
| Базовий образ | `python:3.9` | `python:3.9-slim` + multi-stage |
| Розмір | `3.41GB` | `2.95GB` |
| Кількість шарів | `22` | `17` |
| Debug/tools пакети | `build-essential`, `curl`, `git`, `wget`, `vim`, `less`, `ping` | не встановлюються окремо |
| Підхід до залежностей | встановлення прямо у фінальний образ | встановлення у builder stage і копіювання `/install` |
| Призначення | простіше налагоджувати | краще для production |

## Аналіз

Fat-образ має більший розмір, оскільки містить більше системних пакетів, build-залежностей та проміжних файлів. Такий підхід простіший для розробки, але менш ефективний для production-середовища.

Slim-образ використовує multi-stage build. На першому етапі встановлюються залежності, а у фінальний образ копіюються лише необхідні файли для запуску inference: inference.py, model.pt, imagenet_classes.txt та Python-залежності. Завдяки цьому кількість шарів зменшилась з 22 до 17, а розмір образу — з 3.41 GB до 2.95 GB.

Різниця у розмірі становить приблизно 0.46 GB, тобто slim-образ є компактнішим приблизно на 13–14%.

### Проблеми fat-образу

Fat-образ має такі недоліки:
- більший розмір;
- більше Docker-шарів;
- потенційно більше зайвих системних утиліт;
- більший attack surface;
- довше завантаження у registry або Kubernetes-кластер;
- менш ефективне використання кешу в CI/CD.

## Пропозиції з подальшої оптимізації
Для подальшого зменшення образу можна:
- фіксувати конкретні версії залежностей у requirements.txt;
- видаляти pip cache та тимчасові файли;
- використовувати .dockerignore;
- спробувати distroless-образи для production;
- зменшити кількість системних пакетів;
- не копіювати в образ зайві файли, наприклад .git, venv, кеші IDE.

## Висновок

Обидва образи виконують одну задачу — запускають TorchScript inference для зображення. Fat-образ простіший для налагодження, але містить багато зайвого. Slim-образ краще відповідає MLOps-практикам, бо має менший attack surface, менший розмір і чіткіше розділяє build-time та runtime-залежності.
