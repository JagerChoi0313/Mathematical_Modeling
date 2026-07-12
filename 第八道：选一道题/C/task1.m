%% airport_taxi_general_symbolic_visuals.m
% 机场出租车司机选择问题——一般符号模型可视化
%
% 本程序不代入任何具体机场数据，也不设置题目之外的业务参数。
% 所生成图像均为"结构图"或"归一化决策图"，用于展示模型逻辑，
% 不能解释为某一机场的实际数值结果。
%
% 运行要求：
% 1. MATLAB R2019a 及以上版本；
% 2. 安装 Symbolic Math Toolbox。
%
% 输出内容：
% 1. 一般模型公式汇总表；
% 2. 决策规则汇总表；
% 3. 参数影响方向汇总表；
% 4. 模型求解流程图；
% 5. 归一化等待时间决策图；
% 6. 归一化排队车辆数决策图；
% 7. 参数影响关系图。

clear;
clc;
close all;

%% 1. 创建输出文件夹

outputFolder = 'airport_taxi_general_symbolic_output';

if ~exist(outputFolder, 'dir')
    mkdir(outputFolder);
end

%% 2. 定义一般符号变量

syms F_A D_A T_A T_L C_A c_d positive
syms F_C D_0 D_C T_0 T_s T_C C_B positive
syms T_w n_0 mu positive

% 两种方案的单次预期净利润
Pi_A = simplify(F_A - c_d * D_A - C_A);
Pi_B = simplify(F_C - c_d * (D_0 + D_C) - C_B);

% 两种方案的单位时间预期净收益
r_A = simplify(Pi_A / (T_w + T_L + T_A));
r_B = simplify(Pi_B / (T_0 + T_s + T_C));

% 临界等待时间
T_w_star = simplify(Pi_A / r_B - T_L - T_A);

% 服务率近似恒定时的临界排队车辆数
N_star_constant = simplify(mu * T_w_star - 1);

% 一般时变服务率
syms z t0 real
syms m(t)
G_general = int(m(t0 + z), z, 0, T_w_star);
N_star_general = simplify(G_general - 1);

%% 3. 生成公式汇总表

modelPart = [
    "机场排队方案单次净利润"
    "返回市区方案单次净利润"
    "机场排队方案单位时间净收益"
    "返回市区方案单位时间净收益"
    "临界等待时间"
    "一般时变服务率下的临界车辆数"
    "恒定服务率近似下的临界车辆数"
];

symbolName = [
    "Pi_A"
    "Pi_B"
    "r_A"
    "r_B"
    "T_w_star"
    "N_star(t0)"
    "N_star"
];

expressionText = [
    string(char(Pi_A))
    string(char(Pi_B))
    string(char(r_A))
    string(char(r_B))
    string(char(T_w_star))
    string(char(N_star_general))
    string(char(N_star_constant))
];

economicMeaning = [
    "机场订单收入扣除里程成本和固定成本后的净收益"
    "市区订单收入扣除空驶、载客里程成本和固定成本后的净收益"
    "司机选择机场排队后，单位运营时间能够获得的预期净收益"
    "司机空载返回市区后，单位运营时间能够获得的预期净收益"
    "使两种方案单位时间净收益相等时的最长允许等待时间"
    "临界等待时间内预计可完成载客的车辆数减一"
    "服务率在短时间内近似恒定时的临界车辆数"
];

formulaTable = table( ...
    modelPart, symbolName, expressionText, economicMeaning, ...
    'VariableNames', { ...
    'ModelPart', 'Symbol', 'Expression', 'Meaning'});

%% 4. 生成决策规则汇总表

conditionText = [
    "T_w < T_w_star"
    "T_w = T_w_star"
    "T_w > T_w_star"
    "n_0 < N_star(t0)"
    "n_0 = N_star(t0)"
    "n_0 > N_star(t0)"
];

decisionText = [
    "进入蓄车池排队"
    "两种方案单位时间收益相同"
    "空载返回市区"
    "进入蓄车池排队"
    "处于临界决策状态"
    "空载返回市区"
];

explanationText = [
    "预计等待时间未超过司机可接受上限"
    "机场排队与返回市区的收益相等"
    "机场等待时间过长"
    "现场排队车辆数未超过动态临界值"
    "两种选择处于分界位置"
    "现场排队车辆数超过动态临界值"
];

decisionTable = table( ...
    conditionText, decisionText, explanationText, ...
    'VariableNames', {'Condition', 'Decision', 'Explanation'});

%% 5. 生成参数影响方向汇总表

parameterText = [
    "机场订单单次净利润 Pi_A"
    "返回市区单位时间收益 r_B"
    "机场订单非排队时间 T_L+T_A"
    "机场服务率 mu"
    "现场排队车辆数 n_0"
    "预计等待时间 T_w"
];

targetText = [
    "临界等待时间"
    "临界等待时间"
    "临界等待时间"
    "临界排队车辆数"
    "机场排队方案吸引力"
    "机场排队方案单位时间收益"
];

directionText = [
    "正向"
    "负向"
    "负向"
    "正向"
    "负向"
    "负向"
];

reasonText = [
    "机场订单利润提高后，司机可以接受更长的等待时间"
    "市区收益提高后，司机更倾向于返回市区"
    "非排队时间增加会压缩可接受的排队时间"
    "服务率提高后，同一时间内能够消化更多车辆"
    "前方车辆越多，司机等待时间通常越长"
    "等待时间越长，机场方案单位时间收益越低"
];

sensitivityTable = table( ...
    parameterText, targetText, directionText, reasonText, ...
    'VariableNames', {'Parameter', 'AffectedResult', 'Direction', 'Reason'});

%% 6. 保存表格

workbookFile = fullfile(outputFolder, ...
    'general_symbolic_model_tables.xlsx');

writetable(formulaTable, workbookFile, 'Sheet', '公式汇总');
writetable(decisionTable, workbookFile, 'Sheet', '决策规则');
writetable(sensitivityTable, workbookFile, 'Sheet', '参数影响方向');

fprintf('\n一般模型公式汇总表：\n');
disp(formulaTable);

fprintf('\n决策规则汇总表：\n');
disp(decisionTable);

fprintf('\n参数影响方向汇总表：\n');
disp(sensitivityTable);

%% 7. 图1：一般模型求解流程图
% 该图只展示求解结构，不包含任何数值参数。

fig1 = figure( ...
    'Color', 'w', ...
    'ToolBar', 'none', ...
    'MenuBar', 'none', ...
    'Position', [100, 100, 1200, 520]);

annotation(fig1, 'textbox', [0.03, 0.36, 0.14, 0.25], ...
    'String', {'输入一般变量', ...
    '机场收益参数', ...
    '市区收益参数', ...
    '现场排队状态'}, ...
    'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'middle', ...
    'FontSize', 12, ...
    'LineWidth', 1.2);

annotation(fig1, 'textbox', [0.22, 0.36, 0.14, 0.25], ...
    'String', {'建立两种方案', ...
    '单次预期净利润', ...
    'Pi_A 与 Pi_B'}, ...
    'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'middle', ...
    'FontSize', 12, ...
    'LineWidth', 1.2);

annotation(fig1, 'textbox', [0.41, 0.36, 0.14, 0.25], ...
    'String', {'建立两种方案', ...
    '单位时间净收益', ...
    'r_A 与 r_B'}, ...
    'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'middle', ...
    'FontSize', 12, ...
    'LineWidth', 1.2);

annotation(fig1, 'textbox', [0.60, 0.36, 0.14, 0.25], ...
    'String', {'令两种收益相等', ...
    '求临界等待时间', ...
    'T_w^*'}, ...
    'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'middle', ...
    'FontSize', 12, ...
    'LineWidth', 1.2);

annotation(fig1, 'textbox', [0.79, 0.36, 0.17, 0.25], ...
    'String', {'比较当前状态', ...
    '与临界阈值', ...
    '输出司机策略'}, ...
    'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'middle', ...
    'FontSize', 12, ...
    'LineWidth', 1.2);

annotation(fig1, 'arrow', [0.17, 0.22], [0.485, 0.485], ...
    'LineWidth', 1.3);
annotation(fig1, 'arrow', [0.36, 0.41], [0.485, 0.485], ...
    'LineWidth', 1.3);
annotation(fig1, 'arrow', [0.55, 0.60], [0.485, 0.485], ...
    'LineWidth', 1.3);
annotation(fig1, 'arrow', [0.74, 0.79], [0.485, 0.485], ...
    'LineWidth', 1.3);

annotation(fig1, 'textbox', [0.25, 0.78, 0.50, 0.10], ...
    'String', '机场出租车司机一般决策模型求解流程', ...
    'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'middle', ...
    'FontSize', 16, ...
    'FontWeight', 'bold', ...
    'LineStyle', 'none');

saveFigureNoToolbar(fig1, ...
    fullfile(outputFolder, 'figure1_general_model_flowchart.png'));

%% 8. 图2：归一化等待时间决策图
%
% 横轴为 T_w / T_w_star。
% 纵轴为归一化决策得分：
% S_T = 1 - T_w / T_w_star。
%
% S_T > 0：进入蓄车池；
% S_T = 0：临界状态；
% S_T < 0：空载返回市区。
%
% 横轴中的 1 表示临界点，不是人为设置的业务参数。

xTime = linspace(0, 2, 400);
scoreTime = 1 - xTime;

fig2 = figure( ...
    'Color', 'w', ...
    'ToolBar', 'none', ...
    'MenuBar', 'none');

plot(xTime, scoreTime, 'LineWidth', 1.8, ...
    'DisplayName', '归一化决策得分');
hold on;
yline(0, '--', '临界收益线', ...
    'LineWidth', 1.2, ...
    'DisplayName', '临界收益线');
xline(1, '--', 'T_w = T_w^*', ...
    'LineWidth', 1.2, ...
    'DisplayName', '临界等待时间');

text(0.35, 0.35, '进入蓄车池排队', ...
    'FontSize', 12, ...
    'HorizontalAlignment', 'center');
text(1.55, -0.55, '空载返回市区', ...
    'FontSize', 12, ...
    'HorizontalAlignment', 'center');

xlabel('归一化等待时间  T_w / T_w^*');
ylabel('决策得分  1 - T_w / T_w^*');
title('基于临界等待时间的一般决策区域');
xlim([0, 2]);
grid on;
legend('Location', 'best');

saveFigureNoToolbar(fig2, ...
    fullfile(outputFolder, ...
    'figure2_normalized_waiting_time_decision.png'));

%% 9. 图3：归一化排队车辆数决策图
%
% 横轴为 n_0 / N_star(t0)。
% 纵轴为归一化决策得分：
% S_N = 1 - n_0 / N_star(t0)。

xQueue = linspace(0, 2, 400);
scoreQueue = 1 - xQueue;

fig3 = figure( ...
    'Color', 'w', ...
    'ToolBar', 'none', ...
    'MenuBar', 'none');

plot(xQueue, scoreQueue, 'LineWidth', 1.8, ...
    'DisplayName', '归一化决策得分');
hold on;
yline(0, '--', '临界收益线', ...
    'LineWidth', 1.2, ...
    'DisplayName', '临界收益线');
xline(1, '--', 'n_0 = N^*(t_0)', ...
    'LineWidth', 1.2, ...
    'DisplayName', '临界排队车辆数');

text(0.35, 0.35, '进入蓄车池排队', ...
    'FontSize', 12, ...
    'HorizontalAlignment', 'center');
text(1.55, -0.55, '空载返回市区', ...
    'FontSize', 12, ...
    'HorizontalAlignment', 'center');

xlabel('归一化排队车辆数  n_0 / N^*(t_0)');
ylabel('决策得分  1 - n_0 / N^*(t_0)');
title('基于临界排队车辆数的一般决策区域');
xlim([0, 2]);
grid on;
legend('Location', 'best');

saveFigureNoToolbar(fig3, ...
    fullfile(outputFolder, ...
    'figure3_normalized_queue_decision.png'));

%% 10. 图4：参数影响方向关系图
% 该图只表示影响方向，不表示影响大小。

fig4 = figure( ...
    'Color', 'w', ...
    'ToolBar', 'none', ...
    'MenuBar', 'none', ...
    'Position', [100, 100, 1100, 650]);

annotation(fig4, 'textbox', [0.38, 0.40, 0.24, 0.20], ...
    'String', {'动态决策阈值', ...
    '临界等待时间', ...
    '临界排队车辆数'}, ...
    'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'middle', ...
    'FontSize', 14, ...
    'FontWeight', 'bold', ...
    'LineWidth', 1.4);

annotation(fig4, 'textbox', [0.05, 0.68, 0.22, 0.12], ...
    'String', {'机场订单净利润提高', '正向影响'}, ...
    'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'middle', ...
    'FontSize', 11);

annotation(fig4, 'textbox', [0.05, 0.43, 0.22, 0.12], ...
    'String', {'市区单位时间收益提高', '负向影响'}, ...
    'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'middle', ...
    'FontSize', 11);

annotation(fig4, 'textbox', [0.05, 0.18, 0.22, 0.12], ...
    'String', {'机场非排队时间增加', '负向影响'}, ...
    'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'middle', ...
    'FontSize', 11);

annotation(fig4, 'textbox', [0.73, 0.68, 0.22, 0.12], ...
    'String', {'机场服务率提高', '临界车辆数增加'}, ...
    'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'middle', ...
    'FontSize', 11);

annotation(fig4, 'textbox', [0.73, 0.43, 0.22, 0.12], ...
    'String', {'现场排队车辆数增加', '机场方案吸引力下降'}, ...
    'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'middle', ...
    'FontSize', 11);

annotation(fig4, 'textbox', [0.73, 0.18, 0.22, 0.12], ...
    'String', {'预计等待时间增加', '机场单位时间收益下降'}, ...
    'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'middle', ...
    'FontSize', 11);

annotation(fig4, 'arrow', [0.27, 0.38], [0.74, 0.55], ...
    'LineWidth', 1.3);
annotation(fig4, 'arrow', [0.27, 0.38], [0.49, 0.50], ...
    'LineWidth', 1.3);
annotation(fig4, 'arrow', [0.27, 0.38], [0.24, 0.45], ...
    'LineWidth', 1.3);

annotation(fig4, 'arrow', [0.73, 0.62], [0.74, 0.55], ...
    'LineWidth', 1.3);
annotation(fig4, 'arrow', [0.73, 0.62], [0.49, 0.50], ...
    'LineWidth', 1.3);
annotation(fig4, 'arrow', [0.73, 0.62], [0.24, 0.45], ...
    'LineWidth', 1.3);

annotation(fig4, 'textbox', [0.30, 0.88, 0.40, 0.07], ...
    'String', '一般模型参数影响方向', ...
    'HorizontalAlignment', 'center', ...
    'FontSize', 16, ...
    'FontWeight', 'bold', ...
    'LineStyle', 'none');

saveFigureNoToolbar(fig4, ...
    fullfile(outputFolder, ...
    'figure4_parameter_influence_diagram.png'));

%% 11. 输出完成提示

fprintf('\n============================================================\n');
fprintf('一般符号模型图像与表格生成完成。\n');
fprintf('输出文件夹：%s\n', outputFolder);
fprintf('生成内容：\n');
fprintf('1. general_symbolic_model_tables.xlsx\n');
fprintf('2. figure1_general_model_flowchart.png\n');
fprintf('3. figure2_normalized_waiting_time_decision.png\n');
fprintf('4. figure3_normalized_queue_decision.png\n');
fprintf('5. figure4_parameter_influence_diagram.png\n');
fprintf('============================================================\n');

%% ======================== 局部函数 ========================

function saveFigureNoToolbar(figHandle, filePath)
% 隐藏坐标轴工具栏，并以 300 dpi 保存图片。

    axesList = findall(figHandle, 'Type', 'axes');

    for i = 1:numel(axesList)
        try
            axesList(i).Toolbar.Visible = 'off';
        catch
        end
    end

    drawnow;

    if exist('exportgraphics', 'file') == 2
        exportgraphics(figHandle, filePath, 'Resolution', 300);
    else
        print(figHandle, filePath, '-dpng', '-r300');
    end
end
