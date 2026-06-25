---
name: book-download
description: "Search and download books/papers from Z-Library, Anna's Archive, and Liber3. Uses bookdl (multi-source CLI) for search/download, and OpenCLI zlibrary adapter for lightweight discovery."
version: 1.0.0
author: pi-agent
tags: [book, download, zlibrary, annas-archive, liber3, pdf, epub, research, paper, academic]
---

# Book Download Skill

> Search and download books and academic papers from Z-Library, Anna's Archive, and Liber3.

## Overview

Two complementary tools:

| Tool | Coverage | Browser Required | Source |
|------|----------|-----------------|--------|
| **bookdl** | Anna's Archive + Z-Library + Liber3 | Z-Library/Liber3 search need Chrome; Anna's Archive doesn't | Go binary v0.8.0 |
| **opencli zlibrary** | Z-Library search + info | Chrome + extension + login | Built into OpenCLI v1.8.4 |

Use **bookdl** as primary (multi-source, downloads). Use **opencli zlibrary** for quick discovery when Chrome is available.

## Prerequisites

### bookdl (Primary)
```bash
# Already installed at ~/.local/bin/bookdl
bookdl version
```

### OpenCLI zlibrary (Optional, for Z-Library discovery when Chrome is available)
```bash
opencli zlibrary --help
```

### Anna's Archive API Key (Optional, for faster downloads)
Get a secret key via donation at https://annas-archive.gl/donate
Configure:
```bash
bookdl config set anna.api_key "your-secret-key"
# Or env var:
export BOOKDL_ANNA_API_KEY="your-secret-key"
```

## Quick Reference

### Search Books

```bash
# Search all sources simultaneously (default: Anna's + Z-Library + Liber3)
bookdl search "transformer attention"

# Search only Anna's Archive (no browser needed)
bookdl search --source anna "machine learning"

# Search only Z-Library (needs Chrome browser)
bookdl search --source zlibrary "深度学习"

# Narrow by format, language, year
bookdl search -f pdf -l english --year 2020-2024 "quantum computing"

# Non-interactive mode (print results as table)
bookdl search --no-interactive -n 10 "reinforcement learning"

# Lightweight Z-Library search via OpenCLI (needs Chrome)
opencli zlibrary search "deep learning" --limit 10
```

### Get Book Details

```bash
# OpenCLI: get download formats from Z-Library book page
opencli zlibrary info <book-url>

# bookdl: show details of a specific book (from search result MD5)
bookdl search --no-interactive "specific title"  # then note the MD5
```

### Download Books

```bash
# Download by MD5 hash (from search results)
bookdl download <md5-hash>

# Download to specific directory
bookdl download -o ~/Downloads/books <md5-hash>

# Search and immediately download (interactive)
bookdl search -d "pragmatic programmer"

# Queue multiple books
bookdl search -q "python programming"  # Space to select, Enter to queue
bookdl queue                            # View queue
bookdl queue clear                      # Clear queue
```

### Manage Downloads

```bash
# List all downloads
bookdl list

# Pause / Resume
bookdl pause <id>
bookdl resume <id>
bookdl pause all
bookdl resume all

# Restart failed download
bookdl restart <id>

# Verify integrity
bookdl verify <id>
```

### Configuration

```bash
# View config file location
bookdl config path

# Set defaults
bookdl config set downloads.path ~/Books
bookdl config set downloads.max_concurrent 3
bookdl config set cache.enabled true
bookdl config set cache.ttl 48h
```

## Workflows

### ⚡ Quick: Find & download a paper by title
```
1. bookdl search "attention is all you need" --no-interactive
2. Note MD5 hash from results
3. bookdl download <md5>
```

### ⚡ Z-Library specific: search, inspect, download
```
1. opencli zlibrary search "transformer" --limit 5
2. opencli zlibrary info <url-from-results>
3. bookdl download <md5>   # if same book exists on Anna's
   # OR use the download link from opencli zlibrary info in browser
```

### ⚡ Batch download for research topic
```
1. bookdl search -q "federated learning"     # multi-select queue mode
2. bookdl queue                               # review queue
3. bookdl queue clear                         # remove unwanted
# Downloads start automatically after queueing
```

### ⚡ Find Chinese academic books
```
bookdl search --source anna "机器学习" -l chinese -f pdf
```

## Notes

- **Anna's Archive** search works without browser or API key (public API). Download works without key via slow mirrors, or faster with a membership secret key.
- **Z-Library** download through bookdl needs Chrome for Cloudflare bypass. For pure browser-less environments, prefer `--source anna`.
- **Liber3** also needs Chrome.
- Downloaded files go to `~/Downloads/books/` by default (configurable via `bookdl config set downloads.path`).
- The `opencli zlibrary` adapter requires the Chrome browser extension and login to Z-Library.
- If Chrome is unavailable, use `--source anna` for browser-less search.
