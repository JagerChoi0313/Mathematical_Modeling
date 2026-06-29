% ==========================================
% 第一步：准备"原材料"（输入数据）
% ==========================================
% 卸点名称及需求量 (万吨换算为吨)
dump_names = ["矿石漏", "倒装场Ⅰ", "岩场", "岩石漏", "倒装场Ⅱ"];
D = [12000, 13000, 13000, 19000, 13000];

% 给卸点分类（注意：MATLAB 索引从 1 开始）
ore_dumps = [1, 2, 5];  % 接收矿石的卸点 (矿石漏, 倒装场Ⅰ, 倒装场Ⅱ)
rock_dumps = [3, 4];    % 接收岩石的卸点 (岩场, 岩石漏)

% 铲位储量 (万吨换算为吨)
Q_ore = [9500, 10500, 10000, 10500, 11000, 12500, 10500, 13000, 13500, 12500]'; % 转为列向量
Q_rock = [12500, 11000, 13500, 10500, 11500, 13500, 10500, 11500, 13500, 12500]';

% 铲位矿石铁含量
P = [0.30, 0.28, 0.29, 0.32, 0.31, 0.33, 0.32, 0.31, 0.33, 0.31]';

% 距离矩阵 (10个铲位 x 5个卸点)
dist = [
    5.26, 1.90, 5.89, 0.64, 4.42;
    5.19, 0.99, 5.61, 1.76, 3.86;
    4.21, 1.90, 5.61, 1.27, 3.72;
    4.00, 1.13, 4.56, 1.83, 3.16;
    2.95, 1.27, 3.51, 2.74, 2.25;
    2.74, 2.25, 3.65, 2.60, 2.81;
    2.46, 1.48, 2.46, 4.21, 0.78;
    1.90, 2.04, 2.46, 3.72, 1.62;
    0.64, 3.09, 1.06, 5.05, 1.27;
    1.27, 3.51, 0.57, 6.10, 0.50
];

c = 154;  % 卡车载重(吨)

% 降维操作：计算 1 辆卡车在各路线 1 个班次内的最大趟数
% MATLAB 的矩阵点乘优势：不需要写 for 循环，直接一行公式搞定所有路线
time_cycle = 8 + (30 / 7) * dist;
k = floor(480 ./ time_cycle); 

% ==========================================
% 第二步：建立数学模型
% ==========================================
% 创建优化问题对象（目标为最小化）
prob = optimproblem('ObjectiveSense', 'minimize');

% 1. 设置决策变量
% x 是 10x5 的整数变量矩阵，下限为0
x = optimvar('x', 10, 5, 'Type', 'integer', 'LowerBound', 0);
% y 是 10x1 的整数变量向量，取值 0 或 1 (代表是否放置电铲)
y = optimvar('y', 10, 1, 'Type', 'integer', 'LowerBound', 0, 'UpperBound', 1);

% 2. 设定目标函数：总运量最小 + 微小惩罚项(打破平局，追求卡车最少)
prob.Objective = sum(sum(c * k .* x .* dist)) + 0.1 * sum(sum(x));

% 3. 施加硬性约束条件
% [约束 1] 设备上限
prob.Constraints.shovel_limit = sum(y) <= 7;
prob.Constraints.truck_limit = sum(sum(x)) <= 20;

% [约束 2] 逻辑绑定：没有电铲的铲位，不能派卡车去 (sum(x, 2) 代表对 x 按行求和)
prob.Constraints.bind = sum(x, 2) <= 20 * y;

% [约束 3] 卡车不等待极限
prob.Constraints.load_limit = sum(k .* x, 2) <= 96 * y;      % 按行求和：装车次数
prob.Constraints.unload_limit = sum(k .* x, 1) <= 160;     % 按列求和：卸车次数

% [约束 4] 供需平衡：运到各卸点的总量必须达标
prob.Constraints.demand = sum(c * k .* x, 1) >= D;

% [约束 5] 储量保护 (注意 MATLAB 切片写法 x(:, ore_dumps))
prob.Constraints.ore_res = sum(c * k(:, ore_dumps) .* x(:, ore_dumps), 2) <= Q_ore;
prob.Constraints.rock_res = sum(c * k(:, rock_dumps) .* x(:, rock_dumps), 2) <= Q_rock;

% [约束 6] 矿石品位限制 (品位必须在 28.5% ~ 30.5% 之间)
prob.Constraints.grade_lower = optimconstr(1, 3);
prob.Constraints.grade_upper = optimconstr(1, 3);
for idx = 1:length(ore_dumps)
    j = ore_dumps(idx);
    % 对第 j 列路线计算混合品位
    prob.Constraints.grade_lower(idx) = sum((P - 0.285) .* k(:, j) .* x(:, j)) >= 0;
    prob.Constraints.grade_upper(idx) = sum((0.305 - P) .* k(:, j) .* x(:, j)) >= 0;
end

% ==========================================
% 第三步：求解引擎与结果输出
% ==========================================
% 抑制求解过程的大段文字输出
options = optimoptions('intlinprog', 'Display', 'off'); 
[sol, fval, exitflag] = solve(prob, 'Options', options);

% 打印结果
if exitflag > 0
    total_trucks = sum(sum(sol.x));
    total_shovels = sum(sol.y);
    total_ton_km = fval - 0.1 * total_trucks;
    
    fprintf('-----------------------------------\n');
    fprintf('最优策略 -> 出动电铲: %d 台 | 卡车: %d 辆\n', round(total_shovels), round(total_trucks));
    fprintf('实现最小总运量: %.2f 吨公里\n', total_ton_km);
    fprintf('-----------------------------------\n');
    fprintf('【详细卡车路线分配】\n');
    
    for i = 1:10
        for j = 1:5
            if sol.x(i, j) > 0.5 % 浮点数容差判断
                fprintf('  铲位 %d  --->  %s : 安排 %d 辆车\n', i, dump_names(j), round(sol.x(i, j)));
            end
        end
    end
else
    disp('未找到可行解，请检查约束条件！');
end