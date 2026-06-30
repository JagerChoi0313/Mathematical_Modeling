clc;
clear;

%% 1. 读取数据

filename = 'cumcm2011B附件2_全市六区交通网路和平台设置的数据表.xls';

nodeTable = readtable(filename, ...
    'Sheet', '全市交通路口节点数据', ...
    'VariableNamingRule', 'preserve');

edgeTable = readtable(filename, ...
    'Sheet', '全市交通路口的路线', ...
    'VariableNamingRule', 'preserve');

platformTable = readtable(filename, ...
    'Sheet', '全市交巡警平台', ...
    'VariableNamingRule', 'preserve');

%% 2. 提取节点信息

nodeID = nodeTable{:,1};
xCoord = nodeTable{:,2};
yCoord = nodeTable{:,3};
areaName = string(nodeTable{:,4});

% 判断 A 区节点
isA = areaName == "A";

A_nodeID = nodeID(isA);
A_x = xCoord(isA);
A_y = yCoord(isA);

nA = length(A_nodeID);

fprintf('A区节点数量：%d\n', nA);

%% 3. 提取 A 区现有 20 个平台

platformName = string(platformTable{:,1});
platformNode = platformTable{:,2};

isAPlatform = startsWith(platformName, "A");

A_platformName = platformName(isAPlatform);
A_platformNode = platformNode(isAPlatform);

% 保证平台顺序为 A1, A2, ..., A20
platformNum = zeros(length(A_platformName),1);

for i = 1:length(A_platformName)
    temp = erase(A_platformName(i), "A");
    platformNum(i) = str2double(temp);
end

[~, idx] = sort(platformNum);

A_platformName = A_platformName(idx);
A_platformNode = A_platformNode(idx);

nPlatform = length(A_platformNode);

fprintf('A区平台数量：%d\n', nPlatform);

%% 4. 建立节点编号到区域、坐标的映射

areaMap = containers.Map('KeyType', 'double', 'ValueType', 'char');
xMap = containers.Map('KeyType', 'double', 'ValueType', 'double');
yMap = containers.Map('KeyType', 'double', 'ValueType', 'double');

for i = 1:length(nodeID)
    areaMap(nodeID(i)) = char(areaName(i));
    xMap(nodeID(i)) = xCoord(i);
    yMap(nodeID(i)) = yCoord(i);
end

%% 5. 建立 A 区节点编号到矩阵下标的映射

nodeIndexMap = containers.Map('KeyType', 'double', 'ValueType', 'double');

for i = 1:nA
    nodeIndexMap(A_nodeID(i)) = i;
end

%% 6. 自动识别 A 区出入交通要道

edgeStart = edgeTable{:,1};
edgeEnd = edgeTable{:,2};

rawLockA = [];
rawLockOutside = [];

for e = 1:length(edgeStart)

    u = edgeStart(e);
    v = edgeEnd(e);

    if isKey(areaMap, u) && isKey(areaMap, v)

        areaU = string(areaMap(u));
        areaV = string(areaMap(v));

        % 一端在 A 区，另一端不在 A 区，则为 A 区出入道路
        if areaU == "A" && areaV ~= "A"

            rawLockA = [rawLockA; u];
            rawLockOutside = [rawLockOutside; v];

        elseif areaU ~= "A" && areaV == "A"

            rawLockA = [rawLockA; v];
            rawLockOutside = [rawLockOutside; u];

        end
    end
end

% 注意：
% rawLockA 和 rawLockOutside 统计的是跨区道路边。
% 但题目第二小问要求封锁的是"路口"，不是每一条边。
% 因此，如果同一个 A 区内部节点连接多个外部节点，只算一个封锁口。

lockA = [];
lockOutsideText = strings(0,1);

for i = 1:length(rawLockA)

    currentA = rawLockA(i);
    currentOutside = rawLockOutside(i);

    idx = find(lockA == currentA, 1);

    if isempty(idx)
        lockA = [lockA; currentA];
        lockOutsideText = [lockOutsideText; string(currentOutside)];
    else
        lockOutsideText(idx) = lockOutsideText(idx) + "," + string(currentOutside);
    end
end

nLock = length(lockA);

fprintf('按A区内部封锁节点合并后，封锁口数量：%d\n', nLock);

if nLock ~= 13
    warning('合并后的封锁口数量仍不是13，请检查区域字段或道路数据。');
end

lockTable = table((1:nLock)', lockA, lockOutsideText, ...
    'VariableNames', {'封锁口编号', 'A区内部封锁节点', '连接外部节点'});

fprintf('\n识别出的13个封锁口如下：\n');
disp(lockTable);

%% 7. 构建 A 区道路邻接矩阵

D = inf(nA, nA);

for i = 1:nA
    D(i,i) = 0;
end

for e = 1:length(edgeStart)

    u = edgeStart(e);
    v = edgeEnd(e);

    % 只使用两端都在 A 区内部的道路来构造 A 区内部交通网络
    if isKey(nodeIndexMap, u) && isKey(nodeIndexMap, v)

        iu = nodeIndexMap(u);
        iv = nodeIndexMap(v);

        % 坐标比例：1 个坐标单位对应 0.1 km
        distance_km = sqrt((A_x(iu)-A_x(iv))^2 + (A_y(iu)-A_y(iv))^2) * 0.1;

        D(iu, iv) = distance_km;
        D(iv, iu) = distance_km;
    end
end

%% 8. Floyd 算法计算 A 区内部最短路径

S = D;

for k = 1:nA
    for i = 1:nA
        for j = 1:nA
            if S(i,j) > S(i,k) + S(k,j)
                S(i,j) = S(i,k) + S(k,j);
            end
        end
    end
end

fprintf('\nA区内部最短路计算完成。\n');

%% 9. 提取平台到封锁点的时间矩阵

platformIndex = zeros(nPlatform,1);

for i = 1:nPlatform
    platformIndex(i) = nodeIndexMap(A_platformNode(i));
end

lockIndex = zeros(nLock,1);

for j = 1:nLock
    lockIndex(j) = nodeIndexMap(lockA(j));
end

% T(i,j) 表示平台 i 到封锁点 j 的最短到达时间
% 速度为 60 km/h = 1 km/min，所以距离 km 数值等于时间 min
T = S(platformIndex, lockIndex);

fprintf('\n平台到封锁点的时间矩阵：\n');
disp(array2table(T, ...
    'VariableNames', compose('封锁口%d', 1:nLock), ...
    'RowNames', cellstr(A_platformName)));

%% 10. 第一阶段整数规划：最小化最晚到达时间

% 决策变量：
% u_ij = 1 表示平台 i 派往封锁口 j
% 另有连续变量 Z 表示全封锁完成时间

nX = nPlatform * nLock;      % u_ij 的变量个数
nVar = nX + 1;               % 加上 Z
Z_index = nVar;

% 目标函数：min Z
f = zeros(nVar,1);
f(Z_index) = 1;

% 整数变量是所有 u_ij
intcon = 1:nX;

% 变量上下界
lb = zeros(nVar,1);
ub = ones(nVar,1);
ub(Z_index) = inf;

%% 10.1 每个封锁口必须由一个平台负责

Aeq = zeros(nLock, nVar);
beq = ones(nLock,1);

for j = 1:nLock
    for i = 1:nPlatform
        idx = sub2ind([nPlatform, nLock], i, j);
        Aeq(j, idx) = 1;
    end
end

%% 10.2 每个平台最多封锁一个路口

A1 = zeros(nPlatform, nVar);
b1 = ones(nPlatform,1);

for i = 1:nPlatform
    for j = 1:nLock
        idx = sub2ind([nPlatform, nLock], i, j);
        A1(i, idx) = 1;
    end
end

%% 10.3 Z 不小于任一封锁点的到达时间

A2 = zeros(nLock, nVar);
b2 = zeros(nLock,1);

for j = 1:nLock
    for i = 1:nPlatform
        idx = sub2ind([nPlatform, nLock], i, j);
        A2(j, idx) = T(i,j);
    end

    % sum_i t_ij u_ij - Z <= 0
    A2(j, Z_index) = -1;
end

A = [A1; A2];
b = [b1; b2];

%% 10.4 求解第一阶段模型

options = optimoptions('intlinprog', ...
    'Display', 'off');

[x1, fval1, exitflag1] = intlinprog(f, intcon, A, b, Aeq, beq, lb, ub, options);

if exitflag1 <= 0
    error('第一阶段整数规划未成功求解，请检查数据或是否安装 Optimization Toolbox。');
end

Z_star = fval1;

fprintf('\n第一阶段求解完成。\n');
fprintf('最短全封锁完成时间 Z* = %.4f 分钟\n', Z_star);

%% 11. 第二阶段整数规划：在 Z* 不变下最小化总出警时间

% 第二阶段只需要 u_ij 变量
f2 = T(:);

intcon2 = 1:nX;
lb2 = zeros(nX,1);
ub2 = ones(nX,1);

%% 11.1 每个封锁口必须由一个平台负责

Aeq2 = zeros(nLock, nX);
beq2 = ones(nLock,1);

for j = 1:nLock
    for i = 1:nPlatform
        idx = sub2ind([nPlatform, nLock], i, j);
        Aeq2(j, idx) = 1;
    end
end

%% 11.2 每个平台最多封锁一个路口

A21 = zeros(nPlatform, nX);
b21 = ones(nPlatform,1);

for i = 1:nPlatform
    for j = 1:nLock
        idx = sub2ind([nPlatform, nLock], i, j);
        A21(i, idx) = 1;
    end
end

%% 11.3 每个封锁口到达时间不得超过 Z*

A22 = zeros(nLock, nX);
b22 = ones(nLock,1) * (Z_star + 1e-6);

for j = 1:nLock
    for i = 1:nPlatform
        idx = sub2ind([nPlatform, nLock], i, j);
        A22(j, idx) = T(i,j);
    end
end

A_second = [A21; A22];
b_second = [b21; b22];

[x2, fval2, exitflag2] = intlinprog(f2, intcon2, A_second, b_second, Aeq2, beq2, lb2, ub2, options);

if exitflag2 <= 0
    error('第二阶段整数规划未成功求解，请检查数据。');
end

fprintf('\n第二阶段求解完成。\n');
fprintf('在最快全封锁时间下的最小总出警时间 = %.4f 分钟\n', fval2);

%% 12. 整理调度方案

U = reshape(round(x2), [nPlatform, nLock]);

assignPlatform = zeros(nLock,1);
assignPlatformName = strings(nLock,1);
assignPlatformNode = zeros(nLock,1);
assignTime = zeros(nLock,1);

for j = 1:nLock
    i = find(U(:,j) == 1);

    assignPlatform(j) = i;
    assignPlatformName(j) = A_platformName(i);
    assignPlatformNode(j) = A_platformNode(i);
    assignTime(j) = T(i,j);
end

dispatchResult = table((1:nLock)', lockA, lockOutsideText, ...
    assignPlatformName, assignPlatformNode, assignTime, ...
    'VariableNames', {'封锁口编号', 'A区内部封锁节点', '连接外部节点', ...
    '派出平台编号', '平台所在节点', '到达时间_min'});

fprintf('\n快速全封锁调度方案：\n');
disp(dispatchResult);

%% 13. 统计备用平台

usedPlatformLogical = sum(U,2) > 0;

usedPlatform = A_platformName(usedPlatformLogical);
unusedPlatform = A_platformName(~usedPlatformLogical);

fprintf('\n参与封锁的平台：\n');
disp(usedPlatform);

fprintf('\n未参与封锁的备用平台：\n');
disp(unusedPlatform);

%% 14. 输出整体指标

fullBlockTime = max(assignTime);
totalDispatchTime = sum(assignTime);

fprintf('\n整体封锁指标：\n');
fprintf('全封锁完成时间：%.4f 分钟\n', fullBlockTime);
fprintf('总出警时间：%.4f 分钟\n', totalDispatchTime);
fprintf('平均到达时间：%.4f 分钟\n', mean(assignTime));
fprintf('最早到达时间：%.4f 分钟\n', min(assignTime));
fprintf('最晚到达时间：%.4f 分钟\n', max(assignTime));

%% 15. 保存结果到 Excel

writetable(lockTable, '第一问第二小问_封锁口识别结果.xlsx', ...
    'Sheet', '封锁口');

writetable(dispatchResult, '第一问第二小问_快速封锁调度方案.xlsx', ...
    'Sheet', '调度方案');

fprintf('\n结果已保存为 Excel 文件。\n');