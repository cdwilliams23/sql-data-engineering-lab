"""Local Bronze ingestion for financial transaction CSV files."""


import argparse
import csv
import logging
import os
import sys
from datetime import date
from pathlib import Path

os.environ.setdefault("PYSPARK_PYTHON", sys.executable)
os.environ.setdefault("PYSPARK_DRIVER_PYTHON", sys.executable)

from pyspark.sql import DataFrame, SparkSession
from pyspark.sql.functions import current_timestamp, input_file_name, lit
from pyspark.sql.types import DateType, StringType, StructField, StructType

LOGGER = logging.getLogger(__name__)

SOURCE_COLUMNS = [
    "TransactionId",
    "AccountId",
    "CreatedDate",
    "Amount",
    "Currency",
    "TransactionType",
]

TRANSACTIONS_SCHEMA = StructType(
    [StructField(column, StringType(), True) for column in SOURCE_COLUMNS]
)

PROJECT_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_INPUT = Path("financial-pipeline/data/raw/transactions/transactions_2026-09-01.csv")
DEFAULT_BRONZE_ROOT = Path("financial-pipeline/data/bronze/transactions")


def parse_batch_date(value: str) -> date:
    """Parse an ISO calendar date and reject non-YYYY-MM-DD input."""
    try:
        parsed = date.fromisoformat(value)
    except ValueError as exc:
        raise argparse.ArgumentTypeError(
            f"Invalid batch date '{value}'. Expected YYYY-MM-DD."
        ) from exc


def resolve_project_path(value: str | Path) -> Path:
    """Resolve relative CLI paths from the repository root, not the caller CWD."""
    path = Path(value).expanduser()
    if not path.is_absolute():
        path = PROJECT_ROOT / path
    return path.resolve()


def csv_files(input_path: Path) -> list[Path]:
    """Return CSV files represented by a file or directory input path."""
    if not input_path.exists():
        raise FileNotFoundError(f"Input path does not exist: {input_path}")

    if input_path.is_file():
        return [input_path]

    files = sorted(path for path in input_path.rglob("*.csv") if path.is_file())
    if not files:
        raise FileNotFoundError(f"No CSV files found under input path: {input_path}")
    return files


def validate_headers(files: list[Path]) -> None:
    """Require the exact source header and order used by the positional Spark schema."""
    for file_path in files:
        with file_path.open("r", encoding="utf-8-sig", newline="") as handle:
            header = next(csv.reader(handle), None)

        if header != SOURCE_COLUMNS:
            raise ValueError(
                f"Unexpected CSV header in {file_path}. "
                f"Expected columns in this exact order: {','.join(SOURCE_COLUMNS)}; "
                f"received: {','.join(header or [])}"
            )


def create_spark_session() -> SparkSession:
    """Create the local Spark session used by the Bronze milestone."""
    return (
        SparkSession.builder.master("local[*]")
        .appName("FinancialTransactionBronze")
        .config("spark.driver.host", "localhost")
        .config("spark.driver.bindAddress", "127.0.0.1")
        .config("spark.sql.session.timeZone", "UTC")
        .getOrCreate()
    )


def build_bronze_dataframe(
    spark: SparkSession, files: list[Path], batch_date: date
) -> DataFrame:
    """Read source-faithful transaction strings and append Bronze audit metadata."""
    source_paths = [str(path) for path in files]
    return (
        spark.read.option("header", "true")
        .schema(TRANSACTIONS_SCHEMA)
        .csv(source_paths)
        .withColumn("SourceFile", input_file_name())
        .withColumn("IngestedAtUtc", current_timestamp())
        .withColumn("BatchDate", lit(batch_date.isoformat()).cast(DateType()))
    )


def ingest_transactions(
    spark: SparkSession,
    input_path: str | Path,
    bronze_output_root: str | Path,
    batch_date: date,
) -> tuple[int, int, Path]:
    """Validate, ingest, and replace one Bronze batch partition as Parquet."""
    resolved_input = resolve_project_path(input_path)
    resolved_output_root = resolve_project_path(bronze_output_root)
    files = csv_files(resolved_input)
    validate_headers(files)

    batch_output = resolved_output_root / f"BatchDate={batch_date.isoformat()}"
    LOGGER.info("Resolved input path: %s", resolved_input)
    LOGGER.info("Batch date: %s", batch_date.isoformat())

    bronze_df = build_bronze_dataframe(spark, files, batch_date).persist()
    try:
        source_row_count = bronze_df.count()
        LOGGER.info("Source row count: %d", source_row_count)

        # Writing directly to the batch-specific directory with overwrite mode makes
        # reruns idempotent without touching sibling BatchDate partitions.
        bronze_df.write.mode("overwrite").parquet(str(batch_output))

        written_row_count = spark.read.parquet(str(batch_output)).count()
        LOGGER.info("Written row count: %d", written_row_count)
        LOGGER.info("Resolved output location: %s", batch_output)

        if written_row_count != source_row_count:
            raise RuntimeError(
                "Bronze row-count validation failed: "
                f"source={source_row_count}, written={written_row_count}"
            )

        return source_row_count, written_row_count, batch_output
    finally:
        bronze_df.unpersist()


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Ingest transaction CSV data to Bronze Parquet.")
    parser.add_argument(
        "--input",
        default=str(DEFAULT_INPUT),
        help="CSV file or directory. Relative paths are resolved from the repository root.",
    )
    parser.add_argument(
        "--bronze-output-root",
        default=str(DEFAULT_BRONZE_ROOT),
        help="Bronze transactions root. Relative paths are resolved from the repository root.",
    )
    parser.add_argument("--batch-date", required=True, type=parse_batch_date, help="YYYY-MM-DD")
    return parser


def main() -> int:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    args = build_parser().parse_args()
    spark = create_spark_session()
    try:
        ingest_transactions(spark, args.input, args.bronze_output_root, args.batch_date)
        return 0
    except (FileNotFoundError, ValueError) as exc:
        LOGGER.error("Bronze ingestion failed: %s", exc)
        return 1
    finally:
        spark.stop()


if __name__ == "__main__":
    raise SystemExit(main())
