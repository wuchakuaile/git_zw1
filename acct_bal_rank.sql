SELECT c.name,
       a.account_type,
       a.balance,
       RANK() OVER (PARTITION BY a.account_type ORDER BY a.balance DESC) AS rk
FROM account a
JOIN customer c ON a.customer_id = c.customer_id
LIMIT 20;