#!/usr/bin/env bash
# scan-secrets.sh - fail on credentials, proxy nodes and personal data in a git repo.
#
# Usage:
#   bash guard/scan-secrets.sh            # scan tracked files + full history
#   bash guard/scan-secrets.sh --worktree # scan tracked files only
#
# Exit codes: 0 clean, 1 violations found, 2 usage error.
# Output never echoes the matching secret: only file, line, rule name.

set -uo pipefail

WORKTREE_ONLY=0
SINGLE_PATH=""
case "${1:-}" in
  --worktree) WORKTREE_ONLY=1 ;;
  --path) SINGLE_PATH="${2:-}"; [ -z "$SINGLE_PATH" ] && { echo "usage: $0 --path <file>"; exit 2; } ;;
  "" ) ;;
  * ) echo "usage: $0 [--worktree|--path <file>]"; exit 2 ;;
esac

# rule_name|extended-regex
RULES=$(cat <<'EOF'
github_pat|ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{30,}|gh[ous]_[A-Za-z0-9]{30,}
aws_key|AKIA[0-9A-Z]{16}
openai_like_key|sk-[A-Za-z0-9_-]{20,}|tavly-[A-Za-z0-9_-]{20,}|tvly-[A-Za-z0-9_-]{20,}
private_key_block|BEGIN (RSA|OPENSSH|EC|PGP) PRIVATE KEY
proxy_node|(ss|vmess|vless|trojan|hysteria|hysteria2|tuic|wireguard)://[A-Za-z0-9+/=@:%._-]{8,}
subscribe_url|(clash|surge|sub|nodes|proxy)[-_]?(sub|subscription|list)?\.[A-Za-z0-9]*(\.txt|\.yaml|\.yml)
basic_auth_url|://[^/\s:]+:[^/\s@]+@
local_windows_path|[A-Za-z]:\\\\Users\\\\|C:\\\\Users\\\\
local_unix_path|/home/[A-Za-z0-9._-]+/|/Users/[A-Za-z0-9._-]+/
personal_mail|[A-Za-z0-9._%+-]+@(outlook|gmail|qq|163|126|foxmail|yahoo|proton|icloud)\.(com|net|cn)
cn_mobile|1[3-9][0-9]{9}
EOF
)

hits=0
report() { # $1=file $2=line $3=rule $4=snippet
  local redacted
  redacted=$(printf '%s' "$4" | sed -E 's/(ghp_|gho_|ghu_|ghs_|github_pat_|AKIA|sk-|tvly-)[A-Za-z0-9_-]+/\1<redacted>/g' | cut -c1-80)
  printf 'VIOLATION %s:%s  rule=%s  %s\n' "$1" "$2" "$3" "$redacted"
  hits=$((hits+1))
}

scan_text() { # $1=label(file:lineno prefix)
  local label="$1"
  printf '%s' "$2" | while IFS='|' read -r rule rx; do
    [ -z "$rule" ] && continue
    if printf '%s' "$3" | grep -Eq -e "$rx"; then
      printf '%s\n' "$label|$rule"
    fi
  done
}

# 0) single file mode (used by CI self-test)
if [ -n "$SINGLE_PATH" ]; then
  [ -f "$SINGLE_PATH" ] || { echo "usage: $0 --path <file>"; exit 2; }
  lineno=0
  while IFS= read -r line || [ -n "$line" ]; do
    lineno=$((lineno+1))
    [ -z "$line" ] && continue
    while IFS='|' read -r rule rx; do
      [ -z "$rule" ] && continue
      if printf '%s' "$line" | grep -Eq -e "$rx"; then
        report "$SINGLE_PATH" "$lineno" "$rule" "$line"
      fi
    done <<< "$RULES"
  done < "$SINGLE_PATH"
  if [ "$hits" -eq 0 ]; then echo "RESULT=CLEAN path=$SINGLE_PATH"; exit 0; fi
  echo "RESULT=VIOLATION count=$hits"
  exit 1
fi

# 1) worktree: every tracked text file
while IFS= read -r f; do
  # skip binaries and vendored lock files that legitimately contain hashes
  case "$f" in
    *.png|*.jpg|*.jpeg|*.gif|*.webp|*.ico|*.zip|*.gz|*.7z|*.exe|*.dll|*.pdf|*.woff|*.woff2|*.ttf) continue ;;
  esac
  case "$f" in
    package-lock.json|*.lock|*.sum) continue ;;
  esac
  lineno=0
  while IFS= read -r line || [ -n "$line" ]; do
    lineno=$((lineno+1))
    [ -z "$line" ] && continue
    while IFS='|' read -r rule rx; do
      [ -z "$rule" ] && continue
      if printf '%s' "$line" | grep -Eq -e "$rx"; then
        report "$f" "$lineno" "$rule" "$line"
      fi
    done <<< "$RULES"
  done < "$f"
done < <(git ls-files)

if [ "$WORKTREE_ONLY" -eq 0 ]; then
  # 2) history: added lines only, so deleted secrets do not re-fail forever
  while IFS= read -r entry; do
    sha=${entry%% *}
    path=${entry#* }
    blob=$(git show "$sha:$path" 2>/dev/null | head -c 400000) || continue
    [ -z "$blob" ] && continue
    case "$path" in
      *.png|*.jpg|*.jpeg|*.gif|*.webp|*.ico|*.zip|*.gz|*.7z|*.exe|*.dll|*.pdf|package-lock.json|*.lock) continue ;;
    esac
    lineno=0
    while IFS= read -r line || [ -n "$line" ]; do
      lineno=$((lineno+1))
      [ -z "$line" ] && continue
      while IFS='|' read -r rule rx; do
        [ -z "$rule" ] && continue
        if printf '%s' "$line" | grep -Eq -e "$rx"; then
          report "history:${sha:0:8}:$path" "$lineno" "$rule" "$line"
        fi
      done <<< "$RULES"
    done <<< "$blob"
  done < <(git rev-list --objects --all | awk 'NF==2 {print $1" "$2}')
fi

if [ "$hits" -eq 0 ]; then
  echo "RESULT=CLEAN files=$(git ls-files | wc -l) history=$([ "$WORKTREE_ONLY" -eq 0 ] && echo on || echo off)"
  exit 0
fi
echo "RESULT=VIOLATION count=$hits"
exit 1
