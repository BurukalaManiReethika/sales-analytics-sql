"""Generates seed_data.sql with reproducible sample sales data."""
import random
from datetime import date, timedelta

random.seed(42)

regions = ["North", "South", "East", "West"]
categories = ["Electronics", "Furniture", "Stationery", "Clothing"]
products = [
    ("Laptop", 1, 55000), ("Smartphone", 1, 22000), ("Headphones", 1, 3500),
    ("Office Chair", 2, 8500), ("Desk", 2, 12000), ("Bookshelf", 2, 6500),
    ("Notebook Pack", 3, 250), ("Pen Set", 3, 400), ("Printer Paper", 3, 600),
    ("Jacket", 4, 3200), ("T-Shirt", 4, 800), ("Jeans", 4, 1800),
]
segments = ["Retail", "Corporate", "Online"]
first = ["Aarav", "Diya", "Rohan", "Sneha", "Kiran", "Meera", "Vikram", "Anita",
         "Arjun", "Pooja", "Suresh", "Lakshmi", "Rahul", "Divya", "Manoj"]
last = ["Reddy", "Sharma", "Rao", "Patel", "Naidu", "Kumar", "Singh", "Gupta"]

lines = ["BEGIN TRANSACTION;"]

for i, r in enumerate(regions, 1):
    lines.append(f"INSERT INTO regions VALUES ({i}, '{r}');")
for i, c in enumerate(categories, 1):
    lines.append(f"INSERT INTO categories VALUES ({i}, '{c}');")
for i, (n, c, p) in enumerate(products, 1):
    lines.append(f"INSERT INTO products VALUES ({i}, '{n}', {c}, {p});")

n_customers = 40
for i in range(1, n_customers + 1):
    name = f"{random.choice(first)} {random.choice(last)}"
    lines.append(
        f"INSERT INTO customers VALUES ({i}, '{name}', "
        f"'{random.choice(segments)}', {random.randint(1, len(regions))});"
    )

start = date(2026, 1, 1)
item_id = 1
for oid in range(1, 301):
    d = start + timedelta(days=random.randint(0, 272))  # Jan - Sep 2026
    lines.append(
        f"INSERT INTO orders VALUES ({oid}, {random.randint(1, n_customers)}, '{d.isoformat()}');"
    )
    for _ in range(random.randint(1, 3)):
        lines.append(
            f"INSERT INTO order_items VALUES ({item_id}, {oid}, "
            f"{random.randint(1, len(products))}, {random.randint(1, 5)}, "
            f"{random.choice([0, 0, 0, 5, 10, 15])});"
        )
        item_id += 1

# A few customers with no orders / products never sold are naturally present,
# which makes LEFT JOIN examples meaningful.
lines.append("COMMIT;")

with open("seed_data.sql", "w") as f:
    f.write("\n".join(lines) + "\n")
print("seed_data.sql written")
