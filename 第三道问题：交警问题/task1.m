clc;
clear;

%% 1. 读取数据

filename = 'cumcm2011B附件2_全市六区交通网路和平台设置的数据表.xls';

% 读取节点数据、路线数据、平台数据
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

% 节点表前五列分别是：
% 节点编号、横坐标X、纵坐标Y、所属区域、发案率
nodeID = nodeTable{:,1};
xCoord = nodeTable{:,2};
yCoord = nodeTable{:,3};
areaName = string(nodeTable{:,4});
caseRate = nodeTable{:,5};

% 只提取 A 区节点
isA = areaName == "A";

A_nodeID = nodeID(isA);
A_x = xCoord(isA);
A_y = yCoord(isA);
A_caseRate = caseRate(isA);

nA = length(A_nodeID);

fprintf('A区节点数量：%d\n', nA);

%% 3. 提取 A 区现有 20 个交巡警平台

platformName = string(platformTable{:,1});
platformNode = platformTable{:,2};

% 提取编号以 A 开头的平台，即 A1 到 A20
isAPlatform = startsWith(platformName, "A");

A_platformName = platformName(isAPlatform);
A_platformNode = platformNode(isAPlatform);

% 为了保证顺序是 A1, A2, ..., A20
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

%% 4. 建立 A 区节点编号到矩阵下标的映射

% 为了在矩阵中计算，需要把真实节点编号映射为 1 到 nA 的下标
nodeIndexMap = containers.Map('KeyType', 'double', 'ValueType', 'double');

for i = 1:nA
    nodeIndexMap(A_nodeID(i)) = i;
end

%% 5. 构建 A 区道路邻接矩阵

% 初始化距离矩阵
D = inf(nA, nA);

for i = 1:nA
    D(i,i) = 0;
end

% 读取道路起点和终点
edgeStart = edgeTable{:,1};
edgeEnd = edgeTable{:,2};

for e = 1:length(edgeStart)

    u = edgeStart(e);
    v = edgeEnd(e);

    % 只保留两端节点都在 A 区的道路
    if isKey(nodeIndexMap, u) && isKey(nodeIndexMap, v)

        iu = nodeIndexMap(u);
        iv = nodeIndexMap(v);

        % 题目说明坐标单位为毫米，比例为 1:100000
        % 即 1 mm 对应实际 100 m = 0.1 km
        distance_km = sqrt((A_x(iu)-A_x(iv))^2 + (A_y(iu)-A_y(iv))^2) * 0.1;

        D(iu, iv) = distance_km;
        D(iv, iu) = distance_km;
    end
end

%% 6. Floyd 算法计算任意两节点最短路

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

fprintf('最短路计算完成。\n');

%% 7. 提取 20 个平台到 A 区所有节点的最短距离

platformIndex = zeros(nPlatform,1);

for i = 1:nPlatform
    platformIndex(i) = nodeIndexMap(A_platformNode(i));
end

% platformDist(i,j) 表示平台 i 到节点 j 的最短道路距离
platformDist = S(platformIndex, :);

%% 8. 按最近平台原则分配管辖范围

% 每个节点分配给距离它最近的平台
[minDist, nearestPlatform] = min(platformDist, [], 1);

% 判断是否能在 3 分钟内到达
% 警车速度 60 km/h = 1 km/min，所以 3 分钟对应 3 km
isCovered = minDist <= 3;

coverageRate = sum(isCovered) / nA * 100;

fprintf('3分钟覆盖节点数：%d\n', sum(isCovered));
fprintf('A区总节点数：%d\n', nA);
fprintf('3分钟覆盖率：%.2f%%\n', coverageRate);

%% 9. 找出超过 3 分钟的节点

overtimeNode = A_nodeID(~isCovered);
overtimeDist = minDist(~isCovered)';

fprintf('\n超过3分钟的节点如下：\n');
disp(table(overtimeNode, overtimeDist, ...
    'VariableNames', {'超时节点编号', '最近平台距离_km'}));

%% 10. 统计每个平台的管辖范围和工作量

platformResult = table();

for i = 1:nPlatform

    % 找出由第 i 个平台管辖的节点
    servedLogical = nearestPlatform == i;

    servedNodes = A_nodeID(servedLogical);
    servedDist = minDist(servedLogical);
    servedRate = A_caseRate(servedLogical);

    nodeCount = length(servedNodes);

    if nodeCount > 0
        maxDistance = max(servedDist);
        avgDistance = mean(servedDist);
        totalCaseRate = sum(servedRate);
        overtimeCount = sum(servedDist > 3);
    else
        maxDistance = 0;
        avgDistance = 0;
        totalCaseRate = 0;
        overtimeCount = 0;
    end

    platformResult = [platformResult;
        table(A_platformName(i), A_platformNode(i), nodeCount, ...
        maxDistance, avgDistance, overtimeCount, totalCaseRate, ...
        'VariableNames', {'平台编号', '平台节点', '管辖节点数', ...
        '最大出警距离_km', '平均出警距离_km', '超3km节点数', '管辖区域总发案率'})];

end

fprintf('\n各平台管辖结果：\n');
disp(platformResult);

%% 11. 输出每个节点的归属平台

nodeAssignResult = table();

for j = 1:nA

    p = nearestPlatform(j);

    nodeAssignResult = [nodeAssignResult;
        table(A_nodeID(j), A_x(j), A_y(j), A_caseRate(j), ...
        A_platformName(p), A_platformNode(p), minDist(j), isCovered(j), ...
        'VariableNames', {'节点编号', '横坐标X', '纵坐标Y', '发案率', ...
        '所属平台编号', '所属平台节点', '到平台距离_km', '是否3分钟覆盖'})];

end

fprintf('\n节点分配结果前10行：\n');
disp(nodeAssignResult(1:10,:));

%% 12. 计算整体评价指标

avgDistanceAll = mean(minDist);
maxDistanceAll = max(minDist);
overtimeCountAll = sum(~isCovered);

fprintf('\n整体评价指标：\n');
fprintf('平均出警距离：%.4f km\n', avgDistanceAll);
fprintf('最大出警距离：%.4f km\n', maxDistanceAll);
fprintf('超3km节点数：%d\n', overtimeCountAll);
fprintf('3分钟覆盖率：%.2f%%\n', coverageRate);

%% 13. 工作量均衡指标

workload = platformResult{:, '管辖节点数'};
avgWorkload = mean(workload);
workloadVariance = mean((workload - avgWorkload).^2);
workloadMax = max(workload);
workloadMin = min(workload);

fprintf('\n工作量均衡指标：\n');
fprintf('平均管辖节点数：%.2f\n', avgWorkload);
fprintf('最大管辖节点数：%d\n', workloadMax);
fprintf('最小管辖节点数：%d\n', workloadMin);
fprintf('管辖节点数方差：%.4f\n', workloadVariance);

%% 14. 保存结果到 Excel

writetable(platformResult, '第一问第一小问_平台管辖结果.xlsx', ...
    'Sheet', '平台管辖统计');

writetable(nodeAssignResult, '第一问第一小问_节点分配结果.xlsx', ...
    'Sheet', '节点分配结果');

fprintf('\n结果已保存为 Excel 文件。\n');

%% 15. 输出每个平台具体管辖节点列表

platformNodeList = table();

for i = 1:nPlatform

    % 找出由第 i 个平台管辖的节点
    servedLogical = nearestPlatform == i;

    servedNodes = A_nodeID(servedLogical);
    servedDist = minDist(servedLogical);
    servedRate = A_caseRate(servedLogical);

    % 管辖节点数
    nodeCount = length(servedNodes);

    % 将节点编号合并成字符串，方便放进论文表格
    if nodeCount > 0
        servedNodesText = strjoin(string(servedNodes'), '、');
        maxDistance = max(servedDist);
        avgDistance = mean(servedDist);
        totalCaseRate = sum(servedRate);
        overtimeCount = sum(servedDist > 3);
    else
        servedNodesText = "";
        maxDistance = 0;
        avgDistance = 0;
        totalCaseRate = 0;
        overtimeCount = 0;
    end

    platformNodeList = [platformNodeList;
        table(A_platformName(i), A_platformNode(i), nodeCount, ...
        string(servedNodesText), maxDistance, avgDistance, ...
        overtimeCount, totalCaseRate, ...
        'VariableNames', {'平台编号', '平台节点', '管辖节点数', ...
        '具体管辖节点', '最大出警距离_km', '平均出警距离_km', ...
        '超3km节点数', '管辖区域总发案率'})];

end

fprintf('\n各平台具体管辖节点如下：\n');
disp(platformNodeList);

% 保存到 Excel
writetable(platformNodeList, '第一问第一小问_各平台具体管辖节点.xlsx', ...
    'Sheet', '各平台管辖节点');

fprintf('\n各平台具体管辖节点结果已保存为 Excel 文件。\n');