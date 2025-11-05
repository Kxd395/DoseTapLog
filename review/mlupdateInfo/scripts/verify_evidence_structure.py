#!/usr/bin/env python3
import os, sys, json, pathlib, yaml

BASE = pathlib.Path(__file__).resolve().parents[1]

REQUIRED = [
    "EVIDENCE_STRUCTURE_README.md",
    "code_pointers/swift_code_pointers.json",
    "code_pointers/agent_code_pointers.json",
    "manifests/MANIFEST_TEMPLATE.json",
    "tests/parity/PARITY_TEST_PLAN.md",
    "tests/parity/parity_cases_template.json",
    "tests/unit/EXPECTED_COMMANDS.md",
    "signoff/P0_GATES_CHECKLIST.md",
    "status/STATUS_TRACKER.yaml"
]

def main():
    ok = True
    print(f"[verify] Base: {BASE}")
    for rel in REQUIRED:
        p = BASE / rel
        if not p.exists():
            print(f"✗ MISSING: {rel}")
            ok = False
        else:
            print(f"✓ Found: {rel}")
            if p.suffix == ".json":
                try:
                    json.load(open(p, "r"))
                except Exception as e:
                    print(f"✗ Invalid JSON: {rel} → {e}")
                    ok = False
            if p.suffix in (".yaml", ".yml"):
                try:
                    yaml.safe_load(open(p, "r"))
                except Exception as e:
                    print(f"✗ Invalid YAML: {rel} → {e}")
                    ok = False

    # Check important directories exist
    for d in ["runtime_artifacts/exports", "runtime_artifacts/logs", "screenshots"]:
        p = BASE / d
        if not p.exists():
            print(f"✗ MISSING DIR: {d}")
            ok = False
        else:
            print(f"✓ Dir OK: {d}")

    if ok:
        print("✅ Evidence structure looks good. Populate artifacts next.")
        sys.exit(0)
    else:
        print("⚠️ Evidence structure has issues. See messages above.")
        sys.exit(1)

if __name__ == "__main__":
    main()
