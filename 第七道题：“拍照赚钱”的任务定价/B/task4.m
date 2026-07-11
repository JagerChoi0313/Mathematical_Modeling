%% 第四问：新项目任务定价
% 模型结构：
% 1. 根据附件一重新计算历史任务特征和标准化参数；
% 2. 利用第一问多元线性回归模型预测附件三任务的基础价格；
% 3. 利用第一问Logistic回归模型预测基础方案完成概率；
% 4. 利用第二问加权双目标优化模型调整新任务价格；
% 5. 输出最终定价结果、方案比较表和相关图像。
%
% 只需要以下三个文件：
% 附件一：已结束项目任务数据.xls
% 附件二：会员信息数据.xlsx
% 附件三：新项目任务数据.xls

clear;
clc;
close all;

%% 1. 自动查找附件文件

fileOldTask = findExistingFile({
    '附件一：已结束项目任务数据.xls'
    '附件一：已结束项目任务数据.xlsx'
    '附件一_已结束项目任务数据.xls'
    '附件一_已结束项目任务数据.xlsx'
    });

fileMember = findExistingFile({
    '附件二：会员信息数据.xlsx'
    '附件二：会员信息数据.xls'
    '附件二_会员信息数据.xlsx'
    '附件二_会员信息数据.xls'
    });

fileNewTask = findExistingFile({
    '附件三：新项目任务数据.xls'
    '附件三：新项目任务数据.xlsx'
    '附件三_新项目任务数据.xls'
    '附件三_新项目任务数据.xlsx'
    });

fprintf('已找到数据文件：\n');
fprintf('附件一：%s\n', fileOldTask);
fprintf('附件二：%s\n', fileMember);
fprintf('附件三：%s\n\n', fileNewTask);

%% 2. 参数设置

radiusKm = 3;          % 周边任务和会员统计半径
theta = 0.62;          % 目标完成概率阈值
omega = 0.65;          % 完成效果权重
etaMax = 0.05;         % 平台总成本最大增长率
priceStep = 0.5;       % 价格调整步长
deltaMax = 10;         % 单任务最大涨价幅度
gainTolerance = 1e-12; % 边际综合收益停止阈值

% 是否限制新任务特征不超过历史样本范围
% true：降低多元线性回归模型外推风险
% false：直接使用附件三任务的原始特征
clipFeaturesToHistory = true;

% 是否删除明显远离任务区域的会员坐标
removeFarMembers = true;

% 会员位置允许超出任务区域的经纬度范围
memberMarginDegree = 2;

fprintf('================ 第四问参数设置 ================\n');
fprintf('统计半径：%.1f km\n', radiusKm);
fprintf('目标概率阈值：%.2f\n', theta);
fprintf('完成效果权重：%.2f\n', omega);
fprintf('成本增长上限：%.2f%%\n', etaMax * 100);
fprintf('价格调整步长：%.1f元\n', priceStep);
fprintf('单任务最大涨价：%.1f元\n\n', deltaMax);

%% 3. 第一问已经求得的模型系数

% 多元线性回归模型变量顺序：
% 1 常数项
% 2 最近会员距离
% 3 周边会员数量
% 4 平均信誉值
% 5 平均预订限额
% 6 任务密度
% 7 竞争强度
% 8 任务经度
% 9 任务纬度

beta = [
     69.110778440
      0.164101199
     -1.195526452
     -0.671284992
      0.172692298
     -1.415269119
      0.198761111
     -0.073005964
      0.598954202
    ];

% Logistic回归模型变量顺序：
% 1 常数项
% 2 任务价格
% 3 最近会员距离
% 4 周边会员数量
% 5 平均信誉值
% 6 平均预订限额
% 7 任务密度
% 8 竞争强度
% 9 单位距离价格
% 10 单位竞争价格

alpha = [
      0.550455435
      0.250149617
      0.197467735
     -0.697152292
     -0.096564413
      0.319359341
      0.282381877
     -0.054041967
     -0.032891195
     -0.063063746
    ];

%% 4. 读取三个附件

Told = readtable( ...
    fileOldTask, ...
    'VariableNamingRule', 'preserve');

Tmember = readtable( ...
    fileMember, ...
    'VariableNamingRule', 'preserve');

Tnew = readtable( ...
    fileNewTask, ...
    'VariableNamingRule', 'preserve');

%% 5. 自动识别附件一的列名

oldIDName = findVariableName(Told, {
    '任务号码'
    '任务编号'
    });

oldLatName = findVariableName(Told, {
    '任务GPS纬度'
    '任务纬度'
    '纬度'
    });

oldLonName = findVariableName(Told, {
    '任务GPS经度'
    '任务经度'
    '经度'
    });

oldPriceName = findVariableName(Told, {
    '任务标价'
    '任务价格'
    '原始价格'
    '标价'
    });

%% 6. 自动识别附件二的列名

memberGPSName = findVariableName(Tmember, {
    '会员位置(GPS)'
    '会员位置'
    'GPS'
    });

memberRepName = findVariableName(Tmember, {
    '信誉值'
    '会员信誉值'
    });

memberQuotaName = findVariableName(Tmember, {
    '预订任务限额'
    '任务限额'
    '限额'
    });

%% 7. 自动识别附件三的列名

newIDName = findVariableName(Tnew, {
    '任务号码'
    '任务编号'
    });

newLatName = findVariableName(Tnew, {
    '任务GPS纬度'
    '任务纬度'
    '纬度'
    });

newLonName = findVariableName(Tnew, {
    '任务GPS经度'
    '任务经度'
    '经度'
    });

%% 8. 提取附件一历史任务

oldTaskID = string(Told.(oldIDName));
oldTaskLat = columnToDouble(Told.(oldLatName));
oldTaskLon = columnToDouble(Told.(oldLonName));
oldPrice = columnToDouble(Told.(oldPriceName));

validOldTask = ...
    isfinite(oldTaskLat) & ...
    isfinite(oldTaskLon) & ...
    isfinite(oldPrice) & ...
    abs(oldTaskLat) <= 90 & ...
    abs(oldTaskLon) <= 180;

if any(~validOldTask)

    fprintf('附件一删除无效任务记录：%d条\n', ...
        sum(~validOldTask));

    oldTaskID = oldTaskID(validOldTask);
    oldTaskLat = oldTaskLat(validOldTask);
    oldTaskLon = oldTaskLon(validOldTask);
    oldPrice = oldPrice(validOldTask);
end

nOld = numel(oldPrice);

%% 9. 提取附件三新任务

taskID = string(Tnew.(newIDName));
taskLat = columnToDouble(Tnew.(newLatName));
taskLon = columnToDouble(Tnew.(newLonName));

validNewTask = ...
    isfinite(taskLat) & ...
    isfinite(taskLon) & ...
    abs(taskLat) <= 90 & ...
    abs(taskLon) <= 180;

if any(~validNewTask)

    fprintf('附件三删除无效任务记录：%d条\n', ...
        sum(~validNewTask));

    taskID = taskID(validNewTask);
    taskLat = taskLat(validNewTask);
    taskLon = taskLon(validNewTask);
end

n = numel(taskID);

fprintf('附件一有效历史任务：%d个\n', nOld);
fprintf('附件三有效新任务：%d个\n\n', n);

%% 10. 解析附件二会员GPS

gpsText = string(Tmember.(memberGPSName));

memberRep = columnToDouble(Tmember.(memberRepName));
memberQuota = columnToDouble(Tmember.(memberQuotaName));

memberLat = nan(height(Tmember), 1);
memberLon = nan(height(Tmember), 1);

for i = 1:height(Tmember)

    currentText = char(gpsText(i));

    numberText = regexp( ...
        currentText, ...
        '[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?', ...
        'match');

    if numel(numberText) >= 2

        value1 = str2double(numberText{1});
        value2 = str2double(numberText{2});

        memberLat(i) = value1;
        memberLon(i) = value2;
    end
end

% 修正类似"113.xxx 23.xxx"的经纬度颠倒情况
swapMask = ...
    abs(memberLat) > 90 & ...
    abs(memberLon) <= 90;

temporaryValue = memberLat(swapMask);
memberLat(swapMask) = memberLon(swapMask);
memberLon(swapMask) = temporaryValue;

basicValidMember = ...
    isfinite(memberLat) & ...
    isfinite(memberLon) & ...
    isfinite(memberRep) & ...
    isfinite(memberQuota) & ...
    abs(memberLat) <= 90 & ...
    abs(memberLon) <= 180;

fprintf('会员GPS经纬度颠倒修正：%d条\n', sum(swapMask));
fprintf('会员基础无效记录：%d条\n', sum(~basicValidMember));

%% 11. 删除明显远离任务区域的会员点

allTaskLat = [oldTaskLat; taskLat];
allTaskLon = [oldTaskLon; taskLon];

minTaskLat = min(allTaskLat);
maxTaskLat = max(allTaskLat);
minTaskLon = min(allTaskLon);
maxTaskLon = max(allTaskLon);

if removeFarMembers

    regionValidMember = ...
        memberLat >= minTaskLat - memberMarginDegree & ...
        memberLat <= maxTaskLat + memberMarginDegree & ...
        memberLon >= minTaskLon - memberMarginDegree & ...
        memberLon <= maxTaskLon + memberMarginDegree;

else

    regionValidMember = true(size(memberLat));
end

validMember = basicValidMember & regionValidMember;

fprintf('明显远离任务区域的会员记录：%d条\n', ...
    sum(basicValidMember & ~regionValidMember));

memberLat = memberLat(validMember);
memberLon = memberLon(validMember);
memberRep = memberRep(validMember);
memberQuota = memberQuota(validMember);

m = numel(memberLat);

fprintf('最终保留有效会员：%d个\n\n', m);

if m == 0
    error('没有可用会员数据，请检查附件二的会员GPS格式。');
end

%% 12. 重新计算附件一历史任务特征

fprintf('正在计算附件一历史任务特征，请稍候...\n');

[oldNearestMemberDist, ...
 oldNearMemberCount, ...
 oldAvgReputation, ...
 oldAvgQuota, ...
 oldTaskDensity, ...
 oldCompetition] = buildTaskFeatures( ...
    oldTaskLat, ...
    oldTaskLon, ...
    memberLat, ...
    memberLon, ...
    memberRep, ...
    memberQuota, ...
    radiusKm);

fprintf('附件一历史任务特征计算完成。\n\n');

%% 13. 计算附件三新任务特征

fprintf('正在计算附件三新任务特征，请稍候...\n');

[nearestMemberDist, ...
 nearMemberCount, ...
 avgReputation, ...
 avgQuota, ...
 taskDensity, ...
 competition] = buildTaskFeatures( ...
    taskLat, ...
    taskLon, ...
    memberLat, ...
    memberLon, ...
    memberRep, ...
    memberQuota, ...
    radiusKm);

fprintf('附件三新任务特征计算完成。\n\n');

%% 14. 构造多元线性回归历史特征矩阵

XpriceHist = [
    oldNearestMemberDist, ...
    oldNearMemberCount, ...
    oldAvgReputation, ...
    oldAvgQuota, ...
    oldTaskDensity, ...
    oldCompetition, ...
    oldTaskLon, ...
    oldTaskLat
    ];

muPrice = mean(XpriceHist, 1);
sdPrice = std(XpriceHist, 0, 1);

sdPrice(sdPrice == 0) = 1;

histFeatureMin = min(XpriceHist, [], 1);
histFeatureMax = max(XpriceHist, [], 1);

%% 15. 构造附件三定价模型输入

XpriceNew = [
    nearestMemberDist, ...
    nearMemberCount, ...
    avgReputation, ...
    avgQuota, ...
    taskDensity, ...
    competition, ...
    taskLon, ...
    taskLat
    ];

featureNames = [
    "最近会员距离"
    "周边会员数量"
    "平均信誉值"
    "平均预订限额"
    "任务密度"
    "竞争强度"
    "任务经度"
    "任务纬度"
    ];

outsideMask = ...
    XpriceNew < histFeatureMin | ...
    XpriceNew > histFeatureMax;

outsideCount = sum(outsideMask, 1);

fprintf('附件三特征超出历史样本范围的任务数量：\n');

for j = 1:numel(featureNames)

    fprintf('%s：%d个\n', ...
        featureNames(j), outsideCount(j));
end

if clipFeaturesToHistory

    XpriceModel = min( ...
        max(XpriceNew, histFeatureMin), ...
        histFeatureMax);

    fprintf('已对超出历史范围的特征进行边界修正。\n\n');

else

    XpriceModel = XpriceNew;

    fprintf('未进行特征边界修正，模型直接外推。\n\n');
end

%% 16. 利用多元线性回归模型预测基础价格

ZpriceNew = ...
    (XpriceModel - muPrice) ./ sdPrice;

basePriceRaw = ...
    beta(1) + ZpriceNew * beta(2:end);

histPriceMin = min(oldPrice);
histPriceMax = max(oldPrice);

% 将预测价格限制在历史价格合理范围内
basePrice = min( ...
    max(basePriceRaw, histPriceMin), ...
    histPriceMax);

% 将任务价格调整为0.5元的整数倍
basePrice = round(basePrice / priceStep) * priceStep;

lowerClampCount = sum(basePriceRaw < histPriceMin);
upperClampCount = sum(basePriceRaw > histPriceMax);

fprintf('---------------- 基础价格预测 ----------------\n');
fprintf('修正前预测价格范围：[%.4f，%.4f]\n', ...
    min(basePriceRaw), max(basePriceRaw));

fprintf('历史任务价格范围：[%.2f，%.2f]\n', ...
    histPriceMin, histPriceMax);

fprintf('触发历史价格下限：%d个任务\n', ...
    lowerClampCount);

fprintf('触发历史价格上限：%d个任务\n\n', ...
    upperClampCount);

%% 17. 恢复Logistic模型历史标准化参数

oldUnitDistancePrice = ...
    oldPrice ./ (oldNearestMemberDist + 0.1);

oldUnitCompetitionPrice = ...
    oldPrice ./ (oldTaskDensity + 1);

XlogitHist = [
    oldPrice, ...
    oldNearestMemberDist, ...
    oldNearMemberCount, ...
    oldAvgReputation, ...
    oldAvgQuota, ...
    oldTaskDensity, ...
    oldCompetition, ...
    oldUnitDistancePrice, ...
    oldUnitCompetitionPrice
    ];

muLogit = mean(XlogitHist, 1);
sdLogit = std(XlogitHist, 0, 1);

sdLogit(sdLogit == 0) = 1;

%% 18. 计算基础定价方案的预测完成概率

baseProb = predictProbability( ...
    basePrice, ...
    nearestMemberDist, ...
    nearMemberCount, ...
    avgReputation, ...
    avgQuota, ...
    taskDensity, ...
    competition, ...
    muLogit, ...
    sdLogit, ...
    alpha);

C0 = sum(basePrice);
M0 = sum(baseProb);
R0 = mean(baseProb >= theta);
L0 = sum(baseProb < theta);

fprintf('---------------- 基础定价方案 ----------------\n');
fprintf('基础方案总成本：%.4f\n', C0);
fprintf('基础方案平均价格：%.4f\n', mean(basePrice));
fprintf('基础方案期望完成任务数：%.4f\n', M0);
fprintf('基础方案预测完成率：%.2f%%\n', R0 * 100);
fprintf('基础方案低完成概率任务数：%d\n\n', L0);

%% 19. 初始化加权双目标优化

currentPrice = basePrice;
currentProb = baseProb;
currentCost = C0;
currentExpected = M0;

maxCost = (1 + etaMax) * C0;

% 基础方案下低于阈值的任务进入调价集合
originalCandidate = baseProb < theta;

maxIterations = ...
    floor((maxCost - C0) / priceStep) + 10;

iterRecord = zeros(maxIterations, 5);

iter = 0;

denominatorM = max(n - M0, eps);

stopReason = '达到停止条件';

fprintf('正在执行第四问加权双目标优化...\n');

%% 20. 加权双目标优化循环

while true

    % 剩余预算无法支持一次涨价
    if currentCost + priceStep > maxCost + 1e-10

        stopReason = '平台剩余预算不足';

        break;
    end

    % 基础概率低于阈值且未达到最大涨价幅度
    candidateIndex = find( ...
        originalCandidate & ...
        currentPrice + priceStep ...
        <= basePrice + deltaMax + 1e-10);

    if isempty(candidateIndex)

        stopReason = ...
            '候选任务为空或均达到最大涨价幅度';

        break;
    end

    % 模拟每个候选任务价格增加0.5元
    trialPrice = ...
        currentPrice(candidateIndex) + priceStep;

    trialProb = predictProbability( ...
        trialPrice, ...
        nearestMemberDist(candidateIndex), ...
        nearMemberCount(candidateIndex), ...
        avgReputation(candidateIndex), ...
        avgQuota(candidateIndex), ...
        taskDensity(candidateIndex), ...
        competition(candidateIndex), ...
        muLogit, ...
        sdLogit, ...
        alpha);

    deltaProb = ...
        trialProb - currentProb(candidateIndex);

    % 边际综合收益
    marginalGain = ...
        omega .* deltaProb ./ denominatorM ...
        - ...
        (1 - omega) .* priceStep ./ C0;

    [bestGain, localBestIndex] = max(marginalGain);

    if isempty(bestGain) || bestGain <= gainTolerance

        stopReason = ...
            '所有候选任务的边际综合收益均不为正';

        break;
    end

    bestTask = candidateIndex(localBestIndex);

    % 接受本轮价格调整
    currentPrice(bestTask) = ...
        currentPrice(bestTask) + priceStep;

    currentProb(bestTask) = ...
        trialProb(localBestIndex);

    currentCost = ...
        currentCost + priceStep;

    currentExpected = ...
        currentExpected + deltaProb(localBestIndex);

    iter = iter + 1;

    currentJ = ...
        omega .* ...
        (currentExpected - M0) ./ denominatorM ...
        - ...
        (1 - omega) .* ...
        (currentCost - C0) ./ C0;

    iterRecord(iter, :) = [
        iter, ...
        currentCost, ...
        currentExpected, ...
        currentJ, ...
        sum(currentProb < theta)
        ];

    if mod(iter, 500) == 0

        fprintf(['已迭代%d次，当前总成本为%.2f，' ...
            '期望完成任务数为%.4f。\n'], ...
            iter, currentCost, currentExpected);
    end
end

iterRecord = iterRecord(1:iter, :);

%% 21. 计算最终优化结果

finalPrice = currentPrice;
finalProb = currentProb;

C = sum(finalPrice);
M = sum(finalProb);
R = mean(finalProb >= theta);
L = sum(finalProb < theta);

adjustedCount = ...
    sum(finalPrice > basePrice + 1e-10);

Jfinal = ...
    omega .* ...
    (M - M0) ./ denominatorM ...
    - ...
    (1 - omega) .* ...
    (C - C0) ./ C0;

if C > C0

    unitCostEffect = ...
        (M - M0) / (C - C0);

else

    unitCostEffect = NaN;
end

fprintf('\n---------------- 优化定价方案 ----------------\n');
fprintf('停止原因：%s\n', stopReason);
fprintf('迭代次数：%d\n', iter);
fprintf('优化方案总成本：%.4f\n', C);
fprintf('优化方案平均价格：%.4f\n', mean(finalPrice));
fprintf('成本增加量：%.4f\n', C - C0);
fprintf('成本增长率：%.2f%%\n', ...
    100 * (C - C0) / C0);

fprintf('优化方案期望完成任务数：%.4f\n', M);
fprintf('期望完成任务数增加：%.4f\n', M - M0);

fprintf('优化方案预测完成率：%.2f%%\n', R * 100);
fprintf('预测完成率提高：%.2f个百分点\n', ...
    100 * (R - R0));

fprintf('优化方案低完成概率任务数：%d\n', L);
fprintf('低完成概率任务数减少：%d\n', L0 - L);

fprintf('调价任务数量：%d\n', adjustedCount);
fprintf('综合目标函数值：%.8f\n', Jfinal);
fprintf('单位新增成本期望提升：%.8f\n\n', ...
    unitCostEffect);

%% 22. 输出每个新任务的定价结果

priceIncrease = finalPrice - basePrice;
probIncrease = finalProb - baseProb;

baseReached = double(baseProb >= theta);
finalReached = double(finalProb >= theta);
isAdjusted = double(priceIncrease > 1e-10);

Tresult = table( ...
    taskID, ...
    taskLat, ...
    taskLon, ...
    nearestMemberDist, ...
    nearMemberCount, ...
    avgReputation, ...
    avgQuota, ...
    taskDensity, ...
    competition, ...
    basePriceRaw, ...
    basePrice, ...
    finalPrice, ...
    priceIncrease, ...
    baseProb, ...
    finalProb, ...
    probIncrease, ...
    baseReached, ...
    finalReached, ...
    isAdjusted, ...
    'VariableNames', {
    '任务编号'
    '任务纬度'
    '任务经度'
    '最近会员距离'
    '周边会员数量'
    '平均信誉值'
    '平均预订限额'
    '任务密度'
    '竞争强度'
    '回归原始预测价格'
    '基础预测价格'
    '最终优化价格'
    '价格增加量'
    '基础预测完成概率'
    '优化预测完成概率'
    '预测概率提升量'
    '基础方案是否达标'
    '优化方案是否达标'
    '是否调价'
    });

writetable( ...
    Tresult, ...
    'Q4_新项目最终定价结果.xlsx');

%% 23. 输出基础方案和优化方案比较表

metricNames = [
    "总成本"
    "平均价格"
    "期望完成任务数"
    "预测完成率"
    "低完成概率任务数"
    "调价任务数量"
    "综合目标函数值"
    "单位新增成本期望提升"
    ];

baseValues = [
    C0
    mean(basePrice)
    M0
    R0 * 100
    L0
    0
    0
    NaN
    ];

finalValues = [
    C
    mean(finalPrice)
    M
    R * 100
    L
    adjustedCount
    Jfinal
    unitCostEffect
    ];

changeValues = finalValues - baseValues;

Tcompare = table( ...
    metricNames, ...
    baseValues, ...
    finalValues, ...
    changeValues, ...
    'VariableNames', {
    '指标'
    '基础定价方案'
    '优化定价方案'
    '变化量'
    });

writetable( ...
    Tcompare, ...
    'Q4_基础方案与优化方案比较表.xlsx');

%% 24. 输出优化过程

if iter > 0

    Tprocess = array2table( ...
        iterRecord, ...
        'VariableNames', {
        '迭代次数'
        '当前总成本'
        '期望完成任务数'
        '综合目标函数J'
        '低完成概率任务数'
        });

    writetable( ...
        Tprocess, ...
        'Q4_优化过程记录.xlsx');
end

%% 25. 输出模型标准化参数

TpriceParameter = table( ...
    featureNames, ...
    muPrice(:), ...
    sdPrice(:), ...
    histFeatureMin(:), ...
    histFeatureMax(:), ...
    'VariableNames', {
    '定价模型变量'
    '历史均值'
    '历史标准差'
    '历史最小值'
    '历史最大值'
    });

logitVariableNames = [
    "任务价格"
    "最近会员距离"
    "周边会员数量"
    "平均信誉值"
    "平均预订限额"
    "任务密度"
    "竞争强度"
    "单位距离价格"
    "单位竞争价格"
    ];

TlogitParameter = table( ...
    logitVariableNames, ...
    muLogit(:), ...
    sdLogit(:), ...
    'VariableNames', {
    'Logistic模型变量'
    '历史均值'
    '历史标准差'
    });

writetable( ...
    TpriceParameter, ...
    'Q4_模型标准化参数.xlsx', ...
    'Sheet', ...
    '定价模型参数');

writetable( ...
    TlogitParameter, ...
    'Q4_模型标准化参数.xlsx', ...
    'Sheet', ...
    'Logistic模型参数');

%% 26. 图1：基础价格与优化价格对比

figure('Color', 'w');

scatter( ...
    basePrice, ...
    finalPrice, ...
    25, ...
    'filled');

hold on;

lineMin = min([basePrice; finalPrice]);
lineMax = max([basePrice; finalPrice]);

plot( ...
    [lineMin, lineMax], ...
    [lineMin, lineMax], ...
    'LineWidth', 1.5);

grid on;

xlabel('基础预测价格');
ylabel('优化后任务价格');
title('新项目基础价格与优化价格对比图');

saveas( ...
    gcf, ...
    'Q4_基础价格与优化价格对比图.png');

%% 27. 图2：预测完成概率对比

figure('Color', 'w');

scatter( ...
    baseProb, ...
    finalProb, ...
    25, ...
    'filled');

hold on;

plot( ...
    [0, 1], ...
    [0, 1], ...
    'LineWidth', 1.5);

plot( ...
    [theta, theta], ...
    [0, 1], ...
    '--', ...
    'LineWidth', 1.2);

plot( ...
    [0, 1], ...
    [theta, theta], ...
    '--', ...
    'LineWidth', 1.2);

xlim([0, 1]);
ylim([0, 1]);

grid on;

xlabel('基础方案预测完成概率');
ylabel('优化方案预测完成概率');
title('新项目优化前后预测完成概率对比图');

saveas( ...
    gcf, ...
    'Q4_优化前后预测完成概率对比图.png');

%% 28. 图3：调价任务空间分布

figure('Color', 'w');

adjustedMask = isAdjusted == 1;

scatter( ...
    taskLon(~adjustedMask), ...
    taskLat(~adjustedMask), ...
    18, ...
    'filled');

hold on;

if any(adjustedMask)

    scatter( ...
        taskLon(adjustedMask), ...
        taskLat(adjustedMask), ...
        28, ...
        priceIncrease(adjustedMask), ...
        'filled');

    colorbar;

    legend( ...
        '未调价任务', ...
        '调价任务', ...
        'Location', ...
        'best');

else

    legend( ...
        '未调价任务', ...
        'Location', ...
        'best');
end

grid on;

xlabel('经度');
ylabel('纬度');
title('新项目调价任务空间分布图');

saveas( ...
    gcf, ...
    'Q4_调价任务空间分布图.png');

%% 29. 图4：低完成概率任务数量对比

figure('Color', 'w');

bar([L0, L]);

set( ...
    gca, ...
    'XTickLabel', ...
    {'基础方案', '优化方案'});

ylabel('低完成概率任务数');
title('新项目低完成概率任务数对比图');

grid on;

saveas( ...
    gcf, ...
    'Q4_低完成概率任务数对比图.png');

%% 30. 图5：优化过程

if iter > 0

    figure('Color', 'w');

    yyaxis left;

    plot( ...
        iterRecord(:, 1), ...
        iterRecord(:, 2), ...
        'LineWidth', ...
        1.5);

    ylabel('平台总成本');

    yyaxis right;

    plot( ...
        iterRecord(:, 1), ...
        iterRecord(:, 3), ...
        'LineWidth', ...
        1.5);

    ylabel('期望完成任务数');

    xlabel('迭代次数');
    title('新项目多目标定价优化过程图');

    grid on;

    saveas( ...
        gcf, ...
        'Q4_多目标定价优化过程图.png');
end

%% 31. 程序结束提示

fprintf('\n程序运行完成，已生成以下结果：\n');
fprintf('1. Q4_新项目最终定价结果.xlsx\n');
fprintf('2. Q4_基础方案与优化方案比较表.xlsx\n');
fprintf('3. Q4_优化过程记录.xlsx\n');
fprintf('4. Q4_模型标准化参数.xlsx\n');
fprintf('5. Q4_基础价格与优化价格对比图.png\n');
fprintf('6. Q4_优化前后预测完成概率对比图.png\n');
fprintf('7. Q4_调价任务空间分布图.png\n');
fprintf('8. Q4_低完成概率任务数对比图.png\n');
fprintf('9. Q4_多目标定价优化过程图.png\n');

%% =========================================================
%% 局部函数
%% =========================================================

function fileName = findExistingFile(candidateNames)
% 在当前文件夹中依次查找候选文件名

    fileName = '';

    for i = 1:numel(candidateNames)

        currentName = candidateNames{i};

        if isfile(currentName)

            fileName = currentName;

            return;
        end
    end

    fprintf('\n当前文件夹中的Excel文件有：\n');

    fileList1 = dir('*.xls');
    fileList2 = dir('*.xlsx');
    fileList = [fileList1; fileList2];

    for i = 1:numel(fileList)

        fprintf('%s\n', fileList(i).name);
    end

    error(['没有找到所需附件。请检查文件名，' ...
        '并将附件与MATLAB代码放在同一文件夹中。']);
end

function variableName = findVariableName(T, candidateNames)
% 根据候选名称自动识别表格中的列名

    tableNames = string(T.Properties.VariableNames);
    variableName = '';

    % 优先进行完全匹配
    for i = 1:numel(candidateNames)

        currentName = string(candidateNames{i});

        index = find( ...
            strcmp(tableNames, currentName), ...
            1);

        if ~isempty(index)

            variableName = char(tableNames(index));

            return;
        end
    end

    % 完全匹配失败后，进行包含匹配
    for i = 1:numel(candidateNames)

        currentName = string(candidateNames{i});

        index = find( ...
            contains(tableNames, currentName), ...
            1);

        if ~isempty(index)

            variableName = char(tableNames(index));

            return;
        end
    end

    fprintf('\n当前表格包含以下列名：\n');

    for i = 1:numel(tableNames)

        fprintf('%s\n', tableNames(i));
    end

    error('没有找到需要的列，请检查附件中的表头名称。');
end

function value = columnToDouble(inputColumn)
% 将数值列、字符串列或单元格列统一转成double列向量

    if isnumeric(inputColumn)

        value = double(inputColumn);

    else

        value = str2double(string(inputColumn));
    end

    value = value(:);
end

function [nearestDistance, ...
          nearbyMemberNumber, ...
          averageReputation, ...
          averageQuota, ...
          taskDensity, ...
          competition] = buildTaskFeatures( ...
    taskLat, ...
    taskLon, ...
    memberLat, ...
    memberLon, ...
    memberReputation, ...
    memberQuota, ...
    radiusKm)
% 计算任务的会员资源特征、任务密度和竞争强度

    taskNumber = numel(taskLat);

    nearestDistance = zeros(taskNumber, 1);
    nearbyMemberNumber = zeros(taskNumber, 1);
    averageReputation = zeros(taskNumber, 1);
    averageQuota = zeros(taskNumber, 1);
    taskDensity = zeros(taskNumber, 1);

    % 计算任务与会员之间的关系
    for i = 1:taskNumber

        distanceToMember = geoDistanceApprox( ...
            taskLat(i), ...
            taskLon(i), ...
            memberLat, ...
            memberLon);

        nearestDistance(i) = ...
            min(distanceToMember);

        nearbyMask = ...
            distanceToMember <= radiusKm;

        nearbyMemberNumber(i) = ...
            sum(nearbyMask);

        if nearbyMemberNumber(i) > 0

            averageReputation(i) = ...
                mean(memberReputation(nearbyMask));

            averageQuota(i) = ...
                mean(memberQuota(nearbyMask));

        else

            averageReputation(i) = 0;
            averageQuota(i) = 0;
        end
    end

    % 计算任务密度
    for i = 1:taskNumber

        distanceToTask = geoDistanceApprox( ...
            taskLat(i), ...
            taskLon(i), ...
            taskLat, ...
            taskLon);

        taskDensity(i) = ...
            sum(distanceToTask <= radiusKm) - 1;
    end

    % 计算竞争强度
    competition = ...
        taskDensity ./ max(nearbyMemberNumber, 1);
end

function distance = geoDistanceApprox( ...
    lat0, ...
    lon0, ...
    lat, ...
    lon)
% 根据经纬度计算近似地理距离，单位为km

    distance = 111 .* sqrt( ...
        (lat0 - lat).^2 + ...
        ((lon0 - lon) .* cosd(lat0)).^2);
end

function probability = predictProbability( ...
    price, ...
    nearestDistance, ...
    memberCount, ...
    averageReputation, ...
    averageQuota, ...
    density, ...
    competition, ...
    muLogit, ...
    sdLogit, ...
    alpha)
% 使用第一问Logistic模型计算任务预测完成概率

    price = price(:);
    nearestDistance = nearestDistance(:);
    memberCount = memberCount(:);
    averageReputation = averageReputation(:);
    averageQuota = averageQuota(:);
    density = density(:);
    competition = competition(:);

    % 与任务价格有关的两个变量需要重新计算
    unitDistancePrice = ...
        price ./ (nearestDistance + 0.1);

    unitCompetitionPrice = ...
        price ./ (density + 1);

    X = [
        price, ...
        nearestDistance, ...
        memberCount, ...
        averageReputation, ...
        averageQuota, ...
        density, ...
        competition, ...
        unitDistancePrice, ...
        unitCompetitionPrice
        ];

    % 使用历史样本的均值和标准差进行标准化
    Xstandard = ...
        (X - muLogit) ./ sdLogit;

    linearValue = ...
        alpha(1) + Xstandard * alpha(2:end);

    % 防止指数运算溢出
    linearValue = ...
        max(min(linearValue, 700), -700);

    probability = ...
        1 ./ (1 + exp(-linearValue));
end