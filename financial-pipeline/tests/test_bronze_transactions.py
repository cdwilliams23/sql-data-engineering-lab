"""Smoke/integration tests for local Bronze transaction ingestion."""

from __future__ import annotations

import argparse
import sys
import tempfile
import unittest
from datetime import date
from pathlib import Path

SRC_DIR = Path(__file__).resolve().parents[1] / "src"
sys.path.insert(0, str(SRC_DIR))

from bronze_transactions import (  # noqa: E402
    SOURCE_COLUMNS,
    create_spark_session,
    ingest_transactions,
    parse_batch_date,
)
from pyspark.sql.types import DateType, StringType, TimestampType  # noqa: E402


CSV_HEADER = ",".join(SOURCE_COLUMNS)
CSV_ROWS = [
    "T001,A100,2026-09-01,100.00,JMD,Deposit",
    "T002,A101,2026-09-01, ,JMD,Deposit",
]


class BronzeTransactionsIntegrationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.spark = create_spark_session()
        cls.spark.sparkContext.setLogLevel("ERROR")

    @classmethod
    def tearDownClass(cls) -> None:
        cls.spark.stop()

    def write_csv(self, path: Path, header: str = CSV_HEADER) -> None:
        path.write_text("\n".join([header, *CSV_ROWS]) + "\n", encoding="utf-8")

    def test_bronze_schema_persistence_and_batch_rerun_safety(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            input_file = root / "transactions.csv"
            output_root = root / "bronze" / "transactions"
            self.write_csv(input_file)

            first_batch = date(2026, 9, 1)
            second_batch = date(2026, 9, 2)

            ingest_transactions(self.spark, input_file, output_root, first_batch)
            first_path = output_root / "BatchDate=2026-09-01"
            first_df = self.spark.read.parquet(str(first_path))

            self.assertEqual(first_df.count(), len(CSV_ROWS))
            for column in SOURCE_COLUMNS:
                self.assertIsInstance(first_df.schema[column].dataType, StringType)
            self.assertIsInstance(first_df.schema["SourceFile"].dataType, StringType)
            self.assertIsInstance(first_df.schema["IngestedAtUtc"].dataType, TimestampType)
            self.assertIsInstance(first_df.schema["BatchDate"].dataType, DateType)
            self.assertEqual(
                {row.BatchDate.isoformat() for row in first_df.select("BatchDate").distinct().collect()},
                {"2026-09-01"},
            )

            ingest_transactions(self.spark, input_file, output_root, second_batch)
            second_path = output_root / "BatchDate=2026-09-02"
            self.assertEqual(self.spark.read.parquet(str(second_path)).count(), len(CSV_ROWS))

            ingest_transactions(self.spark, input_file, output_root, first_batch)
            self.assertEqual(self.spark.read.parquet(str(first_path)).count(), len(CSV_ROWS))
            self.assertEqual(self.spark.read.parquet(str(second_path)).count(), len(CSV_ROWS))

    def test_rejects_unexpected_header(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            input_file = root / "bad.csv"
            self.write_csv(input_file, "AccountId,TransactionId,CreatedDate,Amount,Currency,TransactionType")

            with self.assertRaisesRegex(ValueError, "exact order"):
                ingest_transactions(
                    self.spark, input_file, root / "bronze", date(2026, 9, 1)
                )

    def test_rejects_invalid_batch_date(self) -> None:
        with self.assertRaisesRegex(argparse.ArgumentTypeError, "YYYY-MM-DD"):
            parse_batch_date("2026/09/01")


if __name__ == "__main__":
    unittest.main()
