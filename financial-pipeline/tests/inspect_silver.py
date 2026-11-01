import sys
from pathlib import Path

from pyspark.sql import SparkSession

PROJECT_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(PROJECT_ROOT / "financial-pipeline" / "src"))

from silver_transactions import transform_silver_transactions, split_silver_transactions, reconcile_transaction_counts

def main():
    spark = (
        SparkSession.builder
        .appName("SilverTransactionInspection")
        .master("local[*]")
        .getOrCreate()
    )

    try:
        bronze_path = (
            PROJECT_ROOT
            / "financial-pipeline"
            / "data"
            / "bronze"
            / "transactions"
        )

        bronze_df = (
            spark.read.parquet(str(bronze_path))
            .filter("BatchDate = DATE '2026-09-01'")
        )

        silver_df = transform_silver_transactions(bronze_df)

        accepted_df, rejected_df = split_silver_transactions(silver_df)

        reconcile_transaction_counts(
            bronze_df,
            accepted_df,
            rejected_df
        )

        silver_df.printSchema()

        silver_df.select(
            "TransactionId",
            "IsValidTransactionId",
            "IsUniqueTransactionId",
            "IsValidRecord",
            "RejectionReasons"
        ).orderBy("TransactionId").show(truncate=False)

    finally:
        spark.stop()


if __name__ == "__main__":
    main()
