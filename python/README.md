# Python scripts

## Marcus statement CSV converter

`marcus_statement_to_csv.py` extracts transactions from selectable-text Marcus
statement PDFs locally using PyMuPDF. It checks running and ending balances and
writes `Date,Description,Credits,Debits,Balance` columns.
Scanned PDFs require OCR before use; the script does not perform OCR.

Install [uv](https://docs.astral.sh/uv/getting-started/installation/) and use
Python 3.12 or newer. Run from the repository root; uv installs the inline
PyMuPDF dependency automatically:

```powershell
# One statement, writing to a specified CSV
uv run python\marcus_statement_to_csv.py "C:\Statements\statement.pdf" -o "C:\Statements\transactions.csv"

# Append transactions and skip duplicates
uv run python\marcus_statement_to_csv.py "C:\Statements\statement.pdf" -o "C:\Statements\transactions.csv" --append

# Process a folder of PDFs into one CSV
uv run python\marcus_statement_to_csv.py "C:\Statements" -o "C:\Statements\transactions.csv"

uv run python\marcus_statement_to_csv.py --help
```

Without `--output`, a single PDF writes to the same path with a `.csv` extension;
a folder writes to `transactions.csv` within that folder. A single-file run
overwrites unless `--append` is supplied. A folder run with `--output` appends
to an existing CSV even without `--append`. Without either option, a folder run
overwrites on its first PDF, then appends subsequent PDFs. Folder processing
sorts non-hidden `*.pdf` files by name and does not recurse into subfolders.

Duplicate detection in append mode compares all five fields, collapsing
whitespace and normalizing amounts to two decimal places. Existing CSV headers
are matched case-insensitively, including singular `Credit` and `Debit`.
Folder runs report individual parsing errors and continue; check those messages
as well as the final count (a folder run can exit successfully despite errors).

Keep statements and generated CSVs outside the repository. The converter does
not upload their contents; uv may download Python or dependencies during setup.

Run the synthetic regression tests from the repository root:

```powershell
uv run --with pytest --with "pymupdf>=1.24" python -B -m pytest -p no:cacheprovider python\tests\test_marcus_statement_to_csv.py
```
