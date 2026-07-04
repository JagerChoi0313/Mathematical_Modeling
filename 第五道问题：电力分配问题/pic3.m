clc;
clear;
close all;

%% 第三问：负荷982.4MW时新增容量选取过程表

% 说明：
% 该表表示在各机组满足爬坡下限的基础上，
% 为达到982.4MW负荷需求，按照段价从低到高新增选取的容量过程。

%% ===================== 1. 输入新增容量选取结果 =====================

% 每一行依次表示：
% 机组编号、报价段编号、段价、选取容量
selected_detail = [
    8   1   -800     7;
    7   2    120     4.9;
    1   3    124     33;
    3   3    152     18;
    6   3    159     10;
    4   3    170     9.5;
    6   4    173     20;
    7   3    180     5;
    8   3    183     20;
    5   5    188     12;
    4   4    200     10;
    5   6    215     15;
    3   5    233     30;
    2   5    245     15;
    7   4    251     15;
    1   6    252     30;
    6   6    252     15;
    8   5    253     20;
    4   5    255     10;
    7   5    260     10;
    2   6    300     6;
    4   6    302     9.5;
    8   7    303     3.9
];

%% ===================== 2. 生成表格 =====================

% 序号
Step = (1:size(selected_detail, 1))';

% 提取各列数据
Gen = selected_detail(:, 1);
Segment = selected_detail(:, 2);
Price = selected_detail(:, 3);
Selected_Capacity = selected_detail(:, 4);

% 计算累计新增容量
Cumulative_Capacity = cumsum(Selected_Capacity);

% 生成表格
selected_table = table(Step, Gen, Segment, Price, Selected_Capacity, Cumulative_Capacity, ...
    'VariableNames', {'选取顺序', '机组编号', '报价段', '段价_元每MWh', ...
    '选取容量_MW', '累计新增容量_MW'});

%% ===================== 3. 显示结果 =====================

disp('================ 负荷982.4MW时新增容量选取过程表 ================');
disp(selected_table);

% 输出新增容量总和
total_selected = sum(Selected_Capacity);
fprintf('\n新增选取容量总和为：%.1f MW\n', total_selected);

% 输出清算价
lambda = Price(end);
fprintf('最后一个被选中的报价段为：%d号机组第%d段\n', Gen(end), Segment(end));
fprintf('市场清算价为：%.1f 元/MWh\n', lambda);

%% ===================== 4. 导出为 Excel 表格 =====================

writetable(selected_table, '第三问_负荷982点4MW新增容量选取过程表.xlsx');

fprintf('\nExcel表格已保存为：第三问_负荷982点4MW新增容量选取过程表.xlsx\n');

%% ===================== 5. 生成表格图片 =====================

figure('Color', 'w', 'Position', [200 100 900 620]);

uitable('Data', table2cell(selected_table), ...
    'ColumnName', selected_table.Properties.VariableNames, ...
    'RowName', [], ...
    'Units', 'normalized', ...
    'Position', [0 0 1 1], ...
    'FontSize', 10);

drawnow;

% 保存表格图片
exportapp(gcf, '第三问_负荷982点4MW新增容量选取过程表.png');

fprintf('表格图片已保存为：第三问_负荷982点4MW新增容量选取过程表.png\n');