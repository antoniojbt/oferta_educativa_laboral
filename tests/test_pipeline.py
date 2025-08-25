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


def _load_pipeline_module():
    base = Path(__file__).resolve().parents[1]
    sys.path.insert(0, str(base))
    return importlib.import_module(
        "oferta_educativa_laboral.pipeline.pipeline_oferta_laboral"
    )


def test_make_report_raises_if_exists(tmp_path, monkeypatch):
    module = _load_pipeline_module()
    report_dir = tmp_path / "pipeline_report"
    report_dir.mkdir()
    (report_dir / "dummy.txt").write_text("data")
    monkeypatch.setattr(module, "report_dir", str(report_dir))
    with pytest.raises(RuntimeError, match="exists, not overwriting"):
        module.make_report()


def test_make_report_raises_if_missing(tmp_path, monkeypatch):
    module = _load_pipeline_module()
    report_dir = tmp_path / "pipeline_report"
    monkeypatch.setattr(module, "report_dir", str(report_dir))
    with pytest.raises(RuntimeError, match="does not exist"):
        module.make_report()
