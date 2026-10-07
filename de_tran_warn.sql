SELECT c.name, t.trans_date, t.amount, t.trans_type
FROM transaction t
JOIN account a ON t.account_id = a.account_id
JOIN customer c ON a.customer_id = c.customer_id
WHERE t.amount > 40000
ORDER BY t.amount DESC
LIMIT 20;