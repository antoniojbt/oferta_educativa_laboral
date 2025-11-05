#!/usr/bin/env python3
"""
Convert CSV files to SQLite database for testing purposes.

This script creates an SQLite database from CSV files that can be used
for testing the pipeline on Linux/Mac. For Windows users with Access
database requirements, use csv_to_accdb.py instead.

Usage:
    python csv_to_test_db.py <csv_file1> [csv_file2 ...] -o <output.db>

Example:
    python csv_to_test_db.py data/synthetic_dataset.csv data/synthetic_dataset2.csv -o data/test_synthetic.db
"""

import argparse
import csv
import os
import sqlite3
import sys
from pathlib import Path


def infer_sql_type(value):
    """Infer SQL data type from a value."""
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
    """Infer column types from CSV file by sampling rows."""
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


def create_sqlite_db(csv_files, output_db):
    """Create SQLite database from CSV files."""
    # Remove existing database
    if os.path.exists(output_db):
        print(f"WARNING: {output_db} already exists. It will be overwritten.")
        os.remove(output_db)
    
    try:
        # Create the database
        print(f"Creating SQLite database: {output_db}")
        conn = sqlite3.connect(output_db)
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
                cols_def = ', '.join([f'"{h}" {col_types[h]}' for h in headers])
                create_sql = f'CREATE TABLE "{table_name}" ({cols_def})'
                print(f"Creating table...")
                cursor.execute(create_sql)
                
                # Insert data
                placeholders = ', '.join(['?' for _ in headers])
                insert_sql = f'INSERT INTO "{table_name}" VALUES ({placeholders})'
                
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
        
        print(f"\nSuccess! SQLite database created: {output_db}")
        return True
        
    except Exception as e:
        print(f"ERROR: {e}")
        import traceback
        traceback.print_exc()
        return False


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description='Convert CSV files to SQLite database for testing',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python csv_to_test_db.py data/synthetic_dataset.csv -o data/test.db
  python csv_to_test_db.py data/*.csv -o data/combined.db

Note: This creates an SQLite database for testing on Linux/Mac.
      For Windows Access databases, use csv_to_accdb.py instead.
        """
    )
    parser.add_argument('csv_files', nargs='+', help='CSV files to convert')
    parser.add_argument('-o', '--output', required=True, help='Output SQLite database file (.db)')
    
    args = parser.parse_args()
    
    # Validate input files
    for csv_file in args.csv_files:
        if not os.path.exists(csv_file):
            print(f"ERROR: File not found: {csv_file}")
            sys.exit(1)
    
    # Ensure output has .db extension
    if not args.output.endswith('.db'):
        args.output += '.db'
    
    # Convert
    success = create_sqlite_db(args.csv_files, args.output)
    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()
