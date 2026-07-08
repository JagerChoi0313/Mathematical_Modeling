%% generate_Q2_tables.m
% 第二问论文用表格生成代码
% 表1：三轮发射安排
% 表2：各阶段误差变化
% 同时保存为 Excel 和 PNG 图片

clear; clc; close all;

%% ==================== 1. 创建输出文件夹 ====================

outFolder = 'Q2_tables';
if ~exist(outFolder, 'dir')
    mkdir(outFolder);
end

excelFile = fullfile(outFolder, 'Q2_tables.xlsx');

%% ==================== 2. 表1：三轮发射安排 ====================

table1 = {
    '调整轮次', '发射无人机', '接收并调整无人机', '作用';
    '第1轮', ...
    'FY01、FY11、FY15', ...
    'FY02、FY03、FY04、FY05、FY06、FY07、FY08、FY09、FY10、FY12、FY13、FY14', ...
    '利用外轮廓三角骨架完成主要定位调整';
    '第2轮', ...
    'FY02、FY06、FY14', ...
    'FY01、FY03、FY04、FY05、FY07、FY08、FY09、FY10、FY11、FY12、FY13、FY15', ...
    '更换参考点，对队形进行复核调整';
    '第3轮', ...
    'FY03、FY07、FY13', ...
    'FY01、FY02、FY04、FY05、FY06、FY08、FY09、FY10、FY11、FY12、FY14、FY15', ...
    '进一步检验队形稳定性';
};

%% ==================== 3. 表2：各阶段误差变化 ====================

table2 = {
    '阶段', '最大位置误差 / m', '平均位置误差 / m', '最大相邻距离误差 / m', '最大共线误差 / m';
    '初始状态', '7.874000', '3.992000', '10.131000', '8.285100';
    '第1轮后', '8.3939×10^{-11}', '4.2363×10^{-11}', '1.0648×10^{-10}', '1.1186×10^{-10}';
    '第2轮后', '3.2115×10^{-8}', '2.1730×10^{-9}', '3.1784×10^{-8}', '2.9904×10^{-8}';
    '第3轮后', '5.6822×10^{-11}', '2.9346×10^{-11}', '8.9315×10^{-11}', '8.6210×10^{-11}';
};

%% ==================== 4. 保存为 Excel ====================

writecell(table1, excelFile, 'Sheet', '表1_三轮发射安排');
writecell(table2, excelFile, 'Sheet', '表2_误差变化');

fprintf('Excel 表格已保存至：%s\n', excelFile);

%% ==================== 5. 保存为 PNG 图片 ====================

saveTableAsImage( ...
    table1, ...
    fullfile(outFolder, '表1_三轮发射安排.png'), ...
    '表1  三轮发射安排', ...
    [1500, 430], ...
    {120, 240, 760, 340});

saveTableAsImage( ...
    table2, ...
    fullfile(outFolder, '表2_误差变化表.png'), ...
    '表2  各阶段误差变化', ...
    [1300, 520], ...
    {160, 250, 250, 280, 250});

fprintf('PNG 表格图片已保存至文件夹：%s\n', outFolder);

%% ==================== 6. 命令行显示 ====================

disp('========== 表1：三轮发射安排 ==========');
disp(table1);

disp('========== 表2：各阶段误差变化 ==========');
disp(table2);

%% ========================================================================
% 局部函数：将 cell 表格保存为图片
% ========================================================================

function saveTableAsImage(cellData, fileName, tableTitle, figSize, colWidth)

    fig = figure( ...
        'Color', 'w', ...
        'Position', [100, 100, figSize(1), figSize(2)], ...
        'MenuBar', 'none', ...
        'ToolBar', 'none');

    % 标题
    annotation(fig, 'textbox', [0, 0.90, 1, 0.08], ...
        'String', tableTitle, ...
        'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'middle', ...
        'FontSize', 18, ...
        'FontWeight', 'bold', ...
        'EdgeColor', 'none');

    % 表头和数据
    colNames = cellData(1, :);
    data = cellData(2:end, :);

    % 创建表格
    uit = uitable(fig, ...
        'Data', data, ...
        'ColumnName', colNames, ...
        'RowName', [], ...
        'Units', 'normalized', ...
        'Position', [0.03, 0.06, 0.94, 0.80], ...
        'FontSize', 13, ...
        'ColumnWidth', colWidth);

    % 尽量让表格显示完整
    drawnow;

    % 保存图片
    try
        exportgraphics(fig, fileName, 'Resolution', 300);
    catch
        print(fig, fileName, '-dpng', '-r300');
    end

    close(fig);
end