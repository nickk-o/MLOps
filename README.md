# Lesson 3 — Docker image для PyTorch TorchScript inference

Цей проєкт демонструє контейнеризацію ML-моделі на PyTorch:

- експорт `torchvision.models.mobilenet_v2` у TorchScript (`model.pt`);
- запуск `inference.py`, який повертає top-3 класи для зображення;
- побудову двох Docker-образів: `fat` і `slim`;
- порівняння розміру, шарів і зайвих інструментів у `report.md`.

## Структура

```text
lesson-3/
├── inference.py
├── export_model.py
├── model.pt                 # створюється командою python3 export_model.py
├── imagenet_classes.txt     # створюється командою python3 export_model.py
├── requirements.txt
├── Dockerfile.fat
├── Dockerfile.slim
├── install_dev_tools.sh
├── report.md
└── README.md
```

## 1. Підготовка середовища

```bash
chmod +x install_dev_tools.sh
./install_dev_tools.sh
```

Скрипт перевіряє та встановлює Docker, Docker Compose, Python 3.9+, pip і Python-бібліотеки `torch`, `torchvision`, `pillow`, `Django`. Лог записується у `install.log`.

## 2. Експорт TorchScript-моделі

```bash
python3 -m pip install -r requirements.txt
python3 export_model.py
```

Після запуску мають зʼявитися файли:

```text
model.pt
imagenet_classes.txt
```

Якщо немає інтернету для завантаження pretrained weights, можна створити модель без ваг:

```bash
python3 export_model.py --no-pretrained
```

## 3. Тест локального inference

Завантажити тестове зображення:

```bash
wget https://upload.wikimedia.org/wikipedia/commons/2/26/YellowLabradorLooking_new.jpg -O example.jpg
```

Запустити inference локально:

```bash
python3 inference.py example.jpg --model model.pt --labels imagenet_classes.txt
```

Очікуваний формат відповіді:

```json
{
  "image": "example.jpg",
  "top_k": [
    {"class_id": 208, "class_name": "Labrador retriever", "probability": 0.123456},
    {"class_id": 207, "class_name": "golden retriever", "probability": 0.123456},
    {"class_id": 209, "class_name": "Chesapeake Bay retriever", "probability": 0.123456}
  ]
}
```

## 4. Побудова Docker-образів

```bash
docker build -f Dockerfile.fat -t lesson3-pytorch-fat .
docker build -f Dockerfile.slim -t lesson3-pytorch-slim .
```

## 5. Запуск контейнерів

Linux/macOS:

```bash
docker run --rm -v "$PWD/example.jpg:/app/example.jpg:ro" lesson3-pytorch-fat /app/example.jpg
docker run --rm -v "$PWD/example.jpg:/app/example.jpg:ro" lesson3-pytorch-slim /app/example.jpg
```

PowerShell у Windows:

```powershell
docker run --rm -v "${PWD}/example.jpg:/app/example.jpg:ro" lesson3-pytorch-fat /app/example.jpg
docker run --rm -v "${PWD}/example.jpg:/app/example.jpg:ro" lesson3-pytorch-slim /app/example.jpg
```

## 6. Команди для заповнення звіту

Розмір образів:

```bash
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | grep lesson3-pytorch
```

Кількість шарів:

```bash
docker history -q lesson3-pytorch-fat | wc -l
docker history -q lesson3-pytorch-slim | wc -l
```

Історія шарів:

```bash
docker history lesson3-pytorch-fat
docker history lesson3-pytorch-slim
```
