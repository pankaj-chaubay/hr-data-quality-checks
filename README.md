# HR data quality checks

Ten rules that find the problems which make HR reports disagree: trailing spaces that split one department into two, lost leading zeros, ambiguous birth dates, missing manager IDs, one manager with two IDs and salary outliers. The rules are written in SQL, so they can run where the data lives (DuckDB here, Snowflake or another warehouse in a company).

I built the same kind of check at work on real personnel records. That data is confidential, so this repository shows the method on a public, fictional dataset (Human Resources Data Set by Dr. Rich Huebner, 311 employees).

## Results

| | Before | After automatic fixes |
|---|---|---|
| Records with at least one issue | 311 (100%) | 31 (10%) |
| Department, position or sex with extra spaces | 261 | 0 |
| Birth date with a two-digit year | 311 | 0 |
| Zip code missing its leading zero | 287 | 0 |
| Missing manager ID | 8 | 0 |
| Manager name with two manager IDs | 29 | 29 (needs review) |
| Salary outlier within position | 2 | 2 (needs review) |

Automatic fixes handle the format problems. Two things stay for a person to decide: which of the two manager IDs is right, and whether the two salary outliers are errors or real exceptions. That split matters. A rule engine should fix what is safe and send the rest to the data owner with a clear issue log, not silently change records.

## How it works

- `sql/rules.sql`: one SELECT per rule, stacked with UNION ALL. Each failing record returns rule ID, rule name, severity and the value that failed.
- `dq_checks.py`: loads the data, runs the rules, applies the safe fixes (trim text, pad zip codes, fix the birth-year century, fill a manager ID only when the name maps to exactly one ID) and runs the rules again.
- `output/issue_log_before.csv` and `output/issue_log_after.csv`: the issue logs a data owner would work through.

| Severity | Meaning |
|---|---|
| 1 critical | Wrong numbers in reports (status and termination fields disagree, leaver dated before hire) |
| 2 major | Breaks joins or grouping (extra spaces, missing IDs, ambiguous dates) |
| 3 minor | Cosmetic (zip code format) |

## Run

```
pip install -r requirements.txt
python dq_checks.py
```

Full tables: [results.md](results.md).
