# /// script
# requires-python = ">=3.12"
# dependencies = ["pymupdf>=1.24"]
# ///
"""Convert selectable-text Marcus statement PDFs to transaction CSV files."""

from __future__ import annotations

import argparse
import csv
import re
import sys
from dataclasses import dataclass
from decimal import Decimal
from pathlib import Path

DATE_RE = re.compile(r"(?<!\d)(\d{2}/\d{2}/\d{4})(?!\d)")
AMOUNT_RE = re.compile(r"\$?\s*([0-9][0-9,]*\.\d{2})")
SUMMARY_ENDING_RE = re.compile(
    r"Ending\s*Balance\s*\$?\s*([0-9][0-9,]*\.\d{2})", re.IGNORECASE
)
DEBIT_RE = re.compile(
    r"withdrawal|debit|fee|check|purchase|transfer\s*to|"
    r"transferout|wireout|achout|outgoing",
    re.IGNORECASE,
)
CREDIT_RE = re.compile(
    r"deposit|credit|interest(\s*paid)?|transfer\s*from|transferin|"
    r"wirein|refund|cashback|incoming",
    re.IGNORECASE,
)


@dataclass(frozen=True)
class Transaction:
    """One parsed activity row."""

    date: str
    description: str
    credit: str
    debit: str
    balance: str


def as_decimal(value: str) -> Decimal:
    """Convert a formatted dollar amount to Decimal."""
    return Decimal(value.replace(",", ""))


def parse_statement(text: str) -> list[Transaction]:
    """Parse the account activity section and verify its running balances."""
    activity_match = re.search(r"ACCOUNT\s*ACTIVITY", text, re.IGNORECASE)
    if activity_match is None:
        raise ValueError("Could not find the ACCOUNT ACTIVITY section.")

    summary = text[: activity_match.start()]
    expected_ending_match = SUMMARY_ENDING_RE.search(summary)
    expected_ending = (
        as_decimal(expected_ending_match.group(1))
        if expected_ending_match is not None
        else None
    )

    activity = text[activity_match.end() :]
    dates = list(DATE_RE.finditer(activity))
    if not dates:
        raise ValueError("No dated activity rows found.")

    transactions: list[Transaction] = []
    starting_balance: Decimal | None = None
    current_balance: Decimal | None = None
    ending_row_balance: Decimal | None = None

    for index, date_match in enumerate(dates):
        row_end = dates[index + 1].start() if index + 1 < len(dates) else len(activity)
        row = re.sub(r"\s+", " ", activity[date_match.end() : row_end]).strip()
        row = re.sub(
            r"^Date\s*Description\s*Credits\s*Debits\s*Balance\s*",
            "",
            row,
            flags=re.IGNORECASE,
        )
        normalized_description = re.sub(r"[^a-z]", "", row.lower())
        amounts = AMOUNT_RE.findall(row)

        if "beginningbalance" in normalized_description:
            if len(amounts) != 1:
                raise ValueError(f"Malformed beginning balance row: {row!r}")
            starting_balance = as_decimal(amounts[0])
            current_balance = starting_balance
            continue

        if "endingbalance" in normalized_description:
            if len(amounts) != 1:
                raise ValueError(f"Malformed ending balance row: {row!r}")
            ending_row_balance = as_decimal(amounts[0])
            continue

        if len(amounts) != 2:
            raise ValueError(
                f"Expected transaction amount and balance on {date_match.group(1)}; "
                f"found {len(amounts)} in {row!r}"
            )
        description = AMOUNT_RE.sub("", row).strip()
        transaction_amount, balance_amount = map(as_decimal, amounts)

        is_debit = DEBIT_RE.search(description) is not None
        is_credit = CREDIT_RE.search(description) is not None
        if is_debit == is_credit:
            raise ValueError(
                f"Could not unambiguously classify transaction on "
                f"{date_match.group(1)}: {description!r}"
            )

        credit = Decimal("0.00")
        debit = Decimal("0.00")
        if is_debit:
            debit = transaction_amount
        else:
            credit = transaction_amount

        if current_balance is not None:
            calculated_balance = current_balance + credit - debit
            if calculated_balance != balance_amount:
                raise ValueError(
                    f"Balance mismatch on {date_match.group(1)}: expected "
                    f"{calculated_balance:.2f}, PDF shows {balance_amount:.2f}"
                )
        current_balance = balance_amount
        transactions.append(
            Transaction(
                date=date_match.group(1),
                description=description,
                credit=f"{credit:.2f}" if credit else "",
                debit=f"{debit:.2f}" if debit else "",
                balance=f"{balance_amount:.2f}",
            )
        )

    if starting_balance is None:
        raise ValueError("Could not find a beginning balance in account activity.")
    if not transactions:
        raise ValueError("No transactions found in account activity.")

    final_balance = as_decimal(transactions[-1].balance)
    if ending_row_balance is not None and ending_row_balance != final_balance:
        raise ValueError(
            f"Ending balance row shows {ending_row_balance:.2f}, but the final "
            f"transaction balance is {final_balance:.2f}"
        )
    if expected_ending is not None and expected_ending != final_balance:
        raise ValueError(
            f"Statement summary shows ending balance {expected_ending:.2f}, "
            f"but activity ends at {final_balance:.2f}"
        )
    return transactions


def read_pdf_text(pdf_path: Path) -> str:
    """Extract selectable text locally using PyMuPDF."""
    try:
        import pymupdf
    except ImportError as error:
        raise RuntimeError(
            "PyMuPDF is required. Run with uv to install it locally: "
            "uv run python\\marcus_statement_to_csv.py <input>"
        ) from error

    with pymupdf.open(pdf_path) as document:
        text = "\n".join(page.get_text(sort=True) for page in document)
    if not text.strip():
        raise ValueError("No selectable text found; this PDF may require local OCR.")
    return text


def _normalize_amount(val: str | None) -> str:
    """Normalize amount string by removing commas, dollar signs, and trailing zero decimals."""
    if not val:
        return ""
    clean = re.sub(r"[\$,\s]", "", val)
    if not clean:
        return ""
    try:
        return f"{Decimal(clean):.2f}"
    except Exception:
        return clean


def _normalize_text(val: str | None) -> str:
    """Normalize text by collapsing whitespace."""
    if not val:
        return ""
    return re.sub(r"\s+", " ", val).strip()


def write_transactions(
    output_path: Path, transactions: list[Transaction], append: bool = False
) -> tuple[int, int]:
    """Write or append transactions to a CSV file, skipping duplicates.

    Returns:
        tuple[int, int]: (added_count, duplicate_count)
    """
    fieldnames = ["Date", "Description", "Credits", "Debits", "Balance"]
    existing_records: set[tuple[str, str, str, str, str]] = set()

    if output_path.exists() and output_path.stat().st_size > 0:
        with output_path.open("r", newline="", encoding="utf-8-sig", errors="replace") as csv_file:
            reader = csv.DictReader(csv_file)
            if reader.fieldnames:
                # Find matching column names case-insensitively
                col_map = {name.lower().strip(): name for name in reader.fieldnames if name}
                d_col = col_map.get("date")
                desc_col = col_map.get("description")
                c_col = col_map.get("credits") or col_map.get("credit")
                deb_col = col_map.get("debits") or col_map.get("debit")
                b_col = col_map.get("balance")

                for row in reader:
                    existing_records.add(
                        (
                            _normalize_text(row.get(d_col, "") if d_col else ""),
                            _normalize_text(row.get(desc_col, "") if desc_col else ""),
                            _normalize_amount(row.get(c_col, "") if c_col else ""),
                            _normalize_amount(row.get(deb_col, "") if deb_col else ""),
                            _normalize_amount(row.get(b_col, "") if b_col else ""),
                        )
                    )

    file_mode = "a" if append and output_path.exists() and output_path.stat().st_size > 0 else "w"
    needs_header = file_mode == "w" or not (output_path.exists() and output_path.stat().st_size > 0)

    added = 0
    skipped = 0

    with output_path.open(file_mode, newline="", encoding="utf-8-sig") as csv_file:
        writer = csv.DictWriter(csv_file, fieldnames=fieldnames)
        if needs_header:
            writer.writeheader()

        for item in transactions:
            record_key = (
                _normalize_text(item.date),
                _normalize_text(item.description),
                _normalize_amount(item.credit),
                _normalize_amount(item.debit),
                _normalize_amount(item.balance),
            )
            if append and record_key in existing_records:
                skipped += 1
                continue

            writer.writerow(
                {
                    "Date": item.date,
                    "Description": item.description,
                    "Credits": item.credit,
                    "Debits": item.debit,
                    "Balance": item.balance,
                }
            )
            existing_records.add(record_key)
            added += 1

    return added, skipped


def main() -> int:
    """Run the local PDF-to-CSV conversion."""
    parser = argparse.ArgumentParser(
        description="Convert selectable-text Marcus statement PDF(s) to CSV."
    )
    parser.add_argument(
        "input_path",
        type=Path,
        metavar="PATH",
        help="Path to a statement PDF file or directory containing PDFs",
    )
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        help="CSV output path (defaults to <input>.csv if single file, or transactions.csv in directory)",
    )
    parser.add_argument(
        "-a",
        "--append",
        action="store_true",
        help="Append to the target CSV file, skipping exact duplicate transactions",
    )
    arguments = parser.parse_args()

    input_path: Path = arguments.input_path
    if not input_path.exists():
        print(f"Error: Path does not exist: {input_path}", file=sys.stderr)
        return 1

    if input_path.is_dir():
        pdf_files = sorted(
            [p for p in input_path.glob("*.pdf") if not p.name.startswith(".")],
            key=lambda p: p.name.lower(),
        )
        if not pdf_files:
            print(f"Error: No PDF files found in directory: {input_path}", file=sys.stderr)
            return 1
        output_path = arguments.output or (input_path / "transactions.csv")
        # When processing a batch folder into a single CSV, default append/dedup behavior makes sense
        is_append = arguments.append or arguments.output is not None
    else:
        pdf_files = [input_path]
        output_path = arguments.output or input_path.with_suffix(".csv")
        is_append = arguments.append

    total_added = 0
    total_skipped = 0

    for idx, pdf in enumerate(pdf_files):
        try:
            print(f"Processing ({idx + 1}/{len(pdf_files)}): {pdf.name} ...")
            transactions = parse_statement(read_pdf_text(pdf))
            # First file creates/overwrites unless -a was specified; subsequent files always append
            append_mode = is_append if idx == 0 else True
            added, skipped = write_transactions(
                output_path, transactions, append=append_mode
            )
            total_added += added
            total_skipped += skipped
            print(f"  -> Added {added}, skipped {skipped} duplicate(s)")
        except (OSError, RuntimeError, ValueError) as error:
            print(f"  -> Error parsing {pdf.name}: {error}", file=sys.stderr)
            if len(pdf_files) == 1:
                return 1

    print(
        f"\nFinished! Total {total_added} transaction(s) written to {output_path} "
        f"({total_skipped} duplicate(s) skipped)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
