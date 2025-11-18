CREATE TABLE feedback (
  id INT PRIMARY KEY,
  order_id INT UNIQUE REFERENCES orders(id),
  feedback_comment TEXT,
  rating INTEGER
);