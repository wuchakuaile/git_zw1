<img width="1583" height="674" alt="image" src="https://github.com/user-attachments/assets/40974d79-6dfe-4978-931a-84c970177123" /># TEXT2SQL Demo（Dify + DeepSeek + MySQL）

## 这是什么
输入自然语言，自动生成 SQL，连接 MySQL 返回查询结果。

## 效果演示
【《Dify + DeepSeek 搭建 TEXT2SQL 演示》】 https://www.bilibili.com/video/BV1qset6bEyw/?share_source=copy_web&vd_source=0cebdb6ced3ef9faaadf22afc4f0c54d

## 架构
用户输入 → Dify 工作流 → DeepSeek 生成 SQL → MySQL 执行 → 返回结果

## 技术栈
- Dify
- DeepSeek API
- MySQL
- Python（可选，用于校验 SQL）

## 快速开始
1. 部署 Dify
2. 配置 DeepSeek API
3. 连接 MySQL
4. 导入工作流 DSL
5. 输入自然语言测试

## 后续计划
- 增加 SQL 安全校验
- 支持多表关联
- 增加知识库提升准确率
