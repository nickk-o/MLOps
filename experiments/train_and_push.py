import json
import os
import shutil
from pathlib import Path
from tempfile import TemporaryDirectory

import mlflow
from dotenv import load_dotenv
from prometheus_client import CollectorRegistry, Gauge, push_to_gateway
from sklearn.datasets import load_iris
from sklearn.metrics import accuracy_score, log_loss
from sklearn.model_selection import train_test_split
from sklearn.neural_network import MLPClassifier
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler


load_dotenv()

TRACKING_URI = os.getenv("MLFLOW_TRACKING_URI", "http://localhost:5000")
PUSHGATEWAY_URL = os.getenv("PUSHGATEWAY_URL", "http://localhost:9091")
EXPERIMENT_NAME = os.getenv("MLFLOW_EXPERIMENT_NAME", "Iris Classification")
BEST_MODEL_DIR = Path(os.getenv("BEST_MODEL_DIR", "best_model"))
MINIO_ENDPOINT_URL = os.getenv("MLFLOW_S3_ENDPOINT_URL", "http://localhost:9000")
MINIO_ACCESS_KEY = os.getenv("AWS_ACCESS_KEY_ID", "minio")
MINIO_SECRET_KEY = os.getenv("AWS_SECRET_ACCESS_KEY", "minio123")

os.environ.setdefault("MLFLOW_S3_ENDPOINT_URL", MINIO_ENDPOINT_URL)
os.environ.setdefault("AWS_ACCESS_KEY_ID", MINIO_ACCESS_KEY)
os.environ.setdefault("AWS_SECRET_ACCESS_KEY", MINIO_SECRET_KEY)
os.environ.setdefault("AWS_DEFAULT_REGION", os.getenv("AWS_DEFAULT_REGION", "us-east-1"))

HYPERPARAMETERS = [
    {"learning_rate": 0.001, "epochs": 150},
    {"learning_rate": 0.005, "epochs": 200},
    {"learning_rate": 0.01, "epochs": 250},
]


def get_or_create_experiment(experiment_name: str) -> str:
    experiment = mlflow.get_experiment_by_name(experiment_name)
    if experiment is not None:
        return experiment.experiment_id
    return mlflow.create_experiment(experiment_name)


def push_metrics(run_id: str, accuracy: float, loss: float) -> None:
    registry = CollectorRegistry()
    accuracy_gauge = Gauge(
        "mlflow_accuracy",
        "Accuracy logged from MLflow experiment runs",
        registry=registry,
    )
    loss_gauge = Gauge(
        "mlflow_loss",
        "Loss logged from MLflow experiment runs",
        registry=registry,
    )
    accuracy_gauge.set(accuracy)
    loss_gauge.set(loss)
    push_to_gateway(
        PUSHGATEWAY_URL,
        job="mlflow-training",
        grouping_key={"run_id": run_id},
        registry=registry,
    )


def copy_best_model(run_id: str, destination_root: Path) -> Path:
    if destination_root.exists():
        shutil.rmtree(destination_root)
    destination_root.mkdir(parents=True, exist_ok=True)

    with TemporaryDirectory() as tmp_dir:
        local_artifact_path = mlflow.artifacts.download_artifacts(
            artifact_uri=f"runs:/{run_id}/model",
            dst_path=tmp_dir,
        )
        model_source = Path(local_artifact_path)
        final_path = destination_root / run_id
        shutil.copytree(model_source, final_path)
        return final_path


def main() -> None:
    mlflow.set_tracking_uri(TRACKING_URI)
    experiment_id = get_or_create_experiment(EXPERIMENT_NAME)

    X, y = load_iris(return_X_y=True)
    X_train, X_test, y_train, y_test = train_test_split(
        X,
        y,
        test_size=0.2,
        random_state=42,
        stratify=y,
    )

    best_run = None

    for params in HYPERPARAMETERS:
        run_name = f"lr={params['learning_rate']}-epochs={params['epochs']}"
        with mlflow.start_run(experiment_id=experiment_id, run_name=run_name) as run:
            model = Pipeline(
                steps=[
                    ("scaler", StandardScaler()),
                    (
                        "classifier",
                        MLPClassifier(
                            hidden_layer_sizes=(16, 8),
                            learning_rate_init=params["learning_rate"],
                            max_iter=params["epochs"],
                            random_state=42,
                        ),
                    ),
                ]
            )

            model.fit(X_train, y_train)
            y_pred = model.predict(X_test)
            y_proba = model.predict_proba(X_test)

            accuracy = accuracy_score(y_test, y_pred)
            loss = log_loss(y_test, y_proba)

            mlflow.log_params(params)
            mlflow.log_metrics({"accuracy": accuracy, "loss": loss})
            mlflow.log_dict(
                {
                    "run_id": run.info.run_id,
                    "params": params,
                    "accuracy": accuracy,
                    "loss": loss,
                },
                "summary.json",
            )
            mlflow.sklearn.log_model(model, "model")

            push_metrics(run.info.run_id, accuracy, loss)

            run_info = {
                "run_id": run.info.run_id,
                "accuracy": accuracy,
                "loss": loss,
                "params": params,
            }
            if best_run is None:
                best_run = run_info
            else:
                if accuracy > best_run["accuracy"] or (
                    accuracy == best_run["accuracy"] and loss < best_run["loss"]
                ):
                    best_run = run_info

            print(
                json.dumps(
                    {
                        "run_id": run.info.run_id,
                        "accuracy": round(accuracy, 4),
                        "loss": round(loss, 4),
                        "params": params,
                    }
                )
            )

    if best_run is None:
        raise RuntimeError("No MLflow runs were created.")

    best_model_path = copy_best_model(best_run["run_id"], BEST_MODEL_DIR)
    print(
        json.dumps(
            {
                "best_run_id": best_run["run_id"],
                "best_accuracy": round(best_run["accuracy"], 4),
                "best_loss": round(best_run["loss"], 4),
                "best_model_path": str(best_model_path),
            }
        )
    )


if __name__ == "__main__":
    main()
