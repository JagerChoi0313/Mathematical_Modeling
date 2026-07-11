%% Q4_KNN_Logistic_MultiObjective.m
% 第四问：附件三新项目任务定价与实施效果评价
%
% 模型结构：
% 1. 读取附件一、附件二和附件三；
% 2. 清洗会员 GPS，构造历史任务和新任务的空间供需特征；
% 3. 使用留一交叉验证选择 KNN 参数，以空间加权 KNN 迁移历史价格；
% 4. 用附件一重新训练 Logistic 完成概率模型；
% 5. 对附件三超出历史范围的特征实施边界投影，避免模型外推；
% 6. 建立"完成效果—平台成本"多目标定价模型；
% 7. 采用离散边际增益贪心算法求解附件三的最终价格；
% 8. 输出逐任务定价、方案评价、稳健性检验和图像。

clear;
clc;
close all;

%% ==================== Step 0：参数设置 ====================

historyFile = '附件一：已结束项目任务数据.xls';
memberFile  = '附件二：会员信息数据.xlsx';
newTaskFile = '附件三：新项目任务数据.xls';

rMember = 3.0;                    % 周边会员统计半径，km
rTask = 3.0;                      % 任务密度统计半径，km
kList = [3, 5, 10, 15, 20, 30]; % KNN 交叉验证候选值
distanceEps = 0.1;                % KNN 距离平滑项，km
targetProb = 0.62;                % 第一问得到的最优分类阈值

omega = 0.65;                     % 完成效果权重
etaMax = 0.05;                    % 总成本最大增长率
deltaMax = 10.0;                  % 单任务最大涨价，元
priceStep = 0.5;                  % 离散调价步长，元

% 成本上限敏感性分析参数
etaList = [0.01, 0.03, 0.05, 0.07, 0.08];

fprintf('\n============================================================\n');
fprintf(' 第四问：KNN 迁移 + Logistic + 多目标优化定价模型\n');
fprintf('============================================================\n');
fprintf('会员统计半径：%.2f km\n', rMember);
fprintf('任务密度半径：%.2f km\n', rTask);
fprintf('目标完成概率阈值：%.2f\n', targetProb);
fprintf('完成效果权重：%.2f\n', omega);
fprintf('总成本增长上限：%.2f%%\n', etaMax * 100);
fprintf('价格调整步长：%.2f 元\n', priceStep);
fprintf('单任务最大涨价：%.2f 元\n', deltaMax);

%% ==================== Step 1：读取三个附件 ====================

History = readSmartTable(historyFile);
Member = readSmartTable(memberFile);
NewTask = readSmartTable(newTaskFile);

disp('附件一字段名：');
disp(History.Properties.VariableNames');
disp('附件二字段名：');
disp(Member.Properties.VariableNames');
disp('附件三字段名：');
disp(NewTask.Properties.VariableNames');

%% ==================== Step 2：提取历史任务 ====================

histIDCol = findCol(History, {'任务号码', '任务编号', '编号'});
histLatCol = findCol(History, {'任务gps 纬度', '任务gps纬度', '任务GPS纬度', '纬度'});
histLonCol = findCol(History, {'任务gps经度', '任务gps 经度', '任务GPS经度', '经度'});
histPriceCol = findCol(History, {'任务标价', '标价', '定价', '价格'});
histFinishCol = findCol(History, {'任务执行情况', '执行情况', '完成情况', '是否完成'});

histID = History.(histIDCol);
histLat = toNumericVector(History.(histLatCol));
histLon = toNumericVector(History.(histLonCol));
histPrice = toNumericVector(History.(histPriceCol));
histFinish = toNumericVector(History.(histFinishCol));

validHistory = ~isnan(histLat) & ~isnan(histLon) & ...
               ~isnan(histPrice) & ~isnan(histFinish);

histID = histID(validHistory);
histLat = histLat(validHistory);
histLon = histLon(validHistory);
histPrice = histPrice(validHistory);
histFinish = histFinish(validHistory);

nHistory = length(histPrice);

fprintf('\n================ 历史任务统计 ================\n');
fprintf('有效历史任务：%d 个\n', nHistory);
fprintf('完成任务：%d 个\n', sum(histFinish == 1));
fprintf('未完成任务：%d 个\n', sum(histFinish == 0));
fprintf('历史实际完成率：%.2f%%\n', mean(histFinish) * 100);

%% ==================== Step 3：提取附件三新任务 ====================

newIDCol = findCol(NewTask, {'任务号码', '任务编号', '编号'});
newLatCol = findCol(NewTask, {'任务GPS纬度', '任务gps 纬度', '任务gps纬度', '纬度'});
newLonCol = findCol(NewTask, {'任务GPS经度', '任务gps经度', '任务gps 经度', '经度'});

newID = NewTask.(newIDCol);
newLat = toNumericVector(NewTask.(newLatCol));
newLon = toNumericVector(NewTask.(newLonCol));

validNew = ~isnan(newLat) & ~isnan(newLon);
newID = newID(validNew);
newLat = newLat(validNew);
newLon = newLon(validNew);

nNew = length(newLat);

fprintf('\n有效新任务：%d 个\n', nNew);

%% ==================== Step 4：提取并清洗会员数据 ====================

memberIDCol = findCol(Member, {'会员编号', '编号'});
memberGPSCol = findCol(Member, {'会员位置', 'GPS', '位置'});
quotaCol = findCol(Member, {'预订任务限额', '任务限额', '限额'});
creditCol = findCol(Member, {'信誉值', '信誉'});

memberID = Member.(memberIDCol);
memberGPS = Member.(memberGPSCol);
quota = toNumericVector(Member.(quotaCol));
credit = toNumericVector(Member.(creditCol));

taskLatCenter = median(histLat, 'omitnan');
taskLonCenter = median(histLon, 'omitnan');

[memberLat, memberLon, swapCount] = parseGPSAutoCount( ...
    memberGPS, taskLatCenter, taskLonCenter);

validMember = ~isnan(memberLat) & ~isnan(memberLon) & ...
              ~isnan(quota) & ~isnan(credit);

memberID = memberID(validMember);
memberLat = memberLat(validMember);
memberLon = memberLon(validMember);
quota = quota(validMember);
credit = credit(validMember);

lonMinWide = min(histLon) - 5;
lonMaxWide = max(histLon) + 5;
latMinWide = min(histLat) - 5;
latMaxWide = max(histLat) + 5;

validRange = memberLon >= lonMinWide & memberLon <= lonMaxWide & ...
             memberLat >= latMinWide & memberLat <= latMaxWide;

removedMember = sum(~validRange);

memberID = memberID(validRange);
memberLat = memberLat(validRange);
memberLon = memberLon(validRange);
quota = quota(validRange);
credit = credit(validRange);

nMember = length(memberLat);

fprintf('\n================ 会员数据清洗 ================\n');
fprintf('会员 GPS 经纬度颠倒修正：%d 条\n', swapCount);
fprintf('剔除空间异常会员：%d 条\n', removedMember);
fprintf('有效会员：%d 个\n', nMember);

%% ==================== Step 5：构造历史与新任务特征 ====================

fprintf('\n开始计算历史任务特征...\n');
[histDmin, histNi, histAvgC, histAvgQ, histDensity, histCompetition] = ...
    constructTaskFeatures(histLat, histLon, memberLat, memberLon, ...
    quota, credit, rMember, rTask);

fprintf('开始计算附件三新任务特征...\n');
[newDmin, newNi, newAvgC, newAvgQ, newDensity, newCompetition] = ...
    constructTaskFeatures(newLat, newLon, memberLat, memberLon, ...
    quota, credit, rMember, rTask);

fprintf('\n================ 特征迁移检查 ================\n');
fprintf('历史任务 3 km 平均会员数：%.4f\n', mean(histNi));
fprintf('新任务 3 km 平均会员数：%.4f\n', mean(newNi));
fprintf('历史任务 3 km 平均任务密度：%.4f\n', mean(histDensity));
fprintf('新任务 3 km 平均任务密度：%.4f\n', mean(newDensity));

%% ==================== Step 6：KNN 留一交叉验证 ====================

fprintf('\n开始进行 KNN 留一交叉验证...\n');

histDistMat = zeros(nHistory, nHistory);
for i = 1:nHistory
    histDistMat(i, :) = geoDistanceKm( ...
        histLat(i), histLon(i), histLat, histLon);
end
histDistMat(1:nHistory + 1:end) = inf;

[histDistSorted, histIdxSorted] = sort(histDistMat, 2, 'ascend');

cvMAE = zeros(length(kList), 1);
cvRMSE = zeros(length(kList), 1);
cvR2 = zeros(length(kList), 1);

for s = 1:length(kList)
    kValue = kList(s);
    distanceK = histDistSorted(:, 1:kValue);
    indexK = histIdxSorted(:, 1:kValue);
    weightK = 1 ./ (distanceK + distanceEps);
    neighborPrice = histPrice(indexK);
    cvPred = sum(weightK .* neighborPrice, 2) ./ sum(weightK, 2);
    cvError = histPrice - cvPred;
    cvMAE(s) = mean(abs(cvError));
    cvRMSE(s) = sqrt(mean(cvError .^ 2));
    cvR2(s) = 1 - sum(cvError .^ 2) / ...
        sum((histPrice - mean(histPrice)) .^ 2);
end

[~, bestKLocation] = min(cvRMSE);
bestK = kList(bestKLocation);

KNNTable = table(kList(:), cvMAE, cvRMSE, cvR2, ...
    'VariableNames', {'近邻数K', '平均绝对误差MAE', ...
    '均方根误差RMSE', '决定系数R2'});

disp(KNNTable);
fprintf('按 RMSE 最小原则选择 K = %d。\n', bestK);
writetable(KNNTable, 'Q4_KNN参数检验.xlsx');

%% ==================== Step 7：生成附件三基准价格 ====================

fprintf('\n开始使用空间加权 KNN 迁移历史价格...\n');

newHistDistMat = zeros(nNew, nHistory);
for i = 1:nNew
    newHistDistMat(i, :) = geoDistanceKm( ...
        newLat(i), newLon(i), histLat, histLon);
end

[newHistDistSorted, newHistIdxSorted] = sort(newHistDistMat, 2, 'ascend');
distanceK = newHistDistSorted(:, 1:bestK);
indexK = newHistIdxSorted(:, 1:bestK);
weightK = 1 ./ (distanceK + distanceEps);
neighborPrice = histPrice(indexK);

rawBasePrice = sum(weightK .* neighborPrice, 2) ./ sum(weightK, 2);

% 限制在历史价格范围内，并按 0.5 元离散化
basePrice = min(max(rawBasePrice, min(histPrice)), max(histPrice));
basePrice = round(basePrice / priceStep) * priceStep;
nearestHistoryDistance = newHistDistSorted(:, 1);

fprintf('新任务基准价格均值：%.4f 元\n', mean(basePrice));
fprintf('新任务基准价格范围：[%.2f, %.2f] 元\n', ...
    min(basePrice), max(basePrice));
fprintf('新任务到最近历史任务的中位距离：%.4f km\n', ...
    median(nearestHistoryDistance));

%% ==================== Step 8：重新训练 Logistic 模型 ====================

histPricePerDistance = histPrice ./ (histDmin + 0.1);
histPricePerCompetition = histPrice ./ (histDensity + 1);

XHistoryRaw = [histPrice, histDmin, histNi, histAvgC, histAvgQ, ...
    histDensity, histCompetition, histPricePerDistance, ...
    histPricePerCompetition];

[XHistoryStd, muLogit, sigmaLogit] = standardizeData(XHistoryRaw);
XHistoryDesign = [ones(nHistory, 1), XHistoryStd];

alphaInit = zeros(size(XHistoryDesign, 2), 1);
options = optimset('MaxIter', 10000, 'MaxFunEvals', 20000, ...
    'Display', 'off');

alpha = fminsearch(@(a) logisticNLL(a, XHistoryDesign, histFinish), ...
    alphaInit, options);

histProb = sigmoid(XHistoryDesign * alpha);

% 记录历史训练域边界，用于附件三的稳健外推控制
featureLower = min(XHistoryRaw, [], 1);
featureUpper = max(XHistoryRaw, [], 1);

% 重新搜索平衡准确率最优阈值，用于核验与第一问的一致性
thresholdList = 0.05:0.01:0.95;
balancedAccuracy = zeros(length(thresholdList), 1);
for k = 1:length(thresholdList)
    yPredTemp = histProb >= thresholdList(k);
    recallFinish = sum((histFinish == 1) & yPredTemp) / ...
        max(sum(histFinish == 1), 1);
    recallUnfinish = sum((histFinish == 0) & ~yPredTemp) / ...
        max(sum(histFinish == 0), 1);
    balancedAccuracy(k) = (recallFinish + recallUnfinish) / 2;
end
[bestBalancedAccuracy, thresholdLocation] = max(balancedAccuracy);
bestThreshold = thresholdList(thresholdLocation);

fprintf('\n================ Logistic 模型核验 ================\n');
fprintf('平衡准确率最优阈值：%.2f\n', bestThreshold);
fprintf('最优平衡准确率：%.2f%%\n', bestBalancedAccuracy * 100);

logitNames = {'常数项'; '任务价格'; '最近会员距离'; '周边会员数量'; ...
    '平均信誉值'; '平均预订限额'; '任务密度'; '竞争强度'; ...
    '单位距离价格'; '单位竞争价格'};
LogitTable = table(logitNames, alpha, ...
    'VariableNames', {'变量', 'Logistic回归系数'});
writetable(LogitTable, 'Q4_Logistic回归系数.xlsx');

%% ==================== Step 9：评价基准方案 ====================

baseProb = predictProbStable(basePrice, alpha, muLogit, sigmaLogit, ...
    featureLower, featureUpper, newDmin, newNi, newAvgC, newAvgQ, ...
    newDensity, newCompetition);

C0 = sum(basePrice);
M0 = sum(baseProb);
E0 = mean(baseProb);
R0 = mean(baseProb >= targetProb);
L0 = sum(baseProb < targetProb);

fprintf('\n================ 基准方案评价 ================\n');
fprintf('基准总成本：%.4f 元\n', C0);
fprintf('基准平均价格：%.4f 元\n', mean(basePrice));
fprintf('基准期望完成任务数：%.4f\n', M0);
fprintf('基准期望完成率：%.2f%%\n', E0 * 100);
fprintf('基准目标概率达标率：%.2f%%\n', R0 * 100);
fprintf('基准低完成概率任务数：%d\n', L0);

%% ==================== Step 10：多目标优化定价 ====================

fprintf('\n开始多目标离散调价优化...\n');

[finalPrice, finalProb, adjustedFlag, optHistory] = ...
    optimizeNewProjectPricing(basePrice, baseProb, targetProb, ...
    omega, etaMax, deltaMax, priceStep, alpha, muLogit, sigmaLogit, ...
    featureLower, featureUpper, newDmin, newNi, newAvgC, newAvgQ, ...
    newDensity, newCompetition);

C1 = sum(finalPrice);
M1 = sum(finalProb);
E1 = mean(finalProb);
R1 = mean(finalProb >= targetProb);
L1 = sum(finalProb < targetProb);

costIncrease = C1 - C0;
costIncreaseRate = costIncrease / C0;

fprintf('\n================ 最终定价方案评价 ================\n');
fprintf('最终总成本：%.4f 元\n', C1);
fprintf('最终平均价格：%.4f 元\n', mean(finalPrice));
fprintf('成本增加量：%.4f 元\n', costIncrease);
fprintf('成本增长率：%.4f%%\n', costIncreaseRate * 100);
fprintf('最终期望完成任务数：%.4f\n', M1);
fprintf('最终期望完成率：%.2f%%\n', E1 * 100);
fprintf('最终目标概率达标率：%.2f%%\n', R1 * 100);
fprintf('最终低完成概率任务数：%d\n', L1);
fprintf('期望完成任务数提升：%.4f\n', M1 - M0);
fprintf('期望完成率提升：%.2f 个百分点\n', (E1 - E0) * 100);
fprintf('目标概率达标率提升：%.2f 个百分点\n', (R1 - R0) * 100);
fprintf('低完成概率任务减少：%d 个\n', L0 - L1);
fprintf('调价任务数量：%d 个\n', sum(adjustedFlag));

%% ==================== Step 11：成本上限敏感性分析 ====================

sensCost = zeros(length(etaList), 1);
sensExpectedCount = zeros(length(etaList), 1);
sensExpectedRate = zeros(length(etaList), 1);
sensTargetRate = zeros(length(etaList), 1);
sensLowCount = zeros(length(etaList), 1);
sensAdjustedCount = zeros(length(etaList), 1);

fprintf('\n开始成本上限敏感性分析...\n');

for s = 1:length(etaList)
    etaTemp = etaList(s);
    [priceTemp, probTemp, adjustedTemp, ~] = ...
        optimizeNewProjectPricing(basePrice, baseProb, targetProb, ...
        omega, etaTemp, deltaMax, priceStep, alpha, muLogit, sigmaLogit, ...
        featureLower, featureUpper, newDmin, newNi, newAvgC, newAvgQ, ...
        newDensity, newCompetition);

    sensCost(s) = sum(priceTemp);
    sensExpectedCount(s) = sum(probTemp);
    sensExpectedRate(s) = mean(probTemp);
    sensTargetRate(s) = mean(probTemp >= targetProb);
    sensLowCount(s) = sum(probTemp < targetProb);
    sensAdjustedCount(s) = sum(adjustedTemp);
end

SensitivityTable = table(etaList(:) * 100, sensCost, ...
    sensExpectedCount, sensExpectedRate * 100, sensTargetRate * 100, ...
    sensLowCount, sensAdjustedCount, ...
    'VariableNames', {'成本增长上限百分比', '总成本', '期望完成任务数', ...
    '期望完成率百分比', '目标概率达标率百分比', ...
    '低完成概率任务数', '调价任务数'});

disp(SensitivityTable);
writetable(SensitivityTable, 'Q4_成本上限敏感性分析.xlsx');

%% ==================== Step 12：输出结果表格 ====================

TaskResultTable = table(newID, newLat, newLon, nearestHistoryDistance, ...
    newDmin, newNi, newAvgC, newAvgQ, newDensity, newCompetition, ...
    rawBasePrice, basePrice, finalPrice, finalPrice - basePrice, ...
    baseProb, finalProb, finalProb >= targetProb, adjustedFlag, ...
    'VariableNames', {'任务编号', '任务纬度', '任务经度', ...
    '最近历史任务距离', '最近会员距离', '周边会员数量', ...
    '平均信誉值', '平均预订限额', '任务密度', '竞争强度', ...
    'KNN原始估计价格', '基准价格', '最终价格', '涨价幅度', ...
    '基准完成概率', '最终完成概率', '是否达到目标概率', '是否调价'});

writetable(TaskResultTable, 'Q4_新项目任务定价结果.xlsx');

metricName = {'总成本'; '平均任务价格'; '期望完成任务数'; ...
    '期望完成率百分比'; '目标概率达标率百分比'; '低完成概率任务数'};
baseValue = [C0; mean(basePrice); M0; E0 * 100; R0 * 100; L0];
finalValue = [C1; mean(finalPrice); M1; E1 * 100; R1 * 100; L1];
changeValue = finalValue - baseValue;

EvaluationTable = table(metricName, baseValue, finalValue, changeValue, ...
    'VariableNames', {'评价指标', '基准方案', '最终方案', '变化量'});
writetable(EvaluationTable, 'Q4_方案实施效果评价.xlsx');

fprintf('\n结果文件已输出：\n');
fprintf('Q4_KNN参数检验.xlsx\n');
fprintf('Q4_Logistic回归系数.xlsx\n');
fprintf('Q4_新项目任务定价结果.xlsx\n');
fprintf('Q4_方案实施效果评价.xlsx\n');
fprintf('Q4_成本上限敏感性分析.xlsx\n');

%% ==================== Step 13：绘制论文图像 ====================

figure('Color', 'w', 'Position', [100, 100, 900, 680]);
scatter(newLon, newLat, 18, finalPrice, 'filled');
colorbar;
xlabel('经度');
ylabel('纬度');
title('附件三新项目任务优化定价空间分布');
grid on;
box on;
saveFigure300('Q4_优化定价空间分布图.png');

[~, probabilityOrder] = sort(baseProb, 'ascend');
figure('Color', 'w', 'Position', [100, 100, 900, 560]);
plot(baseProb(probabilityOrder), 'LineWidth', 1.2, ...
    'Color', [0.49, 0.56, 0.65]);
hold on;
plot(finalProb(probabilityOrder), 'LineWidth', 1.2, ...
    'Color', [0.85, 0.37, 0.35]);
yline(targetProb, '--', '目标阈值 0.62', 'LineWidth', 1.2);
xlabel('按基准完成概率升序排列的任务');
ylabel('预测完成概率');
title('优化前后任务完成概率对比');
legend('基准方案', '最终方案', 'Location', 'best');
grid on;
box on;
saveFigure300('Q4_优化前后完成概率对比图.png');

figure('Color', 'w', 'Position', [100, 100, 820, 520]);
bar([E0, E1; R0, R1] * 100);
set(gca, 'XTickLabel', {'期望完成率', '目标概率达标率'});
ylabel('比例（%）');
title('附件三定价方案实施效果评价');
legend('基准方案', '最终方案', 'Location', 'northwest');
grid on;
box on;
saveFigure300('Q4_方案实施效果评价图.png');

figure('Color', 'w', 'Position', [100, 100, 820, 520]);
plot(etaList * 100, sensExpectedRate * 100, '-o', ...
    'LineWidth', 1.5, 'MarkerSize', 6);
hold on;
plot(etaList * 100, sensTargetRate * 100, '-s', ...
    'LineWidth', 1.5, 'MarkerSize', 6);
xlabel('成本增长上限（%）');
ylabel('比例（%）');
title('成本增长上限敏感性分析');
legend('期望完成率', '目标概率达标率', 'Location', 'best');
grid on;
box on;
saveFigure300('Q4_成本上限敏感性分析图.png');

figure('Color', 'w', 'Position', [100, 100, 820, 520]);
plot(optHistory.step, optHistory.expectedCount, ...
    'LineWidth', 1.4, 'Color', [0.20, 0.48, 0.64]);
xlabel('调价迭代次数');
ylabel('期望完成任务数');
title('多目标优化迭代过程');
grid on;
box on;
saveFigure300('Q4_多目标优化迭代过程图.png');

fprintf('\n第四问全部计算完成。\n');

%% ============================================================
%% 局部函数
%% ============================================================

function T = readSmartTable(fileName)
    try
        T = readtable(fileName, 'VariableNamingRule', 'preserve');
    catch
        T = readtable(fileName);
    end
end

function colName = findCol(T, keys)
    names = T.Properties.VariableNames;
    colName = '';
    for k = 1:length(keys)
        for i = 1:length(names)
            if contains(names{i}, keys{k})
                colName = names{i};
                return;
            end
        end
    end
    error('没有找到字段。需要字段关键词：%s', strjoin(keys, ', '));
end

function x = toNumericVector(col)
    if isnumeric(col)
        x = double(col);
    elseif iscell(col)
        x = str2double(string(col));
    elseif isstring(col)
        x = str2double(col);
    elseif iscategorical(col)
        x = str2double(string(col));
    else
        x = str2double(string(col));
    end
    x = x(:);
end

function [lat, lon, swapCount] = parseGPSAutoCount( ...
    gpsCol, taskLatCenter, taskLonCenter)

    gpsString = string(gpsCol);
    n = length(gpsString);
    lat = nan(n, 1);
    lon = nan(n, 1);
    swapCount = 0;

    for i = 1:n
        numbers = regexp(gpsString(i), '[-+]?\d+\.?\d*', 'match');
        if length(numbers) < 2
            continue;
        end

        a = str2double(numbers{1});
        b = str2double(numbers{2});

        lat1 = a;
        lon1 = b;
        lat2 = b;
        lon2 = a;

        valid1 = isValidLatLon(lat1, lon1);
        valid2 = isValidLatLon(lat2, lon2);
        distance1 = inf;
        distance2 = inf;

        if valid1
            distance1 = geoDistanceKm( ...
                taskLatCenter, taskLonCenter, lat1, lon1);
        end
        if valid2
            distance2 = geoDistanceKm( ...
                taskLatCenter, taskLonCenter, lat2, lon2);
        end

        if distance1 <= distance2
            lat(i) = lat1;
            lon(i) = lon1;
        else
            lat(i) = lat2;
            lon(i) = lon2;
            swapCount = swapCount + 1;
        end
    end
end

function flag = isValidLatLon(lat, lon)
    flag = ~isnan(lat) && ~isnan(lon) && ...
        lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180;
end

function d = geoDistanceKm(lat1, lon1, lat2, lon2)
    d = 111 * sqrt((lat1 - lat2) .^ 2 + ...
        ((lon1 - lon2) .* cosd(lat1)) .^ 2);
end

function [dMin, memberCount, avgCredit, avgQuota, ...
    taskDensity, competitionIndex] = constructTaskFeatures( ...
    taskLat, taskLon, memberLat, memberLon, quota, credit, ...
    rMember, rTask)

    n = length(taskLat);
    dMin = zeros(n, 1);
    memberCount = zeros(n, 1);
    creditSum = zeros(n, 1);
    quotaSum = zeros(n, 1);

    for i = 1:n
        distanceMember = geoDistanceKm( ...
            taskLat(i), taskLon(i), memberLat, memberLon);
        dMin(i) = min(distanceMember);
        nearby = distanceMember <= rMember;
        memberCount(i) = sum(nearby);
        creditSum(i) = sum(credit(nearby));
        quotaSum(i) = sum(quota(nearby));
    end

    avgCredit = creditSum ./ max(memberCount, 1);
    avgQuota = quotaSum ./ max(memberCount, 1);

    taskDensity = zeros(n, 1);
    for i = 1:n
        distanceTask = geoDistanceKm( ...
            taskLat(i), taskLon(i), taskLat, taskLon);
        taskDensity(i) = sum(distanceTask <= rTask) - 1;
    end

    competitionIndex = taskDensity ./ max(memberCount, 1);
end

function [XStandard, muValue, sigmaValue] = standardizeData(X)
    muValue = mean(X, 1, 'omitnan');
    sigmaValue = std(X, 0, 1, 'omitnan');
    sigmaValue(sigmaValue == 0) = 1;
    XStandard = (X - muValue) ./ sigmaValue;
end

function loss = logisticNLL(alpha, X, Y)
    probability = sigmoid(X * alpha);
    probability = min(max(probability, 1e-10), 1 - 1e-10);
    loss = -sum(Y .* log(probability) + ...
        (1 - Y) .* log(1 - probability));
    loss = loss + 1e-6 * sum(alpha(2:end) .^ 2);
end

function probability = sigmoid(z)
    probability = 1 ./ (1 + exp(-z));
end

function probability = predictProbStable(price, alpha, muValue, ...
    sigmaValue, featureLower, featureUpper, dMin, memberCount, ...
    avgCredit, avgQuota, taskDensity, competitionIndex)

    price = price(:);
    pricePerDistance = price ./ (dMin + 0.1);
    pricePerCompetition = price ./ (taskDensity + 1);

    XRaw = [price, dMin, memberCount, avgCredit, avgQuota, ...
        taskDensity, competitionIndex, pricePerDistance, ...
        pricePerCompetition];

    % 将附件三特征投影到附件一的训练范围内，避免外推失真
    XRaw = bsxfun(@max, XRaw, featureLower);
    XRaw = bsxfun(@min, XRaw, featureUpper);

    XStandard = bsxfun(@rdivide, ...
        bsxfun(@minus, XRaw, muValue), sigmaValue);
    XDesign = [ones(size(XStandard, 1), 1), XStandard];
    probability = sigmoid(XDesign * alpha);
end

function [newPrice, newProb, adjustedFlag, history] = ...
    optimizeNewProjectPricing(basePrice, baseProb, targetProb, ...
    omega, etaMax, deltaMax, priceStep, alpha, muValue, sigmaValue, ...
    featureLower, featureUpper, dMin, memberCount, avgCredit, avgQuota, ...
    taskDensity, competitionIndex)

    n = length(basePrice);
    baseCost = sum(basePrice);
    baseExpectedCount = sum(baseProb);
    denominator = max(n - baseExpectedCount, 1e-8);

    candidateIndex = find(baseProb < targetProb);
    newPrice = basePrice;
    newProb = baseProb;
    adjustedFlag = false(n, 1);

    budget = etaMax * baseCost;
    usedBudget = 0;
    maxIteration = floor(budget / priceStep) + 1;

    history.step = 0;
    history.totalCost = baseCost;
    history.expectedCount = baseExpectedCount;
    history.objective = 0;

    iteration = 0;

    while iteration < maxIteration
        if usedBudget + priceStep > budget + 1e-12
            break;
        end

        movable = candidateIndex( ...
            newPrice(candidateIndex) + priceStep <= ...
            basePrice(candidateIndex) + deltaMax + 1e-9);

        if isempty(movable)
            break;
        end

        candidatePrice = newPrice(movable) + priceStep;
        candidateProb = predictProbStable(candidatePrice, alpha, ...
            muValue, sigmaValue, featureLower, featureUpper, ...
            dMin(movable), memberCount(movable), avgCredit(movable), ...
            avgQuota(movable), taskDensity(movable), ...
            competitionIndex(movable));

        deltaExpected = candidateProb - newProb(movable);
        deltaObjective = omega * deltaExpected / denominator - ...
            (1 - omega) * priceStep / baseCost;

        [bestGain, location] = max(deltaObjective);
        if bestGain <= 0
            break;
        end

        bestTask = movable(location);
        newPrice(bestTask) = newPrice(bestTask) + priceStep;
        newProb(bestTask) = candidateProb(location);
        adjustedFlag(bestTask) = true;
        usedBudget = usedBudget + priceStep;
        iteration = iteration + 1;

        if mod(iteration, 100) == 0
            currentCost = sum(newPrice);
            currentExpected = sum(newProb);
            currentObjective = omega * ...
                (currentExpected - baseExpectedCount) / denominator - ...
                (1 - omega) * (currentCost - baseCost) / baseCost;

            history.step(end + 1, 1) = iteration;
            history.totalCost(end + 1, 1) = currentCost;
            history.expectedCount(end + 1, 1) = currentExpected;
            history.objective(end + 1, 1) = currentObjective;
        end
    end

    if history.step(end) ~= iteration
        currentCost = sum(newPrice);
        currentExpected = sum(newProb);
        currentObjective = omega * ...
            (currentExpected - baseExpectedCount) / denominator - ...
            (1 - omega) * (currentCost - baseCost) / baseCost;

        history.step(end + 1, 1) = iteration;
        history.totalCost(end + 1, 1) = currentCost;
        history.expectedCount(end + 1, 1) = currentExpected;
        history.objective(end + 1, 1) = currentObjective;
    end
end

function saveFigure300(fileName)
    try
        exportgraphics(gcf, fileName, 'Resolution', 300);
    catch
        saveas(gcf, fileName);
    end
end
