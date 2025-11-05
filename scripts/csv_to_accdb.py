#!/usr/bin/env python3
"""
Convert CSV files to Microsoft Access database (.accdb) format.

This script reads CSV files and creates an Access database with tables
containing the CSV data. Requires Windows environment with Microsoft
Access ODBC driver installed.

Usage:
    python csv_to_accdb.py <csv_file1> [csv_file2 ...] -o <output.accdb>

Example:
    python csv_to_accdb.py data/synthetic_dataset.csv \\
        data/synthetic_dataset2.csv -o data/synthetic_data.accdb

Note: This script requires:
- Windows environment
- Microsoft Access Database Engine ODBC driver
- pyodbc package (pip install pyodbc)

For Linux users: Use this script on a Windows machine or use mdb-tools
to work with Access databases.
"""

import argparse
import csv
import os
import sys
from pathlib import Path
from csv_db_utils import get_column_types


def check_pyodbc():
    """Check if pyodbc is available."""
    try:
        import pyodbc  # noqa: F401
        return True
    except ImportError:
        print("ERROR: pyodbc is not installed. "
              "Install it with: pip install pyodbc")
        return False


def check_access_driver():
    """Check if Microsoft Access ODBC driver is available."""
    try:
        import pyodbc
        drivers = pyodbc.drivers()
        access_drivers = [d for d in drivers if 'Access' in d or 'Microsoft' in d]
        if not access_drivers:
            print("ERROR: Microsoft Access ODBC driver not found.")
            print("Available drivers:", drivers)
            print("\nPlease install Microsoft Access Database Engine:")
            print("https://www.microsoft.com/en-us/download/details.aspx?id=54920")
            return False
        print(f"Found Access driver: {access_drivers[0]}")
        return access_drivers[0]
    except Exception as e:
        print(f"ERROR checking drivers: {e}")
        return False


def create_accdb(csv_files, output_accdb):
    """Create Access database from CSV files."""
    if not check_pyodbc():
        return False

    driver = check_access_driver()
    if not driver:
        return False

    import pyodbc

    # Create database file if it doesn't exist
    if os.path.exists(output_accdb):
        print(f"WARNING: {output_accdb} already exists. It will be overwritten.")
        os.remove(output_accdb)

    # Connection string for creating new database
    conn_str = (
        f'DRIVER={{{driver}}};'
        f'DBQ={output_accdb};'
    )

    try:
        # Create the database
        print(f"Creating Access database: {output_accdb}")

        # For Access, we need to create the database file first
        # This is done by opening a connection with autocommit
        with pyodbc.connect(conn_str, autocommit=True):
            # Database is created when connection is opened
            pass

        # Now connect normally to add tables
        conn = pyodbc.connect(conn_str)
        cursor = conn.cursor()

        # Process each CSV file
        for csv_file in csv_files:
            table_name = Path(csv_file).stem
            print(f"\nProcessing {csv_file} -> table '{table_name}'")

            # Read CSV and infer types
            col_types = get_column_types(csv_file)

            with open(csv_file, 'r', encoding='utf-8') as f:
                reader = csv.DictReader(f)
                headers = reader.fieldnames

                # Create table
                cols_def = ', '.join([f'[{h}] {col_types[h]}' for h in headers])
                create_sql = f'CREATE TABLE [{table_name}] ({cols_def})'
                print(f"Creating table: {create_sql[:100]}...")
                cursor.execute(create_sql)

                # Insert data
                placeholders = ', '.join(['?' for _ in headers])
                insert_sql = f'INSERT INTO [{table_name}] VALUES ({placeholders})'

                row_count = 0
                for row_dict in reader:
                    values = []
                    for h in headers:
                        val = row_dict[h]
                        # Handle NA, empty strings, etc.
                        if val in ('', 'NA', 'NULL'):
                            values.append(None)
                        else:
                            values.append(val)
                    cursor.execute(insert_sql, values)
                    row_count += 1
                    if row_count % 1000 == 0:
                        print(f"  Inserted {row_count} rows...", end='\r')

                print(f"  Inserted {row_count} rows total")

        conn.commit()
        conn.close()

        print(f"\nSuccess! Access database created: {output_accdb}")
        return True

    except Exception as e:
        print(f"ERROR: {e}")
        import traceback
        traceback.print_exc()
        return False


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description='Convert CSV files to Microsoft Access database (.accdb)',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python csv_to_accdb.py data/synthetic_dataset.csv -o data/test.accdb
  python csv_to_accdb.py data/*.csv -o data/combined.accdb

Note: This script requires Windows with Microsoft Access ODBC driver.
        """
    )
    parser.add_argument('csv_files', nargs='+',
                        help='CSV files to convert')
    parser.add_argument('-o', '--output', required=True,
                        help='Output Access database file (.accdb)')

    args = parser.parse_args()

    # Validate input files
    for csv_file in args.csv_files:
        if not os.path.exists(csv_file):
            print(f"ERROR: File not found: {csv_file}")
            sys.exit(1)

    # Ensure output has .accdb extension
    if not args.output.endswith('.accdb'):
        args.output += '.accdb'

    # Convert
    success = create_accdb(args.csv_files, args.output)
    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()
