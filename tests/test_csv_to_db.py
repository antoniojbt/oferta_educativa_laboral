"""Tests for CSV to database conversion scripts."""
import sqlite3
from pathlib import Path
import sys

# Add scripts directory to path
base_dir = Path(__file__).resolve().parents[1]
scripts_dir = base_dir / "scripts"
sys.path.insert(0, str(scripts_dir))


def test_csv_to_test_db_creates_database(tmp_path):
    """Test that csv_to_test_db.py creates a valid SQLite database."""
    from csv_to_test_db import create_sqlite_db

    # Create a test CSV file
    csv_file = tmp_path / "test_data.csv"
    csv_file.write_text(
        "id,name,age\n"
        "1,Alice,30\n"
        "2,Bob,25\n"
        "3,Charlie,35\n"
    )

    # Create database
    db_file = tmp_path / "test.db"
    result = create_sqlite_db([str(csv_file)], str(db_file))

    assert result is True
    assert db_file.exists()

    # Verify database contents
    conn = sqlite3.connect(str(db_file))
    cursor = conn.cursor()

    # Check table exists
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
    tables = cursor.fetchall()
    assert len(tables) == 1
    assert tables[0][0] == "test_data"

    # Check data
    cursor.execute("SELECT * FROM test_data")
    rows = cursor.fetchall()
    assert len(rows) == 3

    conn.close()


def test_csv_to_test_db_handles_multiple_csvs(tmp_path):
    """Test that csv_to_test_db.py handles multiple CSV files."""
    from csv_to_test_db import create_sqlite_db

    # Create test CSV files
    csv1 = tmp_path / "data1.csv"
    csv1.write_text("id,value\n1,100\n2,200\n")

    csv2 = tmp_path / "data2.csv"
    csv2.write_text("id,name\n1,Test\n")

    # Create database
    db_file = tmp_path / "multi.db"
    result = create_sqlite_db([str(csv1), str(csv2)], str(db_file))

    assert result is True
    assert db_file.exists()

    # Verify both tables exist
    conn = sqlite3.connect(str(db_file))
    cursor = conn.cursor()

    cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
    tables = [t[0] for t in cursor.fetchall()]
    assert "data1" in tables
    assert "data2" in tables

    conn.close()


def test_csv_to_test_db_handles_na_values(tmp_path):
    """Test that csv_to_test_db.py correctly handles NA values."""
    from csv_to_test_db import create_sqlite_db

    # Create CSV with NA values
    csv_file = tmp_path / "with_na.csv"
    csv_file.write_text(
        "id,name,age\n"
        "1,Alice,30\n"
        "2,NA,25\n"
        "3,Bob,NA\n"
        "4,,\n"
    )

    # Create database
    db_file = tmp_path / "na_test.db"
    result = create_sqlite_db([str(csv_file)], str(db_file))

    assert result is True

    # Verify NA handling
    conn = sqlite3.connect(str(db_file))
    cursor = conn.cursor()

    cursor.execute("SELECT * FROM with_na WHERE name IS NULL")
    null_names = cursor.fetchall()
    assert len(null_names) == 2  # Row 2 (NA) and row 4 (empty)

    conn.close()


def test_infer_sql_type():
    """Test the SQL type inference function."""
    from csv_db_utils import infer_sql_type

    # Test integer
    assert infer_sql_type("123") == "INTEGER"

    # Test float
    assert infer_sql_type("123.45") == "REAL"

    # Test text
    assert infer_sql_type("hello") == "TEXT"

    # Test NA/empty
    assert infer_sql_type("NA") is None
    assert infer_sql_type("") is None
    assert infer_sql_type(None) is None


def test_get_column_types(tmp_path):
    """Test column type inference from CSV."""
    from csv_db_utils import get_column_types

    # Create CSV with mixed types
    csv_file = tmp_path / "mixed_types.csv"
    csv_file.write_text(
        "int_col,float_col,text_col\n"
        "1,1.5,hello\n"
        "2,2.5,world\n"
        "3,3.5,test\n"
    )

    types = get_column_types(str(csv_file), sample_rows=10)

    assert types["int_col"] == "INTEGER"
    assert types["float_col"] == "REAL"
    assert types["text_col"] == "TEXT"
