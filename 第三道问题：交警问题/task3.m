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

%% 2. 提取 A 区节点信息

nodeID = nodeTable{:,1};
xCoord = nodeTable{:,2};
yCoord = nodeTable{:,3};
areaName = string(nodeTable{:,4});
caseRate = nodeTable{:,5};

% 防止发案率被读成非数值
caseRate = double(caseRate);
caseRate(isnan(caseRate)) = 0;

isA = areaName == "A";

A_nodeID = nodeID(isA);
A_x = xCoord(isA);
A_y = yCoord(isA);
A_caseRate = caseRate(isA);

nA = length(A_nodeID);

fprintf('A区节点数量：%d\n', nA);
fprintf('A区总发案率：%.4f\n', sum(A_caseRate));

% 如果发案率全为0，自动改成不考虑发案率
if sum(A_caseRate) == 0
    warning('A区发案率总和为0，程序自动改为不考虑发案率，即所有节点权重为1。');
    A_caseRate = ones(nA,1);
end

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

fprintf('A区现有平台数量：%d\n', nPlatform);

%% 4. 建立 A 区节点编号到矩阵下标的映射

nodeIndexMap = containers.Map('KeyType', 'double', 'ValueType', 'double');

for i = 1:nA
    nodeIndexMap(A_nodeID(i)) = i;
end

%% 5. 构建 A 区道路邻接矩阵

D = inf(nA, nA);

for i = 1:nA
    D(i,i) = 0;
end

edgeStart = edgeTable{:,1};
edgeEnd = edgeTable{:,2};

for e = 1:length(edgeStart)

    u = edgeStart(e);
    v = edgeEnd(e);

    % 只保留 A 区内部道路
    if isKey(nodeIndexMap, u) && isKey(nodeIndexMap, v)

        iu = nodeIndexMap(u);
        iv = nodeIndexMap(v);

        % 坐标比例：1 个坐标单位对应 0.1 km
        distance_km = sqrt((A_x(iu)-A_x(iv))^2 + (A_y(iu)-A_y(iv))^2) * 0.1;

        D(iu, iv) = distance_km;
        D(iv, iu) = distance_km;
    end
end

%% 6. Floyd 算法计算任意两节点最短路径

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

fprintf('A区最短路径计算完成。\n');

%% 7. 确定候选新增平台节点

% 候选点 = A区所有节点中，尚未设置平台的节点
candidateNode = setdiff(A_nodeID, A_platformNode, 'stable');
mCandidate = length(candidateNode);

fprintf('候选新增平台节点数量：%d\n', mCandidate);

%% 8. 提取现有平台和候选点到所有 A 区节点的距离矩阵

platformIndex = zeros(nPlatform,1);

for i = 1:nPlatform
    platformIndex(i) = nodeIndexMap(A_platformNode(i));
end

candidateIndex = zeros(mCandidate,1);

for r = 1:mCandidate
    candidateIndex(r) = nodeIndexMap(candidateNode(r));
end

% 现有平台到所有节点的最短距离
existingDist = S(platformIndex, :);

% 候选平台到所有节点的最短距离
candidateDist = S(candidateIndex, :);

%% 9. 先评价原有 20 个平台布局

originalScore = evaluatePlan(existingDist, candidateDist, [], ...
    A_caseRate, nPlatform);

fprintf('\n原有20个平台布局评价：\n');
fprintf('加权3分钟覆盖率：%.2f%%\n', originalScore.weightedCoverageRate);
fprintf('普通3分钟覆盖率：%.2f%%\n', originalScore.coverageRate);
fprintf('最大出警距离：%.4f km\n', originalScore.maxDist);
fprintf('加权平均出警距离：%.4f km\n', originalScore.weightedAvgDist);
fprintf('工作量最大偏差：%.4f\n', originalScore.workloadMaxDev);

%% 10. 分别求新增 2、3、4、5 个平台的方案

kList = 2:5;

summaryTable = table();

allSelected = cell(length(kList),1);
allScores = cell(length(kList),1);
allAssign = cell(length(kList),1);
allMinDist = cell(length(kList),1);
allWorkload = cell(length(kList),1);

for kk = 1:length(kList)

    kAdd = kList(kk);

    fprintf('\n==============================\n');
    fprintf('开始求解新增 %d 个平台的方案\n', kAdd);
    fprintf('==============================\n');

    %% 10.1 贪心选择初始方案

    selected = [];

    for step = 1:kAdd

        bestCandidate = NaN;
        bestScore = [];

        remain = setdiff(1:mCandidate, selected, 'stable');

        for r = remain

            tempSelected = [selected, r];

            tempScore = evaluatePlan(existingDist, candidateDist, tempSelected, ...
                A_caseRate, nPlatform);

            if isempty(bestScore) || isBetterScore(tempScore, bestScore)
                bestScore = tempScore;
                bestCandidate = r;
            end
        end

        selected = [selected, bestCandidate];

        fprintf('第 %d 次选择：新增节点 %d\n', step, candidateNode(bestCandidate));
    end

    %% 10.2 局部替换优化

    improved = true;

    while improved

        improved = false;

        currentScore = evaluatePlan(existingDist, candidateDist, selected, ...
            A_caseRate, nPlatform);

        for pos = 1:length(selected)

            remain = setdiff(1:mCandidate, selected, 'stable');

            for r = remain

                tempSelected = selected;
                tempSelected(pos) = r;

                tempScore = evaluatePlan(existingDist, candidateDist, tempSelected, ...
                    A_caseRate, nPlatform);

                if isBetterScore(tempScore, currentScore)

                    selected = tempSelected;
                    currentScore = tempScore;
                    improved = true;

                    fprintf('局部替换：位置 %d 替换为新增节点 %d\n', ...
                        pos, candidateNode(r));

                    break;
                end
            end

            if improved
                break;
            end
        end
    end

    %% 10.3 评价最终方案

    finalScore = evaluatePlan(existingDist, candidateDist, selected, ...
        A_caseRate, nPlatform);

    selectedNodes = candidateNode(selected);

    allSelected{kk} = selected;
    allScores{kk} = finalScore;
    allAssign{kk} = finalScore.assignIndex;
    allMinDist{kk} = finalScore.minDist;
    allWorkload{kk} = finalScore.workload;

    fprintf('\n新增 %d 个平台最终位置：\n', kAdd);
    disp(selectedNodes');

    fprintf('加权3分钟覆盖率：%.2f%%\n', finalScore.weightedCoverageRate);
    fprintf('普通3分钟覆盖率：%.2f%%\n', finalScore.coverageRate);
    fprintf('超3km节点数：%d\n', finalScore.overtimeCount);
    fprintf('最大出警距离：%.4f km\n', finalScore.maxDist);
    fprintf('加权平均出警距离：%.4f km\n', finalScore.weightedAvgDist);
    fprintf('普通平均出警距离：%.4f km\n', finalScore.avgDist);
    fprintf('工作量最大偏差：%.4f\n', finalScore.workloadMaxDev);
    fprintf('工作量方差：%.4f\n', finalScore.workloadVariance);

    selectedText = strjoin(string(selectedNodes'), ",");

    summaryTable = [summaryTable;
        table(kAdd, selectedText, ...
        finalScore.weightedCoverageRate, finalScore.coverageRate, ...
        finalScore.overtimeCount, finalScore.maxDist, ...
        finalScore.weightedAvgDist, finalScore.avgDist, ...
        finalScore.workloadMaxDev, finalScore.workloadVariance, ...
        'VariableNames', {'新增平台数', '新增平台节点', ...
        '加权3分钟覆盖率', '普通3分钟覆盖率', ...
        '超3km节点数', '最大出警距离_km', ...
        '加权平均出警距离_km', '普通平均出警距离_km', ...
        '工作量最大偏差', '工作量方差'})];

end

%% 11. 输出不同新增数量的比较结果

fprintf('\n不同新增数量方案比较：\n');
disp(summaryTable);

%% 12. 自动推荐方案

% 推荐原则：
% 1. 加权3分钟覆盖率越高越好；
% 2. 若覆盖率相同，最大出警距离越小越好；
% 3. 若仍相同，加权平均出警距离越小越好；
% 4. 若仍相同，工作量最大偏差越小越好；
% 5. 若指标接近，新增平台数越少越好。

bestIdx = 1;

for kk = 2:length(kList)

    scoreNow = allScores{kk};
    scoreBest = allScores{bestIdx};

    if isBetterScore(scoreNow, scoreBest)
        bestIdx = kk;
    end
end

bestK = kList(bestIdx);
bestSelected = allSelected{bestIdx};
bestSelectedNodes = candidateNode(bestSelected);
bestScore = allScores{bestIdx};

fprintf('\n程序推荐方案：新增 %d 个平台。\n', bestK);
fprintf('推荐新增平台节点为：\n');
disp(bestSelectedNodes');

fprintf('推荐方案指标：\n');
fprintf('加权3分钟覆盖率：%.2f%%\n', bestScore.weightedCoverageRate);
fprintf('普通3分钟覆盖率：%.2f%%\n', bestScore.coverageRate);
fprintf('超3km节点数：%d\n', bestScore.overtimeCount);
fprintf('最大出警距离：%.4f km\n', bestScore.maxDist);
fprintf('加权平均出警距离：%.4f km\n', bestScore.weightedAvgDist);
fprintf('工作量最大偏差：%.4f\n', bestScore.workloadMaxDev);

%% 13. 整理推荐方案的节点分配结果

bestAssign = bestScore.assignIndex;
bestMinDist = bestScore.minDist;
bestCovered = bestMinDist <= 3;

serviceName = strings(nPlatform + bestK, 1);
serviceNode = zeros(nPlatform + bestK, 1);

% 现有平台
for i = 1:nPlatform
    serviceName(i) = A_platformName(i);
    serviceNode(i) = A_platformNode(i);
end

% 新增平台
for r = 1:bestK
    serviceName(nPlatform + r) = "新增平台" + string(r);
    serviceNode(nPlatform + r) = bestSelectedNodes(r);
end

nodeAssignResult = table();

for j = 1:nA

    h = bestAssign(j);

    nodeAssignResult = [nodeAssignResult;
        table(A_nodeID(j), A_x(j), A_y(j), A_caseRate(j), ...
        serviceName(h), serviceNode(h), bestMinDist(j), bestCovered(j), ...
        'VariableNames', {'节点编号', '横坐标X', '纵坐标Y', '发案率', ...
        '所属平台编号', '所属平台节点', '到平台距离_km', '是否3分钟覆盖'})];

end

%% 14. 整理推荐方案的平台工作量结果

bestWorkload = bestScore.workload;

platformStatResult = table();

for h = 1:(nPlatform + bestK)

    servedNodes = A_nodeID(bestAssign == h);
    servedDist = bestMinDist(bestAssign == h);
    servedCaseRate = A_caseRate(bestAssign == h);

    if isempty(servedNodes)
        nodeCount = 0;
        maxD = 0;
        avgD = 0;
        weightedAvgD = 0;
        totalRate = 0;
        overtimeCount = 0;
    else
        nodeCount = length(servedNodes);
        maxD = max(servedDist);
        avgD = mean(servedDist);
        totalRate = sum(servedCaseRate);
        weightedAvgD = sum(servedCaseRate' .* servedDist) / sum(servedCaseRate);
        overtimeCount = sum(servedDist > 3);
    end

    platformStatResult = [platformStatResult;
        table(serviceName(h), serviceNode(h), nodeCount, totalRate, ...
        maxD, avgD, weightedAvgD, overtimeCount, ...
        'VariableNames', {'平台编号', '平台节点', '管辖节点数', ...
        '管辖区域总发案率', '最大出警距离_km', ...
        '普通平均出警距离_km', '加权平均出警距离_km', ...
        '超3km节点数'})];

end

fprintf('\n推荐方案平台统计：\n');
disp(platformStatResult);

%% 15. 保存结果到 Excel

writetable(summaryTable, '第一问第三小问_新增平台方案比较.xlsx', ...
    'Sheet', '不同新增数量比较');

writetable(nodeAssignResult, '第一问第三小问_推荐方案节点分配结果.xlsx', ...
    'Sheet', '节点分配结果');

writetable(platformStatResult, '第一问第三小问_推荐方案平台统计.xlsx', ...
    'Sheet', '平台统计');

fprintf('\n第三小问结果已保存为 Excel 文件。\n');

%% ======================= 局部函数 =======================

function score = evaluatePlan(existingDist, candidateDist, selected, caseRate, nExisting)

    % 合并现有平台和已选择新增平台的距离矩阵
    if isempty(selected)
        allDist = existingDist;
    else
        allDist = [existingDist; candidateDist(selected,:)];
    end

    nNode = length(caseRate);
    nService = size(allDist, 1);

    totalRate = sum(caseRate);

    % 每个节点分配给最近服务平台
    [minDist, assignIndex] = min(allDist, [], 1);

    covered = minDist <= 3;

    % 覆盖指标
    weightedCoveredRate = sum(caseRate(covered));
    weightedCoverageRate = weightedCoveredRate / totalRate * 100;

    coverageRate = sum(covered) / nNode * 100;
    overtimeCount = sum(~covered);

    % 距离指标
    maxDist = max(minDist);
    avgDist = mean(minDist);
    weightedAvgDist = sum(caseRate' .* minDist) / totalRate;

    % 工作量指标：每个平台管辖节点发案率之和
    workload = zeros(nService,1);

    for h = 1:nService
        workload(h) = sum(caseRate(assignIndex == h));
    end

    avgWorkload = totalRate / nService;
    workloadMaxDev = max(abs(workload - avgWorkload));
    workloadVariance = mean((workload - avgWorkload).^2);

    % 保存结果
    score.weightedCoveredRate = weightedCoveredRate;
    score.weightedCoverageRate = weightedCoverageRate;
    score.coverageRate = coverageRate;
    score.overtimeCount = overtimeCount;
    score.maxDist = maxDist;
    score.avgDist = avgDist;
    score.weightedAvgDist = weightedAvgDist;
    score.workloadMaxDev = workloadMaxDev;
    score.workloadVariance = workloadVariance;
    score.minDist = minDist;
    score.assignIndex = assignIndex;
    score.workload = workload;
end

function flag = isBetterScore(scoreA, scoreB)

    tol = 1e-8;

    % 1. 加权覆盖率越高越好
    if scoreA.weightedCoveredRate > scoreB.weightedCoveredRate + tol
        flag = true;
        return;
    elseif scoreA.weightedCoveredRate < scoreB.weightedCoveredRate - tol
        flag = false;
        return;
    end

    % 2. 最大出警距离越小越好
    if scoreA.maxDist < scoreB.maxDist - tol
        flag = true;
        return;
    elseif scoreA.maxDist > scoreB.maxDist + tol
        flag = false;
        return;
    end

    % 3. 加权平均出警距离越小越好
    if scoreA.weightedAvgDist < scoreB.weightedAvgDist - tol
        flag = true;
        return;
    elseif scoreA.weightedAvgDist > scoreB.weightedAvgDist + tol
        flag = false;
        return;
    end

    % 4. 工作量最大偏差越小越好
    if scoreA.workloadMaxDev < scoreB.workloadMaxDev - tol
        flag = true;
        return;
    elseif scoreA.workloadMaxDev > scoreB.workloadMaxDev + tol
        flag = false;
        return;
    end

    % 5. 工作量方差越小越好
    if scoreA.workloadVariance < scoreB.workloadVariance - tol
        flag = true;
    else
        flag = false;
    end
end