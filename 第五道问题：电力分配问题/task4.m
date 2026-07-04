clc;
clear;
close all;

%% ===================== 第四问：阻塞管理优化 =====================

% 负荷需求
D = 982.4;

% 第三问得到的初始出力分配预案
P_init = [150, 79, 180, 99.5, 125, 140, 95, 113.9];

% 第三问得到的市场清算价
lambda = 303;

% 交易时长，15分钟 = 0.25小时
dt = 0.25;

% 当前时段各机组出力，即方案0
P_now = [120, 73, 180, 80, 125, 125, 81.1, 90];

% 各机组爬坡速率，单位 MW/min
r = [2.2, 1, 3.2, 1.3, 1.8, 2, 1.4, 1.8];

% 表6：线路潮流限值
L = [165, 150, 160, 155, 132, 162];

%% ===================== 1. 第一问回归系数 =====================

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

%% ===================== 2. 段容量和段价 =====================

% 表3：各机组段容量
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

% 表4：各机组段价
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

%% ===================== 3. 计算爬坡约束上下限 =====================

T = 15;

P_min = P_now - T .* r;
P_max = P_now + T .* r;

% 机组出力不能小于0
P_min = max(P_min, 0);

% 机组出力不能超过该机组总段容量
P_max = min(P_max, sum(q, 2)');

fprintf('================ 第四问初始数据检查 ================\n');
fprintf('第三问初始出力总和：%.4f MW\n', sum(P_init));
fprintf('机组出力下限总和：%.4f MW\n', sum(P_min));
fprintf('机组出力上限总和：%.4f MW\n\n', sum(P_max));

%% ===================== 4. 初始方案线路潮流计算 =====================

F_init = calc_flow(P_init, B);
abs_F_init = abs(F_init);

block_flag = abs_F_init > L + 1e-6;

Line = (1:6)';
Initial_Flow = F_init';
Initial_Abs_Flow = abs_F_init';
Line_Limit = L';

Block_Status = cell(6, 1);

for j = 1:6
    if block_flag(j)
        Block_Status{j} = '阻塞';
    else
        Block_Status{j} = '正常';
    end
end

init_line_table = table(Line, Initial_Flow, Initial_Abs_Flow, Line_Limit, Block_Status, ...
    'VariableNames', {'线路编号', '初始潮流_MW', '初始潮流绝对值_MW', ...
    '潮流限值_MW', '阻塞状态'});

disp('第三问初始方案下的线路潮流及阻塞判断：');
disp(init_line_table);

if ~any(block_flag)
    fprintf('\n初始方案不发生输电阻塞，阻塞费用为0。\n');
    return;
else
    fprintf('\n初始方案发生输电阻塞，需要进行阻塞调整。\n\n');
end

%% ===================== 5. 建立阻塞管理线性规划模型 =====================

% 将初始出力、出力下限、出力上限分解到各报价段
x_init = split_to_segments(P_init, q);
x_low  = split_to_segments(P_min, q);
x_up   = split_to_segments(P_max, q);

% 相对初始方案，各报价段最多可以增加或削减的容量
add_max = x_up - x_init;
cut_max = x_init - x_low;

add_max(add_max < 1e-9) = 0;
cut_max(cut_max < 1e-9) = 0;

% 增加容量和削减容量对应的单位补偿费用
unit_add_cost = dt .* max(price - lambda, 0);
unit_cut_cost = dt .* max(lambda - price, 0);

% 决策变量 y = [add(:); cut(:)]
% add 表示各报价段相对初始方案增加的容量
% cut 表示各报价段相对初始方案削减的容量
f = [unit_add_cost(:); unit_cut_cost(:)];

% 变量上下界
lb = zeros(160, 1);
ub = [add_max(:); cut_max(:)];

% 负荷平衡约束
% 因为初始方案已经满足982.4MW，所以总增加量 = 总削减量
Aeq = [ones(1, 80), -ones(1, 80)];
beq = 0;

% 线路安全约束
Aineq = [];
bineq = [];

coef = B(2:end, :);
nSeg = 10;

for j = 1:6
    
    % add(:)的顺序为按列展开，即第1段的8台机组、第2段的8台机组……
    row_add = repmat(coef(:, j)', 1, nSeg);
    row_cut = -row_add;
    
    row = [row_add, row_cut];
    
    % 调整后 F_j <= L_j
    Aineq = [Aineq; row];
    bineq = [bineq; L(j) - F_init(j)];
    
    % 调整后 -F_j <= L_j
    Aineq = [Aineq; -row];
    bineq = [bineq; L(j) + F_init(j)];
    
end

%% ===================== 6. 求解线性规划 =====================

options = optimoptions('linprog', 'Display', 'off');

[y_opt, fval, exitflag] = linprog(f, Aineq, bineq, Aeq, beq, lb, ub, options);

if exitflag <= 0
    error('线性规划求解失败，请检查 Optimization Toolbox 或约束条件。');
end

% 清理极小数值误差
y_opt(abs(y_opt) < 1e-7) = 0;

add = reshape(y_opt(1:80), 8, 10);
cut = reshape(y_opt(81:160), 8, 10);

% 调整后的机组出力
P_adjust = P_init + sum(add, 2)' - sum(cut, 2)';

% 调整后的线路潮流
F_adjust = calc_flow(P_adjust, B);
abs_F_adjust = abs(F_adjust);

%% ===================== 7. 计算阻塞费用 =====================

C2_matrix = unit_add_cost .* add;
C1_matrix = unit_cut_cost .* cut;

C1 = sum(C1_matrix(:));
C2 = sum(C2_matrix(:));
C_total = C1 + C2;

%% ===================== 8. 输出机组出力调整结果 =====================

fprintf('\n================ 阻塞调整后机组出力方案 ================\n');

Gen = (1:8)';
Initial_Dispatch = P_init';
Adjusted_Dispatch = P_adjust';
Output_Change = Adjusted_Dispatch - Initial_Dispatch;
Lower_Limit = P_min';
Upper_Limit = P_max';

gen_table = table(Gen, Initial_Dispatch, Adjusted_Dispatch, Output_Change, ...
    Lower_Limit, Upper_Limit, ...
    'VariableNames', {'机组编号', '初始出力_MW', '调整后出力_MW', ...
    '出力变化_MW', '出力下限_MW', '出力上限_MW'});

disp(gen_table);

fprintf('调整后总出力：%.4f MW\n', sum(P_adjust));

%% ===================== 9. 输出线路潮流调整结果 =====================

fprintf('\n================ 阻塞调整前后线路潮流对比 ================\n');

Status_Before = cell(6, 1);
Status_After = cell(6, 1);

for j = 1:6
    
    if abs_F_init(j) > L(j) + 1e-6
        Status_Before{j} = '阻塞';
    else
        Status_Before{j} = '正常';
    end
    
    if abs_F_adjust(j) <= L(j) + 1e-6
        Status_After{j} = '满足';
    else
        Status_After{j} = '超限';
    end
    
end

line_table = table(Line, F_init', abs_F_init', F_adjust', abs_F_adjust', L', ...
    Status_Before, Status_After, ...
    'VariableNames', {'线路编号', '调整前潮流_MW', '调整前绝对值_MW', ...
    '调整后潮流_MW', '调整后绝对值_MW', '潮流限值_MW', ...
    '调整前状态', '调整后状态'});

disp(line_table);

%% ===================== 10. 输出阻塞费用计算结果 =====================

fprintf('\n================ 阻塞费用计算结果 ================\n');

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

%% ===================== 11. 导出Excel表格 =====================

writetable(init_line_table, '第四问_初始方案线路潮流及阻塞判断表.xlsx');
writetable(gen_table, '第四问_阻塞调整前后机组出力对比表.xlsx');
writetable(line_table, '第四问_阻塞调整前后线路潮流对比表.xlsx');
writetable(cost_table, '第四问_阻塞费用构成表.xlsx');

fprintf('\nExcel表格已导出到当前MATLAB文件夹。\n');

%% ===================== 12. 绘制低饱和度中文论文图片 =====================

fontName = 'Microsoft YaHei';

%% 图1：阻塞调整前后各机组出力对比图

figure('Color', 'w');

b1 = bar([P_init(:), P_adjust(:)], 'grouped');
hold on;

% 低饱和度配色
b1(1).FaceColor = [0.55 0.67 0.82];   % 柔和蓝
b1(1).EdgeColor = [0.35 0.35 0.35];
b1(1).LineWidth = 0.8;

b1(2).FaceColor = [0.86 0.63 0.47];   % 柔和橙
b1(2).EdgeColor = [0.35 0.35 0.35];
b1(2).LineWidth = 0.8;

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

exportgraphics(gcf, '第四问_阻塞调整前后各机组出力对比图.png', 'Resolution', 300);


%% 图2：阻塞调整前后线路潮流对比图

figure('Color', 'w');

b2 = bar([abs_F_init(:), abs_F_adjust(:), L(:)], 'grouped');
hold on;

% 低饱和度配色
b2(1).FaceColor = [0.55 0.67 0.82];   % 柔和蓝
b2(1).EdgeColor = [0.35 0.35 0.35];
b2(1).LineWidth = 0.8;

b2(2).FaceColor = [0.86 0.63 0.47];   % 柔和橙
b2(2).EdgeColor = [0.35 0.35 0.35];
b2(2).LineWidth = 0.8;

b2(3).FaceColor = [0.72 0.72 0.72];   % 柔和灰
b2(3).EdgeColor = [0.35 0.35 0.35];
b2(3).LineWidth = 0.8;

xlabel('线路编号', 'FontName', fontName);
ylabel('潮流绝对值 / MW', 'FontName', fontName);
title('阻塞调整前后线路潮流对比图', 'FontName', fontName);

legend({'调整前潮流绝对值', '调整后潮流绝对值', '潮流限值'}, ...
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

exportgraphics(gcf, '第四问_阻塞调整前后线路潮流对比图.png', 'Resolution', 300);

fprintf('低饱和度中文图片已保存。\n');

%% ===================== 函数1：计算线路潮流 =====================

function F = calc_flow(P, B)
    F = B(1, :) + P * B(2:end, :);
end

%% ===================== 函数2：将机组总出力分解到报价段 =====================

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