
第三问最终版程序说明

文件：
Q3_main.m              主程序
response_predict_final.m  响应面预测函数
load_Q2_model.m        第二问模型读取接口
plot_Q3_results.m      绘图

运行：
1. 将所有m文件放入MATLAB当前目录
2. 运行Q3_main.m

功能：
- 基于第二问响应面模型
- 自动标准化变量
- 修复z变量输入错误
- 保留M_total控制项
- PSO非线性优化
- 输出优化结果Excel
- 生成论文可用结果图

注意：
若Q2模型系数更新，只需修改load_Q2_model.m
中的beta和terms。
