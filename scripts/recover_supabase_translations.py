"""Recover selected translations from a subtitle_lines CSV; never writes to Supabase."""

import argparse
import csv
from pathlib import Path


HEADER = """[Script Info]
ScriptType: v4.00+
PlayResX: 1920
PlayResY: 1080

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Default,Arial,48,&H00FFFFFF,&H0000FFFF,&H00000000,&H64000000,0,0,0,0,100,100,0,0,1,3,0,2,40,40,40,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
"""


def ass_time(value):
    centiseconds = int(value) // 10
    seconds, cs = divmod(centiseconds, 100)
    minutes, seconds = divmod(seconds, 60)
    hours, minutes = divmod(minutes, 60)
    return f"{hours}:{minutes:02}:{seconds:02}.{cs:02}"


def recover(csv_path, output, project_id=None):
    with Path(csv_path).open(encoding="utf-8-sig", newline="") as source:
        reader = csv.DictReader(source)
        required = {"project_id", "dialogue_index", "start_ms", "end_ms", "selected_text"}
        if not required.issubset(reader.fieldnames or []):
            raise ValueError(f"CSV must contain: {', '.join(sorted(required))}")
        rows = [r for r in reader if project_id is None or r["project_id"] == project_id]
    if len({r["project_id"] for r in rows}) != 1:
        raise ValueError("Choose exactly one project using --project-id (or export one project).")
    events = []
    for row in sorted(rows, key=lambda r: int(r["dialogue_index"])):
        text = row["selected_text"]
        if not text or not text.strip():
            continue
        if row.get("has_vector_drawing", "").lower() in {"true", "t", "1"}:
            continue
        text = text.replace("\r\n", "\n").replace("\r", "\n").replace("\n", r"\N")
        kind = "Comment" if row.get("doubt", "").lower() in {"true", "t", "1"} else "Dialogue"
        # Standard style keeps the recovered file usable without the original ASS.
        name = (row.get("name") or "").replace(",", " ").replace("\n", " ").replace("\r", " ")
        events.append(f"{kind}: 0,{ass_time(row['start_ms'])},{ass_time(row['end_ms'])},"
                      f"Default,{name},0,0,0,,{text}\n")
    if not events:
        raise ValueError("No selected translations found; no file written.")
    with Path(output).open("x", encoding="utf-8-sig", newline="\n") as destination:
        destination.write(HEADER + "".join(events))
    return len(events)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("csv")
    parser.add_argument("output", help="New .ass file (must not already exist)")
    parser.add_argument("--project-id")
    args = parser.parse_args()
    count = recover(args.csv, args.output, args.project_id)
    print(f"Recovered {count} selected segments to {args.output}")
