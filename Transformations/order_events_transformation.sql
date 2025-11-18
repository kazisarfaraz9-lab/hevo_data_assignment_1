SELECT
  id AS order_id,
  customer_id,
  status,
  CASE
    WHEN LOWER(status) = 'placed' THEN 'order_placed'
    WHEN LOWER(status) = 'shipped' THEN 'order_shipped'
    WHEN LOWER(status) = 'delivered' THEN 'order_delivered'
    WHEN LOWER(status) = 'cancelled' THEN 'order_cancelled'
    ELSE 'unknown_event'
  END AS event_type
FROM orders;