# BibTeX Key Naming Convention

## Rule
All BibTeX keys **MUST** follow the format:
```
{全小写人名}{年份}
```

- `全小写人名`: First author's surname in **all lowercase** (no accents/diacritics)
- `年份`: 4-digit year

### Examples
| Correct | Incorrect |
|---------|-----------|
| `vaswani2017` | `vaswani2017attention` (extra word) |
| `chen2025` | `kelly2025limits` (wrong surname + extra word) |
| `lopezdeprado2018` | `lopezdeprado2018advances` (extra word) |
| `zhang2020` | `zhang2020information` (extra word) |

### Rationale
- Ensures machine-parseable, predictable keys
- Avoids descriptive suffixes that may become inaccurate over time
- Makes cross-project key reuse trivial
- Prevents duplicate or conflicting keys from different citation styles

### Enforcement
- All entries in `references.bib` must pass: `grep -oP '(?<=@\w\{)[^,]+' references.bib | grep -P '^[a-z]+[0-9]{4}$'`
- Any deviation must be corrected before submission
