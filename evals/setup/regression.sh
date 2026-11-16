#!/bin/sh
# Starting point of regression-test-guard: the baseline, then a regression slipped into the code (whitespace
# no longer defaulted) - ACC-001/C2's test now fails. Committed, so it is part of <base>.
#   sh evals/setup/regression.sh <work-dir>  -> <work-dir>/ZavaSales
set -e
out="$(sh "$(dirname "$0")/baseline.sh" "$1")"
sol="${out##*
}"
[ -d "$sol" ] || { echo "baseline.sh failed: $out" >&2; exit 1; }
cd "$sol"
sed -i.bak 's/string.IsNullOrWhiteSpace(target.Description)/string.IsNullOrEmpty(target.Description)/' \
  src/zava.Plugins/Account/Plugins/AccountDefaultDescription.cs && rm -f src/zava.Plugins/Account/Plugins/*.bak
grep -q "IsNullOrEmpty(target.Description)" src/zava.Plugins/Account/Plugins/AccountDefaultDescription.cs
git add -A && git -c user.name=eval -c user.email=eval@local commit -q -m "refactor: simplify the empty check"
echo "$sol"
