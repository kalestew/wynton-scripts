#!/usr/bin/env python3
"""
find_missing_replicas.py – Identify mutations in a Flex ddG saturation run that are
incomplete (one or more replica folders or database files missing), remove those
mutations from *mutinfo.txt*, and output a convenient list of <mut_id>:<replica>
entries suitable for use with *redo_replicas.sh*.

Typical usage (from the run_<id>/flexddg parent directory):

    python3 find_missing_replicas.py            # uses defaults
        --inplace                               # overwrite mutinfo.txt in-place

Outputs:
  • mutinfo.cleaned.txt  (or overwrites mutinfo.txt when --inplace specified)
  • missing_replicas.txt – one "<mut_id>:<replica>" per line.
"""
import argparse
import logging
import sys
from pathlib import Path

# ---------------------------------------------------------------------------
# Command-line handling
# ---------------------------------------------------------------------------

def _get_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(
        description="Detect failed Flex ddG replicas, clean mutinfo.txt, and emit a redo list.")
    p.add_argument(
        "--flex",
        default="flexddg",
        help="Path to the flexddg directory (default: ./flexddg)",
    )
    p.add_argument(
        "--nstruct",
        type=int,
        default=35,
        help="Number of expected replicas per mutation (default: 35)",
    )
    p.add_argument(
        "--mutinfo",
        default="mutinfo.txt",
        help="Filename of mutinfo within --flex (default: mutinfo.txt)",
    )
    p.add_argument(
        "--inplace",
        action="store_true",
        help="Overwrite mutinfo.txt in-place instead of writing *.cleaned.txt",
    )
    p.add_argument(
        "--log",
        default="missing_replicas.txt",
        help="Output file for <mut_id>:<replica> list (default: missing_replicas.txt)",
    )
    p.add_argument(
        "-v", "--verbose",
        action="store_true",
        help="Enable verbose debug logging",
    )
    return p.parse_args()

# ---------------------------------------------------------------------------
# Main logic
# ---------------------------------------------------------------------------

def main() -> None:  # noqa: D401
    args = _get_args()
    log_level = logging.DEBUG if args.verbose else logging.INFO
    logging.basicConfig(format="%(levelname)s: %(message)s", level=log_level)

    flex_path = Path(args.flex).expanduser().resolve()
    if not flex_path.is_dir():
        sys.exit(f"❌  flex directory not found: {flex_path}")

    mutinfo_path = flex_path / args.mutinfo
    if not mutinfo_path.is_file():
        sys.exit(f"❌  mutinfo file not found: {mutinfo_path}")

    nstruct = args.nstruct
    logging.info("Expecting %d replica(s) per mutation", nstruct)

    missing: dict[str, list[int]] = {}
    lines_to_keep: list[str] = []

    with mutinfo_path.open() as fh:
        all_lines = [line.rstrip("\n") for line in fh if line.strip()]
    
    logging.info("Processing %d mutations from mutinfo.txt...", len(all_lines))
    
    for i, line in enumerate(all_lines, 1):
        if not line:
            continue
        cols = line.split(",")
        if len(cols) < 2:
            logging.warning("Skipping malformed mutinfo line: %s", line)
            continue
        mut_id = cols[1]
        mut_dir = flex_path / mut_id

        # Progress logging every 50 mutations
        if i % 50 == 0 or i == len(all_lines):
            logging.info("Progress: %d/%d mutations checked", i, len(all_lines))

        # Determine missing replica(s)
        missing_reps: list[int] = []
        if not mut_dir.is_dir():
            missing_reps = list(range(1, nstruct + 1))
            logging.debug("Missing entire directory for %s", mut_id)
        else:
            for rep in range(1, nstruct + 1):
                if not (mut_dir / str(rep) / "ddg.db3").is_file():
                    missing_reps.append(rep)

        if missing_reps:
            missing[mut_id] = missing_reps
        else:
            lines_to_keep.append(line)

    # Always write the redo list (even if empty) to avoid confusion with old files
    redo_path = Path(args.log).expanduser().resolve()
    with redo_path.open("w") as redo_f:
        for mut_id, reps in sorted(missing.items()):
            for rep in sorted(reps):
                redo_f.write(f"{mut_id}:{rep}\n")
    
    if not missing:
        logging.info("✅  All mutations have the expected %d replicas – no action needed.", nstruct)
        logging.info("Created empty redo list file: %s", redo_path)
        return

    logging.info("Detected %d mutation(s) with incomplete replicas.", len(missing))
    logging.info("Wrote redo list (%s entries) to %s", sum(len(r) for r in missing.values()), redo_path)

    # Write cleaned mutinfo
    if args.inplace:
        backup = mutinfo_path.with_suffix(".bak")
        logging.info("Backing up original mutinfo to %s", backup)
        mutinfo_path.rename(backup)
        cleaned_path = mutinfo_path
    else:
        cleaned_path = mutinfo_path.with_suffix(".cleaned.txt")

    with cleaned_path.open("w") as out_f:
        for entry in lines_to_keep:
            out_f.write(entry + "\n")
    logging.info("Wrote cleaned mutinfo to %s", cleaned_path)


if __name__ == "__main__":
    main() 