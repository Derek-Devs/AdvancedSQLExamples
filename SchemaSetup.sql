-- Purpose: Create a normalized database schema with appropriate relationships and constraints

-- Drop tables if they exist (for clean setup)
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS product_inventory;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS categories;
DROP TABLE IF EXISTS addresses;
DROP TABLE IF EXISTS customers;

-- Create database schema
CREATE SCHEMA IF NOT EXISTS ecommerce;

-- Create extension for UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create tables
-- 1. Customers table
CREATE TABLE customers (
    customer_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    phone VARCHAR(20),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    loyalty_points INTEGER DEFAULT 0,
    CONSTRAINT chk_email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

-- Create index on email for quick lookups
CREATE INDEX idx_customers_email ON customers(email);

-- 2. Addresses table with foreign key to customers
CREATE TABLE addresses (
    address_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID NOT NULL,
    address_type VARCHAR(20) NOT NULL CHECK (address_type IN ('BILLING', 'SHIPPING', 'BOTH')),
    street_address VARCHAR(100) NOT NULL,
    city VARCHAR(50) NOT NULL,
    state VARCHAR(50) NOT NULL,
    postal_code VARCHAR(20) NOT NULL,
    country VARCHAR(50) NOT NULL DEFAULT 'United States',
    is_default BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id) ON DELETE CASCADE,
    CONSTRAINT unique_default_address_type UNIQUE (customer_id, address_type, is_default)
);

-- Create index on customer_id for quick lookups
CREATE INDEX idx_addresses_customer_id ON addresses(customer_id);

-- 3. Categories table
CREATE TABLE categories (
    category_id SERIAL PRIMARY KEY,
    category_name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    parent_category_id INTEGER,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (parent_category_id) REFERENCES categories(category_id) ON DELETE SET NULL
);

-- 4. Products table
CREATE TABLE products (
    product_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    product_name VARCHAR(100) NOT NULL,
    description TEXT,
    category_id INTEGER NOT NULL,
    base_price DECIMAL(10, 2) NOT NULL CHECK (base_price > 0),
    sku VARCHAR(50) NOT NULL UNIQUE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    weight_kg DECIMAL(5, 2),
    dimensions_cm VARCHAR(50),
    FOREIGN KEY (category_id) REFERENCES categories(category_id) ON DELETE RESTRICT
);

-- Create indexes
CREATE INDEX idx_products_category ON products(category_id);
CREATE INDEX idx_products_name ON products(product_name);
CREATE INDEX idx_products_price_active ON products(base_price, is_active);

-- 5. Product Inventory table
CREATE TABLE product_inventory (
    inventory_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    product_id UUID NOT NULL,
    quantity_in_stock INTEGER NOT NULL DEFAULT 0 CHECK (quantity_in_stock >= 0),
    reorder_threshold INTEGER NOT NULL DEFAULT 5 CHECK (reorder_threshold >= 0),
    reorder_quantity INTEGER NOT NULL DEFAULT 10 CHECK (reorder_quantity > 0),
    warehouse_location VARCHAR(100),
    last_restock_date TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE,
    CONSTRAINT unique_product_inventory UNIQUE (product_id)
);

-- 6. Orders table
CREATE TABLE orders (
    order_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID NOT NULL,
    order_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) NOT NULL CHECK (status IN ('PENDING', 'PROCESSING', 'SHIPPED', 'DELIVERED', 'CANCELLED')),
    shipping_address_id UUID NOT NULL,
    billing_address_id UUID NOT NULL,
    shipping_method VARCHAR(50) NOT NULL,
    shipping_cost DECIMAL(10, 2) NOT NULL DEFAULT 0,
    tax_amount DECIMAL(10, 2) NOT NULL DEFAULT 0,
    discount_amount DECIMAL(10, 2) NOT NULL DEFAULT 0,
    total_amount DECIMAL(10, 2) NOT NULL,
    payment_method VARCHAR(50) NOT NULL,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id) ON DELETE RESTRICT,
    FOREIGN KEY (shipping_address_id) REFERENCES addresses(address_id) ON DELETE RESTRICT,
    FOREIGN KEY (billing_address_id) REFERENCES addresses(address_id) ON DELETE RESTRICT,
    CONSTRAINT chk_total_amount CHECK (total_amount >= 0)
);

-- Create indexes for orders
CREATE INDEX idx_orders_customer_id ON orders(customer_id);
CREATE INDEX idx_orders_order_date ON orders(order_date);
CREATE INDEX idx_orders_status ON orders(status);

-- 7. Order Items table (junction table between Orders and Products)
CREATE TABLE order_items (
    order_item_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID NOT NULL,
    product_id UUID NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price DECIMAL(10, 2) NOT NULL CHECK (unit_price >= 0),
    discount_percent DECIMAL(5, 2) NOT NULL DEFAULT 0 CHECK (discount_percent >= 0 AND discount_percent <= 100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE RESTRICT,
    CONSTRAINT unique_order_product UNIQUE (order_id, product_id)
);

-- Create indexes for order items
CREATE INDEX idx_order_items_order_id ON order_items(order_id);
CREATE INDEX idx_order_items_product_id ON order_items(product_id);

-- Create a view for order summaries
CREATE OR REPLACE VIEW order_summary AS
SELECT
    o.order_id,
    o.customer_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    o.order_date,
    o.status,
    COUNT(oi.order_item_id) AS item_count,
    SUM(oi.quantity) AS total_quantity,
    SUM(oi.quantity * oi.unit_price * (1 - oi.discount_percent / 100)) AS subtotal,
    o.shipping_cost,
    o.tax_amount,
    o.discount_amount,
    o.total_amount
FROM
    orders o
    JOIN customers c ON o.customer_id = c.customer_id
    JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY
    o.order_id, o.customer_id, c.first_name, c.last_name, o.order_date, o.status,
    o.shipping_cost, o.tax_amount, o.discount_amount, o.total_amount;

-- Create triggers to automatically update timestamp fields
-- Create function for updating timestamps
CREATE OR REPLACE FUNCTION update_modified_column()
RETURNS TRIGGER AS $$
BEGIN
   NEW.updated_at = CURRENT_TIMESTAMP;
   RETURN NEW;
END;
$$ LANGUAGE 'plpgsql';

-- Apply the trigger to all tables with timestamp columns
CREATE TRIGGER update_customer_modtime
    BEFORE UPDATE ON customers
    FOR EACH ROW EXECUTE FUNCTION update_modified_column();
    
CREATE TRIGGER update_addresses_modtime
    BEFORE UPDATE ON addresses
    FOR EACH ROW EXECUTE FUNCTION update_modified_column();
    
CREATE TRIGGER update_categories_modtime
    BEFORE UPDATE ON categories
    FOR EACH ROW EXECUTE FUNCTION update_modified_column();
    
CREATE TRIGGER update_products_modtime
    BEFORE UPDATE ON products
    FOR EACH ROW EXECUTE FUNCTION update_modified_column();
    
CREATE TRIGGER update_inventory_modtime
    BEFORE UPDATE ON product_inventory
    FOR EACH ROW EXECUTE FUNCTION update_modified_column();
    
CREATE TRIGGER update_orders_modtime
    BEFORE UPDATE ON orders
    FOR EACH ROW EXECUTE FUNCTION update_modified_column();
    
CREATE TRIGGER update_order_items_modtime
    BEFORE UPDATE ON order_items
    FOR EACH ROW EXECUTE FUNCTION update_modified_column();

-- Create a function to automatically decrease inventory when an order is placed
CREATE OR REPLACE FUNCTION decrease_inventory_on_order()
RETURNS TRIGGER AS $$
BEGIN
    -- Decrease the inventory quantity
    UPDATE product_inventory
    SET quantity_in_stock = quantity_in_stock - NEW.quantity
    WHERE product_id = NEW.product_id;
    
    -- Check if we've reached the reorder threshold
    INSERT INTO inventory_alerts (product_id, alert_type, message)
    SELECT 
        pi.product_id,
        'LOW_STOCK',
        'Product inventory below reorder threshold'
    FROM 
        product_inventory pi
    WHERE 
        pi.product_id = NEW.product_id 
        AND pi.quantity_in_stock <= pi.reorder_threshold
    ON CONFLICT (product_id, alert_type) DO NOTHING;
        
    RETURN NEW;
END;
$$ LANGUAGE 'plpgsql';

-- First create the inventory_alerts table
CREATE TABLE IF NOT EXISTS inventory_alerts (
    alert_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    product_id UUID NOT NULL,
    alert_type VARCHAR(50) NOT NULL,
    message TEXT NOT NULL,
    is_resolved BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMP WITH TIME ZONE,
    FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE,
    CONSTRAINT unique_product_alert UNIQUE (product_id, alert_type)
);

-- Then create the trigger
CREATE TRIGGER decrease_inventory
    AFTER INSERT ON order_items
    FOR EACH ROW
    EXECUTE FUNCTION decrease_inventory_on_order();

-- Create a materialized view for product sales analytics that can be refreshed periodically
CREATE MATERIALIZED VIEW product_sales_analytics AS
SELECT
    p.product_id,
    p.product_name,
    c.category_name,
    SUM(oi.quantity) AS total_quantity_sold,
    SUM(oi.quantity * oi.unit_price * (1 - oi.discount_percent / 100)) AS total_revenue,
    COUNT(DISTINCT o.order_id) AS order_count,
    COUNT(DISTINCT o.customer_id) AS customer_count,
    ROUND(AVG(oi.unit_price), 2) AS average_selling_price,
    MIN(o.order_date) AS first_sale_date,
    MAX(o.order_date) AS last_sale_date
FROM
    products p
    JOIN order_items oi ON p.product_id = oi.product_id
    JOIN orders o ON oi.order_id = o.order_id
    JOIN categories c ON p.category_id = c.category_id
WHERE
    o.status != 'CANCELLED'
GROUP BY
    p.product_id, p.product_name, c.category_name;

-- Create index on the materialized view
CREATE UNIQUE INDEX idx_product_sales_analytics ON product_sales_analytics(product_id);

-- Comment on tables and columns for documentation
COMMENT ON TABLE customers IS 'Stores customer information including contact details';
COMMENT ON COLUMN customers.email IS 'Primary contact email - must be unique and validated';
COMMENT ON COLUMN customers.loyalty_points IS 'Points earned through purchases for the loyalty program';

COMMENT ON TABLE orders IS 'Contains order header information';
COMMENT ON COLUMN orders.status IS 'Current status of order (PENDING, PROCESSING, SHIPPED, DELIVERED, CANCELLED)';
COMMENT ON COLUMN orders.total_amount IS 'Total order amount including tax and shipping, minus discounts';

-- Create a customer search function
CREATE OR REPLACE FUNCTION search_customers(search_term TEXT)
RETURNS TABLE (
    customer_id UUID,
    full_name TEXT,
    email VARCHAR(100),
    phone VARCHAR(20),
    total_orders BIGINT,
    total_spent NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.customer_id,
        c.first_name || ' ' || c.last_name AS full_name,
        c.email,
        c.phone,
        COUNT(DISTINCT o.order_id) AS total_orders,
        COALESCE(SUM(o.total_amount), 0) AS total_spent
    FROM
        customers c
        LEFT JOIN orders o ON c.customer_id = o.customer_id
    WHERE
        c.first_name ILIKE '%' || search_term || '%' OR
        c.last_name ILIKE '%' || search_term || '%' OR
        c.email ILIKE '%' || search_term || '%' OR
        c.phone ILIKE '%' || search_term || '%'
    GROUP BY
        c.customer_id, c.first_name, c.last_name, c.email, c.phone
    ORDER BY
        total_spent DESC;
END;
$$ LANGUAGE plpgsql;
