#!/usr/bin/env bash
# Test script to verify syntax of refactored scripts

echo "Testing syntax of refactored tm-monitor scripts..."

# Test all new/modified files
scripts=(
    "lib/core.sh"
    "lib/arguments.sh"
    "bin/tm-monitor"
    "bin/tm-monitor-resources"
)

errors=0

for script in "${scripts[@]}"; do
    echo -n "Checking $script... "
    if bash -n "$script" 2>/dev/null; then
        echo "✓ OK"
    else
        echo "✗ FAILED"
        bash -n "$script"
        ((errors++))
    fi
done

echo
if [[ $errors -eq 0 ]]; then
    echo "✅ All scripts passed syntax check!"
    exit 0
else
    echo "❌ $errors script(s) failed syntax check"
    exit 1
fi
