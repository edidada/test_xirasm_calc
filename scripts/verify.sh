#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exe="$root/build/app"
input="$root/scripts/input.txt"

if [[ ! -x "$exe" ]]; then
    echo "missing built program: $exe" >&2
    exit 1
fi

# ---- Mode 1 + 2 + 3: expression lines, function table, built-in self-test ----
echo '================ calculator output ================'
out="$("$exe" < "$input")"
printf '%s\n' "$out"
echo '===================================================='

needles=(
    '2+3*4 = 14'
    '(2+3)*4 = 20'
    '2^10 = 1024'
    'sqrt(2) = 1.414213562'
    'sin(pi/6) = 0.5'
    'table for x = 0.5'
    'sin(x) = 0.4794255386'
    '--- selftest ---'
    'PASS 2+3*4 = 14'
    'PASS deg(pi) = 180'
    'PASS rad(180) = 3.141592654'
)
for n in "${needles[@]}"; do
    if ! grep -qF -- "$n" <<< "$out"; then
        echo "missing expected output: $n" >&2
        exit 1
    fi
done

if grep -qF 'FAIL' <<< "$out"; then
    echo 'a self-test case reported FAIL' >&2
    exit 1
fi

pass_count="$(grep -c '^PASS ' <<< "$out" || true)"
echo "self-test PASS lines: $pass_count"
if (( pass_count < 20 )); then
    echo "too few PASS lines: $pass_count" >&2
    exit 1
fi

# ---- Empty stdin must trigger the built-in self-test ----
echo '=========== empty stdin -> selftest ==========='
empty_out="$("$exe" < /dev/null)"
printf '%s\n' "$empty_out"
if ! grep -qF -- '--- selftest ---' <<< "$empty_out"; then
    echo 'empty stdin did not trigger the self-test' >&2
    exit 1
fi
if grep -qF 'FAIL' <<< "$empty_out"; then
    echo 'empty-stdin self-test reported FAIL' >&2
    exit 1
fi

echo 'ALL CHECKS PASSED - scientific calculator built and ran successfully'
