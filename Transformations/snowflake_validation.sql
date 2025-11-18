SELECT COUNT(*) FROM customers;
SELECT COUNT(*) FROM orders;
SELECT COUNT(*) FROM feedback;

SELECT email, username FROM customers LIMIT 20;

SELECT event_type, COUNT(*) FROM order_events GROUP BY event_type;
