from pathlib import Path


def test_pipeline_exists():
    """Ensure the example pipeline file is present."""
    base = Path(__file__).resolve().parents[1]
    path = base / "oferta_educativa_laboral" / "pipeline" / "pipeline_test.py"
    assert path.is_file()


def test_analysis_tasks_present():
    """Check new pipeline tasks are defined in the source."""
    base = Path(__file__).resolve().parents[1]
    path = base / "oferta_educativa_laboral" / "pipeline" / "pipeline_oferta_laboral.py"
    text = path.read_text()
    for func in [
        "def convert_to_csv",
        "def run_tables_check",
        "def run_clean_dups",
        "def run_subset",
        "def run_explore",
        "def run_bivar",
    ]:
        assert func in text
