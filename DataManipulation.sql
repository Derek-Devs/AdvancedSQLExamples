-- Purpose: Implement CRUD operations, transactions, and complex business logic

-- 1. Inserting Initial Data
-- Sample categories
INSERT INTO categories (category_name, description)
VALUES 
    ('Electronics', 'Electronic devices and accessories'),
    ('Clothing', 'Apparel and fashion items'),
    ('Home & Kitchen', 'Household goods and kitchen appliances'),
    ('Books', 'Books, e-books, and audiobooks'),
    ('Sports & Outdoors', 'Athletic equipment and outdoor gear');

-- Add sub-categories
INSERT INTO categories (category_name, description, parent_category_id)
VALUES 
    ('Smartphones', 'Mobile phones and accessories', 1),
    ('Laptops', 'Notebook computers and accessories', 1),
    ('Men''s Clothing', 'Clothing items for men', 2),
    ('Women''s Clothing', 'Clothing items for women', 2),
    ('Kitchen Appliances', 'Equipment for food preparation', 3),
    ('Fiction', 'Novels and fictional literature', 4),
    ('Non-Fiction', 'Educational and informative books', 4),
    ('Outdoor Recreation', 'Equipment for outdoor activities', 5),
    ('Fitness Equipment', 'Tools for exercise and fitness', 5);

-- 2. Stored Procedure for Adding a New Product with Inventory
CREATE OR REPLACE PROCEDURE add_new_product(
    product_name VARCHAR(100),
    description TEXT,
    category_name VARCHAR(50),
    base_price DECIMAL(10, 2),
    sku VARCHAR(50),
    initial_stock INTEGER,
    weight_kg DECIMAL(5, 2) DEFAULT NULL,
    dimensions_cm VARCHAR(50) DEFAULT NULL,
    reorder_threshold INTEGER DEFAULT 5,
    reorder_quantity INTEGER DEFAULT 10,
    warehouse_location VARCHAR(100) DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_category_id INTEGER;
    v_product_id UUID;
BEGIN
    -- Begin transaction
    BEGIN
        -- Find category ID or create a new one if it doesn't exist
        SELECT category_id INTO v_category_id FROM categories WHERE category_name = add_new_product.category_name;
        
        IF v_category_id IS NULL THEN
            INSERT INTO categories (category_name, description)
            VALUES (add_new_product.category_name, 'Auto-created category')
            RETURNING category_id INTO v_category_id;
            
            RAISE NOTICE 'Created new category: %', add_new_product.category_name;
        END IF;
        
        -- Insert the new product
        INSERT INTO products (
            product_name, 
            description, 
            category_id, 
            base_price, 
            sku, 
            weight_kg, 
            dimensions_cm
        )
        VALUES (
            add_new_product.product_name,
            add_new_product.description,
            v_category_id,
            add_new_product.base_price,
            add_new_product.sku,
            add_new_product.weight_kg,
            add_new_product.dimensions_cm
        )
        RETURNING product_id INTO v_product_id;
        
        -- Insert initial inventory
        INSERT INTO product_inventory (
            product_id,
            quantity_in_stock,
            reorder_threshold,
            reorder_quantity,
            warehouse_location,
            last_restock_date
        )
        VALUES (
            v_product_id,
            add_new_product.initial_stock,
            add_new_product.reorder_threshold,
            add_new_product.reorder_quantity,
            add_new_product.warehouse_location,
            CURRENT_TIMESTAMP
        );
        
        -- Commit transaction
        COMMIT;
        RAISE NOTICE 'Successfully added product: % with initial stock of %', add_new_product.product_name, add_new_product.initial_stock;
    
    EXCEPTION WHEN OTHERS THEN
        -- Rollback transaction on error
        ROLLBACK;
        RAISE EXCEPTION 'Error adding product: %', SQLERRM;
    END;
END;
$$;

-- Example usage of add_new_product procedure
CALL add_new_product(
    'Smartphone X Pro',
    'Latest flagship smartphone with advanced camera system',
    'Smartphones',
    899.99,
    'SP-X-PRO-001',
    100,
    0.18,
    '15x7x0.8',
    10,
    20,
    'Warehouse A, Section 3'
);

-- 3. Stored Procedure for Creating a Complete Order
CREATE OR REPLACE PROCEDURE create_order(
    p_customer_id UUID,
    p_shipping_address_id UUID,
    p_billing_address_id UUID,
    p_shipping_method VARCHAR(50),
    p_payment_method VARCHAR(50),
    p_items JSONB -- Array of JSON objects with product_id, quantity, unit_price
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_order_id UUID;
    v_total_amount DECIMAL(10, 2) := 0;
    v_subtotal DECIMAL(10, 2) := 0;
    v_shipping_cost DECIMAL(10, 2) := 0;
    v_tax_rate DECIMAL(5, 2) := 0.08; -- 8% tax rate
    v_tax_amount DECIMAL(10, 2) := 0;
    v_item JSONB;
    v_product_id UUID;
    v_quantity INTEGER;
    v_unit_price DECIMAL(10, 2);
    v_current_stock INTEGER;
    v_total_loyalty_points INTEGER := 0;
BEGIN
    -- Begin transaction
    BEGIN
        -- Determine shipping cost based on shipping method
        CASE 
            WHEN p_shipping_method = 'Standard' THEN v_shipping_cost := 5.99;
            WHEN p_shipping_method = 'Express' THEN v_shipping_cost := 12.99;
            WHEN p_shipping_method = 'Overnight' THEN v_shipping_cost := 19.99;
            ELSE v_shipping_cost := 5.99; -- Default to standard
        END CASE;
        
        -- First pass: Calculate subtotal and check inventory
        FOR i IN 0..jsonb_array_length(p_items) - 1 LOOP
            v_item := p_items->i;
            v_product_id := (v_item->>'product_id')::UUID;
            v_quantity := (v_item->>'quantity')::INTEGER;
            v_unit_price := (v_item->>'unit_price')::DECIMAL(10, 2);
            
            -- Check if we have enough inventory
            SELECT quantity_in_stock INTO v_current_stock 
            FROM product_inventory 
            WHERE product_id = v_product_id;
            
            IF v_current_stock < v_quantity THEN
                RAISE EXCEPTION 'Insufficient inventory for product ID %: % requested, % available', 
                    v_product_id, v_quantity, v_current_stock;
            END IF;
            
            -- Add to subtotal
            v_subtotal := v_subtotal + (v_quantity * v_unit_price);
            
            -- Calculate loyalty points (1 point per $10 spent)
            v_total_loyalty_points := v_total_loyalty_points + FLOOR(v_quantity * v_unit_price / 10);
        END LOOP;
        
        -- Calculate tax
        v_tax_amount := ROUND(v_subtotal * v_tax_rate, 2);
        
        -- Calculate total
        v_total_amount := v_subtotal + v_shipping_cost + v_tax_amount;
        
        -- Create order
        INSERT INTO orders (
            customer_id,
            shipping_address_id,
            billing_address_id,
            shipping_method,
            payment_method,
            shipping_cost,
            tax_amount,
            total_amount,
            status
        )
        VALUES (
            p_customer_id,
            p_shipping_address_id,
            p_billing_address_id,
            p_shipping_method,
            p_payment_method,
            v_shipping_cost,
            v_tax_amount,
            v_total_amount,
            'PENDING'
        )
        RETURNING order_id INTO v_order_id;
        
        -- Second pass: Add order items (this will trigger inventory updates via trigger)
        FOR i IN 0..jsonb_array_length(p_items) - 1 LOOP
            v_item := p_items->i;
            v_product_id := (v_item->>'product_id')::UUID;
            v_quantity := (v_item->>'quantity')::INTEGER;
            v_unit_price := (v_item->>'unit_price')::DECIMAL(10, 2);
            
            INSERT INTO order_items (
                order_id,
                product_id,
                quantity,
                unit_price
            )
            VALUES (
                v_order_id,
                v_product_id,
                v_quantity,
                v_unit_price
            );
        END LOOP;
        
        -- Update customer loyalty points
        UPDATE customers
        SET loyalty_points = loyalty_points + v_total_loyalty_points
        WHERE customer_id = p_customer_id;
        
        -- Commit transaction
        COMMIT;
        RAISE NOTICE 'Successfully created order ID: % for customer ID: % with total amount: $%', 
            v_order_id, p_customer_id, v_total_amount;
    
    EXCEPTION WHEN OTHERS THEN
        -- Rollback transaction on error
        ROLLBACK;
        RAISE EXCEPTION 'Error creating order: %', SQLERRM;
    END;
END;
$$;

-- 4. Function to Get Product Recommendations based on Purchase History
CREATE OR REPLACE FUNCTION get_product_recommendations(p_customer_id UUID, p_limit INTEGER DEFAULT 5)
RETURNS TABLE (
    product_id UUID,
    product_name VARCHAR(100),
    category_name VARCHAR(50),
    base_price DECIMAL(10, 2),
    recommendation_score DECIMAL(10, 4)
) AS $$
BEGIN
    RETURN QUERY
    WITH customer_categories AS (
        -- Find categories this customer has purchased from
        SELECT
            p.category_id,
            COUNT(oi.order_item_id) AS purchase_count
        FROM
            orders o
            JOIN order_items oi ON o.order_id = oi.order_id
            JOIN products p ON oi.product_id = p.product_id
        WHERE
            o.customer_id = p_customer_id
            AND o.status != 'CANCELLED'
        GROUP BY
            p.category_id
    ),
    customer_products AS (
        -- Products this customer has already purchased
        SELECT DISTINCT oi.product_id
        FROM
            orders o
            JOIN order_items oi ON o.order_id = oi.order_id
        WHERE
            o.customer_id = p_customer_id
            AND o.status != 'CANCELLED'
    ),
    product_popularity AS (
        -- Overall popularity of products
        SELECT
            p.product_id,
            COUNT(oi.order_item_id) AS total_orders,
            COUNT(DISTINCT o.customer_id) AS unique_customers
        FROM
            products p
            JOIN order_items oi ON p.product_id = oi.product_id
            JOIN orders o ON oi.order_id = o.order_id
        WHERE
            o.status != 'CANCELLED'
        GROUP BY
            p.product_id
    )
    SELECT
        p.product_id,
        p.product_name,
        c.category_name,
        p.base_price,
        -- Calculate recommendation score based on category preference and product popularity
        (
            COALESCE(cc.purchase_count, 0) * 0.7 +  -- Category preference (70% weight)
            COALESCE(pp.total_orders, 0) * 0.2 +     -- Product popularity (20% weight)
            COALESCE(pp.unique_customers, 0) * 0.1   -- Unique customers (10% weight)
        ) AS recommendation_score
    FROM
        products p
        JOIN categories c ON p.category_id = c.category_id
        LEFT JOIN customer_categories cc ON p.category_id = cc.category_id
        LEFT JOIN product_popularity pp ON p.product_id = pp.product_id
    WHERE
        p.is_active = TRUE
        AND p.product_id NOT IN (SELECT product_id FROM customer_products)
        -- Ensure we have inventory
        AND EXISTS (
            SELECT 1 FROM product_inventory pi 
            WHERE pi.product_id = p.product_id 
            AND pi.quantity_in_stock > 0
        )
    ORDER BY
        recommendation_score DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- 5. Procedure to Update Order Status with Notifications
CREATE TABLE IF NOT EXISTS customer_notifications (
    notification_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID NOT NULL,
    order_id UUID,
    notification_type VARCHAR(50) NOT NULL,
    message TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id) ON DELETE CASCADE,
    FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE SET NULL
);

CREATE OR REPLACE PROCEDURE update_order_status(
    p_order_id UUID,
    p_new_status VARCHAR(20),
    p_notify_customer BOOLEAN DEFAULT TRUE
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_current_status VARCHAR(20);
    v_customer_id UUID;
    v_notification_message TEXT;
BEGIN
    -- Get current status and customer ID
    SELECT status, customer_id INTO v_current_status, v_customer_id
    FROM orders
    WHERE order_id = p_order_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order ID % not found', p_order_id;
    END IF;
    
    -- Check if status transition is valid
    IF NOT (
        (v_current_status = 'PENDING' AND p_new_status IN ('PROCESSING', 'CANCELLED')) OR
        (v_current_status = 'PROCESSING' AND p_new_status IN ('SHIPPED', 'CANCELLED')) OR
        (v_current_status = 'SHIPPED' AND p_new_status IN ('DELIVERED', 'CANCELLED')) OR
        (v_current_status = 'DELIVERED')
    ) THEN
        RAISE EXCEPTION 'Invalid status transition from % to %', v_current_status, p_new_status;
    END IF;
    
    -- Update order status
    UPDATE orders
    SET status = p_new_status, updated_at = CURRENT_TIMESTAMP
    WHERE order_id = p_order_id;
    
    -- Create customer notification if requested
    IF p_notify_customer THEN
        CASE p_new_status
            WHEN 'PROCESSING' THEN
                v_notification_message := 'Your order has been confirmed and is now being processed.';
            WHEN 'SHIPPED' THEN
                v_notification_message := 'Great news! Your order has been shipped and is on its way to you.';
            WHEN 'DELIVERED' THEN
                v_notification_message := 'Your order has been delivered. Thank you for shopping with us!';
            WHEN 'CANCELLED' THEN
                v_notification_message := 'Your order has been cancelled. Please contact customer support for more information.';
            ELSE
                v_notification_message := 'Your order status has been updated to ' || p_new_status;
        END CASE;
        
        INSERT INTO customer_notifications (
            customer_id,
            order_id,
            notification_type,
            message
        )
        VALUES (
            v_customer_id,
            p_order_id,
            'ORDER_STATUS',
            v_notification_message
        );
    END IF;
    
    RAISE NOTICE 'Order % status updated from % to %', p_order_id, v_current_status, p_new_status;
END;
$$;

-- 6. Function to Apply Bulk Price Updates with Constraints
CREATE OR REPLACE FUNCTION bulk_price_update(
    p_category_id INTEGER,
    p_adjustment_percent DECIMAL(5, 2),
    p_max_adjustment_amount DECIMAL(10, 2) DEFAULT 100.00,
    p_apply_changes BOOLEAN DEFAULT FALSE
)
RETURNS TABLE (
    product_id UUID,
    product_name VARCHAR(100),
    old_price DECIMAL(10, 2),
    new_price DECIMAL(10, 2),
    absolute_change DECIMAL(10, 2),
    percent_change DECIMAL(5, 2)
) AS $$
BEGIN
    -- Validate inputs
    IF p_adjustment_percent > 25.0 OR p_adjustment_percent < -25.0 THEN
        RAISE EXCEPTION 'Adjustment percentage must be between -25% and 25%';
    END IF;
    
    RETURN QUERY
    WITH price_changes AS (
        SELECT
            p.product_id,
            p.product_name,
            p.base_price AS old_price,
            CASE
                WHEN p_adjustment_percent >= 0 THEN
                    LEAST(
                        p.base_price * (1 + p_adjustment_percent / 100),
                        p.base_price + p_max_adjustment_amount
                    )
                ELSE
                    GREATEST(
                        p.base_price * (1 + p_adjustment_percent / 100),
                        p.base_price - p_max_adjustment_amount
                    )
            END AS new_price
        FROM
            products p
        WHERE
            (p_category_id IS NULL OR p.category_id = p_category_id)
            AND p.is_active = TRUE
    )
    SELECT
        pc.product_id,
        pc.product_name,
        pc.old_price,
        ROUND(pc.new_price, 2) AS new_price,
        ROUND(ABS(pc.new_price - pc.old_price), 2) AS absolute_change,
        ROUND((pc.new_price - pc.old_price) / pc.old_price * 100, 2) AS percent_change
    FROM
        price_changes pc;
    
    -- Apply changes if requested
    IF p_apply_changes THEN
        UPDATE products p
        SET base_price = pc.new_price
        FROM (
            SELECT
                product_id,
                CASE
                    WHEN p_adjustment_percent >= 0 THEN
                        LEAST(
                            base_price * (1 + p_adjustment_percent / 100),
                            base_price + p_max_adjustment_amount
                        )
                    ELSE
                        GREATEST(
                            base_price * (1 + p_adjustment_percent / 100),
                            base_price - p_max_adjustment_amount
                        )
                END AS new_price
            FROM
                products
            WHERE
                (p_category_id IS NULL OR category_id = p_category_id)
                AND is_active = TRUE
        ) pc
        WHERE p.product_id = pc.product_id;
        
        RAISE NOTICE 'Updated prices for % products', 
            (SELECT COUNT(*) FROM products WHERE (p_category_id IS NULL OR category_id = p_category_id) AND is_active = TRUE);
    ELSE
        RAISE NOTICE 'This was a preview only. No prices were actually updated.';
    END IF;
END;
$$ LANGUAGE plpgsql;

-- 7. Customer Analytics Function
CREATE OR REPLACE FUNCTION customer_purchase_analysis(p_months_lookback INTEGER DEFAULT 12)
RETURNS TABLE (
    customer_id UUID,
    customer_name TEXT,
    total_orders INTEGER,
    total_spent DECIMAL(10, 2),
    average_order_value DECIMAL(10, 2),
    most_purchased_category VARCHAR(50),
    last_purchase_date TIMESTAMP WITH TIME ZONE,
    days_since_last_purchase INTEGER,
    customer_segment TEXT
) AS $$
DECLARE
    v_cutoff_date TIMESTAMP WITH TIME ZONE := CURRENT_TIMESTAMP - (p_months_lookback * INTERVAL '1 month');
BEGIN
    RETURN QUERY
    WITH customer_orders AS (
        SELECT
            c.customer_id,
            c.first_name || ' ' || c.last_name AS customer_name,
            COUNT(DISTINCT o.order_id) AS total_orders,
            SUM(o.total_amount) AS total_spent,
            AVG(o.total_amount) AS average_order_value,
            MAX(o.order_date) AS last_purchase_date,
            EXTRACT(DAY FROM (CURRENT_TIMESTAMP - MAX(o.order_date)))::INTEGER AS days_since_last_purchase
        FROM
            customers c
            JOIN orders o ON c.customer_id = o.customer_id
        WHERE
            o.order_date >= v_cutoff_date
            AND o.status != 'CANCELLED'
        GROUP BY
            c.customer_id, c.first_name, c.last_name
    ),
    customer_categories AS (
        SELECT
            o.customer_id,
            p.category_id,
            c.category_name,
            COUNT(*) AS purchase_count,
            ROW_NUMBER() OVER (PARTITION BY o.customer_id ORDER BY COUNT(*) DESC) AS rank
        FROM
            orders o
            JOIN order_items oi ON o.order_id = oi.order_id
            JOIN products p ON oi.product_id = p.product_id
            JOIN categories c ON p.category_id = c.category_id
        WHERE
            o.order_date >= v_cutoff_date
            AND o.status != 'CANCELLED'
        GROUP BY
            o.customer_id, p.category_id, c.category_name
    )
    SELECT
        co.customer_id,
        co.customer_name,
        co.total_orders,
        ROUND(co.total_spent, 2) AS total_spent,
        ROUND(co.average_order_value, 2) AS average_order_value,
        cc.category_name AS most_purchased_category,
        co.last_purchase_date,
        co.days_since_last_purchase,
        CASE
            WHEN co.days_since_last_purchase <= 30 AND co.total_orders >= 3 AND co.total_spent > 500 THEN 'VIP'
            WHEN co.days_since_last_purchase <= 90 AND co.total_spent > 300 THEN 'Loyal'
            WHEN co.days_since_last_purchase <= 180 THEN 'Active'
            WHEN co.days_since_last_purchase <= 365 THEN 'At Risk'
            ELSE 'Inactive'
        END AS customer_segment
    FROM
        customer_orders co
        LEFT JOIN customer_categories cc ON co.customer_id = cc.customer_id AND cc.rank = 1
    ORDER BY
        co.total_spent DESC;
END;
$$ LANGUAGE plpgsql;

-- 8. Upsert Example: Insert or Update Product
CREATE OR REPLACE PROCEDURE upsert_product(
    p_sku VARCHAR(50),
    p_product_name VARCHAR(100),
    p_description TEXT,
    p_category_id INTEGER,
    p_base_price DECIMAL(10, 2),
    p_is_active BOOLEAN DEFAULT TRUE,
    p_weight_kg DECIMAL(5, 2) DEFAULT NULL,
    p_dimensions_cm VARCHAR(50) DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_product_id UUID;
BEGIN
    -- Check if product exists by SKU
    SELECT product_id INTO v_product_id
    FROM products
    WHERE sku = p_sku;
    
    IF v_product_id IS NULL THEN
        -- Insert new product
        INSERT INTO products (
            product_name,
            description,
            category_id,
            base_price,
            sku,
            is_active,
            weight_kg,
            dimensions_cm
        )
        VALUES (
            p_product_name,
            p_description,
            p_category_id,
            p_base_price,
            p_sku,
            p_is_active,
            p_weight_kg,
            p_dimensions_cm
        )
        RETURNING product_id INTO v_product_id;
        
        RAISE NOTICE 'Inserted new product with SKU: %', p_sku;
    ELSE
        -- Update existing product
        UPDATE products
        SET
            product_name = p_product_name,
            description = p_description,
            category_id = p_category_id,
            base_price = p_base_price,
            is_active = p_is_active,
            weight_kg = p_weight_kg,
            dimensions_cm = p_dimensions_cm,
            updated_at = CURRENT_TIMESTAMP
        WHERE
            product_id = v_product_id;
            
        RAISE NOTICE 'Updated existing product with SKU: %', p_sku;
    END IF;
END;
$$;

-- 9. Procedure to Handle Product Returns and Inventory Updates
CREATE OR REPLACE PROCEDURE process_product_return(
    p_order_id UUID,
    p_product_id UUID,
    p_return_quantity INTEGER,
    p_return_reason TEXT,
    p_restock_inventory BOOLEAN DEFAULT TRUE,
    p_refund_amount DECIMAL(10, 2) DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_customer_id UUID;
    v_order_item_id UUID;
    v_original_quantity INTEGER;
    v_unit_price DECIMAL(10, 2);
    v_calculated_refund DECIMAL(10, 2);
    v_return_id UUID;
BEGIN
    -- Begin transaction
    BEGIN
        -- Verify order item exists and get details
        SELECT 
            oi.order_item_id, 
            oi.quantity, 
            oi.unit_price, 
            o.customer_id
        INTO 
            v_order_item_id, 
            v_original_quantity, 
            v_unit_price, 
            v_customer_id
        FROM 
            order_items oi
            JOIN orders o ON oi.order_id = o.order_id
        WHERE 
            oi.order_id = p_order_id
            AND oi.product_id = p_product_id;
            
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Order item not found for order ID % and product ID %', p_order_id, p_product_id;
        END IF;
        
        -- Validate return quantity
        IF p_return_quantity > v_original_quantity THEN
            RAISE EXCEPTION 'Return quantity (%) exceeds original order quantity (%)', 
                p_return_quantity, v_original_quantity;
        END IF;
        
        -- Calculate refund amount if not provided
        IF p_refund_amount IS NULL THEN
            v_calculated_refund := ROUND(p_return_quantity * v_unit_price, 2);
        ELSE
            v_calculated_refund := p_refund_amount;
        END IF;
        
        -- Create return record
        INSERT INTO product_returns (
            order_id,
            product_id,
            customer_id,
            return_quantity,
            return_reason,
            refund_amount,
            status
        )
        VALUES (
            p_order_id,
            p_product_id,
            v_customer_id,
            p_return_quantity,
            p_return_reason,
            v_calculated_refund,
            'PROCESSED'
        )
        RETURNING return_id INTO v_return_id;
        
        -- Update inventory if requested
        IF p_restock_inventory THEN
            UPDATE product_inventory
            SET 
                quantity_in_stock = quantity_in_stock + p_return_quantity,
                updated_at = CURRENT_TIMESTAMP
            WHERE 
                product_id = p_product_id;
                
            RAISE NOTICE 'Restocked % units of product ID %', p_return_quantity, p_product_id;
        END IF;
        
        -- Create customer notification
        INSERT INTO customer_notifications (
            customer_id,
            order_id,
            notification_type,
            message
        )
        VALUES (
            v_customer_id,
            p_order_id,
            'RETURN_PROCESSED',
            'Your return has been processed. Refund amount: $' || v_calculated_refund || 
            '. Thank you for letting us know about your experience.'
        );
        
        -- Commit transaction
        COMMIT;
        RAISE NOTICE 'Successfully processed return ID: % with refund amount: $%', 
            v_return_id, v_calculated_refund;
    
    EXCEPTION WHEN OTHERS THEN
        -- Rollback transaction on error
        ROLLBACK;
        RAISE EXCEPTION 'Error processing return: %', SQLERRM;
    END;
END;
$$;

-- Create returns table for the above procedure
CREATE TABLE IF NOT EXISTS product_returns (
    return_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID NOT NULL,
    product_id UUID NOT NULL,
    customer_id UUID NOT NULL,
    return_quantity INTEGER NOT NULL CHECK (return_quantity > 0),
    return_reason TEXT,
    refund_amount DECIMAL(10, 2) NOT NULL,
    status VARCHAR(20) NOT NULL CHECK (status IN ('PENDING', 'PROCESSED', 'REJECTED')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    processed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE RESTRICT,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id) ON DELETE CASCADE
);

-- 10. Materialized View Refresh Function
CREATE OR REPLACE FUNCTION refresh_all_materialized_views(p_concurrently BOOLEAN DEFAULT TRUE)
RETURNS VOID AS $$
DECLARE
    v_statement TEXT;
    v_view_name TEXT;
    v_schema_name TEXT;
BEGIN
    FOR v_schema_name, v_view_name IN
        SELECT schemaname, matviewname FROM pg_matviews
    LOOP
        v_statement := 'REFRESH MATERIALIZED VIEW ';
        
        IF p_concurrently THEN
            v_statement := v_statement || 'CONCURRENTLY ';
        END IF;
        
        v_statement := v_statement || quote_ident(v_schema_name) || '.' || quote_ident(v_view_name);
        
        EXECUTE v_statement;
        RAISE NOTICE 'Refreshed materialized view: %.%', v_schema_name, v_view_name;
    END LOOP;
END;
$$ LANGUAGE plpgsql;
