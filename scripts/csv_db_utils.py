"""Shared utilities for CSV to database conversion."""

import csv


def infer_sql_type(value):
    """Infer SQL data type from a value.

    Args:
        value: String value from CSV

    Returns:
        String SQL type ('INTEGER', 'REAL', 'TEXT') or None for NA/empty
    """
    if value is None or value == '' or value == 'NA':
        return None

    # Try integer
    try:
        int(value)
        return 'INTEGER'
    except ValueError:
        pass

    # Try float
    try:
        float(value)
        return 'REAL'
    except ValueError:
        pass

    # Default to text
    return 'TEXT'


def get_column_types(csv_file, sample_rows=100):
    """Infer column types from CSV file by sampling rows.

    Args:
        csv_file: Path to CSV file
        sample_rows: Number of rows to sample for type inference

    Returns:
        Dictionary mapping column names to SQL types
    """
    with open(csv_file, 'r', encoding='utf-8') as f:
        reader = csv.reader(f)
        headers = next(reader)

        # Initialize type counters for each column
        col_types = {h: {} for h in headers}

        # Sample rows to infer types
        for i, row in enumerate(reader):
            if i >= sample_rows:
                break
            for h, val in zip(headers, row):
                sql_type = infer_sql_type(val)
                if sql_type:
                    col_types[h][sql_type] = col_types[h].get(sql_type, 0) + 1

        # Choose most common type for each column, default to TEXT
        result = {}
        for h in headers:
            if col_types[h]:
                result[h] = max(col_types[h], key=col_types[h].get)
            else:
                result[h] = 'TEXT'

        return result
