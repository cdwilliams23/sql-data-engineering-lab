import sys
import unittest
from pathlib import Path

from pyspark.sql import SparkSession


PROJECT_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(PROJECT_ROOT / "financial-pipeline" / "src"))

import silver_transactions as silver
from datetime import date
from pyspark.sql.types import StringType, StructType, StructField, DateType

class TestSilverTransactions(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.spark = (
            SparkSession.builder
            .appName("SilverTransactionTests")
            .master("local[*]")
            .getOrCreate()
        )

        schema = StructType([
            StructField("TransactionId", StringType(), True),
            StructField("AccountId", StringType(), True),
            StructField("CreatedDate", StringType(), True),
            StructField("Amount", StringType(), True),
            StructField("Currency", StringType(), True),
            StructField("TransactionType", StringType(), True),
            StructField("BatchDate", DateType(), True)
        ])

        records = [
            ("T001", "A100", "2026-08-20", "100.00", "JMD", "Deposit", date(2026, 9, 1)),
            ("T002", "A101", "2026-08-21", " ", "JMD", "Deposit", date(2026, 9, 1)),
            ("T003", "A102", "2026-08-22", "-50.00", "JMD", "Withdrawal", date(2026, 9, 1)),
            ("T003", "A102", "2026-08-22", "-60.00", "JMD", "Withdrawal", date(2026, 9, 1)),
            ("T005", "A100", "2026-08-23", "-100.00", "JMD", "Withdrawal", date(2026, 9, 1)),
            ("T006", "A103", "BadDate", "-300.00", "JMD", "", date(2026, 9, 1)),
            ("T007", "A999", "2026-08-27", "75.00", "JMD", "Deposit", date(2026, 9, 1)),
            ("T008", "A104", "9999-12-31", "500.00", "JMD", "Deposit", date(2026, 9, 1)),
            ("T009", "A101", "2026-09-01", "-200.00", "JMD", "Deposit", date(2026, 9, 1)),
            ("T010", "A105", "2026-09-01", "250.00", "JMD", "Deposit", date(2026, 9, 1))
        ]

        bronze_df = cls.spark.createDataFrame(records, schema=schema)

        cls.silver_df = silver.transform_silver_transactions(bronze_df)

    @classmethod
    def tearDownClass(cls):
        cls.spark.stop()

    def test_silver_accepted_rejected_counts(self):

        accepted_df, rejected_df = silver.split_silver_transactions(self.silver_df)

        self.assertEqual(accepted_df.count(), 3)
        self.assertEqual(rejected_df.count(), 7)

    def test_duplicate_transaction_rejection(self):

        duplicate_transactions = (
            self.silver_df
            .filter(self.silver_df["TransactionId"] == "T003")
            .collect()
        )
        self.assertEqual(len(duplicate_transactions), 2)

        for transaction in duplicate_transactions:
            reasons = transaction["RejectionReasons"]
            self.assertIn("DUPLICATE_TRANSACTION_ID", reasons)
            self.assertFalse(transaction["IsValidRecord"])

    def test_null_validation_flag_is_not_lost(self):
        test_data = [
            ("T001", True),
            ("T002", False),
            ("T003", None),
        ]
        columns = ["TransactionId", "IsValidRecord"]

        test_df = self.spark.createDataFrame(test_data, schema=columns)

        accepted_df, rejected_df = silver.split_silver_transactions(test_df)

        self.assertEqual(accepted_df.count(), 1)
        self.assertEqual(rejected_df.count(), 2)

        rejected_ids = [
            row["TransactionId"]
            for row in rejected_df.collect()
        ]

        self.assertIn("T003", rejected_ids)

    def test_null_batch_date_is_invalid(self):

        schema = StructType([
            StructField("CreatedDate", DateType(), True),
            StructField("BatchDate", DateType(), True)
        ])
        test_data = [
            (date(2026, 8, 20), None)
        ]

        test_df = self.spark.createDataFrame(test_data,schema = schema)

        validated_dates_df = silver.validate_transaction_dates(test_df)

        rows = validated_dates_df.collect()

        self.assertEqual(len(rows), 1)
        self.assertIs(rows[0]["IsValidDate"], False)

    def test_null_batch_date_produces_rejection_reason(self):
        schema = StructType([
                    StructField("TransactionId", StringType(), True),
                    StructField("AccountId", StringType(), True),
                    StructField("CreatedDate", StringType(), True),
                    StructField("Amount", StringType(), True),
                    StructField("Currency", StringType(), True),
                    StructField("TransactionType", StringType(), True),
                    StructField("BatchDate", DateType(), True)
                    ])
        test_data = [
            ("T100", "A100", "2026-08-20", "100.00", "JMD", "Deposit", None)
        ]

        test_df = self.spark.createDataFrame(test_data, schema = schema)

        silver_df = silver.transform_silver_transactions(test_df)

        accepted_df, rejected_df = silver.split_silver_transactions(silver_df)

        self.assertEqual(accepted_df.count(), 0)
        self.assertEqual(rejected_df.count(), 1)

        rows = rejected_df.collect()
        self.assertEqual(len(rows), 1)
        self.assertIs(rows[0]["IsValidDate"], False)
        self.assertIs(rows[0]["IsValidRecord"], False)
        self.assertIn("INVALID_DATE", rows[0]["RejectionReasons"])


    def test_duplicate_transaction_id_validation(self):
        schema = StructType([
                    StructField("TransactionId", StringType(), True)

                ])
        test_data = [
            ("T100",),
            ("T100",),
            ("T101",)
        ]

        test_df = self.spark.createDataFrame(test_data, schema)

        validated_ids = silver.validate_transaction_ids(test_df)

        rows = validated_ids.collect()

        self.assertEqual(len(rows),3)



        for row in rows:
            if row["TransactionId"] == "T100":
                expected_count = 2
                expected_unique = False
            else:
                expected_count = 1
                expected_unique = True

            self.assertEqual(row["TransactionIdCount"], expected_count)
            self.assertIs(row["IsUniqueTransactionId"], expected_unique)

    def test_normalized_transaction_ids_detect_duplicates(self):
        schema = StructType([
                            StructField("TransactionId", StringType(), True)

                        ])
        test_data = [
            ("T100",),
            (" T100 ",),
            ("T101",)
        ]

        test_df = self.spark.createDataFrame(test_data, schema = schema)
        normalized_df = silver.normalize_transaction_ids(test_df)
        validated_df = silver.validate_transaction_ids(normalized_df)


        rows = validated_df.collect()

        self.assertEqual(len(rows), 3)

        for row in rows:
                    if row["TransactionId"] == "T100":
                        expected_count = 2
                        expected_unique = False
                    else:
                        self.assertEqual(row["TransactionId"], "T101")
                        expected_count = 1
                        expected_unique = True

                    self.assertEqual(row["TransactionIdCount"], expected_count)
                    self.assertIs(row["IsUniqueTransactionId"], expected_unique)

    def test_rejects_excess_amount_precision(self):

        schema = StructType([
            StructField("TransactionId", StringType(), True),
            StructField("CreatedDate", StringType(), True),
            StructField("Amount", StringType(), True),
            StructField("TransactionType", StringType(), True),
            StructField("BatchDate", DateType(), True)
        ])
        test_data = [(
            "T100",           # TransactionId
            "2026-08-20",     # CreatedDate
            "100.005",        # Amount
            "Deposit",        # TransactionType
            date(2026, 9, 1)  # BatchDate
        )]

        test_df = self.spark.createDataFrame(test_data, schema=schema)

        silver_df = silver.transform_silver_transactions(test_df)

        rows = silver_df.collect()
        self.assertEqual(len(rows), 1)
        self.assertIs(rows[0]["IsValidAmount"], False)
        self.assertIn("INVALID_AMOUNT", rows[0]["RejectionReasons"])

    def test_amount_precision_boundaries(self):
        schema = StructType([
                    StructField("TransactionId", StringType(), True),
                    StructField("CreatedDate", StringType(), True),
                    StructField("Amount", StringType(), True),
                    StructField("TransactionType", StringType(), True),
                    StructField("BatchDate", DateType(), True)
                ])
        test_data = [("T101", "2026-08-20", "100", "Deposit", date(2026, 9, 1)),
                        ("T102", "2026-08-21", "100.0", "Deposit", date(2026, 9, 1)),
                        ("T103", "2026-08-22", "100.00", "Deposit", date(2026, 9, 1)),
                        ("T104", "2026-08-23", "100.000", "Deposit", date(2026, 9, 1)),
                        ("T105", "2026-08-24", "0.01", "Deposit", date(2026, 9, 1)),
                        ("T106", "2026-08-25", "0.00", "Deposit", date(2026, 9, 1))
                ]

        test_df = self.spark.createDataFrame(test_data, schema = schema)
        silver_df = silver.transform_silver_transactions(test_df)

        test_cases = {
            "100": True,
            "100.0": True,
            "100.00": True,
            "100.000": False,
            "0.01": True,
            "0.00": False
        }

        rows = silver_df.collect()
        self.assertEqual(len(rows), len(test_cases))

        for row in rows:
            row_amount = row["RawAmount"]

            self.assertIs(
                row["IsValidAmount"],
                test_cases[row_amount],
                f"Unexpected validation result for amount {row_amount}"
            )
