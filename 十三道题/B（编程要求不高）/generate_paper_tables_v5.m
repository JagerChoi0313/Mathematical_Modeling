function generate_paper_tables_v5(regFile, stabFile, outDir)
%GENERATE_PAPER_TABLES_V5
% 根据第一问 V3 结果整理论文正文专用表格和附录表。
%
% 输出：
% 1) 一个总Excel文件：paper_tables_v5.xlsx
% 2) 若干单独CSV文件，便于直接复制到Word或Excel中进一步排版。

if ~exist(outDir, 'dir')
    mkdir(outDir);
end

%% 1. 读取 V3 结果
finalTable = readtable(regFile, 'Sheet', '最终模型', 'VariableNamingRule', 'preserve');
compareTable = readtable(regFile, 'Sheet', '候选模型比较', 'VariableNamingRule', 'preserve');
stabTable = readtable(stabFile, 'VariableNamingRule', 'preserve');

% 统一为 string，避免不同 MATLAB 版本读入为 cellstr/categorical 导致筛选报错。
finalTable.('催化剂编号') = string(finalTable.('催化剂编号'));
finalTable.('指标') = string(finalTable.('指标'));
finalTable.('最终模型') = string(finalTable.('最终模型'));
finalTable.('模型表达式') = string(finalTable.('模型表达式'));
finalTable.('选择依据') = string(finalTable.('选择依据'));

compareTable.('催化剂编号') = string(compareTable.('催化剂编号'));
compareTable.('指标') = string(compareTable.('指标'));
compareTable.('最终选择') = string(compareTable.('最终选择'));

stabTable.('指标') = string(stabTable.('指标'));
stabTable.('趋势结论') = string(stabTable.('趋势结论'));

%% 2. 表5-1：典型组合一次/二次模型比较
repIDs = ["A1","A2","A7","A8"];
mask1 = false(height(compareTable),1);
for i = 1:numel(repIDs)
    mask1 = mask1 | compareTable.('催化剂编号') == repIDs(i);
end

Table5_1 = compareTable(mask1, {'催化剂编号','指标', ...
    '一次调整R2','二次调整R2', ...
    '一次RMSE','二次RMSE', ...
    '一次LOOCV_RMSE','二次LOOCV_RMSE', ...
    '二次项F检验p值','最终选择'});

Table5_1 = sortrows(Table5_1, {'催化剂编号','指标'});

%% 3. 表5-2：温度响应模型选型统计
metrics = unique(finalTable.('指标'), 'stable');
rows = cell(numel(metrics), 6);
for i = 1:numel(metrics)
    m = metrics(i);
    sub = finalTable(finalTable.('指标') == m, :);
    nLinear = sum(sub.('最终模型') == "一次多项式");
    nQuad   = sum(sub.('最终模型') == "二次多项式");
    adjMed  = median(sub.('调整R2'));
    adjMin  = min(sub.('调整R2'));
    rmseMed = median(sub.('RMSE'));
    looMed  = median(sub.('LOOCV_RMSE'));
    rows(i,:) = {m, nLinear, nQuad, adjMed, rmseMed, looMed};
end

Table5_2 = cell2table(rows, 'VariableNames', ...
    {'指标','一次多项式个数','二次多项式个数','调整R2中位数','RMSE中位数','LOOCV_RMSE中位数'});

%% 4. 表5-3：代表性最终模型结果
mask3 = false(height(finalTable),1);
for i = 1:numel(repIDs)
    mask3 = mask3 | finalTable.('催化剂编号') == repIDs(i);
end

Table5_3 = finalTable(mask3, {'催化剂编号','指标','最终模型','模型表达式', ...
    '调整R2','RMSE','LOOCV_RMSE','二次项F检验p值','选择依据'});
Table5_3 = sortrows(Table5_3, {'催化剂编号','指标'});

%% 5. 表5-4：350℃稳定性分析结果
Table5_4 = stabTable(:, {'指标','均值','标准差','变异系数CV','时间斜率','R2','斜率p值','趋势结论'});

%% 6. 附录表：42组最终模型汇总（精简列）
AppendixTable = finalTable(:, {'催化剂编号','指标','最终模型','模型表达式', ...
    '调整R2','RMSE','LOOCV_RMSE','二次项F检验p值','最大绝对标准化残差','选择依据'});
AppendixTable = sortrows(AppendixTable, {'催化剂编号','指标'});

%% 7. 另做一个“正文可直接粘贴版”表：A7/A8 拟合图对应结果
mask57 = finalTable.('催化剂编号') == "A7" | finalTable.('催化剂编号') == "A8";
Table_Fig52 = finalTable(mask57, {'催化剂编号','指标','最终模型','调整R2','RMSE','LOOCV_RMSE'});
Table_Fig52 = sortrows(Table_Fig52, {'催化剂编号','指标'});

%% 8. 输出到一个总 Excel 文件
xlsOut = fullfile(outDir, 'paper_tables_v5.xlsx');

writetable(Table5_1, xlsOut, 'Sheet', '表5_1_典型比较');
writetable(Table5_2, xlsOut, 'Sheet', '表5_2_模型统计');
writetable(Table5_3, xlsOut, 'Sheet', '表5_3_代表模型');
writetable(Table5_4, xlsOut, 'Sheet', '表5_4_稳定性');
writetable(Table_Fig52, xlsOut, 'Sheet', '图5_2对应数据');
writetable(AppendixTable, xlsOut, 'Sheet', '附录_42组模型');

%% 9. 同步导出为独立 CSV，便于单表复制使用
writetable(Table5_1, fullfile(outDir, 'Table5_1_typical_model_comparison.csv'));
writetable(Table5_2, fullfile(outDir, 'Table5_2_model_selection_summary.csv'));
writetable(Table5_3, fullfile(outDir, 'Table5_3_representative_final_models.csv'));
writetable(Table5_4, fullfile(outDir, 'Table5_4_stability_summary.csv'));
writetable(Table_Fig52, fullfile(outDir, 'Table_Fig5_2_related_data.csv'));
writetable(AppendixTable, fullfile(outDir, 'Appendix_42_final_models.csv'));

%% 10. 生成一个表格说明文本，方便写论文时查找
write_note_file(outDir);

fprintf('已生成论文表格：\n');
fprintf('  paper_tables_v5.xlsx\n');
fprintf('  Table5_1_typical_model_comparison.csv\n');
fprintf('  Table5_2_model_selection_summary.csv\n');
fprintf('  Table5_3_representative_final_models.csv\n');
fprintf('  Table5_4_stability_summary.csv\n');
fprintf('  Appendix_42_final_models.csv\n');
end

function write_note_file(outDir)
notePath = fullfile(outDir, '表格说明.txt');
fid = fopen(notePath, 'w', 'n', 'UTF-8');
if fid < 0
    warning('无法创建表格说明文件：%s', notePath);
    return;
end

fprintf(fid, '第一问论文表格说明\n');
fprintf(fid, '==============================================\n');
fprintf(fid, '表5-1：典型组合一次/二次模型比较结果\n');
fprintf(fid, '    建议放在“模型选取”小节后，用于说明为什么不能只看 F 检验。\n\n');
fprintf(fid, '表5-2：温度响应模型选型统计\n');
fprintf(fid, '    建议放在“各催化剂温度响应模型求解结果”小节开头或结尾。\n\n');
fprintf(fid, '表5-3：代表性最终模型结果\n');
fprintf(fid, '    建议放在 A7、A8 拟合图附近，和图5-2配合使用。\n\n');
fprintf(fid, '表5-4：350℃稳定性分析结果\n');
fprintf(fid, '    建议放在图5-4之后。\n\n');
fprintf(fid, '附录_42组模型：完整模型结果\n');
fprintf(fid, '    不建议放正文，可放附录。\n');

fclose(fid);
end
