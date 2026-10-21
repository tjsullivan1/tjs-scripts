"""Regression tests using only generated statements and temporary CSV files."""

from __future__ import annotations

import csv
import subprocess
import sys
from pathlib import Path

import pymupdf
import pytest

SCRIPT = Path(__file__).resolve().parents[1] / "marcus_statement_to_csv.py"
STATEMENT = """Ending Balance $1,075.50
ACCOUNT ACTIVITY
Date Description Credits Debits Balance
01/01/2026 Beginning Balance $1,000.00
01/02/2026 Deposit $100.00 $1,100.00
01/03/2026 Withdrawal $25.00 $1,075.00
01/31/2026 Interest Paid $0.50 $1,075.50
01/31/2026 Ending Balance $1,075.50
"""
EXPECTED = [
    {
        "Date": "01/02/2026",
        "Description": "Deposit",
        "Credits": "100.00",
        "Debits": "",
        "Balance": "1100.00",
    },
    {
        "Date": "01/03/2026",
        "Description": "Withdrawal",
        "Credits": "",
        "Debits": "25.00",
        "Balance": "1075.00",
    },
    {
        "Date": "01/31/2026",
        "Description": "Interest Paid",
        "Credits": "0.50",
        "Debits": "",
        "Balance": "1075.50",
    },
]


def make_pdf(path: Path, text: str = STATEMENT) -> None:
    """Create a synthetic selectable-text PDF."""
    with pymupdf.open() as document:
        page = document.new_page()
        page.insert_text((72, 72), text, fontsize=10)
        document.save(path)


def run_cli(*arguments: str | Path) -> subprocess.CompletedProcess[str]:
    """Run the copied script without accessing any real statements."""
    return subprocess.run(
        [sys.executable, "-B", str(SCRIPT), *(str(arg) for arg in arguments)],
        capture_output=True,
        text=True,
        check=False,
    )


def read_rows(path: Path) -> list[dict[str, str]]:
    """Read a generated transaction CSV."""
    with path.open(newline="", encoding="utf-8-sig") as stream:
        return list(csv.DictReader(stream))


def test_single_pdf_output_append_and_overwrite(tmp_path: Path) -> None:
    """Preserve specified output, duplicate skipping, and overwrite behavior."""
    pdf = tmp_path / "statement.pdf"
    output = tmp_path / "chosen.csv"
    make_pdf(pdf)

    result = run_cli(pdf, "-o", output)
    assert result.returncode == 0, result.stderr
    assert read_rows(output) == EXPECTED

    result = run_cli(pdf, "-o", output, "--append")
    assert result.returncode == 0, result.stderr
    assert "Added 0, skipped 3 duplicate(s)" in result.stdout
    assert read_rows(output) == EXPECTED

    result = run_cli(pdf, "-o", output)
    assert result.returncode == 0, result.stderr
    assert "Added 3, skipped 0 duplicate(s)" in result.stdout
    assert read_rows(output) == EXPECTED


def test_default_single_output(tmp_path: Path) -> None:
    """A single PDF defaults to a CSV with the same stem."""
    pdf = tmp_path / "statement.pdf"
    make_pdf(pdf)
    result = run_cli(pdf)
    assert result.returncode == 0, result.stderr
    assert read_rows(pdf.with_suffix(".csv")) == EXPECTED


@pytest.mark.parametrize("specified_output", [False, True])
def test_folder_input(tmp_path: Path, specified_output: bool) -> None:
    """Folder conversion deduplicates overlapping statements and ignores hidden PDFs."""
    make_pdf(tmp_path / "a.pdf")
    make_pdf(tmp_path / "b.pdf")
    make_pdf(tmp_path / ".hidden.pdf", "Not a statement")
    output = tmp_path / ("chosen.csv" if specified_output else "transactions.csv")
    arguments: list[str | Path] = [tmp_path]
    if specified_output:
        arguments.extend(["-o", output])

    result = run_cli(*arguments)
    assert result.returncode == 0, result.stderr
    assert "Total 3 transaction(s)" in result.stdout
    assert "(3 duplicate(s) skipped)" in result.stdout
    assert read_rows(output) == EXPECTED

    result = run_cli(*arguments)
    assert result.returncode == 0, result.stderr
    expected_added = 0 if specified_output else 3
    assert f"Total {expected_added} transaction(s)" in result.stdout
    assert read_rows(output) == EXPECTED


def test_normalized_duplicate_detection(tmp_path: Path) -> None:
    """Append recognizes singular headers, formatted amounts, and whitespace."""
    pdf = tmp_path / "statement.pdf"
    make_pdf(pdf)
    output = tmp_path / "existing.csv"
    output.write_text(
        'date,description,credit,debit,balance\n'
        '01/02/2026, Deposit ,$100,,\"$1,100.0\"\n'
        '01/03/2026,Withdrawal,,$25,1075\n'
        '01/31/2026,Interest   Paid,.5,,1075.5\n',
        encoding="utf-8-sig",
    )
    before = output.read_bytes()
    result = run_cli(pdf, "-o", output, "-a")
    assert result.returncode == 0, result.stderr
    assert "Added 0, skipped 3 duplicate(s)" in result.stdout
    assert output.read_bytes() == before


@pytest.mark.parametrize(
    ("text", "message"),
    [
        ("", "No selectable text found"),
        ("Not a statement", "Could not find the ACCOUNT ACTIVITY section"),
        (
            STATEMENT.replace("Withdrawal $25.00 $1,075.00", "Withdrawal $25.00 $1,074.00"),
            "Balance mismatch",
        ),
        (STATEMENT.replace("Deposit", "Unknown"), "unambiguously classify"),
        (
            STATEMENT.replace("Ending Balance $1,075.50", "Ending Balance $1,076.50", 1),
            "Statement summary shows ending balance",
        ),
    ],
)
def test_invalid_pdf_text(tmp_path: Path, text: str, message: str) -> None:
    """Invalid synthetic input reports an error without writing transactions."""
    pdf = tmp_path / "invalid.pdf"
    make_pdf(pdf, text)
    result = run_cli(pdf)
    assert result.returncode == 1
    assert message in result.stderr
    assert not pdf.with_suffix(".csv").exists()


def test_missing_input_and_empty_folder(tmp_path: Path) -> None:
    """Missing paths and folders without PDFs fail explicitly."""
    result = run_cli(tmp_path / "missing.pdf")
    assert result.returncode == 1
    assert "Path does not exist" in result.stderr

    result = run_cli(tmp_path)
    assert result.returncode == 1
    assert "No PDF files found" in result.stderr
