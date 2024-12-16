# Scrambler

A Ruby CLI for securing markdown files with encryption + text scrambling.

## Features

- AES-256-CBC encryption
- Scramble markdown files into completely unreadable content
- Batch processing of multiple markdown files
- Preserves markdown syntax and structure
- Automatic file backups

## Installation

1. Ensure you have Ruby 2.5+ installed
2. Install required gems:
```bash
gem install thor openssl
```

## Usage

### Basic Commands

Encrypt a single file:
```bash
ruby scrambler.rb encrypt "journal.md" encrypted/ --scramble
```

Encrypt multiple files:
```bash
ruby scrambler.rb encrypt "*.md" encrypted/ --key-file key.txt
```

Decrypt files:
```bash
ruby scrambler.rb decrypt "encrypted/*" decrypted/ "your-key-here"
```

### Wildcards
```
# *.md matches any file ending in .md in the current directory
ruby scrambler.rb encrypt "*.md" output/
Example matches:
- journal.md
- notes.md
- todo.md

# docs/**/*.md matches .md files in docs and all its subdirectories
ruby scrambler.rb encrypt "docs/**/*.md" encrypted/
Example matches:
- docs/journal.md
- docs/personal/diary.md
- docs/work/notes/meeting.md

# journal*.md matches any file starting with "journal" and ending in .md
ruby scrambler.rb encrypt "journal*.md" secure/
Example matches:
- journal.md
- journal-2024.md
- journal_private.md
```
### Flags

- `--key-file PATH`: Save/load encryption key to/from file
- `--scramble`: Enable text scrambling (default: false)
- `--backup`: Create backups of original files (default: true)
- `--no-backup`: Disable automatic backups

## Examples

### Original Markdown
```markdown
# Secret file 

I *really* hope my wife does not read my journal entries
```

### After Scrambling
```markdown
# Kx$tBz mPq@

R *really* Jk#n Qz wL&x Mvb pKt Yzx%B Nw jHq@xL vTp$iKs
```

### After Encryption
```
gAAAAABllYK6X9q4Z8J1X2fY7Qv_0jX5j1ZQ9K8e5tL2vQz8Yw9NmYH_6yRx7vDtZ8JKZV2x
f6iQKQ0L3YpX5jN2QY6QX5v7Z9J1X2fY7Qv_0jX5j1ZQ9K8e5tL2vQz8Yw9NmYH_6yRx7vDt
Z8JKZV2xf6iQKQ0L3YpX5jN2QY6QX5v7==
```

### Encryption
- Uses AES-256-CBC encryption
- Secure random key generation
- IV (Initialization Vector) randomization
- Base64 encoded output

### Scrambling
- Completely transforms words into random characters
- Mixes in special characters
- Varies word lengths
- Preserves markdown syntax only
- Makes content unreadable even before encryption

### Limitations

- Processes markdown files only (.md, .markdown)
- Requires valid UTF-8 encoded text
- Keeps files in memory during processing
