"""Generates seed_elite.sql: 21 months (Jan 2025 - Sep 2026) of reproducible sample sales data."""
import bisect
import random
from datetime import date, timedelta

random.seed(7)

START = date(2025, 1, 1)
END = date(2026, 9, 30)
N_DAYS = (END - START).days

regions = ["North", "South", "East", "West"]
categories = ["Electronics", "Furniture", "Stationery", "Clothing"]
# (name, category_id, price)
products = [
    ("Laptop", 1, 55000), ("Smartphone", 1, 22000), ("Headphones", 1, 3500),
    ("Office Chair", 2, 8500), ("Desk", 2, 12000), ("Bookshelf", 2, 6500),
    ("Notebook Pack", 3, 250), ("Pen Set", 3, 400), ("Printer Paper", 3, 600),
    ("Jacket", 4, 3200), ("T-Shirt", 4, 800), ("Jeans", 4, 1800),
    ("Smart Watch", 1, 9000),  # intentionally never sold -> shows up in LEFT JOIN report
]
sellable = list(range(1, len(products)))  # product ids 1..12 (13 never sold)
segments = ["Retail", "Corporate", "Online"]
first = ["Aarav", "Diya", "Rohan", "Sneha", "Kiran", "Meera", "Vikram", "Anita", "Arjun",
         "Pooja", "Suresh", "Lakshmi", "Rahul", "Divya", "Manoj", "Nisha", "Karthik",
         "Swathi", "Harsha", "Priya"]
last = ["Reddy", "Sharma", "Rao", "Patel", "Naidu", "Kumar", "Singh", "Gupta", "Varma",
        "Iyer", "Chowdary", "Nair"]
sp_names = ["Ravi Teja", "Anjali Rao", "Imran Khan", "Sowmya Reddy",
            "Naveen Kumar", "Deepa Nair", "Faisal Ahmed", "Lavanya Iyer"]
return_reasons = ["Damaged", "Wrong item", "Not as described", "Changed mind", "Defective"]
month_weight = {1: 1, 2: 1, 3: 1.3, 4: 1, 5: 1, 6: 1, 7: 1.1, 8: 1.5, 9: 1.2,
                10: 1.3, 11: 1.6, 12: 1.8}

L = ["BEGIN TRANSACTION;"]

for i, r in enumerate(regions, 1):
    L.append(f"INSERT INTO regions VALUES ({i}, '{r}');")
for i, c in enumerate(categories, 1):
    L.append(f"INSERT INTO categories VALUES ({i}, '{c}');")
for i, (n, c, p) in enumerate(products, 1):
    cost = round(p * random.uniform(0.55, 0.70), 2)
    L.append(f"INSERT INTO products VALUES ({i}, '{n}', {c}, {p}, {cost});")

for i, n in enumerate(sp_names, 1):
    L.append(f"INSERT INTO salespeople VALUES ({i}, '{n}', {(i - 1) % 4 + 1});")

# Customers: signups spread over Jan 2025 - Jun 2026; the last 4 never order
N_CUST = 120
N_INACTIVE = 4
active = N_CUST - N_INACTIVE
signup_days = []
for i in range(N_CUST):
    d = 0 if i == 0 else min(int(i / N_CUST * 540) + random.randint(0, 8), 600)
    signup_days.append(d)
for i in range(N_CUST):
    name = f"{random.choice(first)} {random.choice(last)}"
    sd = (START + timedelta(days=signup_days[i])).isoformat()
    L.append(f"INSERT INTO customers VALUES ({i + 1}, '{name}', "
             f"'{random.choice(segments)}', {random.randint(1, 4)}, '{sd}');")
active_signups = signup_days[:active]  # sorted ascending by construction (non-strict w/ jitter)
active_signups_sorted = sorted(range(active), key=lambda k: signup_days[k])
sorted_days = [signup_days[k] for k in active_signups_sorted]

# Orders
N_ORDERS = 1600
all_days = list(range(N_DAYS + 1))
weights = [month_weight[(START + timedelta(days=d)).month] for d in all_days]
order_days = sorted(random.choices(all_days, weights=weights, k=N_ORDERS))

item_id = 1
return_id = 1
for oid, d in enumerate(order_days, 1):
    k = bisect.bisect_right(sorted_days, d)
    cust = active_signups_sorted[random.randrange(k)] + 1
    od = START + timedelta(days=d)
    channel = random.choices(["Online", "Store", "Phone"], [5, 3, 2])[0]
    L.append(f"INSERT INTO orders VALUES ({oid}, {cust}, {random.randint(1, len(sp_names))}, "
             f"'{od.isoformat()}', '{channel}');")
    for _ in range(random.randint(1, 4)):
        pid = random.choice(sellable)
        L.append(f"INSERT INTO order_items VALUES ({item_id}, {oid}, {pid}, "
                 f"{random.randint(1, 5)}, {random.choice([0, 0, 0, 5, 10, 15])});")
        if random.random() < 0.04:
            rd = min(od + timedelta(days=random.randint(3, 30)), END + timedelta(days=30))
            L.append(f"INSERT INTO returns VALUES ({return_id}, {item_id}, "
                     f"'{rd.isoformat()}', '{random.choice(return_reasons)}');")
            return_id += 1
        item_id += 1

# Monthly targets per salesperson
months = []
y, m = 2025, 1
while (y, m) <= (2026, 9):
    months.append(f"{y}-{m:02d}")
    m += 1
    if m == 13:
        y, m = y + 1, 1
for sp in range(1, len(sp_names) + 1):
    for mo in months:
        tgt = int(round(random.uniform(500000, 760000), -3))
        L.append(f"INSERT INTO sales_targets VALUES ({sp}, '{mo}', {tgt});")

L.append("COMMIT;")
with open("seed_elite.sql", "w") as f:
    f.write("\n".join(L) + "\n")
print(f"seed_elite.sql written: {N_ORDERS} orders, {item_id - 1} items, {return_id - 1} returns")
