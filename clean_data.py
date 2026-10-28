"""Clean the supplied workout dataset with pandas.

Run with: python clean_data.py [input.csv] [output.csv]
"""

from pathlib import Path
import sys

import pandas as pd


DEFAULT_INPUT = Path("/Users/adarsh/Downloads/data.csv")
DEFAULT_OUTPUT = Path(__file__).resolve().parent / "cleaned_data.csv"


def clean(input_path: Path, output_path: Path) -> dict[str, int]:
    df = pd.read_csv(input_path)
    initial_rows = len(df)

    # Strip stray quote characters and parse both slash-separated and compact dates.
    date_text = df["Date"].astype("string").str.strip().str.strip("'").str.strip('"')
    date_text = date_text.mask(date_text.eq("20201226"), "2020/12/26")
    df["Date"] = pd.to_datetime(date_text, format="mixed", errors="coerce")

    # This log is a daily sequence, so the one missing date is uniquely inferable.
    missing_date = df["Date"].isna()
    if missing_date.sum() == 1:
        idx = df.index[missing_date][0]
        if idx > 0 and idx + 1 < len(df):
            before, after = df.at[idx - 1, "Date"], df.at[idx + 1, "Date"]
            if pd.notna(before) and pd.notna(after) and after - before == pd.Timedelta(days=2):
                df.at[idx, "Date"] = before + pd.Timedelta(days=1)

    # Remove duplicate records, then retain plausible durations and pulse ordering.
    duplicate_rows = int(df.duplicated().sum())
    df = df.drop_duplicates()
    valid = df["Duration"].between(1, 120) & (df["Maxpulse"] >= df["Pulse"])
    filtered_rows = int((~valid).sum())
    df = df.loc[valid].copy()

    # Fill calorie gaps with the median of remaining valid records.
    missing_calories = int(df["Calories"].isna().sum())
    calorie_median = df["Calories"].median()
    df["Calories"] = df["Calories"].fillna(calorie_median)
    df["Calories_per_minute"] = (df["Calories"] / df["Duration"]).round(2)

    df = df.sort_values("Date", kind="stable").reset_index(drop=True)
    df["Date"] = df["Date"].dt.strftime("%Y-%m-%d")
    output_path.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(output_path, index=False)

    return {
        "input_rows": initial_rows,
        "duplicate_rows_removed": duplicate_rows,
        "implausible_rows_filtered": filtered_rows,
        "calorie_values_filled": missing_calories,
        "output_rows": len(df),
    }


if __name__ == "__main__":
    input_file = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_INPUT
    output_file = Path(sys.argv[2]) if len(sys.argv) > 2 else DEFAULT_OUTPUT
    print(clean(input_file, output_file))
