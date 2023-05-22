CREATE VIEW order_details AS
SELECT o.order_id, p.product_name, op.amount, r.restaurant_name
FROM orders o
JOIN order_product op ON o.order_id = op.order_id
JOIN products p ON op.product_id = p.product_id
JOIN restaurants r ON p.restaurant_id = r.restaurant_id;