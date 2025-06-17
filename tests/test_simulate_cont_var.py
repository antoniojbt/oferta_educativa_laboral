from pathlib import Path
import sys


def _load_module():
    base = Path(__file__).resolve().parents[1]
    sys.path.insert(0, str(base))
    from oferta_educativa_laboral.pipeline.scripts import simulate_cont_var

    return simulate_cont_var


def test_create_df_from_config(tmp_path):
    config = Path(__file__).resolve().parents[0] / "fixtures" / "sample_config.csv"
    simulate_cont_var = _load_module()
    df = simulate_cont_var.create_df_from_config(
        config_path=str(config), sample_size=5, seed=1
    )
    assert list(df.columns) == ["id", "age", "sex"]
    assert len(df) == 5
    assert df["age"].min() >= 18
    assert df["age"].max() <= 65
