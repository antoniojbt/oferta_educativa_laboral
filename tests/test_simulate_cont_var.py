from pathlib import Path
import sys
import pytest


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


def test_number_generator_respects_bounds():
    simulate_cont_var = _load_module()
    simulate_cont_var.np.random.seed(0)
    sample = simulate_cont_var.number_generator(
        lower_bound=10, upper_bound=20, mean=15, sd=2, sample_size=1000
    )
    assert sample.min() >= 10
    assert sample.max() <= 20


def test_number_generator_invalid_sd():
    simulate_cont_var = _load_module()
    with pytest.raises(ValueError):
        simulate_cont_var.number_generator(sd=0)


def test_create_df_from_config_missing_file():
    simulate_cont_var = _load_module()
    with pytest.raises(FileNotFoundError):
        simulate_cont_var.create_df_from_config("no_such_file.csv")


def test_id_generator_length():
    simulate_cont_var = _load_module()
    ids = simulate_cont_var.id_generator(sample_size=3)
    assert len(ids) == 3


def test_id_generator_returns_prefix_and_length():
    simulate_cont_var = _load_module()
    series = simulate_cont_var.id_generator(text="sample_", size=4, sample_size=3)
    assert len(series) == 3
    assert series.str.startswith("sample_").all()


def test_id_generator_handles_zero_sample_size():
    simulate_cont_var = _load_module()
    series = simulate_cont_var.id_generator(sample_size=0)
    assert series.empty

