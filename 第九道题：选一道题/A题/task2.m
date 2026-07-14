%% 问题二前置分析：402家供应商未来供货能力分析
% 功能：
% 1. 读取附件1中402家供应商近5年（240周）的订货量和供货量；
% 2. 计算每家供应商的供货规模、供货响应、供货稳定性及供订关系；
% 3. 分年度分析供货能力变化，计算趋势斜率与近期能力；
% 4. 给出后续第二问可使用的多组供货能力候选参数；
% 5. 输出中文Excel结果、中文图像和命令行统计结果。
%
% 本程序只完成"供货能力估计与诊断"，不直接求解最少供应商数量，
% 也不直接生成未来24周订购方案。
%
% 后续模型可重点使用以下参数：
% （1）期望供货能力：
%       有订货周内实际供货量的平均值（未供货周按0计入）。
%
% （2）风险调整保守供货能力：
%       订货完成率 × 实际供货量20%分位数（仅在正供货周内计算）。
%       该指标同时考虑断供概率和低位供货水平，但不是严格的概率保证下界。
%
% （3）稳健供货上限：
%       实际供货量90%分位数（仅在正供货周内计算），避免直接使用极端最大值。
%
% （4）订货响应系数：
%       有订货周逐周供货率的10%双侧截尾均值。
%
% （5）未来供货响应函数候选：
%       预计供货量 = min(订货响应系数 × 订货量, 稳健供货上限)。
%
% 输出文件：
% 问题二_供应商未来供货能力分析.xlsx
% 问题二_期望供货能力前50名.png
% 问题二_风险调整供货能力前50名.png
% 问题二_五年总体供订变化.png

clear;
clc;
close all;

%% 1. 参数设置
defaultInputFile = '附件1 近5年402家供应商的相关数据.xlsx';
outputFile = '问题二_供应商未来供货能力分析.xlsx';

figureExpected = '问题二_期望供货能力前50名.png';
figureConservative = '问题二_风险调整供货能力前50名.png';
figureAnnual = '问题二_五年总体供订变化.png';

orderSheet = '企业的订货量（m³）';
supplySheet = '供应商的供货量（m³）';

weeksPerYear = 48;
numberOfYears = 5;

% 分位数参数
lowerPercentile = 20;       % 正供货周低位分位数
upperPercentile = 90;       % 正供货周稳健上限分位数
trimFraction = 0.10;        % 逐周供货率双侧10%截尾

% 近期年度时间权重：越接近当前，权重越大
yearWeights = (1:numberOfYears)';
yearWeights = yearWeights / sum(yearWeights);

%% 2. 自动查找附件1
inputFile = defaultInputFile;

if ~isfile(inputFile)
    candidateFiles = dir('附件1*供应商*.xlsx');

    if numel(candidateFiles) == 1
        inputFile = candidateFiles(1).name;
        fprintf('未找到默认文件名，已自动使用：%s\n', inputFile);
    elseif isempty(candidateFiles)
        error('未找到附件1。请将本程序与附件1 Excel文件放在同一文件夹。');
    else
        fprintf('检测到多个可能的附件1文件：\n');
        for f = 1:numel(candidateFiles)
            fprintf('  %d. %s\n', f, candidateFiles(f).name);
        end
        error('请在程序开头将defaultInputFile修改为需要使用的准确文件名。');
    end
end

%% 3. 读取订货量和供货量
orderCell = readcell(inputFile, 'Sheet', orderSheet);
supplyCell = readcell(inputFile, 'Sheet', supplySheet);

if size(orderCell,2) < 3 || size(supplyCell,2) < 3
    error('工作表结构异常，未读取到完整的供应商信息和周数据。');
end

% 删除供应商编号为空的尾部空白行
orderIDAll = strtrim(string(orderCell(2:end,1)));
supplyIDAll = strtrim(string(supplyCell(2:end,1)));

orderValidRow = strlength(orderIDAll) > 0 & ~ismissing(orderIDAll);
supplyValidRow = strlength(supplyIDAll) > 0 & ~ismissing(supplyIDAll);

orderCell = [orderCell(1,:); orderCell(find(orderValidRow)+1,:)];
supplyCell = [supplyCell(1,:); supplyCell(find(supplyValidRow)+1,:)];

supplierID = strtrim(string(orderCell(2:end,1)));
materialType = upper(strtrim(string(orderCell(2:end,2))));

supplyID = strtrim(string(supplyCell(2:end,1)));
supplyMaterialType = upper(strtrim(string(supplyCell(2:end,2))));

% 检查重复供应商编号
if numel(unique(supplierID)) ~= numel(supplierID)
    error('订货量工作表中存在重复的供应商编号。');
end
if numel(unique(supplyID)) ~= numel(supplyID)
    error('供货量工作表中存在重复的供应商编号。');
end

% 按订货量表顺序重新排列供货量表
[isFound, supplyLocation] = ismember(supplierID, supplyID);

if any(~isFound)
    missingSupplier = strjoin(cellstr(supplierID(~isFound)), '、');
    error('供货量工作表中缺少以下供应商：%s', missingSupplier);
end

supplyCell = [supplyCell(1,:); supplyCell(supplyLocation+1,:)];
supplyMaterialType = supplyMaterialType(supplyLocation);

if any(materialType ~= supplyMaterialType)
    error('同一供应商在订货量表与供货量表中的材料类别不一致。');
end

orderData = localCellBlockToDouble(orderCell(2:end,3:end), '订货量');
supplyData = localCellBlockToDouble(supplyCell(2:end,3:end), '供货量');

[nSuppliers, nWeeks] = size(orderData);

if ~isequal(size(orderData), size(supplyData))
    error('订货量矩阵与供货量矩阵的维度不一致。');
end
if any(orderData(:) < 0) || any(supplyData(:) < 0)
    error('原始数据中存在负数订货量或供货量。');
end
if nSuppliers ~= 402
    warning('当前读取到%d家供应商，题目理论值为402家。', nSuppliers);
end
if nWeeks ~= weeksPerYear * numberOfYears
    error('当前读取到%d周数据，无法按照每年%d周划分为%d年。', ...
        nWeeks, weeksPerYear, numberOfYears);
end

validType = materialType=="A" | materialType=="B" | materialType=="C";
if any(~validType)
    wrongType = unique(materialType(~validType));
    error('存在无法识别的材料类别：%s', strjoin(cellstr(wrongType), '、'));
end

%% 4. 数据一致性核验
orderedMask = orderData > 0;
suppliedMask = supplyData > 0;

% 检查是否存在无订货却供货的记录
unexpectedSupplyMask = (~orderedMask) & suppliedMask;
unexpectedSupplyCount = sum(unexpectedSupplyMask(:));

% 基础统计
totalOrder = sum(orderData,2);
totalSupply = sum(supplyData,2);
orderWeeks = sum(orderedMask,2);
supplyWeeks = sum(suppliedMask,2);
completedOrderWeeks = sum(orderedMask & suppliedMask,2);

if any(totalOrder <= 0)
    error('存在累计订货量为0的供应商，无法开展供货能力分析。');
end
if any(orderWeeks <= 0)
    error('存在订货周数为0的供应商，无法开展供货能力分析。');
end
if any(supplyWeeks <= 0)
    error('存在从未实际供货的供应商，部分能力指标无法计算。');
end

%% 5. 产能当量换算系数
% 每生产1立方米产品需要：
% A类0.60立方米，B类0.66立方米，C类0.72立方米。
materialConsumption = zeros(nSuppliers,1);
materialConsumption(materialType=="A") = 0.60;
materialConsumption(materialType=="B") = 0.66;
materialConsumption(materialType=="C") = 0.72;

%% 6. 初始化供应商总体能力指标
meanSupplyOnOrderWeeks = zeros(nSuppliers,1);
medianSupplyOnOrderWeeks = zeros(nSuppliers,1);

meanPositiveSupply = zeros(nSuppliers,1);
medianPositiveSupply = zeros(nSuppliers,1);
positiveSupplyP20 = zeros(nSuppliers,1);
positiveSupplyP90 = zeros(nSuppliers,1);
maximumPositiveSupply = zeros(nSuppliers,1);

orderCompletionRate = completedOrderWeeks ./ orderWeeks;
cumulativeSupplyRate = totalSupply ./ totalOrder;

meanWeeklySupplyRate = zeros(nSuppliers,1);
medianWeeklySupplyRate = zeros(nSuppliers,1);
trimmedMeanSupplyRate = zeros(nSuppliers,1);
weeklySupplyRateStd = zeros(nSuppliers,1);

orderSupplyPearson = nan(nSuppliers,1);
orderSupplyValidWeeks = orderWeeks;

typicalOrderQuantity = zeros(nSuppliers,1);
expectedSupplyAbility = zeros(nSuppliers,1);
riskAdjustedConservativeAbility = zeros(nSuppliers,1);
stableSupplyUpper = zeros(nSuppliers,1);
typicalOrderPredictedSupply = zeros(nSuppliers,1);
saturationOrderQuantity = nan(nSuppliers,1);

% 换算为可支持产品产量
expectedProductCapacity = zeros(nSuppliers,1);
conservativeProductCapacity = zeros(nSuppliers,1);
upperProductCapacity = zeros(nSuppliers,1);
typicalOrderProductCapacity = zeros(nSuppliers,1);

%% 7. 分年度指标初始化
annualTotalOrder = zeros(nSuppliers,numberOfYears);
annualTotalSupply = zeros(nSuppliers,numberOfYears);
annualOrderWeeks = zeros(nSuppliers,numberOfYears);
annualSupplyWeeks = zeros(nSuppliers,numberOfYears);

annualMeanSupplyOnOrderWeeks = nan(nSuppliers,numberOfYears);
annualCumulativeSupplyRate = nan(nSuppliers,numberOfYears);
annualCompletionRate = nan(nSuppliers,numberOfYears);

trendSlope = nan(nSuppliers,1);
trendRelativeSlope = nan(nSuppliers,1);
trendR2 = nan(nSuppliers,1);

recentYearExpectedAbility = nan(nSuppliers,1);
recentYearSupplyRate = nan(nSuppliers,1);
recentYearCompletionRate = nan(nSuppliers,1);

timeWeightedExpectedAbility = nan(nSuppliers,1);
recentToHistoryRatio = nan(nSuppliers,1);

%% 8. 逐家供应商计算供货能力
for i = 1:nSuppliers
    currentOrderMask = orderedMask(i,:);
    currentSupplyMask = suppliedMask(i,:);

    supplyOnOrderWeeks = supplyData(i,currentOrderMask);
    orderOnOrderWeeks = orderData(i,currentOrderMask);
    positiveSupply = supplyData(i,currentSupplyMask);

    weeklySupplyRate = supplyOnOrderWeeks ./ orderOnOrderWeeks;

    % 供货规模
    meanSupplyOnOrderWeeks(i) = mean(supplyOnOrderWeeks);
    medianSupplyOnOrderWeeks(i) = median(supplyOnOrderWeeks);

    meanPositiveSupply(i) = mean(positiveSupply);
    medianPositiveSupply(i) = median(positiveSupply);
    positiveSupplyP20(i) = localPercentile(positiveSupply,lowerPercentile);
    positiveSupplyP90(i) = localPercentile(positiveSupply,upperPercentile);
    maximumPositiveSupply(i) = max(positiveSupply);

    % 供订关系
    meanWeeklySupplyRate(i) = mean(weeklySupplyRate);
    medianWeeklySupplyRate(i) = median(weeklySupplyRate);
    trimmedMeanSupplyRate(i) = localTrimmedMean(weeklySupplyRate,trimFraction);
    weeklySupplyRateStd(i) = std(weeklySupplyRate,1);

    orderSupplyPearson(i) = localSafeCorrelation( ...
        orderOnOrderWeeks,supplyOnOrderWeeks);

    % 典型订货量
    typicalOrderQuantity(i) = median(orderOnOrderWeeks);

    % 三类供货能力候选参数
    expectedSupplyAbility(i) = meanSupplyOnOrderWeeks(i);

    riskAdjustedConservativeAbility(i) = ...
        orderCompletionRate(i) * positiveSupplyP20(i);

    stableSupplyUpper(i) = positiveSupplyP90(i);

    % 典型订货量下的供货响应函数预测值
    typicalOrderPredictedSupply(i) = min( ...
        trimmedMeanSupplyRate(i) * typicalOrderQuantity(i), ...
        stableSupplyUpper(i));

    if trimmedMeanSupplyRate(i) > eps
        saturationOrderQuantity(i) = ...
            stableSupplyUpper(i) / trimmedMeanSupplyRate(i);
    end

    % 原材料能力换算为可支持产品产量
    expectedProductCapacity(i) = ...
        expectedSupplyAbility(i) / materialConsumption(i);

    conservativeProductCapacity(i) = ...
        riskAdjustedConservativeAbility(i) / materialConsumption(i);

    upperProductCapacity(i) = ...
        stableSupplyUpper(i) / materialConsumption(i);

    typicalOrderProductCapacity(i) = ...
        typicalOrderPredictedSupply(i) / materialConsumption(i);

    % 分年度统计
    for y = 1:numberOfYears
        weekIndex = (y-1)*weeksPerYear + (1:weeksPerYear);

        yearOrder = orderData(i,weekIndex);
        yearSupply = supplyData(i,weekIndex);
        yearOrderedMask = yearOrder > 0;
        yearSuppliedMask = yearSupply > 0;

        annualTotalOrder(i,y) = sum(yearOrder);
        annualTotalSupply(i,y) = sum(yearSupply);
        annualOrderWeeks(i,y) = sum(yearOrderedMask);
        annualSupplyWeeks(i,y) = sum(yearSuppliedMask);

        if annualOrderWeeks(i,y) > 0
            annualMeanSupplyOnOrderWeeks(i,y) = ...
                mean(yearSupply(yearOrderedMask));

            annualCumulativeSupplyRate(i,y) = ...
                sum(yearSupply) / sum(yearOrder);

            annualCompletionRate(i,y) = ...
                sum(yearOrderedMask & yearSuppliedMask) / ...
                annualOrderWeeks(i,y);
        end
    end

    % 年度能力趋势，只对有订货的年度进行线性拟合
    [trendSlope(i),trendRelativeSlope(i),trendR2(i)] = ...
        localAnnualTrend(annualMeanSupplyOnOrderWeeks(i,:));

    recentYearExpectedAbility(i) = ...
        annualMeanSupplyOnOrderWeeks(i,numberOfYears);

    recentYearSupplyRate(i) = ...
        annualCumulativeSupplyRate(i,numberOfYears);

    recentYearCompletionRate(i) = ...
        annualCompletionRate(i,numberOfYears);

    timeWeightedExpectedAbility(i) = localWeightedMean( ...
        annualMeanSupplyOnOrderWeeks(i,:)',yearWeights);

    historyAnnualMean = mean( ...
        annualMeanSupplyOnOrderWeeks(i,isfinite( ...
        annualMeanSupplyOnOrderWeeks(i,:))));

    if isfinite(recentYearExpectedAbility(i)) && ...
            historyAnnualMean > eps
        recentToHistoryRatio(i) = ...
            recentYearExpectedAbility(i) / historyAnnualMean;
    end
end

%% 9. 可选读取问题一综合排名
problem1Rank = nan(nSuppliers,1);
problem1Score = nan(nSuppliers,1);
problem1FileUsed = "未读取";

rankingCandidates = dir('问题一_CRITIC_TOPSIS供应商综合评价结果*.xlsx');

if numel(rankingCandidates) == 1
    rankingFile = rankingCandidates(1).name;

    try
        rankingCell = readcell(rankingFile, ...
            'Sheet','402家供应商综合排名');

        rankingHeader = strtrim(string(rankingCell(1,:)));
        supplierColumn = find(rankingHeader=="供应商编号",1);
        rankColumn = find(rankingHeader=="综合排名",1);
        scoreColumn = find(rankingHeader=="综合重要度",1);

        if ~isempty(supplierColumn) && ~isempty(rankColumn) && ...
                ~isempty(scoreColumn)

            rankingID = strtrim(string(rankingCell(2:end,supplierColumn)));
            rankingRank = localCellBlockToDouble( ...
                rankingCell(2:end,rankColumn),'问题一综合排名');
            rankingScore = localCellBlockToDouble( ...
                rankingCell(2:end,scoreColumn),'问题一综合重要度');

            [rankingFound,rankingLocation] = ismember( ...
                supplierID,rankingID);

            problem1Rank(rankingFound) = ...
                rankingRank(rankingLocation(rankingFound));

            problem1Score(rankingFound) = ...
                rankingScore(rankingLocation(rankingFound));

            problem1FileUsed = string(rankingFile);
        end
    catch rankingError
        warning('读取问题一排名文件失败：%s',rankingError.message);
    end
elseif numel(rankingCandidates) > 1
    warning('检测到多个问题一排名结果文件，未自动读取。');
end

%% 10. 能力排名
[~,expectedSortIndex] = sort(expectedProductCapacity,'descend');
expectedCapacityRank = zeros(nSuppliers,1);
expectedCapacityRank(expectedSortIndex) = (1:nSuppliers)';

[~,conservativeSortIndex] = sort( ...
    conservativeProductCapacity,'descend');
conservativeCapacityRank = zeros(nSuppliers,1);
conservativeCapacityRank(conservativeSortIndex) = ...
    (1:nSuppliers)';

[~,upperSortIndex] = sort(upperProductCapacity,'descend');
upperCapacityRank = zeros(nSuppliers,1);
upperCapacityRank(upperSortIndex) = (1:nSuppliers)';

%% 11. 组织未来供货能力参数表
abilityParameterTable = table( ...
    supplierID,materialType,problem1Rank,problem1Score, ...
    orderWeeks,supplyWeeks,orderCompletionRate, ...
    expectedSupplyAbility,riskAdjustedConservativeAbility, ...
    stableSupplyUpper,trimmedMeanSupplyRate, ...
    typicalOrderQuantity,typicalOrderPredictedSupply, ...
    saturationOrderQuantity, ...
    expectedProductCapacity,conservativeProductCapacity, ...
    upperProductCapacity,typicalOrderProductCapacity, ...
    recentYearExpectedAbility,timeWeightedExpectedAbility, ...
    recentToHistoryRatio,trendSlope,trendRelativeSlope,trendR2, ...
    expectedCapacityRank,conservativeCapacityRank, ...
    upperCapacityRank, ...
    'VariableNames',{ ...
    '供应商编号','材料类别','问题一综合排名','问题一综合重要度', ...
    '订货周数','实际供货周数','订货完成率', ...
    '期望供货能力','风险调整保守供货能力', ...
    '稳健供货上限','订货响应系数', ...
    '典型订货量','典型订货量下预计供货量', ...
    '达到稳健上限的参考订货量', ...
    '期望产能当量','风险调整产能当量', ...
    '上限产能当量','典型订货产能当量', ...
    '最近一年期望供货能力','时间加权期望供货能力', ...
    '最近一年与历史年度均值之比', ...
    '年度能力趋势斜率','年度能力相对趋势斜率','年度趋势拟合优度', ...
    '期望产能排名','风险调整产能排名','上限产能排名'});

%% 12. 组织供货规模和供订关系诊断表
relationshipTable = table( ...
    supplierID,materialType,totalOrder,totalSupply, ...
    orderWeeks,supplyWeeks,completedOrderWeeks, ...
    meanSupplyOnOrderWeeks,medianSupplyOnOrderWeeks, ...
    meanPositiveSupply,medianPositiveSupply, ...
    positiveSupplyP20,positiveSupplyP90,maximumPositiveSupply, ...
    cumulativeSupplyRate,orderCompletionRate, ...
    meanWeeklySupplyRate,medianWeeklySupplyRate, ...
    trimmedMeanSupplyRate,weeklySupplyRateStd, ...
    orderSupplyPearson,orderSupplyValidWeeks, ...
    'VariableNames',{ ...
    '供应商编号','材料类别','累计订货量','累计供货量', ...
    '订货周数','实际供货周数','完成订货周数', ...
    '订货周平均供货量','订货周供货量中位数', ...
    '正供货周平均供货量','正供货周供货量中位数', ...
    '正供货量20百分位数','正供货量90百分位数','历史最大供货量', ...
    '累计供货率','订货完成率', ...
    '逐周供货率均值','逐周供货率中位数', ...
    '逐周供货率截尾均值','逐周供货率标准差', ...
    '订货量供货量相关系数','供订关系有效周数'});

%% 13. 分年度能力表
annualTable = table(supplierID,materialType, ...
    'VariableNames',{'供应商编号','材料类别'});

for y = 1:numberOfYears
    annualTable.(sprintf('第%d年累计订货量',y)) = ...
        annualTotalOrder(:,y);
    annualTable.(sprintf('第%d年累计供货量',y)) = ...
        annualTotalSupply(:,y);
    annualTable.(sprintf('第%d年订货周数',y)) = ...
        annualOrderWeeks(:,y);
    annualTable.(sprintf('第%d年供货周数',y)) = ...
        annualSupplyWeeks(:,y);
    annualTable.(sprintf('第%d年订货周平均供货量',y)) = ...
        annualMeanSupplyOnOrderWeeks(:,y);
    annualTable.(sprintf('第%d年累计供货率',y)) = ...
        annualCumulativeSupplyRate(:,y);
    annualTable.(sprintf('第%d年订货完成率',y)) = ...
        annualCompletionRate(:,y);
end

% 使用addvars添加中文列名，避免旧版MATLAB将中文点索引识别为无效字符
annualTable = addvars(annualTable, ...
    trendSlope, ...
    trendRelativeSlope, ...
    trendR2, ...
    recentYearExpectedAbility, ...
    timeWeightedExpectedAbility, ...
    recentToHistoryRatio, ...
    'NewVariableNames', { ...
    '年度能力趋势斜率', ...
    '年度能力相对趋势斜率', ...
    '年度趋势拟合优度', ...
    '最近一年期望供货能力', ...
    '时间加权期望供货能力', ...
    '最近一年与历史年度均值之比'});

%% 14. 能力排名表
rankingTable = table( ...
    (1:nSuppliers)', ...
    supplierID(expectedSortIndex), ...
    materialType(expectedSortIndex), ...
    problem1Rank(expectedSortIndex), ...
    expectedSupplyAbility(expectedSortIndex), ...
    expectedProductCapacity(expectedSortIndex), ...
    riskAdjustedConservativeAbility(expectedSortIndex), ...
    conservativeProductCapacity(expectedSortIndex), ...
    stableSupplyUpper(expectedSortIndex), ...
    upperProductCapacity(expectedSortIndex), ...
    orderCompletionRate(expectedSortIndex), ...
    trimmedMeanSupplyRate(expectedSortIndex), ...
    'VariableNames',{ ...
    '期望产能排名','供应商编号','材料类别','问题一综合排名', ...
    '期望供货能力','期望产能当量', ...
    '风险调整保守供货能力','风险调整产能当量', ...
    '稳健供货上限','上限产能当量', ...
    '订货完成率','订货响应系数'});

%% 15. 五年企业总体统计
overallAnnualOrder = sum(annualTotalOrder,1)';
overallAnnualSupply = sum(annualTotalSupply,1)';
overallAnnualOrderWeeks = sum(annualOrderWeeks,1)';
overallAnnualSupplyWeeks = sum(annualSupplyWeeks,1)';

overallAnnualSupplyRate = overallAnnualSupply ./ ...
    overallAnnualOrder;

overallAnnualCompletionRate = overallAnnualSupplyWeeks ./ ...
    overallAnnualOrderWeeks;

overallAnnualTable = table( ...
    (1:numberOfYears)',overallAnnualOrder,overallAnnualSupply, ...
    overallAnnualOrderWeeks,overallAnnualSupplyWeeks, ...
    overallAnnualSupplyRate,overallAnnualCompletionRate, ...
    'VariableNames',{ ...
    '年度','累计订货量','累计供货量','总订货周次', ...
    '总供货周次','总体累计供货率','总体订货完成率'});

%% 16. 指标说明表
indicatorDescription = { ...
    '期望供货能力', ...
    '有订货周内实际供货量的平均值，未供货周按0计入', ...
    '反映下一次正常订货条件下的平均实际供货水平'; ...
    '风险调整保守供货能力', ...
    '订货完成率乘以正供货量20%分位数', ...
    '同时考虑断供概率和低位供货水平，不是严格保证下界'; ...
    '稳健供货上限', ...
    '正供货量90%分位数', ...
    '反映供应商较高但非极端的周供货水平'; ...
    '订货响应系数', ...
    '有订货周逐周供货率的10%双侧截尾均值', ...
    '用于描述订货量变化时供应商的平均响应程度'; ...
    '典型订货量', ...
    '有订货周订货量的中位数', ...
    '反映企业历史上向该供应商的典型订货规模'; ...
    '典型订货量下预计供货量', ...
    'min(订货响应系数×典型订货量,稳健供货上限)', ...
    '用于检查供货响应函数在典型订货规模下的结果'; ...
    '达到稳健上限的参考订货量', ...
    '稳健供货上限除以订货响应系数', ...
    '订货量超过该值后，供货预测受稳健上限约束'; ...
    '期望产能当量', ...
    '期望供货能力除以该类原材料单位产品消耗系数', ...
    '将A、B、C类供应商换算到可支持产品产量的统一尺度'; ...
    '年度能力趋势斜率', ...
    '五个年度订货周平均供货量对年度序号的线性回归斜率', ...
    '正值表示历史能力总体上升，负值表示总体下降'; ...
    '年度能力相对趋势斜率', ...
    '年度能力趋势斜率除以有效年度能力均值', ...
    '便于比较不同供货规模供应商的相对变化速度'; ...
    '年度趋势拟合优度', ...
    '年度线性趋势的决定系数R²', ...
    '越接近1说明线性趋势越明显'};

descriptionTable = cell2table(indicatorDescription, ...
    'VariableNames',{'指标名称','计算方法','指标含义'});

parameterTable = table( ...
    ["正供货量低位分位数"; ...
     "正供货量稳健上限分位数"; ...
     "逐周供货率双侧截尾比例"; ...
     "每年周数"; ...
     "年度数量"; ...
     "年度时间权重"], ...
    [string(lowerPercentile+"%"); ...
     string(upperPercentile+"%"); ...
     string(trimFraction*100+"%"); ...
     string(weeksPerYear); ...
     string(numberOfYears); ...
     strjoin(string(round(yearWeights',6)), "、")], ...
    'VariableNames',{'参数名称','参数取值'});

%% 17. 数据核验表
validCorrelationCount = sum(isfinite(orderSupplyPearson));
zeroMedianRateCount = sum(medianWeeklySupplyRate==0);
decreasingTrendCount = sum(trendRelativeSlope<0 & isfinite(trendRelativeSlope));
increasingTrendCount = sum(trendRelativeSlope>0 & isfinite(trendRelativeSlope));

checkItems = [ ...
    "使用的附件文件"; ...
    "供应商数量"; ...
    "历史周数"; ...
    "A类供应商数量"; ...
    "B类供应商数量"; ...
    "C类供应商数量"; ...
    "企业累计订货量"; ...
    "供应商累计供货量"; ...
    "无订货却供货的记录数"; ...
    "订货量与供货量相关系数可计算的供应商数量"; ...
    "逐周供货率中位数为0的供应商数量"; ...
    "年度能力趋势斜率为正的供应商数量"; ...
    "年度能力趋势斜率为负的供应商数量"; ...
    "读取的问题一排名文件"];

checkValues = [ ...
    string(inputFile); ...
    string(nSuppliers); ...
    string(nWeeks); ...
    string(sum(materialType=="A")); ...
    string(sum(materialType=="B")); ...
    string(sum(materialType=="C")); ...
    string(sum(totalOrder)); ...
    string(sum(totalSupply)); ...
    string(unexpectedSupplyCount); ...
    string(validCorrelationCount); ...
    string(zeroMedianRateCount); ...
    string(increasingTrendCount); ...
    string(decreasingTrendCount); ...
    problem1FileUsed];

checkTable = table(checkItems,checkValues, ...
    'VariableNames',{'核验项目','核验结果'});

%% 18. 写入Excel
if isfile(outputFile)
    delete(outputFile);
end

writetable(abilityParameterTable,outputFile, ...
    'Sheet','未来供货能力参数');
writetable(relationshipTable,outputFile, ...
    'Sheet','供货规模与供订关系');
writetable(annualTable,outputFile, ...
    'Sheet','分年度供货能力');
writetable(rankingTable,outputFile, ...
    'Sheet','期望产能能力排名');
writetable(overallAnnualTable,outputFile, ...
    'Sheet','五年总体供订统计');
writetable(descriptionTable,outputFile, ...
    'Sheet','指标说明');
writetable(parameterTable,outputFile, ...
    'Sheet','参数设置');
writetable(checkTable,outputFile, ...
    'Sheet','数据核验');

%% 19. 绘制期望产能能力前50名
topNumber = min(50,nSuppliers);
topExpectedIndex = expectedSortIndex(1:topNumber);

fig1 = figure('Color','w','Position',[100,50,1100,1500]);
ax1 = axes(fig1);

displayExpected = flipud(expectedProductCapacity(topExpectedIndex));
displayExpectedID = flipud(supplierID(topExpectedIndex));

barh(ax1,displayExpected);
set(ax1, ...
    'YTick',1:topNumber, ...
    'YTickLabel',cellstr(displayExpectedID), ...
    'FontSize',9);

xlabel(ax1,'期望产能当量（立方米产品/周）');
ylabel(ax1,'供应商编号');
title(ax1,'期望产能当量排名前50的供应商','FontSize',15);
grid(ax1,'on');

localCloseToolbar(ax1);
drawnow;
localExportFigure(fig1,figureExpected);

%% 20. 绘制风险调整产能能力前50名
topConservativeIndex = conservativeSortIndex(1:topNumber);

fig2 = figure('Color','w','Position',[100,50,1100,1500]);
ax2 = axes(fig2);

displayConservative = flipud( ...
    conservativeProductCapacity(topConservativeIndex));
displayConservativeID = flipud( ...
    supplierID(topConservativeIndex));

barh(ax2,displayConservative);
set(ax2, ...
    'YTick',1:topNumber, ...
    'YTickLabel',cellstr(displayConservativeID), ...
    'FontSize',9);

xlabel(ax2,'风险调整产能当量（立方米产品/周）');
ylabel(ax2,'供应商编号');
title(ax2,'风险调整产能当量排名前50的供应商','FontSize',15);
grid(ax2,'on');

localCloseToolbar(ax2);
drawnow;
localExportFigure(fig2,figureConservative);

%% 21. 绘制五年总体供订变化
fig3 = figure('Color','w','Position',[100,100,1000,650]);
ax3 = axes(fig3);

bar(ax3,1:numberOfYears, ...
    [overallAnnualOrder,overallAnnualSupply]);

set(ax3,'XTick',1:numberOfYears,'FontSize',11);
xlabel(ax3,'年度');
ylabel(ax3,'原材料数量（立方米）');
title(ax3,'近5年企业总体订货量与供应商供货量','FontSize',15);
legend(ax3,{'累计订货量','累计供货量'}, ...
    'Location','best');
grid(ax3,'on');

localCloseToolbar(ax3);
drawnow;
localExportFigure(fig3,figureAnnual);

%% 22. 命令行输出
fprintf('\n================ 数据读取与核验 ================\n');
fprintf('使用文件：%s\n',inputFile);
fprintf('供应商数量：%d家\n',nSuppliers);
fprintf('历史周数：%d周\n',nWeeks);
fprintf('A类供应商：%d家\n',sum(materialType=="A"));
fprintf('B类供应商：%d家\n',sum(materialType=="B"));
fprintf('C类供应商：%d家\n',sum(materialType=="C"));
fprintf('企业累计订货量：%.2f立方米\n',sum(totalOrder));
fprintf('供应商累计供货量：%.2f立方米\n',sum(totalSupply));
fprintf('无订货却供货的记录：%d条\n',unexpectedSupplyCount);
fprintf('供订相关系数可计算的供应商：%d家\n', ...
    validCorrelationCount);
fprintf('逐周供货率中位数为0的供应商：%d家\n', ...
    zeroMedianRateCount);

fprintf('\n================ 三类供货能力参数汇总 ================\n');
fprintf('全部供应商期望供货能力之和：%.2f立方米/周\n', ...
    sum(expectedSupplyAbility));
fprintf('全部供应商风险调整保守供货能力之和：%.2f立方米/周\n', ...
    sum(riskAdjustedConservativeAbility));
fprintf('全部供应商稳健供货上限之和：%.2f立方米/周\n', ...
    sum(stableSupplyUpper));

fprintf('\n================ 期望产能当量前20名 ================\n');
disp(rankingTable(1:min(20,nSuppliers), ...
    {'期望产能排名','供应商编号','材料类别', ...
     '期望供货能力','期望产能当量','问题一综合排名'}));

fprintf('\n================ 五年总体供订统计 ================\n');
disp(overallAnnualTable);

fprintf('\n计算完成。\n');
fprintf('供货能力分析结果：%s\n',outputFile);
fprintf('期望产能前50名图：%s\n',figureExpected);
fprintf('风险调整产能前50名图：%s\n',figureConservative);
fprintf('五年总体供订变化图：%s\n',figureAnnual);
fprintf(['注意：本程序输出多组供货能力候选参数，' ...
    '下一步应根据结果确定最少供应商选择模型采用哪一组能力参数。\n']);

%% 局部函数1：将混合单元格区域转换为数值矩阵
function numericMatrix = localCellBlockToDouble(cellBlock,blockName)
    numericMatrix = zeros(size(cellBlock));

    for index = 1:numel(cellBlock)
        value = cellBlock{index};

        if isempty(value)
            numericMatrix(index) = 0;

        elseif isnumeric(value)
            if isnan(value)
                numericMatrix(index) = 0;
            else
                numericMatrix(index) = double(value);
            end

        elseif islogical(value)
            numericMatrix(index) = double(value);

        else
            textValue = strtrim(string(value));

            if ismissing(textValue) || strlength(textValue)==0
                numericMatrix(index) = 0;
            else
                convertedValue = str2double(textValue);

                if isnan(convertedValue)
                    error('%s数据中存在无法转换为数值的内容：%s', ...
                        blockName,textValue);
                end

                numericMatrix(index) = convertedValue;
            end
        end
    end
end

%% 局部函数2：线性插值百分位数，不依赖统计工具箱
function percentileValue = localPercentile(data,percentile)
    data = sort(data(isfinite(data)));

    if isempty(data)
        percentileValue = NaN;
        return;
    end

    if numel(data)==1
        percentileValue = data(1);
        return;
    end

    percentile = max(0,min(100,percentile));
    position = 1 + (numel(data)-1)*percentile/100;

    lowerIndex = floor(position);
    upperIndex = ceil(position);

    if lowerIndex==upperIndex
        percentileValue = data(lowerIndex);
    else
        interpolationWeight = position-lowerIndex;
        percentileValue = ...
            data(lowerIndex)*(1-interpolationWeight) + ...
            data(upperIndex)*interpolationWeight;
    end
end

%% 局部函数3：双侧截尾均值，不依赖统计工具箱
function trimmedMeanValue = localTrimmedMean(data,trimFraction)
    data = sort(data(isfinite(data)));

    if isempty(data)
        trimmedMeanValue = NaN;
        return;
    end

    trimFraction = max(0,min(0.49,trimFraction));
    trimCount = floor(numel(data)*trimFraction);

    if 2*trimCount >= numel(data)
        trimmedMeanValue = mean(data);
    else
        trimmedData = data((trimCount+1):(end-trimCount));
        trimmedMeanValue = mean(trimmedData);
    end
end

%% 局部函数4：安全计算Pearson相关系数
function correlationValue = localSafeCorrelation(x,y)
    x = x(:);
    y = y(:);

    validMask = isfinite(x) & isfinite(y);
    x = x(validMask);
    y = y(validMask);

    if numel(x)<2 || std(x,1)<=eps || std(y,1)<=eps
        correlationValue = NaN;
        return;
    end

    correlationMatrix = corrcoef(x,y);
    correlationValue = correlationMatrix(1,2);
end

%% 局部函数5：计算年度线性趋势
function [slopeValue,relativeSlope,rSquared] = ...
        localAnnualTrend(annualValues)

    annualValues = annualValues(:);
    yearIndex = (1:numel(annualValues))';

    validMask = isfinite(annualValues);
    x = yearIndex(validMask);
    y = annualValues(validMask);

    if numel(y)<2 || mean(y)<=eps
        slopeValue = NaN;
        relativeSlope = NaN;
        rSquared = NaN;
        return;
    end

    coefficient = polyfit(x,y,1);
    fittedValue = polyval(coefficient,x);

    slopeValue = coefficient(1);
    relativeSlope = slopeValue / mean(y);

    totalSquare = sum((y-mean(y)).^2);
    residualSquare = sum((y-fittedValue).^2);

    if totalSquare<=eps
        rSquared = 0;
    else
        rSquared = 1-residualSquare/totalSquare;
    end
end

%% 局部函数6：忽略缺失值的加权平均
function weightedMeanValue = localWeightedMean(values,weights)
    values = values(:);
    weights = weights(:);

    validMask = isfinite(values) & isfinite(weights);

    if ~any(validMask)
        weightedMeanValue = NaN;
        return;
    end

    validValues = values(validMask);
    validWeights = weights(validMask);

    if sum(validWeights)<=eps
        weightedMeanValue = NaN;
    else
        validWeights = validWeights/sum(validWeights);
        weightedMeanValue = sum(validValues.*validWeights);
    end
end

%% 局部函数7：关闭坐标区工具栏
function localCloseToolbar(ax)
    try
        if ~isempty(ax.Toolbar)
            ax.Toolbar.Visible = 'off';
        end
    catch
    end

    try
        disableDefaultInteractivity(ax);
    catch
    end
end

%% 局部函数8：导出图像
function localExportFigure(fig,fileName)
    try
        exportgraphics(fig,fileName,'Resolution',300);
    catch
        print(fig,fileName,'-dpng','-r300');
    end
end
