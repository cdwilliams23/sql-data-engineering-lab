from pyspark.sql import DataFrame
from pyspark.sql import functions as F
from pyspark.sql.window import Window

def parse_transaction_fields(bronze_df: DataFrame) -> DataFrame:
    """Parse Bronze transaction fields into Silver data types."""
    return (
        bronze_df
        .withColumn("RawAmount", F.col("Amount"))
        .withColumn("Amount", F.expr("try_cast(trim(Amount) AS DECIMAL(18,2))"))
        .withColumn("CreatedDate", F.expr("try_cast(trim(CreatedDate) AS DATE)"))
    )

def validate_transaction_dates(df: DataFrame) -> DataFrame:
    is_valid_date = (F.col("CreatedDate").isNotNull()
                     & F.col("BatchDate").isNotNull()
                     & (F.col("CreatedDate") <= F.col("BatchDate"))
                    )
    return (
        df
        .withColumn("IsValidDate", is_valid_date)
    )

def validate_transaction_amounts(df: DataFrame) -> DataFrame:
    is_valid_amount = (
        F.col("Amount").isNotNull()
        & (F.col("Amount") > 0)
        & F.regexp_like(
            F.col("RawAmount"),
            F.lit(r"^[0-9]+(\.[0-9]{1,2})?$")
        )
    )

    return df.withColumn("IsValidAmount", is_valid_amount)

def normalize_transaction_types(df: DataFrame) -> DataFrame:
    return (
        df
        .withColumn("TransactionType", F.trim(F.col("TransactionType")))
    )

def validate_transaction_types(df: DataFrame) -> DataFrame:
    valid_types = ["Deposit", "Withdrawal"]
    is_valid_type = F.col("TransactionType").isin(valid_types) & (F.col("TransactionType").isNotNull())
    return (
        df
        .withColumn("IsValidTransactionType", is_valid_type)
    )

def validate_transaction_record(df: DataFrame) -> DataFrame:
    is_valid_record = (
    F.col("IsValidDate")
    & F.col("IsValidAmount")
    & F.col("IsValidTransactionType")
    & F.col("IsUniqueTransactionId")
    & F.col("IsValidTransactionId")
    )
    return (
        df
        .withColumn("IsValidRecord", is_valid_record)
    )

def add_rejection_reasons(df: DataFrame) -> DataFrame:
    return (
        df
        .withColumn(
            "RejectionReasons",
            F.array_compact(
                F.array(
                    F.when(~F.col("IsValidDate"), F.lit("INVALID_DATE")),
                    F.when(~F.col("IsValidAmount"), F.lit("INVALID_AMOUNT")),
                    F.when(
                        ~F.col("IsValidTransactionType"),
                        F.lit("INVALID_TRANSACTION_TYPE")
                    ),
                    F.when(~F.col("IsUniqueTransactionId"), F.lit("DUPLICATE_TRANSACTION_ID")),
                    F.when(~F.col("IsValidTransactionId"), F.lit("INVALID_TRANSACTION_ID"))
                )
            )
        )
    )

def validate_transaction_ids(df: DataFrame) -> DataFrame:
    window = Window.partitionBy("TransactionId")

    transaction_id_count = F.count("*").over(window)

    is_unique_transaction_id = transaction_id_count == 1

    is_valid_transaction_id = F.col("TransactionId").isNotNull() & (F.col("TransactionId") != "")

    return (
        df
        .withColumn("TransactionIdCount", transaction_id_count)
        .withColumn("IsUniqueTransactionId", is_unique_transaction_id)
        .withColumn("IsValidTransactionId", is_valid_transaction_id)
    )

def normalize_transaction_ids(df: DataFrame) -> DataFrame:
    return (
            df
            .withColumn("TransactionId", F.trim(F.col("TransactionId")))
        )

def split_silver_transactions(df: DataFrame) -> tuple[DataFrame, DataFrame]:
    """Separate validated transactions into accepted and rejected datasets."""

    accepted_condition = F.col("IsValidRecord").eqNullSafe(F.lit(True))
    accepted_df = df.filter(accepted_condition)
    rejected_df = df.filter(~accepted_condition)
    return accepted_df, rejected_df

def reconcile_transaction_counts(
    input_df: DataFrame,
    accepted_df: DataFrame,
    rejected_df: DataFrame
) -> None:
    """Verify every input transaction is accounted for."""
    input_count = input_df.count()
    accepted_count = accepted_df.count()
    rejected_count = rejected_df.count()

    if input_count != accepted_count + rejected_count:
        raise ValueError(
            f"Reconciliation failed: "
            f"{input_count} input != "
            f"{accepted_count} accepted + {rejected_count} rejected"
        )
    else:
        print(
            f"Reconciliation successful: "
            f"{input_count} input = "
            f"{accepted_count} accepted + {rejected_count} rejected"
        )

def transform_silver_transactions(bronze_df: DataFrame) -> DataFrame:
    """Transform Bronze transactions into Silver transactions."""
    silver_df = (
        bronze_df
        .transform(parse_transaction_fields)
        .transform(normalize_transaction_types)
        .transform(normalize_transaction_ids)
        .transform(validate_transaction_dates)
        .transform(validate_transaction_amounts)
        .transform(validate_transaction_types)
        .transform(validate_transaction_ids)
        .transform(validate_transaction_record)
        .transform(add_rejection_reasons)
    )
    return silver_df
