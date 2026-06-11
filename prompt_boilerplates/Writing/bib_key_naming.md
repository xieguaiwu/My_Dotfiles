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

### Disambiguation (same author, same year)

When the **same first author** has **multiple publications in the same year**,
append a **lowercase letter suffix** (`a`, `b`, `c`, …) in publication order:

```
{全小写人名}{年份}{字母}
```

| Key | Meaning |
|-----|---------|
| `chen2025` | First Chen (2025) paper |
| `chen2025a` | Second Chen (2025) paper |
| `chen2025b` | Third Chen (2025) paper |

- The letter suffix MUST be lowercase (`a`–`z`)
- Do **not** skip `a` — the first entry has no suffix; the second adds `a`; third adds `b`; etc.
- Only use disambiguation when a collision actually exists in your `.bib` file — do not pre-emptively add suffixes

### Rationale
- Ensures machine-parseable, predictable keys
- Avoids descriptive suffixes that may become inaccurate over time
- Makes cross-project key reuse trivial
- Prevents duplicate or conflicting keys from different citation styles

### Sorting Order
All entries in `references.bib` **MUST** be sorted **alphabetically by bib key** (i.e., the first field after `@type{`).

- Sorting is case-sensitive lowercase: `a → z`, then numeric by year within same surname
- Use `sort` or your editor's sort-lines to verify: extract all keys, sort, and compare
- Example sorted order:
  ```
  andreoletti2026
  atsalakis2009
  baek2018
  bai2026
  …
  zhang2020
  ```
- Do **not** group by `@type` (article, inproceedings, etc.) — sorting is purely by key

### Enforcement
- All entries in `references.bib` must pass:
  ```bash
  grep -oP '(?<=@\w\{)[^,]+' references.bib | grep -P '^[a-z]+[0-9]{4}[a-z]?$'
  ```
- Sorting must be verified with:
  ```bash
  grep '^@' references.bib | sed 's/.*{//;s/,.*//' | sort -c && echo "sorted" || echo "UNSORTED"
  ```
- Any deviation from naming or sorting rules must be corrected before submission
