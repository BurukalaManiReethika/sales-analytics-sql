-- Sales Analytics ELITE: schema (SQLite; portable to MySQL/PostgreSQL with minor changes)

DROP TABLE IF EXISTS sales_targets;
DROP TABLE IF EXISTS returns;
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS salespeople;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS regions;
DROP TABLE IF EXISTS categories;

CREATE TABLE regions (
    region_id   INTEGER PRIMARY KEY,
    region_name TEXT NOT NULL UNIQUE
);

CREATE TABLE categories (
    category_id   INTEGER PRIMARY KEY,
    category_name TEXT NOT NULL UNIQUE
);

CREATE TABLE customers (
    customer_id   INTEGER PRIMARY KEY,
    customer_name TEXT NOT NULL,
    segment       TEXT NOT NULL CHECK (segment IN ('Retail','Corporate','Online')),
    region_id     INTEGER NOT NULL REFERENCES regions(region_id),
    signup_date   TEXT NOT NULL
);

CREATE TABLE products (
    product_id   INTEGER PRIMARY KEY,
    product_name TEXT NOT NULL,
    category_id  INTEGER NOT NULL REFERENCES categories(category_id),
    unit_price   REAL NOT NULL CHECK (unit_price > 0),
    unit_cost    REAL NOT NULL CHECK (unit_cost > 0)
);

CREATE TABLE salespeople (
    sp_id     INTEGER PRIMARY KEY,
    sp_name   TEXT NOT NULL,
    region_id INTEGER NOT NULL REFERENCES regions(region_id)
);

CREATE TABLE orders (
    order_id    INTEGER PRIMARY KEY,
    customer_id INTEGER NOT NULL REFERENCES customers(customer_id),
    sp_id       INTEGER NOT NULL REFERENCES salespeople(sp_id),
    order_date  TEXT NOT NULL,
    channel     TEXT NOT NULL CHECK (channel IN ('Online','Store','Phone'))
);

CREATE TABLE order_items (
    order_item_id INTEGER PRIMARY KEY,
    order_id      INTEGER NOT NULL REFERENCES orders(order_id),
    product_id    INTEGER NOT NULL REFERENCES products(product_id),
    quantity      INTEGER NOT NULL CHECK (quantity > 0),
    discount_pct  REAL NOT NULL DEFAULT 0
);

CREATE TABLE returns (
    return_id     INTEGER PRIMARY KEY,
    order_item_id INTEGER NOT NULL UNIQUE REFERENCES order_items(order_item_id),
    return_date   TEXT NOT NULL,
    reason        TEXT NOT NULL
);

CREATE TABLE sales_targets (
    sp_id         INTEGER NOT NULL REFERENCES salespeople(sp_id),
    month         TEXT NOT NULL,            -- YYYY-MM
    target_amount REAL NOT NULL,
    PRIMARY KEY (sp_id, month)
);

CREATE INDEX idx_orders_customer ON orders(customer_id);
CREATE INDEX idx_orders_sp       ON orders(sp_id);
CREATE INDEX idx_orders_date     ON orders(order_date);
CREATE INDEX idx_items_order     ON order_items(order_id);
CREATE INDEX idx_items_product   ON order_items(product_id);
