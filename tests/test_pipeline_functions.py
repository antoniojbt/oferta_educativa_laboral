from pathlib import Path
import importlib
import sys
import subprocess
import inspect

import pytest


def _load_pipeline_module():
    base = Path(__file__).resolve().parents[1]
    sys.path.insert(0, str(base))
    return importlib.import_module(
        "oferta_educativa_laboral.pipeline.pipeline_oferta_laboral"
    )


class _DummyP:
    """Minimal stand-in for cgatcore.pipeline.P."""

    PARAMS: dict = {}

    def run(self, statement: str) -> None:  # noqa: D401
        pass

    def run(self, statement: str) -> None:
        pass

    def load(self, infile: str, outfile: str, options: str) -> None:
        Path(outfile).touch()


@pytest.mark.parametrize("files,expected", [(["pipeline.yml"], 1), ([], 0)])
def test_get_params_files(tmp_path, files, expected, monkeypatch):
    module = _load_pipeline_module()
    for name in files:
        (tmp_path / name).write_text("")
    monkeypatch.setattr(module, "ini_paths", [str(tmp_path)])
    results = module.getParamsFiles()
    assert len(results) == expected


def test_get_ini_paths(monkeypatch):
    module = _load_pipeline_module()
    monkeypatch.setattr(module, "PARAMS", {"general": {"project_scripts_dir": "scripts"}})
    assert module.getINIpaths() == "scripts/"
    monkeypatch.setattr(module, "PARAMS", {}, raising=False)
    with pytest.raises(KeyError):
        module.getINIpaths()


def test_make_report_conditions(tmp_path, monkeypatch):
    module = _load_pipeline_module()
    monkeypatch.setattr(module, "P", _DummyP())

    report_dir = tmp_path / "report"
    monkeypatch.setattr(module, "report_dir", str(report_dir))

    # Missing directory triggers error
    with pytest.raises(SystemExit):
        module.make_report()

    # Non-empty directory triggers error
    report_dir.mkdir()
    (report_dir / "file.txt").write_text("x")
    with pytest.raises(SystemExit):
        module.make_report()

    # Empty directory runs successfully
    for p in report_dir.iterdir():
        p.unlink()
    module.make_report()
    assert (report_dir / "file.txt").exists() is False
