clc;
clear;
close all;


%%读取数据
filename='cumcm2011B附件2_全市六区交通网路和平台设置的数据表.xls';

nodeTable = readtable(filename,...
    'Sheet','全市交通路口节点数据',...
    'VariableNamingRule','preserve');

edgeTable = readtable(filename,...
    'Sheet','全市交通路口的路线',...
    'VariableNamingRule','preserve');

platformTable = readtable(filename,...
    'Sheet','全市交巡警平台',...
    'VariableNamingRule','preserve');




%% 2. 提取节点、路线、平台信息

% 节点表一般前几列为：
% 节点编号、横坐标X、纵坐标Y、所属区域、发案率
nodeID = nodeTable{:,1};
xCoord = nodeTable{:,2};
yCoord = nodeTable{:,3};

n = length(nodeID);

% 路线表一般前两列为相连节点编号
edgeStart = edgeTable{:,1};
edgeEnd   = edgeTable{:,2};

% 平台表一般包含平台编号和所在节点编号
% 若平台表第1列是平台编号，第2列是节点编号，则如下读取
% 读取平台数据
% 由于平台编号是 A1、A2、A3... 这种文本编号，
% 用 readtable 有时会读成 NaN，因此这里用 xlsread 的 raw 数据更稳妥
[~,~,platformRaw] = xlsread(filename, '全市交巡警平台');

% 去掉表头
platformRaw = platformRaw(2:end,:);

% 只保留有效行
validPlatformRows = false(size(platformRaw,1),1);

for r = 1:size(platformRaw,1)
    nodeValue = platformRaw{r,2};
    if isnumeric(nodeValue) && ~isnan(nodeValue)
        validPlatformRows(r) = true;
    elseif ischar(nodeValue) || isstring(nodeValue)
        validPlatformRows(r) = ~isnan(str2double(string(nodeValue)));
    end
end

platformRaw = platformRaw(validPlatformRows,:);

% 平台编号，如 A1、A2、B1 等
platformID = string(platformRaw(:,1));

% 平台所在节点
platformNode = zeros(size(platformRaw,1),1);

for r = 1:size(platformRaw,1)
    nodeValue = platformRaw{r,2};

    if isnumeric(nodeValue)
        platformNode(r) = nodeValue;
    else
        platformNode(r) = str2double(string(nodeValue));
    end
end

m = length(platformNode);
fprintf('全市节点数：%d\n', n);
fprintf('全市道路数：%d\n', length(edgeStart));
fprintf('全市交巡警平台数：%d\n', m);


%% 3. 建立全市交通网络邻接矩阵

% 因为题目给的是节点坐标和道路连接关系，所以道路长度按欧氏距离计算
% 如果附件中路线表已经给出了道路长度，可以改为读取路线表中的长度列

INF = 1e9;
T = INF * ones(n,n);

for i = 1:n
    T(i,i) = 0;
end

for e = 1:length(edgeStart)

    a = edgeStart(e);
    b = edgeEnd(e);

    % 找到节点编号对应的行号
    idxA = find(nodeID == a);
    idxB = find(nodeID == b);

    if isempty(idxA) || isempty(idxB)
        continue;
    end

% 计算两节点之间道路长度
dx = xCoord(idxA) - xCoord(idxB);
dy = yCoord(idxA) - yCoord(idxB);

% 附件坐标通常按"百米"为单位，除以 10 转换为 km
% 例如坐标距离 10 表示约 1 km
distance = sqrt(dx^2 + dy^2) / 10;

% 题目中警车速度为 60 km/h = 1 km/min
% 因此通行时间 min = 距离 km
travelTime = distance;

    T(idxA, idxB) = travelTime;
    T(idxB, idxA) = travelTime;
end


%% 4. Floyd 算法求全市最短路径矩阵

D = T;

% nextNode 用于恢复最短路径
nextNode = zeros(n,n);

for i = 1:n
    for j = 1:n
        if T(i,j) < INF && i ~= j
            nextNode(i,j) = j;
        end
    end
end

fprintf('正在计算 Floyd 最短路径...\n');

for k = 1:n
    for i = 1:n
        for j = 1:n
            if D(i,j) > D(i,k) + D(k,j)
                D(i,j) = D(i,k) + D(k,j);
                nextNode(i,j) = nextNode(i,k);
            end
        end
    end
end

fprintf('Floyd 最短路径计算完成。\n');


%% 5. 计算犯罪嫌疑人从 32 号节点出发的逃逸时间

caseNode = 32;

caseIndex = find(nodeID == caseNode);

if isempty(caseIndex)
    error('未找到第 32 个节点，请检查节点编号。');
end

% 犯罪嫌疑人从 32 号节点到各节点的最短时间
suspectTime = D(caseIndex, :);

% 警方接警延迟
alarmDelay = 3;

% 案发 3 分钟后犯罪嫌疑人可能到达的节点
R0_index = find(suspectTime <= alarmDelay);
R0_node = nodeID(R0_index);

fprintf('\n案发 3 分钟后，嫌疑人可能到达的节点为：\n');
disp(R0_node');


%% 6. 自动搜索可行围堵圈

% tau 表示从案发开始计算的时间
% 从 3 分钟以后开始逐层扩大逃逸区域
tauStart = 3.1;
tauEnd = max(suspectTime(suspectTime < INF));
tauStep = 0.1;

bestFound = false;

bestTau = NaN;
bestBlockIndex = [];
bestAssign = [];
bestZ = INF;
bestSafety = [];

fprintf('\n开始搜索可行围堵圈...\n');

for tau = tauStart:tauStep:tauEnd

    % 当前嫌疑人可能逃逸区域
    R_index = find(suspectTime <= tau);

    % 候选围堵点：不在 R 中，但与 R 中节点直接相连
    C_index = findBoundaryNodes(R_index, T, INF, n);

    % 若没有边界点，跳过
    if isempty(C_index)
        continue;
    end

    % 若边界点数量超过平台数量，不可行
    if length(C_index) > m
        continue;
    end

    % 计算平台到候选围堵点的时间矩阵
    q = length(C_index);
    Tp = zeros(m,q);

    for i = 1:m
        platformIdx = find(nodeID == platformNode(i));
        for j = 1:q
            Tp(i,j) = D(platformIdx, C_index(j));
        end
    end

    % 判断平台 i 是否能及时到达围堵点 j
    feasible = false(m,q);
    for i = 1:m
        for j = 1:q
            blockIdx = C_index(j);
            feasible(i,j) = (alarmDelay + Tp(i,j) <= suspectTime(blockIdx));
        end
    end

    % 如果某个围堵点没有任何平台能及时到达，则该 tau 不可行
    if any(sum(feasible,1) == 0)
        continue;
    end

     % 求平台—围堵点最优匹配
    [assign, Z, safety] = solveAssignment(Tp, feasible, suspectTime(C_index), alarmDelay);

    % 如果不可行，跳过
    if isempty(assign)
        continue;
    end

    % 找到第一个可行围堵圈后立即停止
    % 这样得到的是最早能够形成有效围堵的方案
    bestFound = true;
    bestTau = tau;
    bestBlockIndex = C_index;
    bestAssign = assign;
    bestZ = Z;
    bestSafety = safety;

    fprintf('已找到最早可行围堵圈，tau = %.2f min\n', tau);

    break;
end

%% 7. 输出结果


if ~bestFound
    error('在当前搜索范围内没有找到可行围堵方案。可适当增大 tauEnd 或检查数据。');
end

blockNode = nodeID(bestBlockIndex);
q = length(blockNode);

% 平台编号可能是文本编号，所以用 string 数组保存
resultPlatformID = strings(q,1);

resultPlatformNode = zeros(q,1);
resultBlockNode = zeros(q,1);
resultPoliceTravelTime = zeros(q,1);
resultPoliceArriveTime = zeros(q,1);
resultSuspectArriveTime = zeros(q,1);
resultSafetyMargin = zeros(q,1);

for j = 1:q
    i = bestAssign(j);

    resultPlatformID(j) = string(platformID(i));
    resultPlatformNode(j) = platformNode(i);
    resultBlockNode(j) = blockNode(j);

    platformIdx = find(nodeID == platformNode(i));
    blockIdx = bestBlockIndex(j);

    resultPoliceTravelTime(j) = D(platformIdx, blockIdx);
    resultPoliceArriveTime(j) = alarmDelay + D(platformIdx, blockIdx);
    resultSuspectArriveTime(j) = suspectTime(blockIdx);
    resultSafetyMargin(j) = resultSuspectArriveTime(j) - resultPoliceArriveTime(j);
end

resultTable = table( ...
    resultBlockNode, ...
    resultPlatformID, ...
    resultPlatformNode, ...
    resultPoliceTravelTime, ...
    resultPoliceArriveTime, ...
    resultSuspectArriveTime, ...
    resultSafetyMargin, ...
    'VariableNames', { ...
    '围堵节点', ...
    '负责平台编号', ...
    '平台所在节点', ...
    '平台行驶时间_min', ...
    '平台到达绝对时间_min', ...
    '嫌疑人最早到达时间_min', ...
    '安全裕度_min'});

fprintf('\n================ 最优围堵方案 ================\n');
fprintf('最佳围堵圈时间 tau = %.2f min\n', bestTau);
fprintf('整体围堵完成时间 Z = %.2f min\n', bestZ);
fprintf('最小安全裕度 = %.2f min\n', min(resultSafetyMargin));
disp(resultTable);

%% 8. 输出 Excel 结果

outputFile = '问题二围堵调度结果.xlsx';

writetable(resultTable, outputFile, 'Sheet', '最优围堵方案');

escapeTable = table(R0_node(:), ...
    'VariableNames', {'案发3分钟后嫌疑人可能到达节点'});
writetable(escapeTable, outputFile, 'Sheet', '3分钟逃逸范围');

fprintf('\n结果已输出到文件：%s\n', outputFile);


%% 9. 绘制全市围堵示意图

figure;
hold on;
box on;
axis equal;

title('问题二：重大刑事案件围堵调度示意图');
xlabel('X 坐标');
ylabel('Y 坐标');

% 画道路
for e = 1:length(edgeStart)
    a = edgeStart(e);
    b = edgeEnd(e);

    idxA = find(nodeID == a);
    idxB = find(nodeID == b);

    if isempty(idxA) || isempty(idxB)
        continue;
    end

    plot([xCoord(idxA), xCoord(idxB)], ...
         [yCoord(idxA), yCoord(idxB)], ...
         '-', 'Color', [0.75 0.75 0.75], 'LineWidth', 0.8);
end

% 画所有节点
scatter(xCoord, yCoord, 20, 'k', 'filled');

% 画案发点 32
scatter(xCoord(caseIndex), yCoord(caseIndex), 100, 'r', 'filled');
text(xCoord(caseIndex), yCoord(caseIndex), '  P(32)', ...
    'Color', 'r', 'FontSize', 10, 'FontWeight', 'bold');

% 画 3 分钟逃逸范围
scatter(xCoord(R0_index), yCoord(R0_index), 60, ...
    'MarkerEdgeColor', 'r', ...
    'MarkerFaceColor', 'none', ...
    'LineWidth', 1.5);

% 画围堵节点
scatter(xCoord(bestBlockIndex), yCoord(bestBlockIndex), 90, ...
    'MarkerEdgeColor', 'b', ...
    'MarkerFaceColor', 'b');

for j = 1:q
    idx = bestBlockIndex(j);
    text(xCoord(idx), yCoord(idx), ...
        ['  B', num2str(resultBlockNode(j))], ...
        'Color', 'b', 'FontSize', 9, 'FontWeight', 'bold');
end

% 画参与调度的平台
for j = 1:q
    i = bestAssign(j);
    pIdx = find(nodeID == platformNode(i));
    bIdx = bestBlockIndex(j);

    scatter(xCoord(pIdx), yCoord(pIdx), 80, ...
        'MarkerEdgeColor', 'g', ...
        'MarkerFaceColor', 'g');

    text(xCoord(pIdx), yCoord(pIdx), ...
        ['  S', char(platformID(i))], ...
        'Color', 'g', 'FontSize', 9, 'FontWeight', 'bold');

    % 画平台到围堵点的调度线
    plot([xCoord(pIdx), xCoord(bIdx)], ...
         [yCoord(pIdx), yCoord(bIdx)], ...
         '--', 'Color', [0 0.45 0], 'LineWidth', 1.2);
end

legend({'道路', '交通节点', '案发点P', '3分钟逃逸范围', '围堵节点', '调度平台'}, ...
    'Location', 'bestoutside');

saveas(gcf, '问题二围堵调度示意图.png');

fprintf('围堵示意图已保存为：问题二围堵调度示意图.png\n');


%% =========================================================
%  辅助函数 1：寻找逃逸区域外侧边界节点
%% =========================================================

function C_index = findBoundaryNodes(R_index, T, INF, n)

    inR = false(1,n);
    inR(R_index) = true;

    C = false(1,n);

    for idx = R_index
        neighbors = find(T(idx,:) < INF & T(idx,:) > 0);
        for nb = neighbors
            if ~inR(nb)
                C(nb) = true;
            end
        end
    end

    C_index = find(C);
end


%% =========================================================
%  辅助函数 2：求平台—围堵点最优匹配
%  优先使用 intlinprog；如果没有优化工具箱，则自动使用贪心法
%% =========================================================

function [assign, Z, safety] = solveAssignment(Tp, feasible, suspectArriveTime, alarmDelay)

    [m,q] = size(Tp);

    assign = [];
    Z = [];
    safety = [];

    % 判断是否有 intlinprog
    hasIntlinprog = exist('intlinprog', 'file') == 2;

    if hasIntlinprog

        % 决策变量：
        % x_ij 共 m*q 个
        % 最后一个变量为 Z
        numX = m*q;
        numVar = numX + 1;
        Zidx = numVar;

        f = zeros(numVar,1);
        f(Zidx) = 1;

        intcon = 1:numX;

        lb = zeros(numVar,1);
        ub = ones(numVar,1);
        ub(Zidx) = 1e6;

        % 不可行匹配直接令上界为 0
        for i = 1:m
            for j = 1:q
                varIdx = sub2ind([m,q], i, j);
                if ~feasible(i,j)
                    ub(varIdx) = 0;
                end
            end
        end

        Aeq = [];
        beq = [];

        % 每个围堵点必须由一个平台负责
        for j = 1:q
            row = zeros(1,numVar);
            for i = 1:m
                varIdx = sub2ind([m,q], i, j);
                row(varIdx) = 1;
            end
            Aeq = [Aeq; row];
            beq = [beq; 1];
        end

        A = [];
        b = [];

        % 每个平台最多负责一个围堵点
        for i = 1:m
            row = zeros(1,numVar);
            for j = 1:q
                varIdx = sub2ind([m,q], i, j);
                row(varIdx) = 1;
            end
            A = [A; row];
            b = [b; 1];
        end

        % 围堵有效性约束：
        % 3 + sum x_ij Tp(i,j) <= suspectArriveTime(j)
        for j = 1:q
            row = zeros(1,numVar);
            for i = 1:m
                varIdx = sub2ind([m,q], i, j);
                row(varIdx) = Tp(i,j);
            end
            A = [A; row];
            b = [b; suspectArriveTime(j) - alarmDelay];
        end

        % Z 约束：
        % 3 + sum x_ij Tp(i,j) <= Z
        % sum x_ij Tp(i,j) - Z <= -3
        for j = 1:q
            row = zeros(1,numVar);
            for i = 1:m
                varIdx = sub2ind([m,q], i, j);
                row(varIdx) = Tp(i,j);
            end
            row(Zidx) = -1;

            A = [A; row];
            b = [b; -alarmDelay];
        end

        options = optimoptions('intlinprog', ...
            'Display', 'off');

        [sol, fval, exitflag] = intlinprog(f, intcon, A, b, Aeq, beq, lb, ub, options);

        if exitflag <= 0
            assign = [];
            Z = [];
            safety = [];
            return;
        end

        X = reshape(round(sol(1:numX)), [m,q]);

        assign = zeros(q,1);
        safety = zeros(q,1);

        for j = 1:q
            i = find(X(:,j) == 1);
            if isempty(i)
                assign = [];
                Z = [];
                safety = [];
                return;
            end

            assign(j) = i;
            safety(j) = suspectArriveTime(j) - (alarmDelay + Tp(i,j));
        end

        Z = fval;

    else

        % 如果没有 intlinprog，则使用贪心匹配
        usedPlatform = false(m,1);
        assign = zeros(q,1);
        safety = zeros(q,1);

        % 优先处理可选平台少的围堵点
        feasibleCount = sum(feasible,1);
        [~, order] = sort(feasibleCount, 'ascend');

        for jj = 1:q
            j = order(jj);

            candidate = find(feasible(:,j) & ~usedPlatform);

            if isempty(candidate)
                assign = [];
                Z = [];
                safety = [];
                return;
            end

            [~, bestLocal] = min(Tp(candidate,j));
            bestPlatform = candidate(bestLocal);

            assign(j) = bestPlatform;
            usedPlatform(bestPlatform) = true;

            safety(j) = suspectArriveTime(j) - (alarmDelay + Tp(bestPlatform,j));
        end

        arriveTimes = zeros(q,1);
        for j = 1:q
            arriveTimes(j) = alarmDelay + Tp(assign(j),j);
        end

        Z = max(arriveTimes);
    end
end