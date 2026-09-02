CUMCM 2021 B题 第一问 MATLAB V3

【文件】
1. Q1_main_v3.m                  主程序，只运行这个
2. fit_temperature_models_v3.m  温度响应回归与模型比较
3. analyze_time_stability_v3.m  350℃时间稳定性分析
4. 附件1.xlsx
5. 附件2.xlsx

【运行】
将上述5个文件放在同一个文件夹，在 MATLAB 中运行：
Q1_main_v3

【V3改进】
V2只在二次项F检验 p<0.05 时选择二次模型。
V3增加 LOOCV-RMSE，并综合：
- Adjusted R^2
- 训练RMSE
- LOOCV-RMSE
- F检验
- 标准化残差

【选择逻辑】
A. p<0.05，Adj-R2不下降，LOOCV不明显恶化 -> 二次
B. 即使p>=0.05，但：
   LOOCV至少改善10%
   Adj-R2至少提高0.03
   RMSE至少改善10%
   -> 二次
C. 否则优先一次，防止小样本过拟合。

【输出】
Q1_output_v3/
  temperature_regression_results_v3.xlsx
    Sheet1：最终模型
    Sheet2：候选模型比较
  stability_results_v3.xlsx
  figures/
