clc;
clear;
close all;

%% 第三问：负荷982.4MW时各机组初始出力分配结果表

% 机组编号
Gen = (1:8)';

% 当前出力 / MW
Current_Output = [120; 73; 180; 80; 125; 125; 81.1; 90];

% 爬坡约束下限 / MW
Lower_Limit = [87; 58; 132; 60.5; 98; 95; 60.1; 63];

% 爬坡约束上限 / MW
Upper_Limit = [153; 88; 228; 99.5; 152; 155; 102.1; 117];

% 第三问计算得到的初始出力分配预案 / MW
Initial_Dispatch = [150; 79; 180; 99.5; 125; 140; 95; 113.9];

% 出力变化量 / MW
Change_Output = Initial_Dispatch - Current_Output;

% 生成 MATLAB 表格
result_table = table(Gen, Current_Output, Lower_Limit, Upper_Limit, ...
    Initial_Dispatch, Change_Output, ...
    'VariableNames', {'机组编号', '当前出力_MW', '出力下限_MW', ...
    '出力上限_MW', '初始出力_MW', '出力变化_MW'});

% 显示结果表
disp('================ 负荷982.4MW时各机组初始出力分配结果表 ================');
disp(result_table);

% 检查总出力
total_output = sum(Initial_Dispatch);
fprintf('\n初始出力总和为：%.1f MW\n', total_output);

% 检查是否满足负荷需求
D = 982.4;
if abs(total_output - D) < 1e-6
    fprintf('总出力满足负荷需求 %.1f MW。\n', D);
else
    fprintf('总出力不满足负荷需求，请检查数据。\n');
end

% 检查是否满足爬坡约束
if all(Initial_Dispatch >= Lower_Limit) && all(Initial_Dispatch <= Upper_Limit)
    fprintf('各机组初始出力均满足爬坡约束。\n');
else
    fprintf('存在机组出力不满足爬坡约束，请检查数据。\n');
end

%% 可选：导出为 Excel 表格，方便粘贴到论文
writetable(result_table, '第三问_负荷982点4MW初始出力分配结果表.xlsx');

%% 可选：生成表格图片，方便直接插入论文

figure('Color','w','Position',[200 200 900 260]);

uitable('Data', table2cell(result_table), ...
    'ColumnName', result_table.Properties.VariableNames, ...
    'RowName', [], ...
    'Units', 'normalized', ...
    'Position', [0 0 1 1]);

title('负荷982.4MW时各机组初始出力分配结果表');

% 保存表格图片
exportgraphics(gcf, '第三问_负荷982点4MW初始出力分配结果表.png', 'Resolution', 300);