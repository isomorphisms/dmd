# Çehreli book corpus

This directory is a verification harness for Ali Çehreli's *Programming in D*
code samples. It intentionally does not vendor the book's sample sources.
Instead, each run downloads the ZIP published by the book's official site and
records its SHA-256 in the result summary.

The corpus is differential:

1. Compile every `.d` file independently with a released reference DMD and the
   candidate DMD.
2. For files accepted by both compilers, attempt to link an executable.
3. For files linked by both, execute each with empty stdin and a short timeout.
4. Report a regression only when the reference succeeds at a stage and the
   candidate fails at that same stage.

This avoids turning intentionally invalid snippets, modules without `main`,
interactive examples, and environment-dependent examples into bogus compiler
failures while still exercising every D source file in the archive.

Run locally:

```sh
bash compiler/test/cehreli/run.sh \
    /path/to/candidate/dmd \
    /path/to/reference/dmd \
    cehreli-results
```

Useful environment variables:

- `CEHRELI_ARCHIVE_URL`: alternate archive URL.
- `CEHRELI_RUN_SECONDS`: per-example execution timeout (default: 5 seconds).
- `CEHRELI_COMPILE_SECONDS`: per-example compile/link timeout (default: 30 seconds).

The detailed evidence is written to `ledger.tsv` and `logs/`.
