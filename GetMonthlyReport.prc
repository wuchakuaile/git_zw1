--存储过程
DELIMITER //
CREATE PROCEDURE GetMonthlyReport(IN p_month VARCHAR(7))
BEGIN
    SELECT c.city,
           COUNT(DISTINCT c.customer_id) AS customer_count,
           SUM(t.amount) AS total_amount
    FROM transaction t
    JOIN account a ON t.account_id = a.account_id
    JOIN customer c ON a.customer_id = c.customer_id
    WHERE DATE_FORMAT(t.trans_date, '%Y-%m') = p_month
    GROUP BY c.city;
END //
DELIMITER ;