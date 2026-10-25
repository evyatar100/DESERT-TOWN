---
name: hebrew-spellcheck
description: >-
  Spellcheck Hebrew text with the Windows built-in he-IL dictionary: the `he` values in
  game-files/PBS/translations.json, a text file, or a string. Use after adding or editing
  Hebrew dialogue, names, or translation keys.
---

# hebrew-spellcheck

Windows `ISpellChecker` (he-IL), nothing to install. PowerShell 5.1, Windows only.

```bash
S=.agents/skills/hebrew-spellcheck/scripts/hebrew_spellcheck.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File $S                      # every `he` in PBS/translations.json
powershell -NoProfile -ExecutionPolicy Bypass -File $S -File notes.txt      # UTF-8 file, one entry per line
powershell -NoProfile -ExecutionPolicy Bypass -File $S -Json other.json     # same JSON shape as translations.json
powershell -NoProfile -ExecutionPolicy Bypass -File $S -Text "..."          # short ASCII-safe text
```

Prefer `-File` for Hebrew; non-ASCII command-line arguments can be mangled by the shell.

## Output and exit codes

One finding per line, tab separated: `key  word  suggestions` (key is `line N` for a file). The summary goes to stderr.

| Exit | Meaning |
|---|---|
| 0 | clean |
| 1 | findings |
| 2 | bad input or crash: missing file or allowlist, unparseable JSON, 0 entries checked |
| 3 | no he-IL dictionary on this Windows |

## Allowlist (`allowlist.txt`)

- One word per line; a word also passes with 1-2 Hebrew prefix letters (`ב ה ו כ ל מ ש`), so `במידברן` passes on `מידברן`.
- `re:<regex>` lines are full-word patterns, kept narrow (`[יאוה]{3,}` for stretched interjections like `יאווווו`). Never "any repeated letter": it hides typos such as `שלוווום`.
- Every `he` value of a `NAME_*` key is allowed automatically.
- Add camp slang, place names and dictionary false positives here, grouped under the existing comments. A real typo goes into the translation, not the allowlist.

## Reading findings

- Suggestions come from Microsoft's dictionary and miss slang, transliterated English (`ניים`, `מיי`) and some valid words; judge each one.
- Essentials message codes are stripped before checking: `\b \B \r \R \. \| \! \^ \> \< \{ \}`, and named codes with optional brackets (`\c[n] \v[n] \se[..] \wt[n] \PN \l[n] \g`). `\n` and `\N` count as a line break. A code glued to a word (`\bניצחת`) is not a typo.
- The script never edits translations. Fix the text in `translations.json`, then re-run.
