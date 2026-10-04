from decimal import Decimal
from pyspark.sql.functions import when

import os
import sys

os.environ["PYSPARK_PYTHON"] = sys.executable
os.environ["PYSPARK_DRIVER_PYTHON"] = sys.executable

from pyspark.sql import SparkSession
from pyspark.sql.types import (
    DecimalType,
    StringType,
    StructField,
    StructType,
)

spark = (
    SparkSession.builder
    .master("local[*]")
    .appName("FinancialDataLab")
    .config("spark.driver.host", "localhost")
    .config("spark.driver.bindAddress", "127.0.0.1")
    .getOrCreate()
)

transactions = [
    ("T001", "A100", Decimal("250.00")),
    ("T002", "A101", Decimal("100.00")),
    ("T003", "A102", Decimal("-50.00")),
    ("T004", "A103", Decimal("500.00")),
    ("T005", "A104", Decimal("75.00")),
]

transaction_schema = StructType([
    StructField("TransactionId", StringType(), False),
    StructField("AccountId", StringType(), False),
    StructField("Amount", DecimalType(18, 2), True),
])

transactions_df = spark.createDataFrame(
    transactions,
    schema=transaction_schema
)

transactions_df.printSchema()
transactions_df.show()

transactions_new = [
    ("T006", "A105", Decimal("325.00")),
]
transactions_new_df = spark.createDataFrame(
    transactions_new,
    schema=transaction_schema
)


new_df = transactions_df.union(transactions_new_df)


updated_df = new_df.withColumn("Amount", when (
new_df["TransactionId"] == "T001", Decimal("300.00")).otherwise(new_df["Amount"]
))

transaction_amounts_df = updated_df.select("TransactionId", "Amount", (updated_df["Amount"] * Decimal("0.01")).alias("Fee"))

print("\n--- Before Update: new_df ---")
new_df.show()
print("\n--- After Update: updated_df ---")
updated_df.show()
print("\n--- Transaction Amounts: transaction_amounts_df ---")
transaction_amounts_df.show()

transaction_amounts_df.printSchema()
transaction_amounts_df.show()
spark.stop()