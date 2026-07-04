clc;
clear;
close all;

%% ===================== 第三问：市场出清计算 =====================

% 预测负荷需求
D = 982.4;

% 一个交易时段为15分钟
T = 15;

% 当前时段各机组出力，即题目中方案0对应的机组出力
P_now = [120, 73, 180, 80, 125, 125, 81.1, 90];

% 各机组爬坡速率，单位为 MW/min
r = [2.2, 1, 3.2, 1.3, 1.8, 2, 1.4, 1.8];

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

%% ===================== 1. 计算爬坡约束下的出力上下限 =====================

% 每台机组下一时段的出力下限和上限
P_min = P_now - T .* r;
P_max = P_now + T .* r;

% 机组出力不能小于0
P_min = max(P_min, 0);

% 机组出力不能超过自身总段容量
P_cap = sum(q, 2)';
P_max = min(P_max, P_cap);

% 判断负荷是否在可行范围内
if D < sum(P_min)
    error('预测负荷小于所有机组出力下限之和，无法满足爬坡约束。');
end

if D > sum(P_max)
    error('预测负荷大于所有机组出力上限之和，无法满足爬坡约束。');
end

%% ===================== 2. 将出力上下限分解到报价段 =====================

% x_min 表示各机组在出力下限时，各报价段的容量分布
x_min = split_to_segments(P_min, q);

% x_max 表示各机组在出力上限时，各报价段的容量分布
x_max = split_to_segments(P_max, q);

% 在爬坡约束允许范围内，各报价段还可以增加的容量
available = x_max - x_min;

%% ===================== 3. 按照段价从低到高进行市场出清 =====================

% 先取各机组出力下限
x_plan = x_min;

% 还需要补足的负荷
remain_load = D - sum(P_min);

% 构造可选报价段列表
% 每一行依次表示：段价、机组编号、报价段编号、可增加容量
candidate = [];

for i = 1:8
    for m = 1:10
        if available(i, m) > 1e-8
            candidate = [candidate; price(i, m), i, m, available(i, m)];
        end
    end
end

% 按照段价从低到高排序
candidate = sortrows(candidate, 1);

% 记录被选中的报价段
selected_detail = [];

% 清算价
lambda = NaN;

for k = 1:size(candidate, 1)
    
    if remain_load <= 1e-8
        break;
    end
    
    seg_price = candidate(k, 1);
    i = candidate(k, 2);
    m = candidate(k, 3);
    cap = candidate(k, 4);
    
    % 本报价段实际选取容量
    take = min(cap, remain_load);
    
    % 更新该机组该报价段的出力
    x_plan(i, m) = x_plan(i, m) + take;
    
    % 更新剩余负荷
    remain_load = remain_load - take;
    
    % 最后一个被选中的报价段价格就是清算价
    lambda = seg_price;
    
    % 记录选中信息
    selected_detail = [selected_detail; i, m, seg_price, take];
end

%% ===================== 4. 得到各机组初始出力分配预案 =====================

P_plan = sum(x_plan, 2)';

% 再次检查总出力
total_output = sum(P_plan);

if abs(total_output - D) > 1e-6
    error('总出力与预测负荷不相等，请检查程序。');
end

%% ===================== 5. 输出结果 =====================

disp('================ 第三问计算结果 ================');

fprintf('预测负荷需求为：%.1f MW\n', D);
fprintf('市场清算价为：%.1f 元/MWh\n', lambda);
fprintf('初始出力总和为：%.1f MW\n\n', total_output);

Gen = (1:8)';
Current_Output = P_now';
Lower_Limit = P_min';
Upper_Limit = P_max';
Initial_Dispatch = P_plan';
Change_Output = P_plan' - P_now';

result_table = table(Gen, Current_Output, Lower_Limit, Upper_Limit, ...
    Initial_Dispatch, Change_Output);

disp('各机组初始出力分配预案：');
disp(result_table);

disp('被选中的报价段信息：');
selected_table = array2table(selected_detail, ...
    'VariableNames', {'Gen', 'Segment', 'Price', 'Selected_Capacity'});
disp(selected_table);

%% ===================== 6. 绘制初始出力分配图 =====================

figure;
bar(P_plan);
xlabel('机组编号');
ylabel('出力 / MW');
title('负荷982.4MW时各机组初始出力分配预案');
grid on;

%% ===================== 函数：将机组总出力分解到各报价段 =====================

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
            error('第 %d 台机组的出力超过了其段容量总和。', i);
        end
        
    end

end