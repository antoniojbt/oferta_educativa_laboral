from pathlib import Path
import importlib
import inspect
import sys
import pytest


def test_pipeline_exists():
    """Ensure the example pipeline file is present."""
    base = Path(__file__).resolve().parents[1]
    path = base / "oferta_educativa_laboral" / "pipeline" / "pipeline_test.py"
    assert path.is_file()


def test_pipeline_tasks_present():
    """Import the real pipeline and verify key tasks are defined."""
    base = Path(__file__).resolve().parents[1]
    sys.path.insert(0, str(base))
    module = importlib.import_module(
        "oferta_educativa_laboral.pipeline.pipeline_oferta_laboral"
    )
    functions = {
        name for name, obj in inspect.getmembers(module) if inspect.isfunction(obj)
    }
    expected = {"convert_to_csv", "run_1b_accdb_tables_check"}
    assert expected.issubset(functions)


def test_config_path_exists():
    """Ensure pipeline config path variable points to the correct file."""
    base = Path(__file__).resolve().parents[1]
    sys.path.insert(0, str(base))
    module = importlib.import_module(
        "oferta_educativa_laboral.pipeline.pipeline_oferta_laboral"
    )
    expected = (
        base
        / "oferta_educativa_laboral"
        / "pipeline"
        / "configuration"
        / "pipeline.yml"
    )
    assert hasattr(module, "config_path")
    assert Path(module.config_path).resolve() == expected.resolve()


def test_get_py_exec_missing_config(monkeypatch):
    """get_py_exec should raise when configuration is missing."""
    base = Path(__file__).resolve().parents[1]
    sys.path.insert(0, str(base))
    module = importlib.import_module(
        "oferta_educativa_laboral.pipeline.pipeline_oferta_laboral"
    )
    monkeypatch.setattr(module, "PARAMS", {"general": {}})
    with pytest.raises(KeyError, match="py_exec"):
        module.get_py_exec()


def test_get_py_exec_empty_config(monkeypatch):
    """Empty configuration should raise a ValueError."""
    base = Path(__file__).resolve().parents[1]
    sys.path.insert(0, str(base))
    module = importlib.import_module(
        "oferta_educativa_laboral.pipeline.pipeline_oferta_laboral"
    )
    monkeypatch.setattr(module, "PARAMS", {"general": {"py_exec": ""}})
    with pytest.raises(ValueError, match="general.py_exec"):
        module.get_py_exec()
