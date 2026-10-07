import pymysql
import random
from faker import Faker

fake = Faker('zh_CN')
conn = pymysql.connect(
    host='localhost',
    user='root',
    password='123456',
    database='demo_bank',
    charset='utf8mb4'
)
cursor = conn.cursor()

# 客户
for i in range(1, 501):
    cursor.execute(
        "INSERT INTO customer VALUES (%s,%s,%s,%s)",
        (i, fake.name(), fake.city(), fake.date_between('-5y', 'today'))
    )

# 账户
for i in range(1, 801):
    cursor.execute(
        "INSERT INTO account VALUES (%s,%s,%s,%s,%s)",
        (i, random.randint(1, 500),
         random.choice(['储蓄', '信用', '理财']),
         round(random.uniform(1000, 500000), 2),
         fake.date_between('-3y', 'today'))
    )

# 交易
for i in range(1, 50001):
    cursor.execute(
        "INSERT INTO transaction VALUES (%s,%s,%s,%s,%s)",
        (i, random.randint(1, 800),
         fake.date_time_between('-1y', 'now'),
         round(random.uniform(10, 50000), 2),
         random.choice(['转入', '转出', '消费', '还款']))
    )

conn.commit()
print("数据生成完成")
cursor.close()
conn.close()