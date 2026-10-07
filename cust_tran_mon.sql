--客户月度交易汇总
SELECT c.name,
       DATE_FORMAT(t.trans_date, '%Y-%m') AS month,
       COUNT(*) AS trans_count,
       SUM(t.amount) AS total_amount
FROM transaction t
JOIN account a ON t.account_id = a.account_id
JOIN customer c ON a.customer_id = c.customer_id
GROUP BY c.name, month
ORDER BY month DESC, total_amount DESC
LIMIT 20;