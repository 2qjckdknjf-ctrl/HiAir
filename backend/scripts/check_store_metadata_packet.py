import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_PACKET_PATH = ROOT / "docs" / "store-metadata-packet.md"


def _parse_args() -> tuple[Path, Path | None]:
    packet_path = DEFAULT_PACKET_PATH
    json_output: Path | None = None
    if "--packet-path" in sys.argv:
        idx = sys.argv.index("--packet-path")
        try:
            packet_path = Path(sys.argv[idx + 1]).resolve()
        except IndexError:
            raise SystemExit("--packet-path requires a file path")
    if "--json-output" in sys.argv:
        idx = sys.argv.index("--json-output")
        try:
            json_output = Path(sys.argv[idx + 1]).resolve()
        except IndexError:
            raise SystemExit("--json-output requires a file path")
    return packet_path, json_output


def _collect_unchecked_checkboxes(lines: list[str]) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for line_number, line in enumerate(lines, start=1):
        if re.search(r"- \[ \]", line):
            rows.append(
                {
                    "line": line_number,
                    "type": "UNCHECKED_CHECKBOX",
                    "text": line.strip(),
                }
            )
    return rows


def _collect_tbd_placeholders(lines: list[str]) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for line_number, line in enumerate(lines, start=1):
        if "[TBD" in line.upper():
            rows.append(
                {
                    "line": line_number,
                    "type": "TBD_PLACEHOLDER",
                    "text": line.strip(),
                }
            )
    return rows


def _write_json_report(path: Path, packet_path: Path, rows: list[dict[str, object]], is_ready: bool) -> None:
    report = {
        "gate": "store-metadata-packet",
        "packet_path": str(packet_path),
        "is_ready": is_ready,
        "rows": rows,
    }
    path.write_text(json.dumps(report, ensure_ascii=True, indent=2), encoding="utf-8")


def main() -> int:
    packet_path, json_output = _parse_args()
    if not packet_path.exists():
        print(f"Store metadata packet is missing: {packet_path}")
        return 1

    lines = packet_path.read_text(encoding="utf-8").splitlines()
    rows = _collect_unchecked_checkboxes(lines) + _collect_tbd_placeholders(lines)
    rows = sorted(rows, key=lambda item: int(item["line"]))
    is_ready = len(rows) == 0

    print(f"Store metadata packet readiness: {'READY' if is_ready else 'NOT_READY'}")
    if not is_ready:
        for row in rows:
            print(f"- L{row['line']} {row['type']}: {row['text']}")
        print("Store metadata packet contains unresolved checklist items/placeholders.")
    else:
        print("Store metadata packet has no unresolved checklist items/placeholders.")

    if json_output is not None:
        _write_json_report(json_output, packet_path, rows, is_ready)

    return 0 if is_ready else 1


if __name__ == "__main__":
    raise SystemExit(main())
