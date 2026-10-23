"""Builds sales.db from schema + seed data, runs analysis.sql, prints each report
and exports every result to results/*.csv."""
import csv
import os
import re
import sqlite3
import subprocess
import sys

here = os.path.dirname(os.path.abspath(__file__))
os.chdir(here)

subprocess.run([sys.executable, "generate_seed.py"], check=True)

if os.path.exists("sales.db"):
    os.remove("sales.db")
con = sqlite3.connect("sales.db")
for f in ("schema.sql", "seed_data.sql"):
    con.executescript(open(f).read())

sql = open("analysis.sql").read()
# create the view first
view_sql = sql.split("-- Q1.")[0]
con.executescript(view_sql)

os.makedirs("results", exist_ok=True)
blocks = re.split(r"-- @(Q\d+) (.*)\n", sql)[1:]
for i in range(0, len(blocks), 3):
    qid, title, body = blocks[i], blocks[i + 1], blocks[i + 2]
    query = "\n".join(l for l in body.splitlines() if not l.strip().startswith("--")).strip().rstrip(";")
    cur = con.execute(query)
    cols = [d[0] for d in cur.description]
    rows = cur.fetchall()
    print(f"\n=== {qid}: {title} ===")
    widths = [max(len(str(c)), *(len(str(r[j])) for r in rows)) if rows else len(c)
              for j, c in enumerate(cols)]
    print("  ".join(str(c).ljust(w) for c, w in zip(cols, widths)))
    for r in rows:
        print("  ".join(str(v).ljust(w) for v, w in zip(r, widths)))
    if not rows:
        print("(no rows)")
    with open(f"results/{qid}.csv", "w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(cols)
        w.writerows(rows)
con.close()
