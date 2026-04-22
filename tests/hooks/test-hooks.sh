#!/usr/bin/env bash
# Hook script validation tests

echo "# -- Hook File Existence --"
assert_file_exists ".claude/hooks/session-context.sh"
assert_file_exists ".claude/hooks/secret-scan.sh"
assert_file_exists ".claude/hooks/check-doc-sync.sh"
assert_file_exists ".claude/hooks/notify.sh"

echo "# -- Hook Permissions --"
assert_executable ".claude/hooks/session-context.sh"
assert_executable ".claude/hooks/secret-scan.sh"
assert_executable ".claude/hooks/check-doc-sync.sh"
assert_executable ".claude/hooks/notify.sh"

echo "# -- Hook Registration --"
assert_contains ".claude/settings.json" "SessionStart"
assert_contains ".claude/settings.json" "PreToolUse"
assert_contains ".claude/settings.json" "PostToolUse"
assert_contains ".claude/settings.json" "Notification"
assert_contains ".claude/settings.json" "session-context.sh"
assert_contains ".claude/settings.json" "secret-scan.sh"
assert_contains ".claude/settings.json" "check-doc-sync.sh"
assert_contains ".claude/settings.json" "notify.sh"

echo "# -- Hook Shebangs --"
assert_contains ".claude/hooks/session-context.sh" "#!/usr/bin/env bash"
assert_contains ".claude/hooks/secret-scan.sh" "#!/usr/bin/env bash"
assert_contains ".claude/hooks/check-doc-sync.sh" "#!/usr/bin/env bash"
assert_contains ".claude/hooks/notify.sh" "#!/usr/bin/env bash"

echo "# -- Deny List --"
assert_contains ".claude/settings.json" "terraform destroy"
assert_contains ".claude/settings.json" "rm -rf"
assert_contains ".claude/settings.json" "git push --force"
assert_contains ".claude/settings.json" "git reset --hard"
