#!/usr/bin/env bash
# Differential compiler/run smoke test for Ali Çehreli's Programming in D samples.
#
# Usage:
#   ./compiler/test/cehreli/run.sh CANDIDATE_DMD REFERENCE_DMD [RESULT_DIR]
#
# The reference compiler defines the baseline. A sample is a regression only when
# the reference succeeds at a stage and the candidate fails at the same stage.
# This lets us exercise the whole corpus without pretending intentionally-invalid,
# interactive, multi-file, or environment-dependent examples should all succeed.

set -uo pipefail

candidate_dmd=${1:?candidate dmd path required}
reference_dmd=${2:?reference dmd path required}
result_dir=${3:-cehreli-results}
archive_url=${CEHRELI_ARCHIVE_URL:-https://www.ddili.org/ders/d.en/Programming_in_D_code_samples.zip}
run_seconds=${CEHRELI_RUN_SECONDS:-5}

mkdir -p "$result_dir/logs" "$result_dir/bin"
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/cehreli.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM

archive="$work_dir/samples.zip"
samples="$work_dir/samples"
mkdir -p "$samples"

download() {
    local url=$1 out=$2
    if command -v curl >/dev/null 2>&1; then
        curl --fail --location --retry 4 --retry-delay 1 -A 'DMD-Cehreli-corpus' -o "$out" "$url"
    elif command -v fetch >/dev/null 2>&1; then
        fetch -o "$out" "$url"
    elif command -v ftp >/dev/null 2>&1; then
        ftp -o "$out" "$url"
    elif command -v wget >/dev/null 2>&1; then
        wget -O "$out" "$url"
    else
        echo "No downloader found (tried curl, fetch, ftp, wget)." >&2
        return 1
    fi
}

extract_zip() {
    local zip=$1 out=$2
    if command -v unzip >/dev/null 2>&1; then
        unzip -q "$zip" -d "$out"
    elif command -v bsdtar >/dev/null 2>&1; then
        bsdtar -xf "$zip" -C "$out"
    else
        echo "No ZIP extractor found (tried unzip, bsdtar)." >&2
        return 1
    fi
}

hash_file() {
    local f=$1
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$f" | awk '{print $1}'
    elif command -v sha256 >/dev/null 2>&1; then
        sha256 -q "$f"
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$f" | awk '{print $1}'
    else
        echo unknown
    fi
}

run_limited() {
    local exe=$1 out=$2 err=$3
    if command -v timeout >/dev/null 2>&1; then
        timeout --signal=TERM --kill-after=1 "${run_seconds}s" "$exe" </dev/null >"$out" 2>"$err"
        return $?
    fi
    if command -v gtimeout >/dev/null 2>&1; then
        gtimeout --signal=TERM --kill-after=1 "${run_seconds}s" "$exe" </dev/null >"$out" 2>"$err"
        return $?
    fi

    "$exe" </dev/null >"$out" 2>"$err" &
    local pid=$!
    (
        sleep "$run_seconds"
        kill -TERM "$pid" 2>/dev/null || exit 0
        sleep 1
        kill -KILL "$pid" 2>/dev/null || true
    ) &
    local watchdog=$!

    wait "$pid"
    local rc=$?
    kill "$watchdog" 2>/dev/null || true
    wait "$watchdog" 2>/dev/null || true
    return "$rc"
}

echo "Downloading Çehreli corpus: $archive_url"
download "$archive_url" "$archive" || exit 2
archive_sha256=$(hash_file "$archive")
extract_zip "$archive" "$samples" || exit 2

mapfile -d '' files < <(find "$samples" -type f -name '*.d' -print0 | sort -z)
if [ "${#files[@]}" -eq 0 ]; then
    echo "No .d files found in corpus." >&2
    exit 2
fi

candidate_version=$("$candidate_dmd" --version 2>&1 | head -n 1)
reference_version=$("$reference_dmd" --version 2>&1 | head -n 1)

ledger="$result_dir/ledger.tsv"
summary="$result_dir/summary.md"
printf 'path\tref_compile\tcand_compile\tref_link\tcand_link\tref_run\tcand_run\tclassification\n' >"$ledger"

total=0
compile_both=0
link_both=0
run_both=0
baseline_compile_fail=0
baseline_link_fail=0
baseline_run_fail=0
candidate_expansion=0
regressions=0

for file in "${files[@]}"; do
    total=$((total + 1))
    rel=${file#"$samples"/}
    id=$(printf '%05d' "$total")
    dir=$(dirname "$file")
    ref_compile_log="$result_dir/logs/$id.ref.compile.log"
    cand_compile_log="$result_dir/logs/$id.cand.compile.log"

    "$reference_dmd" -o- -I"$samples" -I"$dir" "$file" >"$ref_compile_log" 2>&1
    ref_compile=$?
    "$candidate_dmd" -o- -I"$samples" -I"$dir" "$file" >"$cand_compile_log" 2>&1
    cand_compile=$?

    ref_link=-
    cand_link=-
    ref_run=-
    cand_run=-
    class=

    if [ "$ref_compile" -eq 0 ] && [ "$cand_compile" -ne 0 ]; then
        class=COMPILE_REGRESSION
        regressions=$((regressions + 1))
    elif [ "$ref_compile" -ne 0 ] && [ "$cand_compile" -eq 0 ]; then
        class=CANDIDATE_COMPILE_EXPANSION
        candidate_expansion=$((candidate_expansion + 1))
    elif [ "$ref_compile" -ne 0 ]; then
        class=BASELINE_COMPILE_FAIL
        baseline_compile_fail=$((baseline_compile_fail + 1))
    else
        compile_both=$((compile_both + 1))
        ref_exe="$result_dir/bin/$id.ref"
        cand_exe="$result_dir/bin/$id.cand"
        ref_link_log="$result_dir/logs/$id.ref.link.log"
        cand_link_log="$result_dir/logs/$id.cand.link.log"

        "$reference_dmd" -i -I"$samples" -I"$dir" "$file" -of"$ref_exe" >"$ref_link_log" 2>&1
        ref_link=$?
        "$candidate_dmd" -i -I"$samples" -I"$dir" "$file" -of"$cand_exe" >"$cand_link_log" 2>&1
        cand_link=$?

        if [ "$ref_link" -eq 0 ] && [ "$cand_link" -ne 0 ]; then
            class=LINK_REGRESSION
            regressions=$((regressions + 1))
        elif [ "$ref_link" -ne 0 ] && [ "$cand_link" -eq 0 ]; then
            class=CANDIDATE_LINK_EXPANSION
            candidate_expansion=$((candidate_expansion + 1))
        elif [ "$ref_link" -ne 0 ]; then
            class=BASELINE_LINK_FAIL
            baseline_link_fail=$((baseline_link_fail + 1))
        else
            link_both=$((link_both + 1))
            ref_out="$result_dir/logs/$id.ref.run.out"
            ref_err="$result_dir/logs/$id.ref.run.err"
            cand_out="$result_dir/logs/$id.cand.run.out"
            cand_err="$result_dir/logs/$id.cand.run.err"

            run_limited "$ref_exe" "$ref_out" "$ref_err"
            ref_run=$?
            run_limited "$cand_exe" "$cand_out" "$cand_err"
            cand_run=$?

            if [ "$ref_run" -eq 0 ] && [ "$cand_run" -ne 0 ]; then
                # One retry reduces noise from timing-sensitive/concurrent examples.
                run_limited "$cand_exe" "$cand_out.retry" "$cand_err.retry"
                cand_retry=$?
                if [ "$cand_retry" -eq 0 ]; then
                    cand_run=0
                    class=RUN_PASS_AFTER_RETRY
                    run_both=$((run_both + 1))
                else
                    class=RUN_REGRESSION
                    regressions=$((regressions + 1))
                fi
            elif [ "$ref_run" -ne 0 ] && [ "$cand_run" -eq 0 ]; then
                class=CANDIDATE_RUN_EXPANSION
                candidate_expansion=$((candidate_expansion + 1))
            elif [ "$ref_run" -ne 0 ]; then
                class=BASELINE_RUN_FAIL_OR_INTERACTIVE
                baseline_run_fail=$((baseline_run_fail + 1))
            else
                class=RUN_PASS
                run_both=$((run_both + 1))
            fi
        fi
    fi

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n'         "$rel" "$ref_compile" "$cand_compile" "$ref_link" "$cand_link" "$ref_run" "$cand_run" "$class" >>"$ledger"

    case "$class" in
        *REGRESSION*) printf 'REGRESSION: %s (%s)\n' "$rel" "$class" ;;
    esac
done

cat >"$summary" <<EOF
# Çehreli corpus result

- Source: $archive_url
- Archive SHA-256: $archive_sha256
- Reference: $reference_version
- Candidate: $candidate_version
- D source files: $total
- Compile with both: $compile_both
- Link with both: $link_both
- Run successfully with both: $run_both
- Baseline compile failures: $baseline_compile_fail
- Baseline link failures: $baseline_link_fail
- Baseline run failures / interactive examples: $baseline_run_fail
- Candidate-only expansions: $candidate_expansion
- Candidate regressions: $regressions

A failure is charged to the candidate only when the reference compiler succeeds at
that stage and the candidate does not. See `ledger.tsv` and `logs/` for the
per-example evidence.
EOF

cat "$summary"
if [ "$regressions" -ne 0 ]; then
    exit 1
fi
