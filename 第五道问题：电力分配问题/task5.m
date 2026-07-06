clc;
clear;
close all;

%% ===================== 第五问：负荷1052.8MW下的出力分配与阻塞管理 =====================

%% 1. 基本数据输入

% 第五问预测负荷
D = 1052.8;

% 当前时段各机组出力，即方案0
P_now = [120, 73, 180, 80, 125, 125, 81.1, 90];

% 各机组爬坡速率，单位 MW/min
r = [2.2, 1, 3.2, 1.3, 1.8, 2, 1.4, 1.8];

% 交易时长，15分钟
T = 15;

% 交易时长，单位小时，用于费用计算
dt = 0.25;

% 线路正常潮流限值
L_normal = [165, 150, 160, 155, 132, 162];

% 表6：相对安全裕度
safe_margin = [0.13, 0.18, 0.09, 0.11, 0.15, 0.14];

% 安全裕度后允许限值
L_safe = L_normal .* (1 + safe_margin);

% 第四问结果，用于画负荷增加前后对比图
D_Q4 = 982.4;
P_init_Q4 = [150, 79, 180, 99.5, 125, 140, 95, 113.9];

%% 2. 第一问得到的线路潮流回归系数

% B第一行为常数项
% B第2行到第9行分别对应P1到P8的系数
% B每一列对应一条线路
B = [
    110.4775  131.3521 -108.9928   77.6116  133.1334  120.8481;
      0.0826   -0.0547   -0.0694   -0.0346    0.0003    0.2376;
      0.0478    0.1275    0.0620   -0.1028    0.2428   -0.0607;
      0.0528   -0.0001   -0.1565    0.2050   -0.0647   -0.0781;
      0.1199    0.0332   -0.0099   -0.0209   -0.0412    0.0929;
     -0.0257    0.0867    0.1247   -0.0120   -0.0655    0.0466;
      0.1216   -0.1127    0.0024    0.0057    0.0700   -0.0003;
      0.1220   -0.0186   -0.0028    0.1452   -0.0039    0.1664;
     -0.0015    0.0985   -0.2012    0.0763   -0.0092    0.0004
];

%% 3. 表3：各机组段容量

q = [
    70  0  50  0   0   30  0   0   0   40;
    30  0  20  8   15  6   2   0   0   8;
    110 0  40  0   30  0   20  40  0   40;
    55  5  10  10  10  10  15  0   0   1;
    75  5  15  0   15  15  0   10  10  10;
    95  0  10  20  0   15  10  20  0   10;
    50  15 5   15  10  10  5   10  3   2;
    70  0  20  0   20  0   20  10  15  5
];

%% 4. 表4：各机组段价

price = [
    -505 0 124 168 210 252 312 330 363 489;
    -560 0 182 203 245 300 320 360 410 495;
    -610 0 152 189 233 258 308 356 415 500;
    -500 150 170 200 255 302 325 380 435 800;
    -590 0 116 146 188 215 250 310 396 510;
    -607 0 159 173 205 252 305 380 405 520;
    -500 120 180 251 260 306 315 335 348 548;
    -800 153 183 233 253 283 303 318 400 800
];

%% 5. 计算爬坡约束上下限

P_min = P_now - T .* r;
P_max = P_now + T .* r;

P_min = max(P_min, 0);
P_max = min(P_max, sum(q, 2)');

fprintf('================ 第五问初始数据检查 ================\n');
fprintf('预测负荷：%.4f MW\n', D);
fprintf('机组出力下限总和：%.4f MW\n', sum(P_min));
fprintf('机组出力上限总和：%.4f MW\n\n', sum(P_max));

if D < sum(P_min) || D > sum(P_max)
    error('预测负荷不在机组爬坡约束允许范围内，无法完成出力分配。');
end

%% 6. 负荷1052.8MW下的市场出清

[x_init, P_init, lambda, selected_detail] = market_clearing(D, P_min, P_max, q, price);

fprintf('================ 第五问市场出清结果 ================\n');
fprintf('初始出力总和：%.4f MW\n', sum(P_init));
fprintf('市场清算价：%.4f 元/MWh\n\n', lambda);

Gen = (1:8)';
Current_Output = P_now';
Lower_Limit = P_min';
Initial_Dispatch = P_init';
Upper_Limit = P_max';
Output_Change = Initial_Dispatch - Current_Output;

init_dispatch_table = table(Gen, Current_Output, Lower_Limit, Initial_Dispatch, ...
    Upper_Limit, Output_Change, ...
    'VariableNames', {'机组编号', '当前出力_MW', '出力下限_MW', ...
    '初始出力_MW', '出力上限_MW', '相对当前出力变化_MW'});

disp('负荷1052.8MW时的初始出力分配表：');
disp(init_dispatch_table);

% 报价段选取过程表
if isempty(selected_detail)
    selected_table = table();
else
    selected_table = array2table(selected_detail, ...
        'VariableNames', {'机组编号', '报价段编号', '段价_元每MWh', '选取容量_MW'});
    
    selected_table.("累计选取容量_MW") = cumsum(selected_table.("选取容量_MW"));
end

disp('负荷1052.8MW时的新增容量选取过程表：');
disp(selected_table);

%% 7. 初始方案线路潮流及阻塞判断

F_init = calc_flow(P_init, B);
abs_F_init = abs(F_init);

block_normal = abs_F_init > L_normal + 1e-6;
block_safe = abs_F_init > L_safe + 1e-6;

Line = (1:6)';
Initial_Flow = F_init';
Initial_Abs_Flow = abs_F_init';
Normal_Limit = L_normal';
Safe_Limit = L_safe';

Initial_Status = cell(6, 1);

for j = 1:6
    if abs_F_init(j) <= L_normal(j) + 1e-6
        Initial_Status{j} = '正常';
    elseif abs_F_init(j) <= L_safe(j) + 1e-6
        Initial_Status{j} = '超过正常限值但未超过安全裕度';
    else
        Initial_Status{j} = '超过安全裕度';
    end
end

init_line_table = table(Line, Initial_Flow, Initial_Abs_Flow, Normal_Limit, ...
    Safe_Limit, Initial_Status, ...
    'VariableNames', {'线路编号', '初始潮流_MW', '初始潮流绝对值_MW', ...
    '正常潮流限值_MW', '安全裕度后限值_MW', '初始状态'});

fprintf('\n================ 初始方案线路潮流及阻塞判断 ================\n');
disp(init_line_table);

%% 8. 阻塞管理优化

need_adjust = any(block_normal);

if ~need_adjust
    
    fprintf('\n初始方案未超过正常潮流限值，可以直接执行。\n');
    
    P_adjust = P_init;
    F_adjust = F_init;
    abs_F_adjust = abs_F_init;
    limit_used = L_normal;
    limit_type = '正常潮流限值';
    
    add = zeros(8, 10);
    cut = zeros(8, 10);
    C1_matrix = zeros(8, 10);
    C2_matrix = zeros(8, 10);
    C1 = 0;
    C2 = 0;
    C_total = 0;
    
else
    
    fprintf('\n初始方案超过正常潮流限值，开始尝试在正常潮流限值下进行阻塞调整。\n');
    
    [success_normal, P_adjust_normal, F_adjust_normal, add_normal, cut_normal, ...
        C1_normal, C2_normal, C_total_normal, C1_matrix_normal, C2_matrix_normal] = ...
        solve_congestion(P_init, P_min, P_max, q, price, lambda, dt, B, L_normal);
    
    if success_normal
        
        fprintf('正常潮流限值下存在可行阻塞调整方案。\n');
        
        P_adjust = P_adjust_normal;
        F_adjust = F_adjust_normal;
        add = add_normal;
        cut = cut_normal;
        C1 = C1_normal;
        C2 = C2_normal;
        C_total = C_total_normal;
        C1_matrix = C1_matrix_normal;
        C2_matrix = C2_matrix_normal;
        limit_used = L_normal;
        limit_type = '正常潮流限值';
        
    else
        
        fprintf('正常潮流限值下无可行调整方案，开始判断安全裕度限值。\n');
        
        [success_safe, P_adjust_safe, F_adjust_safe, add_safe, cut_safe, ...
            C1_safe, C2_safe, C_total_safe, C1_matrix_safe, C2_matrix_safe] = ...
            solve_congestion(P_init, P_min, P_max, q, price, lambda, dt, B, L_safe);
        
        if success_safe
            
            fprintf('安全裕度限值下存在可行方案。\n');
            
            P_adjust = P_adjust_safe;
            F_adjust = F_adjust_safe;
            add = add_safe;
            cut = cut_safe;
            C1 = C1_safe;
            C2 = C2_safe;
            C_total = C_total_safe;
            C1_matrix = C1_matrix_safe;
            C2_matrix = C2_matrix_safe;
            limit_used = L_safe;
            limit_type = '安全裕度后限值';
            
        else
            
            error('安全裕度限值下仍无可行方案，需要考虑拉闸限电。');
            
        end
    end
end

abs_F_adjust = abs(F_adjust);

%% 9. 输出调整后机组出力方案

fprintf('\n================ 第五问机组出力调整结果 ================\n');
fprintf('本次采用的线路约束类型：%s\n', limit_type);

Adjusted_Dispatch = P_adjust';
Adjust_Change = Adjusted_Dispatch - Initial_Dispatch;

adjust_table = table(Gen, Initial_Dispatch, Adjusted_Dispatch, Adjust_Change, ...
    Lower_Limit, Upper_Limit, ...
    'VariableNames', {'机组编号', '初始出力_MW', '调整后出力_MW', ...
    '出力变化_MW', '出力下限_MW', '出力上限_MW'});

disp(adjust_table);

fprintf('调整后总出力：%.4f MW\n', sum(P_adjust));

%% ===================== 9.1 安全裕度下机组出力方案表 =====================

Reach_Upper_Limit = cell(8, 1);

for i = 1:8
    if abs(P_adjust(i) - P_max(i)) <= 1e-6
        Reach_Upper_Limit{i} = '是';
    else
        Reach_Upper_Limit{i} = '否';
    end
end

Adopted_Constraint = repmat({limit_type}, 8, 1);

safe_dispatch_table = table(Gen, Current_Output, Lower_Limit, ...
    Initial_Dispatch, Adjusted_Dispatch, Adjust_Change, Upper_Limit, ...
    Reach_Upper_Limit, Adopted_Constraint, ...
    'VariableNames', {'机组编号', '当前出力_MW', '出力下限_MW', ...
    '初始出力_MW', '安全裕度下执行出力_MW', '出力变化_MW', ...
    '出力上限_MW', '是否达到上限', '采用约束类型'});

fprintf('\n================ 安全裕度下机组出力方案表 ================\n');
disp(safe_dispatch_table);

%% 10. 输出线路潮流对比表

fprintf('\n================ 第五问线路潮流对比结果 ================\n');

Status_Before = cell(6, 1);
Status_After_Normal = cell(6, 1);
Status_After_Used = cell(6, 1);

for j = 1:6
    
    if abs_F_init(j) <= L_normal(j) + 1e-6
        Status_Before{j} = '正常';
    elseif abs_F_init(j) <= L_safe(j) + 1e-6
        Status_Before{j} = '超过正常限值';
    else
        Status_Before{j} = '超过安全裕度';
    end
    
    if abs_F_adjust(j) <= L_normal(j) + 1e-6
        Status_After_Normal{j} = '满足正常限值';
    else
        Status_After_Normal{j} = '超过正常限值';
    end
    
    if abs_F_adjust(j) <= limit_used(j) + 1e-6
        Status_After_Used{j} = '满足采用限值';
    else
        Status_After_Used{j} = '超过采用限值';
    end
    
end

line_compare_table = table(Line, F_init', abs_F_init', F_adjust', abs_F_adjust', ...
    L_normal', L_safe', limit_used', Status_Before, Status_After_Normal, Status_After_Used, ...
    'VariableNames', {'线路编号', '调整前潮流_MW', '调整前绝对值_MW', ...
    '调整后潮流_MW', '调整后绝对值_MW', '正常潮流限值_MW', ...
    '安全裕度后限值_MW', '本次采用限值_MW', ...
    '调整前状态', '调整后正常限值状态', '调整后采用限值状态'});

disp(line_compare_table);

%% 11. 输出阻塞费用结果

fprintf('\n================ 第五问阻塞费用计算结果 ================\n');

Cut_MW = sum(cut, 2);
Add_MW = sum(add, 2);
C1_Gen = sum(C1_matrix, 2);
C2_Gen = sum(C2_matrix, 2);
C_Gen = C1_Gen + C2_Gen;

cost_table = table(Gen, Cut_MW, Add_MW, C1_Gen, C2_Gen, C_Gen, ...
    'VariableNames', {'机组编号', '削减容量_MW', '增加容量_MW', ...
    '序内容量补偿费用_元', '序外容量补偿费用_元', '合计费用_元'});

disp(cost_table);

fprintf('\n序内容量不能出力补偿费用 C1 = %.4f 元\n', C1);
fprintf('序外容量出力补偿费用 C2 = %.4f 元\n', C2);
fprintf('总阻塞费用 C = C1 + C2 = %.4f 元\n', C_total);

%% 12. 第四问与第五问初始线路潮流对比

F_Q4 = calc_flow(P_init_Q4, B);
abs_F_Q4 = abs(F_Q4);

q4_q5_line_table = table(Line, abs_F_Q4', abs_F_init', L_normal', L_safe', ...
    'VariableNames', {'线路编号', '第四问初始潮流绝对值_MW', ...
    '第五问初始潮流绝对值_MW', '正常潮流限值_MW', '安全裕度后限值_MW'});

fprintf('\n================ 第四问与第五问初始线路潮流对比 ================\n');
disp(q4_q5_line_table);

%% 13. 导出Excel表格

writetable(init_dispatch_table, '第五问_负荷1052.8MW初始出力分配表.xlsx');
writetable(selected_table, '第五问_新增容量选取过程表.xlsx');
writetable(init_line_table, '第五问_初始方案线路潮流及阻塞判断表.xlsx');
writetable(adjust_table, '第五问_阻塞调整前后机组出力对比表.xlsx');
writetable(line_compare_table, '第五问_阻塞调整前后线路潮流对比表.xlsx');
writetable(cost_table, '第五问_阻塞费用构成表.xlsx');
writetable(q4_q5_line_table, '第四问与第五问初始线路潮流对比表.xlsx');
writetable(safe_dispatch_table, '第五问_安全裕度下机组出力方案表.xlsx');
fprintf('\nExcel表格已导出到当前MATLAB文件夹。\n');

%% ===================== 14. 绘制第五问论文图片 =====================

% 关闭已有图窗，避免看错旧图
close all;

fontName = 'Microsoft YaHei';

% 低饱和度论文配色
color_blue   = [0.55 0.67 0.82];
color_orange = [0.86 0.63 0.47];
color_gray   = [0.72 0.72 0.72];
color_green  = [0.58 0.72 0.62];
color_red    = [0.78 0.48 0.45];

%% 图5-7：负荷1052.8MW时各机组初始出力及上下限图

figure('Color', 'w');

b = bar([P_min(:), P_init(:), P_max(:)], 'grouped');

b(1).FaceColor = color_gray;
b(1).EdgeColor = [0.35 0.35 0.35];
b(1).LineWidth = 0.8;

b(2).FaceColor = color_blue;
b(2).EdgeColor = [0.35 0.35 0.35];
b(2).LineWidth = 0.8;

b(3).FaceColor = color_orange;
b(3).EdgeColor = [0.35 0.35 0.35];
b(3).LineWidth = 0.8;

xlabel('机组编号', 'FontName', fontName);
ylabel('出力 / MW', 'FontName', fontName);
title('负荷1052.8MW时各机组初始出力及上下限图', 'FontName', fontName);

legend({'出力下限', '初始出力', '出力上限'}, ...
    'Location', 'best', ...
    'FontName', fontName, ...
    'Box', 'on');

set(gca, 'FontName', fontName, 'LineWidth', 1);
grid on;
box on;

ax = gca;
try
    ax.Toolbar.Visible = 'off';
catch
end

exportgraphics(gcf, '图5-7_负荷1052.8MW时各机组初始出力及上下限图.png', 'Resolution', 300);


%% 图5-8：初始方案线路潮流及限值对比图

figure('Color', 'w', 'Position', [100, 100, 1000, 600]);

x = 1:6;

% 柱状图：初始潮流绝对值
b = bar(x, abs_F_init(:), 0.45);
hold on;

b.FaceColor = [0.86 0.63 0.47];   % 柔和橙
b.EdgeColor = [0.35 0.35 0.35];
b.LineWidth = 0.8;

% 折线：正常潮流限值
p1 = plot(x, L_normal, '-o', ...
    'Color', [0.35 0.35 0.35], ...
    'LineWidth', 1.8, ...
    'MarkerSize', 6, ...
    'MarkerFaceColor', [0.72 0.72 0.72]);

% 折线：安全裕度后限值
p2 = plot(x, L_safe, '-s', ...
    'Color', [0.35 0.55 0.40], ...
    'LineWidth', 1.8, ...
    'MarkerSize', 6, ...
    'MarkerFaceColor', [0.58 0.72 0.62]);

xlabel('线路编号', 'FontName', fontName);
ylabel('潮流绝对值 / MW', 'FontName', fontName);
title('初始方案线路潮流及限值对比图', 'FontName', fontName);

legend({'初始潮流绝对值', '正常潮流限值', '安全裕度后限值'}, ...
    'Location', 'northoutside', ...
    'Orientation', 'horizontal', ...
    'FontName', fontName, ...
    'Box', 'on');

set(gca, 'FontName', fontName, 'LineWidth', 1);
grid on;
box on;

xlim([0.5, 6.5]);
ylim([0, max(L_safe) + 15]);

ax = gca;
try
    ax.Toolbar.Visible = 'off';
catch
end

exportgraphics(gcf, '图5-8_初始方案线路潮流及限值对比图.png', 'Resolution', 300);


%% 图5-9：阻塞调整前后各机组出力对比图

figure('Color', 'w');

b = bar([P_init(:), P_adjust(:)], 'grouped');

b(1).FaceColor = color_blue;
b(1).EdgeColor = [0.35 0.35 0.35];
b(1).LineWidth = 0.8;

b(2).FaceColor = color_orange;
b(2).EdgeColor = [0.35 0.35 0.35];
b(2).LineWidth = 0.8;

xlabel('机组编号', 'FontName', fontName);
ylabel('出力 / MW', 'FontName', fontName);
title('阻塞调整前后各机组出力对比图', 'FontName', fontName);

legend({'初始出力', '调整后出力'}, ...
    'Location', 'best', ...
    'FontName', fontName, ...
    'Box', 'on');

set(gca, 'FontName', fontName, 'LineWidth', 1);
grid on;
box on;

ax = gca;
try
    ax.Toolbar.Visible = 'off';
catch
end

exportgraphics(gcf, '图5-9_阻塞调整前后各机组出力对比图.png', 'Resolution', 300);


%% 图5-10：阻塞调整前后线路潮流对比图

figure('Color', 'w', 'Position', [100, 100, 1000, 600]);

x = 1:6;

% 只用柱状图表示调整前后潮流
b = bar(x, [abs_F_init(:), abs_F_adjust(:)], 'grouped');
hold on;

b(1).FaceColor = color_blue;
b(1).EdgeColor = [0.35 0.35 0.35];
b(1).LineWidth = 0.8;

b(2).FaceColor = color_orange;
b(2).EdgeColor = [0.35 0.35 0.35];
b(2).LineWidth = 0.8;

% 用折线表示正常潮流限值和安全裕度后限值
p1 = plot(x, L_normal, '-o', ...
    'Color', [0.35 0.35 0.35], ...
    'LineWidth', 1.8, ...
    'MarkerSize', 6, ...
    'MarkerFaceColor', [0.72 0.72 0.72]);

p2 = plot(x, L_safe, '-s', ...
    'Color', [0.35 0.55 0.40], ...
    'LineWidth', 1.8, ...
    'MarkerSize', 6, ...
    'MarkerFaceColor', color_green);

xlabel('线路编号', 'FontName', fontName);
ylabel('潮流绝对值 / MW', 'FontName', fontName);
title('阻塞调整前后线路潮流对比图', 'FontName', fontName);

legend({'调整前潮流绝对值', '调整后潮流绝对值', ...
    '正常潮流限值', '安全裕度后限值'}, ...
    'Location', 'northoutside', ...
    'Orientation', 'horizontal', ...
    'FontName', fontName, ...
    'Box', 'on');

set(gca, 'FontName', fontName, 'LineWidth', 1);
grid on;
box on;

xlim([0.5, 6.5]);
ylim([0, max(L_safe) + 15]);

ax = gca;
try
    ax.Toolbar.Visible = 'off';
catch
end

exportgraphics(gcf, '图5-10_阻塞调整前后线路潮流对比图.png', 'Resolution', 300);
%% ===================== 函数1：市场出清 =====================

function [x_plan, P_plan, lambda, selected_detail] = market_clearing(D, P_min, P_max, q, price)

    x_low = split_to_segments(P_min, q);
    x_up = split_to_segments(P_max, q);

    available = x_up - x_low;
    available(available < 1e-9) = 0;

    x_plan = x_low;
    remain = D - sum(P_min);

    selected_detail = [];

    if remain < -1e-6
        error('负荷小于机组出力下限总和，市场出清失败。');
    end

    if remain <= 1e-6
        P_plan = sum(x_plan, 2)';
        lambda = min(price(:));
        return;
    end

    candidate = [];

    for i = 1:8
        for m = 1:10
            if available(i, m) > 1e-9
                candidate = [candidate; price(i, m), i, m, available(i, m)];
            end
        end
    end

    candidate = sortrows(candidate, 1);

    lambda = NaN;

    for k = 1:size(candidate, 1)

        if remain <= 1e-8
            break;
        end

        p = candidate(k, 1);
        i = candidate(k, 2);
        m = candidate(k, 3);
        cap = candidate(k, 4);

        take = min(cap, remain);

        x_plan(i, m) = x_plan(i, m) + take;
        remain = remain - take;

        lambda = p;

        selected_detail = [selected_detail; i, m, p, take];

    end

    if remain > 1e-6
        error('可用容量不足，市场出清失败。');
    end

    P_plan = sum(x_plan, 2)';

end

%% ===================== 函数2：阻塞管理优化 =====================

function [success, P_adjust, F_adjust, add, cut, C1, C2, C_total, C1_matrix, C2_matrix] = ...
    solve_congestion(P_init, P_min, P_max, q, price, lambda, dt, B, L_limit)

    x_init = split_to_segments(P_init, q);
    x_low  = split_to_segments(P_min, q);
    x_up   = split_to_segments(P_max, q);

    add_max = x_up - x_init;
    cut_max = x_init - x_low;

    add_max(add_max < 1e-9) = 0;
    cut_max(cut_max < 1e-9) = 0;

    unit_add_cost = dt .* max(price - lambda, 0);
    unit_cut_cost = dt .* max(lambda - price, 0);

    f = [unit_add_cost(:); unit_cut_cost(:)];

    lb = zeros(160, 1);
    ub = [add_max(:); cut_max(:)];

    Aeq = [ones(1, 80), -ones(1, 80)];
    beq = 0;

    F_init = calc_flow(P_init, B);

    Aineq = [];
    bineq = [];

    coef = B(2:end, :);
    nSeg = 10;

    for j = 1:6

        row_add = repmat(coef(:, j)', 1, nSeg);
        row_cut = -row_add;

        row = [row_add, row_cut];

        Aineq = [Aineq; row];
        bineq = [bineq; L_limit(j) - F_init(j)];

        Aineq = [Aineq; -row];
        bineq = [bineq; L_limit(j) + F_init(j)];

    end

    options = optimoptions('linprog', 'Display', 'off');

    [y_opt, ~, exitflag] = linprog(f, Aineq, bineq, Aeq, beq, lb, ub, options);

    if exitflag <= 0

        success = false;
        P_adjust = [];
        F_adjust = [];
        add = [];
        cut = [];
        C1 = [];
        C2 = [];
        C_total = [];
        C1_matrix = [];
        C2_matrix = [];
        return;

    end

    success = true;

    y_opt(abs(y_opt) < 1e-7) = 0;

    add = reshape(y_opt(1:80), 8, 10);
    cut = reshape(y_opt(81:160), 8, 10);

    P_adjust = P_init + sum(add, 2)' - sum(cut, 2)';
    F_adjust = calc_flow(P_adjust, B);

    C2_matrix = unit_add_cost .* add;
    C1_matrix = unit_cut_cost .* cut;

    C1 = sum(C1_matrix(:));
    C2 = sum(C2_matrix(:));
    C_total = C1 + C2;

end

%% ===================== 函数3：计算线路潮流 =====================

function F = calc_flow(P, B)
    F = B(1, :) + P * B(2:end, :);
end

%% ===================== 函数4：将机组总出力分解到报价段 =====================

function x = split_to_segments(P, q)

    [nGen, nSeg] = size(q);
    x = zeros(nGen, nSeg);

    for i = 1:nGen

        remain = P(i);

        for m = 1:nSeg

            if remain <= 1e-8
                break;
            end

            take = min(q(i, m), remain);
            x(i, m) = take;
            remain = remain - take;

        end

        if remain > 1e-6
            error('某台机组出力超过了该机组总段容量。');
        end

    end

end

%% ===================== 函数5：去除坐标区工具栏 =====================

function remove_toolbar()
    ax = gca;
    try
        ax.Toolbar.Visible = 'off';
    catch
    end
end