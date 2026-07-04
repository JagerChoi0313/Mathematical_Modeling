clc;
clear;

%% 第二问：阻塞费用计算模块
% 说明：
% 本代码用于计算输电阻塞调整后的阻塞费用。
% 需要输入：
% 1. 初始交易结果下各机组各报价段的出力容量 x0
% 2. 阻塞调整后各机组各报价段的实际出力容量 x
% 3. 清算价 lambda
%
% 阻塞费用 = 序内容量不能出力补偿 + 序外容量出力补偿

%% 1. 输入表3：各机组段容量，单位 MW
q = [
70  0   50  0   0   30  0   0   0   40;
30  0   20  8   15  6   2   0   0   8;
110 0   40  0   30  0   20  40  0   40;
55  5   10  10  10  10  15  0   0   1;
75  5   15  0   15  15  0   10  10  10;
95  0   10  20  0   15  10  20  0   10;
50  15  5   15  10  10  5   10  3   2;
70  0   20  0   20  0   20  10  15  5
];

%% 2. 输入表4：各机组段价，单位 元/MWh
price = [
-505 0   124 168 210 252 312 330 363 489;
-560 0   182 203 245 300 320 360 410 495;
-610 0   152 189 233 258 308 356 415 500;
-500 150 170 200 255 302 325 380 435 800;
-590 0   116 146 188 215 250 310 396 510;
-607 0   159 173 205 252 305 380 405 520;
-500 120 180 251 260 306 315 335 348 548;
-800 153 183 233 253 283 303 318 400 800
];

%% 3. 设置交易时长
% 题目中一个交易时段为15分钟，即0.25小时
dt = 0.25;

%% 4. 输入清算价和测试出力方案
% 注意：
% 这里不是最终答案，只是为了验证第二问阻塞费用计算公式是否能正常工作。
% 真正计算第四问、第五问时，需要把 lambda、P_init、P_adjust
% 替换成第三问和第四问求出的真实结果。

lambda = 300;     % 假设清算价为300元/MWh

% 初始交易结果下8台机组的总出力
P_init = [120 73 180 80 125 125 81.1 90];

% 假设由于阻塞调整：
% 1号机组减少15MW，4号机组增加15MW
% 总出力保持不变
P_adjust = [105 73 180 95 125 125 81.1 90];

%% 5. 将机组总出力分解到各报价段
% 如果后面已经直接求出了每个报价段的 x0 和 x，
% 可以跳过这一步，直接输入 x0 和 x。

x0 = decompose_power_to_segments(q, P_init);
x = decompose_power_to_segments(q, P_adjust);

%% 6. 计算阻塞费用
[C, detail] = calc_congestion_cost(q, price, lambda, x0, x, dt);

%% 7. 输出结果
fprintf('\n================ 第二问阻塞费用计算结果 ================\n\n');

fprintf('清算价 lambda = %.4f 元/MWh\n', lambda);
fprintf('交易时长 dt = %.4f 小时\n\n', dt);

fprintf('序内容量不能出力补偿 C1 = %.4f 元\n', detail.C1);
fprintf('序外容量出力补偿 C2 = %.4f 元\n', detail.C2);
fprintf('总阻塞费用 C = %.4f 元\n\n', C);

fprintf('各机组阻塞费用明细：\n');
disp(detail.gen_table);

fprintf('各机组各报价段削减容量 cut_MW：\n');
disp(detail.cut_MW);

fprintf('各机组各报价段增加容量 add_MW：\n');
disp(detail.add_MW);

%% ======================== 本脚本用到的函数 ========================

function x = decompose_power_to_segments(q, P)
% 将每台机组总出力 P 分解到各报价段
% q 为 8×10 段容量矩阵
% P 为 1×8 机组总出力向量
% x 为 8×10 各报价段实际出力容量矩阵

    [nGen, nSeg] = size(q);
    x = zeros(nGen, nSeg);

    for i = 1:nGen
        remain = P(i);

        for m = 1:nSeg
            if remain <= 1e-8
                break;
            end

            x(i,m) = min(q(i,m), remain);
            remain = remain - x(i,m);
        end

        if remain > 1e-6
            error('第 %d 台机组的总出力超过了其最大可用段容量。', i);
        end
    end
end


function [C, detail] = calc_congestion_cost(q, price, lambda, x0, x, dt)
% 计算阻塞费用
%
% 输入：
% q      : 段容量矩阵，8×10
% price  : 段价矩阵，8×10
% lambda : 清算价
% x0     : 初始交易结果下各段出力，8×10
% x      : 阻塞调整后各段出力，8×10
% dt     : 交易时长，单位小时
%
% 输出：
% C      : 总阻塞费用
% detail : 费用明细结构体

    if nargin < 6
        dt = 0.25;
    end

    if ~isequal(size(q), size(price), size(x0), size(x))
        error('q、price、x0、x 的矩阵维度必须一致。');
    end

    if any(x0(:) < -1e-8) || any(x(:) < -1e-8)
        error('出力容量不能为负。');
    end

    if any(x0(:) - q(:) > 1e-8) || any(x(:) - q(:) > 1e-8)
        error('某些报价段出力超过了该段容量。');
    end

    % 序内容量不能出力的部分
    cut_MW = max(x0 - x, 0);

    % 序外容量出力的部分
    add_MW = max(x - x0, 0);

    % 序内容量不能出力的单位补偿
    unit_cut_cost = max(lambda - price, 0);

    % 序外容量出力的单位补偿
    unit_add_cost = max(price - lambda, 0);

    % 两类补偿费用矩阵
    C1_matrix = dt .* unit_cut_cost .* cut_MW;
    C2_matrix = dt .* unit_add_cost .* add_MW;

    % 汇总费用
    C1 = sum(C1_matrix(:));
    C2 = sum(C2_matrix(:));
    C = C1 + C2;

    % 按机组汇总
    C1_by_gen = sum(C1_matrix, 2);
    C2_by_gen = sum(C2_matrix, 2);
    C_by_gen = C1_by_gen + C2_by_gen;

    cut_by_gen = sum(cut_MW, 2);
    add_by_gen = sum(add_MW, 2);

    gen_id = (1:size(q,1))';

    gen_table = table(gen_id, cut_by_gen, add_by_gen, C1_by_gen, C2_by_gen, C_by_gen, ...
        'VariableNames', {'Gen', 'Cut_MW', 'Add_MW', 'C1_Yuan', 'C2_Yuan', 'Total_Yuan'});

    % 输出明细
    detail.C1 = C1;
    detail.C2 = C2;
    detail.C = C;

    detail.cut_MW = cut_MW;
    detail.add_MW = add_MW;

    detail.unit_cut_cost = unit_cut_cost;
    detail.unit_add_cost = unit_add_cost;

    detail.C1_matrix = C1_matrix;
    detail.C2_matrix = C2_matrix;

    detail.gen_table = gen_table;
end