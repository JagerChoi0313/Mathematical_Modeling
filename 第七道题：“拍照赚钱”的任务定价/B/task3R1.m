%% Q3_DBSCAN_MultiObjective_Pricing.m
% 第三问：基于 DBSCAN 聚类与加权多目标优化的任务打包定价模型
%
% 模型结构：
% Step 1  读取任务数据、会员数据和第二问结果
% Step 2  清洗会员 GPS，并构造任务空间与会员资源特征
% Step 3  重新建立 Logistic 完成概率模型
% Step 4  读取并验证第二问多目标优化结果
% Step 5  计算任务之间的距离矩阵
% Step 6  搜索 DBSCAN 参数 eps 和 MinPts
% Step 7  对 DBSCAN 聚类结果进行任务包规模后处理
% Step 8  计算任务包紧凑度和低完成概率比例
% Step 9  建立任务包多目标定价模型并进行离散优化
% Step 10 选择综合目标函数最大的 DBSCAN 参数组合
% Step 11 输出任务包、任务价格和方案比较结果
% Step 12 绮制必要图像
%
% 说明：
% 1. 本代码不依赖 MATLAB 自带的 dbscan 函数，
%    内置了一个简单 DBSCAN 算法，避免统计工具箱缺失。
% 2. 第三问以第二问多目标优化后的价格 P2 为基准。
% 3. 打包后的等效价格继续代入 Logistic 模型预测完成概率。
% 4. 第三问的完成概率属于模型情景预测，不是实际观测结果。

clear;
clc;
close all;

%% ==================== Step 0：文件名和参数设置 ====================

taskFile   = '附件一：已结束项目任务数据.xls';
memberFile = '附件二：会员信息数据.xlsx';
q2File     = 'Q2_多目标_任务新定价结果.xlsx';

% 第一问和第二问使用的空间参数
rMember = 3;                 % 周边会员统计半径，单位 km
rTask   = 3;                 % 任务密度统计半径，单位 km
targetProb = 0.62;           % 目标完成概率阈值

% DBSCAN 参数候选范围
% eps：任务邻域半径，单位 km
epsList = [0.40, 0.60, 0.80, 1.00, 1.20];

% MinPts：形成核心任务所需的最少邻域任务数量
% 包括任务自身
minPtsList = [2, 3, 4];

% 任务包规模约束
maxPackSize = 5;             % 每个任务包最多包含 5 个任务

% 第三问多目标优化参数
omega3 = 0.70;               % 完成效果权重
eta3 = 0.03;                 % 第三问相对第二问最大成本增长率
deltaDiscount = 0.15;        % 空间紧凑任务包最大折扣比例
deltaCompensation = 0.12;    % 低完成概率任务最大补偿比例
priceStep3 = 0.50;           % 任务包价格搜索步长
maxOptIter = 20000;          % 单组参数最大优化迭代次数

fprintf('\n');
fprintf('============================================================\n');
fprintf(' 第三问：DBSCAN + 多目标任务包定价优化模型\n');
fprintf('============================================================\n');
fprintf('会员统计半径：%.2f km\n', rMember);
fprintf('任务密度半径：%.2f km\n', rTask);
fprintf('目标完成概率阈值：%.2f\n', targetProb);
fprintf('最大任务包规模：%d\n', maxPackSize);
fprintf('第三问完成效果权重：%.2f\n', omega3);
fprintf('第三问成本增长上限：%.2f%%\n', eta3 * 100);
fprintf('空间紧凑最大折扣比例：%.2f%%\n', deltaDiscount * 100);
fprintf('低概率任务最大补偿比例：%.2f%%\n', deltaCompensation * 100);
fprintf('任务包价格搜索步长：%.2f\n', priceStep3);

%% ==================== Step 1：读取原始数据 ====================

Task = readSmartTable(taskFile);
Member = readSmartTable(memberFile);
Q2Result = readSmartTable(q2File);

fprintf('\n================ Step 1：读取数据 ================\n');

disp('附件一字段名：');
disp(Task.Properties.VariableNames');

disp('附件二字段名：');
disp(Member.Properties.VariableNames');

disp('第二问结果文件字段名：');
disp(Q2Result.Properties.VariableNames');

%% ==================== Step 2：提取任务数据 ====================

taskID_col  = findCol(Task, {'任务号码', '任务编号', '编号'});
taskLat_col = findCol(Task, ...
    {'任务gps 纬度', '任务gps纬度', 'GPS纬度', '纬度'});
taskLon_col = findCol(Task, ...
    {'任务gps经度', '任务gps 经度', 'GPS经度', '经度'});
price_col   = findCol(Task, ...
    {'任务标价', '标价', '定价', '价格'});
finish_col  = findCol(Task, ...
    {'任务执行情况', '执行情况', '完成情况', '是否完成'});

taskID  = Task.(taskID_col);
taskLat = toNumericVector(Task.(taskLat_col));
taskLon = toNumericVector(Task.(taskLon_col));
P0      = toNumericVector(Task.(price_col));
Y       = toNumericVector(Task.(finish_col));

validTask = ~isnan(taskLat) & ...
            ~isnan(taskLon) & ...
            ~isnan(P0) & ...
            ~isnan(Y);

taskID  = taskID(validTask);
taskLat = taskLat(validTask);
taskLon = taskLon(validTask);
P0      = P0(validTask);
Y       = Y(validTask);

n = length(P0);

fprintf('\n任务总数：%d\n', n);
fprintf('完成任务数：%d\n', sum(Y == 1));
fprintf('未完成任务数：%d\n', sum(Y == 0));
fprintf('历史实际完成率：%.2f%%\n', mean(Y) * 100);

%% ==================== Step 3：提取并清洗会员数据 ====================

memberID_col  = findCol(Member, {'会员编号', '编号'});
memberGPS_col = findCol(Member, {'会员位置', 'GPS', '位置'});
quota_col     = findCol(Member, {'预订任务限额', '任务限额', '限额'});
credit_col    = findCol(Member, {'信誉值', '信誉'});

memberID  = Member.(memberID_col);
memberGPS = Member.(memberGPS_col);
Q         = toNumericVector(Member.(quota_col));
C         = toNumericVector(Member.(credit_col));

% 以任务区域中心作为判断经纬度顺序的参考点
taskLatCenter = median(taskLat, 'omitnan');
taskLonCenter = median(taskLon, 'omitnan');

[memberLat, memberLon] = parseGPSAuto( ...
    memberGPS, taskLatCenter, taskLonCenter);

validMember = ~isnan(memberLat) & ...
              ~isnan(memberLon) & ...
              ~isnan(Q) & ...
              ~isnan(C);

memberID  = memberID(validMember);
memberLat = memberLat(validMember);
memberLon = memberLon(validMember);
Q         = Q(validMember);
C         = C(validMember);

% 删除明显远离任务区域的会员点
lonMinWide = min(taskLon) - 5;
lonMaxWide = max(taskLon) + 5;
latMinWide = min(taskLat) - 5;
latMaxWide = max(taskLat) + 5;

validRange = memberLon >= lonMinWide & ...
             memberLon <= lonMaxWide & ...
             memberLat >= latMinWide & ...
             memberLat <= latMaxWide;

removedMember = sum(~validRange);

memberID  = memberID(validRange);
memberLat = memberLat(validRange);
memberLon = memberLon(validRange);
Q         = Q(validRange);
C         = C(validRange);

m = length(C);

fprintf('\n有效会员总数：%d\n', m);
fprintf('剔除异常会员点数量：%d\n', removedMember);

%% ==================== Step 4：构造任务周边会员特征 ====================

fprintf('\n================ Step 2：构造任务特征 ================\n');
fprintf('正在计算任务与会员之间的距离...\n');

di_min = zeros(n, 1);
Ni     = zeros(n, 1);
Si     = zeros(n, 1);
Ui     = zeros(n, 1);

for i = 1:n

    d = geoDistanceKm( ...
        taskLat(i), taskLon(i), memberLat, memberLon);

    di_min(i) = min(d);

    idxNear = d <= rMember;

    Ni(i) = sum(idxNear);
    Si(i) = sum(C(idxNear));
    Ui(i) = sum(Q(idxNear));
end

avgC = Si ./ max(Ni, 1);
avgQ = Ui ./ max(Ni, 1);

fprintf('任务周边会员特征计算完成。\n');

%% ==================== Step 5：计算任务距离矩阵 ====================

fprintf('正在计算任务之间的距离矩阵...\n');

taskDistMat = zeros(n, n);

for i = 1:n
    taskDistMat(i, :) = geoDistanceKm( ...
        taskLat(i), taskLon(i), taskLat, taskLon);
end

taskDensity = zeros(n, 1);

for i = 1:n
    % 去除任务本身
    taskDensity(i) = sum(taskDistMat(i, :) <= rTask) - 1;
end

competitionIndex = taskDensity ./ max(Ni, 1);

fprintf('任务距离矩阵和竞争特征计算完成。\n');

%% ==================== Step 6：重新训练 Logistic 模型 ====================

fprintf('\n================ Step 3：建立 Logistic 模型 ================\n');

pricePerDistance0 = P0 ./ (di_min + 0.1);
pricePerCompetition0 = P0 ./ (taskDensity + 1);

X_logit_raw = [ ...
    P0, ...
    di_min, ...
    Ni, ...
    avgC, ...
    avgQ, ...
    taskDensity, ...
    competitionIndex, ...
    pricePerDistance0, ...
    pricePerCompetition0];

[X_logit, mu_logit, sigma_logit] = ...
    standardizeData(X_logit_raw);

X_design = [ones(n, 1), X_logit];

alphaInit = zeros(size(X_design, 2), 1);

options = optimset( ...
    'MaxIter', 10000, ...
    'MaxFunEvals', 20000, ...
    'Display', 'off');

alpha = fminsearch( ...
    @(a) logisticNLL(a, X_design, Y), ...
    alphaInit, options);

logitNames = { ...
    '常数项'; ...
    '任务价格'; ...
    '最近会员距离'; ...
    '周边会员数量'; ...
    '平均信誉值'; ...
    '平均预订限额'; ...
    '任务密度'; ...
    '竞争强度'; ...
    '单位距离价格'; ...
    '单位竞争价格'};

LogitCoefTable = table( ...
    logitNames, alpha, ...
    'VariableNames', {'变量', 'Logistic回归系数'});

disp(LogitCoefTable);

writetable( ...
    LogitCoefTable, ...
    'Q3_Logistic回归系数.xlsx');

%% ==================== Step 7：读取并对齐第二问结果 ====================

fprintf('\n================ Step 4：读取第二问结果 ================\n');

q2ID_col = findCol(Q2Result, ...
    {'任务编号', '任务号码', '编号'});

q2Price_col = findCol(Q2Result, ...
    {'新价格', '优化价格', '第二问价格'});

q2Prob_col = findCol(Q2Result, ...
    {'新方案预测完成概率', '预测完成概率', '新完成概率'});

q2ID = Q2Result.(q2ID_col);
q2Price = toNumericVector(Q2Result.(q2Price_col));
q2ProbFile = toNumericVector(Q2Result.(q2Prob_col));

% 按照任务编号匹配第二问结果，避免表格顺序不同
taskIDString = string(taskID);
q2IDString = string(q2ID);

[isMatched, q2Location] = ismember(taskIDString, q2IDString);

if ~all(isMatched)
    missingIDs = taskIDString(~isMatched);
    disp('未在第二问结果中找到的任务编号：');
    disp(missingIDs);
    error('第二问结果与附件一任务编号未能完全匹配。');
end

P2 = q2Price(q2Location);
p2File = q2ProbFile(q2Location);

if any(isnan(P2))
    error('第二问结果中的新价格存在缺失值。');
end

% 使用重新建立的 Logistic 模型再次计算第二问概率
% 这样可保证第三问概率预测与同一模型完全一致
p2 = predictProb( ...
    P2, alpha, mu_logit, sigma_logit, ...
    di_min, Ni, avgC, avgQ, ...
    taskDensity, competitionIndex);

probDifference = max(abs(p2 - p2File));

fprintf('第二问文件概率与重新计算概率的最大差值：%.8f\n', ...
    probDifference);

if probDifference > 1e-3
    warning(['第二问文件中的概率与当前重新拟合的 Logistic 模型存在差异，' ...
        '第三问将采用当前模型重新计算的概率。']);
end

C2 = sum(P2);
M2 = sum(p2);
R2 = mean(p2 >= targetProb);
L2 = sum(p2 < targetProb);

fprintf('\n第二问方案总成本 C2：%.4f\n', C2);
fprintf('第二问期望完成任务数 M2：%.4f\n', M2);
fprintf('第二问预测完成率 R2：%.2f%%\n', R2 * 100);
fprintf('第二问低完成概率任务数 L2：%d\n', L2);

%% ==================== Step 8：搜索 DBSCAN 参数 ====================

fprintf('\n================ Step 5：搜索 DBSCAN 参数 ================\n');

numCombination = length(epsList) * length(minPtsList);

searchEps = zeros(numCombination, 1);
searchMinPts = zeros(numCombination, 1);
searchUnitCount = zeros(numCombination, 1);
searchBundleCount = zeros(numCombination, 1);
searchBundledTaskCount = zeros(numCombination, 1);
searchSingleCount = zeros(numCombination, 1);
searchCost = zeros(numCombination, 1);
searchExpected = zeros(numCombination, 1);
searchRate = zeros(numCombination, 1);
searchLow = zeros(numCombination, 1);
searchObjective = zeros(numCombination, 1);

best.J3 = -inf;
best.exists = false;

combinationIndex = 0;

for e = 1:length(epsList)

    epsValue = epsList(e);

    for mp = 1:length(minPtsList)

        minPtsValue = minPtsList(mp);
        combinationIndex = combinationIndex + 1;

        fprintf('\n------------------------------------------------------------\n');
        fprintf('正在计算参数组合：eps = %.2f km，MinPts = %d\n', ...
            epsValue, minPtsValue);

        % Step 5.1：执行自定义 DBSCAN
        clusterLabel = dbscanSimple( ...
            taskDistMat, epsValue, minPtsValue);

        % Step 5.2：聚类后处理，限制任务包规模
        [packages, parentCluster] = buildPackagesFromDBSCAN( ...
            clusterLabel, taskDistMat, maxPackSize);

        % Step 5.3：计算任务包特征和价格上下限
        packageMeta = computePackageMeta( ...
            packages, parentCluster, ...
            taskLat, taskLon, ...
            P2, p2, targetProb, epsValue, ...
            deltaDiscount, deltaCompensation);

        % Step 5.4：任务包多目标定价优化
        [Bopt, P3, p3, optHistory, J3] = ...
            optimizePackagePricing( ...
            packages, packageMeta, ...
            P2, C2, M2, ...
            omega3, eta3, priceStep3, maxOptIter, ...
            alpha, mu_logit, sigma_logit, ...
            di_min, Ni, avgC, avgQ, ...
            taskDensity, competitionIndex);

        % Step 5.5：计算方案评价指标
        C3 = sum(P3);
        M3 = sum(p3);
        R3 = mean(p3 >= targetProb);
        L3 = sum(p3 < targetProb);

        packSize = packageMeta.size;

        actualBundleCount = sum(packSize >= 2);
        bundledTaskCount = sum(packSize(packSize >= 2));
        singleTaskCount = sum(packSize == 1);
        publicationUnitCount = length(packages);

        fprintf('发布单元数：%d\n', publicationUnitCount);
        fprintf('实际任务包数：%d\n', actualBundleCount);
        fprintf('被打包任务数：%d\n', bundledTaskCount);
        fprintf('单独发布任务数：%d\n', singleTaskCount);
        fprintf('第三问总成本：%.4f\n', C3);
        fprintf('第三问期望完成任务数：%.4f\n', M3);
        fprintf('第三问预测完成率：%.2f%%\n', R3 * 100);
        fprintf('第三问低完成概率任务数：%d\n', L3);
        fprintf('综合目标函数 J3：%.8f\n', J3);

        searchEps(combinationIndex) = epsValue;
        searchMinPts(combinationIndex) = minPtsValue;
        searchUnitCount(combinationIndex) = publicationUnitCount;
        searchBundleCount(combinationIndex) = actualBundleCount;
        searchBundledTaskCount(combinationIndex) = bundledTaskCount;
        searchSingleCount(combinationIndex) = singleTaskCount;
        searchCost(combinationIndex) = C3;
        searchExpected(combinationIndex) = M3;
        searchRate(combinationIndex) = R3 * 100;
        searchLow(combinationIndex) = L3;
        searchObjective(combinationIndex) = J3;

        % 综合目标函数优先
        % 若目标函数近似相同，则优先选择期望完成任务数较高的方案
        isBetter = false;

        if ~best.exists
            isBetter = true;
        elseif J3 > best.J3 + 1e-10
            isBetter = true;
        elseif abs(J3 - best.J3) <= 1e-10 && M3 > best.M3
            isBetter = true;
        elseif abs(J3 - best.J3) <= 1e-10 && ...
                abs(M3 - best.M3) <= 1e-10 && C3 < best.C3
            isBetter = true;
        end

        if isBetter

            best.exists = true;
            best.eps = epsValue;
            best.minPts = minPtsValue;
            best.clusterLabel = clusterLabel;
            best.packages = packages;
            best.parentCluster = parentCluster;
            best.packageMeta = packageMeta;
            best.Bopt = Bopt;
            best.P3 = P3;
            best.p3 = p3;
            best.history = optHistory;
            best.J3 = J3;
            best.C3 = C3;
            best.M3 = M3;
            best.R3 = R3;
            best.L3 = L3;
            best.actualBundleCount = actualBundleCount;
            best.bundledTaskCount = bundledTaskCount;
            best.singleTaskCount = singleTaskCount;
            best.publicationUnitCount = publicationUnitCount;
        end
    end
end

%% ==================== Step 9：输出参数搜索结果 ====================

SearchTable = table( ...
    searchEps, ...
    searchMinPts, ...
    searchUnitCount, ...
    searchBundleCount, ...
    searchBundledTaskCount, ...
    searchSingleCount, ...
    searchCost, ...
    searchExpected, ...
    searchRate, ...
    searchLow, ...
    searchObjective, ...
    'VariableNames', { ...
    'DBSCAN邻域半径eps', ...
    'DBSCAN最小点数MinPts', ...
    '发布单元数量', ...
    '实际任务包数量', ...
    '被打包任务数量', ...
    '单独发布任务数量', ...
    '第三问总成本', ...
    '第三问期望完成任务数', ...
    '第三问预测完成率百分比', ...
    '第三问低完成概率任务数', ...
    '综合目标函数J3'});

disp(' ');
disp('================ DBSCAN 参数搜索结果 ================');
disp(SearchTable);

writetable( ...
    SearchTable, ...
    'Q3_DBSCAN参数搜索结果.xlsx');

%% ==================== Step 10：输出最优方案关键结果 ====================

fprintf('\n');
fprintf('============================================================\n');
fprintf(' 最优 DBSCAN 与任务包定价结果\n');
fprintf('============================================================\n');

fprintf('最优 eps：%.2f km\n', best.eps);
fprintf('最优 MinPts：%d\n', best.minPts);
fprintf('发布单元数量：%d\n', best.publicationUnitCount);
fprintf('实际任务包数量：%d\n', best.actualBundleCount);
fprintf('被打包任务数量：%d\n', best.bundledTaskCount);
fprintf('单独发布任务数量：%d\n', best.singleTaskCount);

fprintf('\n第二问总成本 C2：%.4f\n', C2);
fprintf('第三问总成本 C3：%.4f\n', best.C3);
fprintf('成本变化量：%.4f\n', best.C3 - C2);
fprintf('成本变化率：%.2f%%\n', ...
    (best.C3 - C2) / C2 * 100);

fprintf('\n第二问期望完成任务数 M2：%.4f\n', M2);
fprintf('第三问期望完成任务数 M3：%.4f\n', best.M3);
fprintf('期望完成任务数变化：%.4f\n', best.M3 - M2);

fprintf('\n第二问预测完成率 R2：%.2f%%\n', R2 * 100);
fprintf('第三问预测完成率 R3：%.2f%%\n', best.R3 * 100);
fprintf('预测完成率变化：%.2f 个百分点\n', ...
    (best.R3 - R2) * 100);

fprintf('\n第二问低完成概率任务数 L2：%d\n', L2);
fprintf('第三问低完成概率任务数 L3：%d\n', best.L3);
fprintf('低完成概率任务数变化：%d\n', best.L3 - L2);

fprintf('\n最优综合目标函数 J3：%.8f\n', best.J3);

%% ==================== Step 11：构造任务包结果表 ====================

K = length(best.packages);

packageID = (1:K)';
packageSize = best.packageMeta.size;
packageCenterLat = best.packageMeta.centerLat;
packageCenterLon = best.packageMeta.centerLon;
packageMeanRadius = best.packageMeta.meanRadius;
packageCompactness = best.packageMeta.lambda;
packageLowProbRatio = best.packageMeta.q;
packageQ2Price = best.packageMeta.S2;
packageLowerPrice = best.packageMeta.lower;
packageUpperPrice = best.packageMeta.upper;
packageFinalPrice = best.Bopt;
packagePriceChange = packageFinalPrice - packageQ2Price;

packageExpectedQ2 = zeros(K, 1);
packageExpectedQ3 = zeros(K, 1);
packageTaskIDs = strings(K, 1);

taskPackageID = zeros(n, 1);
taskPackageSize = zeros(n, 1);
taskParentCluster = zeros(n, 1);

for k = 1:K

    idx = best.packages{k};

    packageExpectedQ2(k) = sum(p2(idx));
    packageExpectedQ3(k) = sum(best.p3(idx));

    packageTaskIDs(k) = strjoin( ...
        cellstr(string(taskID(idx))), ', ');

    taskPackageID(idx) = k;
    taskPackageSize(idx) = length(idx);
    taskParentCluster(idx) = best.parentCluster(k);
end

PackageTable = table( ...
    packageID, ...
    best.parentCluster, ...
    packageSize, ...
    packageCenterLat, ...
    packageCenterLon, ...
    packageMeanRadius, ...
    packageCompactness, ...
    packageLowProbRatio, ...
    packageQ2Price, ...
    packageLowerPrice, ...
    packageUpperPrice, ...
    packageFinalPrice, ...
    packagePriceChange, ...
    packageExpectedQ2, ...
    packageExpectedQ3, ...
    packageExpectedQ3 - packageExpectedQ2, ...
    packageTaskIDs, ...
    'VariableNames', { ...
    '任务包编号', ...
    '原DBSCAN聚类编号', ...
    '任务包规模', ...
    '任务包中心纬度', ...
    '任务包中心经度', ...
    '包内平均中心距离', ...
    '空间紧凑系数', ...
    '低完成概率任务比例', ...
    '第二问包内价格总和', ...
    '任务包价格下限', ...
    '任务包价格上限', ...
    '第三问最终任务包价格', ...
    '任务包价格变化量', ...
    '第二问包内期望完成数', ...
    '第三问包内期望完成数', ...
    '包内期望完成数变化', ...
    '包内任务编号'});

writetable( ...
    PackageTable, ...
    'Q3_任务包信息表.xlsx');

%% ==================== Step 12：构造任务级结果表 ====================

TaskResultTable = table( ...
    taskID, ...
    taskLat, ...
    taskLon, ...
    Y, ...
    P0, ...
    P2, ...
    best.P3, ...
    best.P3 - P2, ...
    p2, ...
    best.p3, ...
    best.p3 - p2, ...
    p2 >= targetProb, ...
    best.p3 >= targetProb, ...
    best.clusterLabel, ...
    taskParentCluster, ...
    taskPackageID, ...
    taskPackageSize, ...
    di_min, ...
    Ni, ...
    avgC, ...
    avgQ, ...
    taskDensity, ...
    competitionIndex, ...
    'VariableNames', { ...
    '任务编号', ...
    '任务纬度', ...
    '任务经度', ...
    '实际完成情况', ...
    '原始价格', ...
    '第二问优化价格', ...
    '第三问等效价格', ...
    '第三问相对第二问价格变化', ...
    '第二问预测完成概率', ...
    '第三问预测完成概率', ...
    '预测概率变化量', ...
    '第二问是否达到概率阈值', ...
    '第三问是否达到概率阈值', ...
    'DBSCAN聚类编号', ...
    '原DBSCAN聚类编号', ...
    '最终任务包编号', ...
    '最终任务包规模', ...
    '最近会员距离', ...
    '周边会员数量', ...
    '平均信誉值', ...
    '平均预订限额', ...
    '任务密度', ...
    '竞争强度'});

writetable( ...
    TaskResultTable, ...
    'Q3_任务打包定价结果.xlsx');

%% ==================== Step 13：输出方案比较表 ====================

CompareTable = table( ...
    {'总成本'; ...
     '平均等效价格'; ...
     '期望完成任务数'; ...
     '预测完成率'; ...
     '低完成概率任务数'}, ...
    [C2; ...
     mean(P2); ...
     M2; ...
     R2 * 100; ...
     L2], ...
    [best.C3; ...
     mean(best.P3); ...
     best.M3; ...
     best.R3 * 100; ...
     best.L3], ...
    [best.C3 - C2; ...
     mean(best.P3) - mean(P2); ...
     best.M3 - M2; ...
     (best.R3 - R2) * 100; ...
     best.L3 - L2], ...
    'VariableNames', { ...
    '指标', ...
    '第二问多目标优化方案', ...
    '第三问DBSCAN打包方案', ...
    '变化量'});

disp(' ');
disp('================ 第二问与第三问比较结果 ================');
disp(CompareTable);

writetable( ...
    CompareTable, ...
    'Q3_第二问与第三问比较表.xlsx');

%% ==================== Step 14：绘制图像 ====================

fprintf('\n================ Step 12：绘制图像 ================\n');

%% 图1：DBSCAN 任务打包空间分布图

figure;

singleIndex = taskPackageSize == 1;
bundleIndex = taskPackageSize >= 2;

scatter( ...
    taskLon(singleIndex), taskLat(singleIndex), ...
    18, [0.6, 0.6, 0.6], 'filled');

hold on;

scatter( ...
    taskLon(bundleIndex), taskLat(bundleIndex), ...
    28, taskPackageID(bundleIndex), 'filled');

scatter( ...
    packageCenterLon(packageSize >= 2), ...
    packageCenterLat(packageSize >= 2), ...
    45, 'k', 'x', 'LineWidth', 1.2);

xlabel('经度');
ylabel('纬度');
title(sprintf( ...
    '最优 DBSCAN 任务打包空间分布图：eps=%.2f km，MinPts=%d', ...
    best.eps, best.minPts));

legend( ...
    {'单独发布任务', '被打包任务', '任务包中心'}, ...
    'Location', 'best');

grid on;
hold off;

saveFigure300('Q3_DBSCAN任务打包空间分布图.png');

%% 图2：任务包规模分布图

sizeValues = 1:maxPackSize;
sizeCount = zeros(size(sizeValues));

for s = 1:length(sizeValues)
    sizeCount(s) = sum(packageSize == sizeValues(s));
end

figure;
bar(sizeValues, sizeCount);

xlabel('任务包规模');
ylabel('发布单元数量');
title('任务包规模分布图');
set(gca, 'XTick', sizeValues);
grid on;

saveFigure300('Q3_任务包规模分布图.png');

%% 图3：第二问与第三问价格比较图

figure;
scatter(P2, best.P3, 28, 'filled');

hold on;

minPrice = min([P2; best.P3]);
maxPrice = max([P2; best.P3]);

plot( ...
    [minPrice, maxPrice], ...
    [minPrice, maxPrice], ...
    'k--', 'LineWidth', 1.2);

xlabel('第二问多目标优化价格');
ylabel('第三问打包等效价格');
title('第二问与第三问任务价格比较图');
grid on;
hold off;

saveFigure300('Q3_第二问与第三问价格比较图.png');

%% 图4：第二问与第三问完成概率比较图

figure;
scatter(p2, best.p3, 28, 'filled');

hold on;

plot([0, 1], [0, 1], 'k--', 'LineWidth', 1.2);
plot([targetProb, targetProb], [0, 1], ...
    'r--', 'LineWidth', 1.0);
plot([0, 1], [targetProb, targetProb], ...
    'r--', 'LineWidth', 1.0);

xlabel('第二问预测完成概率');
ylabel('第三问预测完成概率');
title('第二问与第三问预测完成概率比较图');

xlim([0, 1]);
ylim([0, 1]);
grid on;
hold off;

saveFigure300('Q3_第二问与第三问完成概率比较图.png');

%% 图5：期望完成任务数对比图

figure;
bar([M2, best.M3]);

set(gca, ...
    'XTickLabel', {'第二问', '第三问'});

ylabel('期望完成任务数');
title('第二问与第三问期望完成任务数对比图');
grid on;

saveFigure300('Q3_期望完成任务数对比图.png');

%% 图6：总成本对比图

figure;
bar([C2, best.C3]);

set(gca, ...
    'XTickLabel', {'第二问', '第三问'});

ylabel('总成本');
title('第二问与第三问总成本对比图');
grid on;

saveFigure300('Q3_第二问与第三问总成本对比图.png');

%% 图7：低完成概率任务数对比图

figure;
bar([L2, best.L3]);

set(gca, ...
    'XTickLabel', {'第二问', '第三问'});

ylabel('低完成概率任务数');
title('第二问与第三问低完成概率任务数对比图');
grid on;

saveFigure300('Q3_低完成概率任务数对比图.png');

%% 图8：DBSCAN 参数搜索综合目标函数图

Jmatrix = nan(length(minPtsList), length(epsList));

% 使用表格下标访问中文列名，避免中文变量名导致语法错误
epsColumn = SearchTable{:, 'DBSCAN邻域半径eps'};
minPtsColumn = SearchTable{:, 'DBSCAN最小点数MinPts'};
JColumn = SearchTable{:, '综合目标函数J3'};

for i = 1:height(SearchTable)

    ePosition = find( ...
        abs(epsList - epsColumn(i)) < 1e-10, ...
        1);

    mPosition = find( ...
        minPtsList == minPtsColumn(i), ...
        1);

    % 确保当前参数在候选参数列表中能够找到
    if ~isempty(ePosition) && ~isempty(mPosition)
        Jmatrix(mPosition, ePosition) = JColumn(i);
    end
end

figure;

imagesc(epsList, minPtsList, Jmatrix);

set(gca, 'YDir', 'normal');

colorbar;
xlabel('DBSCAN 邻域半径 eps/km');
ylabel('DBSCAN 最小点数 MinPts');
title('DBSCAN 参数组合综合目标函数热力图');

saveFigure300('Q3_DBSCAN参数综合目标函数热力图.png');

%% 图9：多目标优化迭代过程

figure;

yyaxis left;
plot( ...
    best.history.iteration, ...
    best.history.expected, ...
    'LineWidth', 1.5);

ylabel('期望完成任务数');

yyaxis right;
plot( ...
    best.history.iteration, ...
    best.history.cost, ...
    'LineWidth', 1.5);

ylabel('总成本');
xlabel('优化迭代次数');
title('任务包多目标定价优化过程');
grid on;

saveFigure300('Q3_任务包多目标优化过程图.png');

fprintf('所有图像已保存为 PNG 文件。\n');

%% ==================== Step 15：运行结果自动解释 ====================

fprintf('\n');
fprintf('============================================================\n');
fprintf(' 代码运行结果解释\n');
fprintf('============================================================\n');

fprintf(['1. 最优 eps 和 MinPts 表示在所设置的候选范围内，' ...
    '该组 DBSCAN 参数对应的任务打包和定价综合效果最好。\n']);

fprintf(['2. 实际任务包数量表示包含两个及以上任务的发布单元数量；' ...
    '单独发布任务数量表示 DBSCAN 噪声点或无法形成有效任务包的任务数量。\n']);

fprintf(['3. 第三问总成本 C3 与第二问总成本 C2 的差值，' ...
    '反映任务打包定价对平台总支出的影响。\n']);

fprintf(['4. 第三问期望完成任务数 M3 与第二问 M2 的差值，' ...
    '反映打包方案对整体预测完成概率之和的影响。\n']);

fprintf(['5. 预测完成率表示预测完成概率达到 %.2f 的任务比例，' ...
    '它不是实际执行完成率。\n'], targetProb);

fprintf(['6. 低完成概率任务数越少，表示更多任务达到设定的目标完成概率水平。\n']);

if best.C3 <= C2 && best.M3 >= M2

    fprintf(['7. 当前最优方案在不降低期望完成效果的同时降低了成本，' ...
        '说明打包方案同时实现了成本节约和完成效果保护。\n']);

elseif best.C3 > C2 && best.M3 > M2

    fprintf(['7. 当前最优方案通过适度增加成本提高了期望完成任务数，' ...
        '需要结合成本增长率和完成效果提升幅度进行权衡。\n']);

elseif best.C3 < C2 && best.M3 >= M2

    fprintf(['7. 当前最优方案降低了成本且保持或提高了完成效果，' ...
        '任务打包方案具有较明显优势。\n']);

else

    fprintf(['7. 当前参数范围内打包方案改善有限，' ...
        '可进一步调整 eps、MinPts、任务包规模和价格调整范围。\n']);
end

fprintf(['8. 第三问的预测结果属于基于历史单任务数据的情景模拟，' ...
    '不能解释为任务包实际投入运行后的真实完成率。\n']);

fprintf('\n结果文件已输出：\n');
fprintf('Q3_Logistic回归系数.xlsx\n');
fprintf('Q3_DBSCAN参数搜索结果.xlsx\n');
fprintf('Q3_任务包信息表.xlsx\n');
fprintf('Q3_任务打包定价结果.xlsx\n');
fprintf('Q3_第二问与第三问比较表.xlsx\n');

fprintf('\n第三问计算完成。\n');

%% ============================================================
%                      局部函数区
% =============================================================

function T = readSmartTable(fileName)
% 读取 Excel 表格，尽量保留原字段名称

    try
        T = readtable( ...
            fileName, ...
            'VariableNamingRule', 'preserve');
    catch
        T = readtable(fileName);
    end
end

function colName = findCol(T, keys)
% 根据关键词自动寻找字段名称

    names = T.Properties.VariableNames;
    colName = '';

    for k = 1:length(keys)

        key = keys{k};

        for i = 1:length(names)

            if contains(names{i}, key)
                colName = names{i};
                return;
            end
        end
    end

    error( ...
        '没有找到所需字段。字段关键词为：%s', ...
        strjoin(keys, ', '));
end

function x = toNumericVector(col)
% 将表格中的不同类型数据转换为数值列向量

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

function [lat, lon] = parseGPSAuto( ...
    gpsCol, taskLatCenter, taskLonCenter)
% 自动判断会员 GPS 中经度和纬度的排列顺序

    gpsString = string(gpsCol);
    N = length(gpsString);

    lat = nan(N, 1);
    lon = nan(N, 1);

    for i = 1:N

        textValue = gpsString(i);

        numberText = regexp( ...
            textValue, ...
            '[-+]?\d+\.?\d*', ...
            'match');

        if length(numberText) < 2
            continue;
        end

        a = str2double(numberText{1});
        b = str2double(numberText{2});

        % 候选顺序一：纬度、经度
        lat1 = a;
        lon1 = b;

        % 候选顺序二：经度、纬度
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
        end
    end
end

function flag = isValidLatLon(lat, lon)
% 判断经纬度是否处于合法范围

    flag = ...
        ~isnan(lat) && ...
        ~isnan(lon) && ...
        lat >= -90 && lat <= 90 && ...
        lon >= -180 && lon <= 180;
end

function d = geoDistanceKm(lat1, lon1, lat2, lon2)
% 经纬度近似距离，单位为 km
%
% 适用于当前任务区域范围，不需要额外地图工具箱

    d = 111 .* sqrt( ...
        (lat1 - lat2).^2 + ...
        ((lon1 - lon2) .* cosd(lat1)).^2);
end

function [Xstandard, muValue, sigmaValue] = ...
    standardizeData(X)
% 对解释变量进行标准化

    muValue = mean(X, 1, 'omitnan');
    sigmaValue = std(X, 0, 1, 'omitnan');

    sigmaValue(sigmaValue == 0) = 1;
    sigmaValue(isnan(sigmaValue)) = 1;

    Xstandard = ...
        (X - muValue) ./ sigmaValue;
end

function loss = logisticNLL(alpha, X, Y)
% Logistic 回归负对数似然函数

    Z = X * alpha;
    probability = sigmoid(Z);

    smallValue = 1e-10;

    probability = min( ...
        max(probability, smallValue), ...
        1 - smallValue);

    loss = -sum( ...
        Y .* log(probability) + ...
        (1 - Y) .* log(1 - probability));

    % 很小的正则项，用于提高数值稳定性
    loss = loss + ...
        1e-6 * sum(alpha(2:end).^2);
end

function probability = sigmoid(Z)
% Logistic 函数

    probability = 1 ./ (1 + exp(-Z));
end

function probability = predictProb( ...
    P, alpha, mu_logit, sigma_logit, ...
    di_min, Ni, avgC, avgQ, ...
    taskDensity, competitionIndex)
% 根据给定价格重新计算任务预测完成概率

    P = P(:);

    pricePerDistance = ...
        P ./ (di_min + 0.1);

    pricePerCompetition = ...
        P ./ (taskDensity + 1);

    Xraw = [ ...
        P, ...
        di_min, ...
        Ni, ...
        avgC, ...
        avgQ, ...
        taskDensity, ...
        competitionIndex, ...
        pricePerDistance, ...
        pricePerCompetition];

    Xstandard = ...
        (Xraw - mu_logit) ./ sigma_logit;

    Xdesign = ...
        [ones(size(Xstandard, 1), 1), Xstandard];

    probability = ...
        sigmoid(Xdesign * alpha);
end

function label = dbscanSimple(distanceMatrix, epsValue, minPts)
% 自定义 DBSCAN 算法
%
% 输入：
% distanceMatrix：任务之间的距离矩阵
% epsValue：DBSCAN 邻域半径
% minPts：核心点最少邻域点数，包括自身
%
% 输出：
% label = 0 表示噪声任务
% label > 0 表示所属 DBSCAN 聚类编号

    n = size(distanceMatrix, 1);

    label = zeros(n, 1);
    visited = false(n, 1);

    clusterNumber = 0;

    for i = 1:n

        if visited(i)
            continue;
        end

        visited(i) = true;

        neighbor = find( ...
            distanceMatrix(i, :) <= epsValue);

        if length(neighbor) < minPts

            % 暂时标记为噪声点
            label(i) = 0;

        else

            clusterNumber = clusterNumber + 1;
            label(i) = clusterNumber;

            seedSet = neighbor(:);
            pointer = 1;

            while pointer <= length(seedSet)

                j = seedSet(pointer);

                if ~visited(j)

                    visited(j) = true;

                    neighborJ = find( ...
                        distanceMatrix(j, :) <= epsValue);

                    if length(neighborJ) >= minPts

                        seedSet = unique( ...
                            [seedSet; neighborJ(:)], ...
                            'stable');
                    end
                end

                % 原本为噪声点或未分配点时，加入当前聚类
                if label(j) == 0
                    label(j) = clusterNumber;
                end

                pointer = pointer + 1;
            end
        end
    end
end

function [packages, parentCluster] = ...
    buildPackagesFromDBSCAN( ...
    clusterLabel, distanceMatrix, maxPackSize)
% 将 DBSCAN 聚类进一步拆分成满足规模约束的任务包
%
% 规则：
% 1. DBSCAN 噪声任务作为单独任务发布；
% 2. 聚类规模不超过 maxPackSize 时直接形成任务包；
% 3. 聚类规模过大时，按空间距离进行平衡拆分；
% 4. 保证每个任务仅出现一次。

    packages = {};
    parentCluster = [];

    clusterNumbers = unique(clusterLabel);
    clusterNumbers(clusterNumbers == 0) = [];

    for c = clusterNumbers(:)'

        clusterTasks = find(clusterLabel == c);
        taskCount = length(clusterTasks);

        if taskCount <= maxPackSize

            packages{end + 1, 1} = clusterTasks(:);
            parentCluster(end + 1, 1) = c;

        else

            % 计算应拆分成多少个任务包
            groupCount = ceil(taskCount / maxPackSize);

            % 平衡每个包的规模，防止最后只剩一个任务
            baseSize = floor(taskCount / groupCount);
            remainder = mod(taskCount, groupCount);

            targetSizes = ...
                baseSize * ones(groupCount, 1);

            targetSizes(1:remainder) = ...
                targetSizes(1:remainder) + 1;

            unassigned = clusterTasks(:);

            for g = 1:groupCount

                targetSize = targetSizes(g);

                if length(unassigned) == targetSize

                    chosen = unassigned;

                else

                    % 先选择相对外围的点作为起点，
                    % 再选取与其最近的任务
                    subDistance = ...
                        distanceMatrix(unassigned, unassigned);

                    averageDistance = ...
                        mean(subDistance, 2);

                    [~, seedPosition] = ...
                        max(averageDistance);

                    seedTask = ...
                        unassigned(seedPosition);

                    [~, order] = sort( ...
                        distanceMatrix(seedTask, unassigned), ...
                        'ascend');

                    chosen = ...
                        unassigned(order(1:targetSize));
                end

                packages{end + 1, 1} = chosen(:);
                parentCluster(end + 1, 1) = c;

                unassigned = ...
                    unassigned(~ismember(unassigned, chosen));
            end
        end
    end

    % DBSCAN 噪声任务单独发布
    noiseTasks = find(clusterLabel == 0);

    for i = 1:length(noiseTasks)

        packages{end + 1, 1} = noiseTasks(i);
        parentCluster(end + 1, 1) = 0;
    end

    % 检查每个任务是否恰好出现一次
    allTasks = vertcat(packages{:});

    if length(unique(allTasks)) ~= length(allTasks)
        error('任务包构造出现重复任务。');
    end

    if length(allTasks) ~= length(clusterLabel)
        error('任务包构造后存在任务遗漏。');
    end
end

function meta = computePackageMeta( ...
    packages, parentCluster, ...
    taskLat, taskLon, ...
    P2, p2, targetProb, epsValue, ...
    deltaDiscount, deltaCompensation)
% 计算每个任务包的空间和价格特征

    K = length(packages);

    meta.parentCluster = parentCluster(:);
    meta.size = zeros(K, 1);
    meta.centerLat = zeros(K, 1);
    meta.centerLon = zeros(K, 1);
    meta.meanRadius = zeros(K, 1);
    meta.lambda = zeros(K, 1);
    meta.q = zeros(K, 1);
    meta.S2 = zeros(K, 1);
    meta.lower = zeros(K, 1);
    meta.upper = zeros(K, 1);

    for k = 1:K

        idx = packages{k};
        packSize = length(idx);

        meta.size(k) = packSize;

        centerLat = mean(taskLat(idx));
        centerLon = mean(taskLon(idx));

        meta.centerLat(k) = centerLat;
        meta.centerLon(k) = centerLon;

        centerDistance = geoDistanceKm( ...
            centerLat, centerLon, ...
            taskLat(idx), taskLon(idx));

        meanRadius = mean(centerDistance);

        meta.meanRadius(k) = meanRadius;
        meta.S2(k) = sum(P2(idx));
        meta.q(k) = mean(p2(idx) < targetProb);

        if packSize >= 2

            compactness = max( ...
                0, 1 - meanRadius / epsValue);

            meta.lambda(k) = compactness;

            meta.lower(k) = ...
                meta.S2(k) * ...
                (1 - deltaDiscount * compactness);

            meta.upper(k) = ...
                meta.S2(k) * ...
                (1 + deltaCompensation * meta.q(k));

        else

            % 单独任务价格保持第二问结果不变
            meta.lambda(k) = 0;
            meta.lower(k) = meta.S2(k);
            meta.upper(k) = meta.S2(k);
        end
    end
end

function [Bopt, P3, p3, history, Jcurrent] = ...
    optimizePackagePricing( ...
    packages, meta, ...
    P2, C2, M2, ...
    omega3, eta3, priceStep, maxIter, ...
    alpha, mu_logit, sigma_logit, ...
    di_min, Ni, avgC, avgQ, ...
    taskDensity, competitionIndex)
% 任务包多目标定价优化
%
% 优化思想：
% 1. 初始任务包价格为第二问包内价格总和；
% 2. 为每个任务包提前计算价格候选网格；
% 3. 每次尝试将某个任务包价格向上或向下移动一步；
% 4. 保留能使综合目标函数增加最大的调整；
% 5. 保证总成本不超过成本上限；
% 6. 保证期望完成任务数不低于第二问。

    K = length(packages);
    n = length(P2);

    priceGrid = cell(K, 1);
    expectedGrid = cell(K, 1);
    baseState = zeros(K, 1);

    %% 预计算每个任务包在不同价格下的期望完成数

    for k = 1:K

        idx = packages{k};

        S2 = meta.S2(k);
        lowerPrice = meta.lower(k);
        upperPrice = meta.upper(k);

        if meta.size(k) == 1

            candidatePrice = S2;

        else

            downStepCount = floor( ...
                (S2 - lowerPrice) / priceStep + 1e-10);

            upStepCount = floor( ...
                (upperPrice - S2) / priceStep + 1e-10);

            stepIndex = ...
                (-downStepCount:upStepCount)';

            candidatePrice = ...
                S2 + stepIndex * priceStep;
        end

        % 防止浮点误差和重复值
        candidatePrice = unique(candidatePrice, 'sorted');

        if ~any(abs(candidatePrice - S2) < 1e-8)
            candidatePrice = sort([candidatePrice; S2]);
        end

        [~, basePosition] = min( ...
            abs(candidatePrice - S2));

        priceGrid{k} = candidatePrice;
        baseState(k) = basePosition;

        expectedValue = zeros( ...
            length(candidatePrice), 1);

        for s = 1:length(candidatePrice)

            Bcandidate = candidatePrice(s);

            equivalentPrice = ...
                P2(idx) .* Bcandidate ./ S2;

            probabilityCandidate = predictProb( ...
                equivalentPrice, ...
                alpha, mu_logit, sigma_logit, ...
                di_min(idx), Ni(idx), ...
                avgC(idx), avgQ(idx), ...
                taskDensity(idx), ...
                competitionIndex(idx));

            expectedValue(s) = ...
                sum(probabilityCandidate);
        end

        expectedGrid{k} = expectedValue;
    end

    %% 从第二问价格开始进行贪心迭代

    currentState = baseState;

    Bcurrent = zeros(K, 1);
    packageExpectedCurrent = zeros(K, 1);

    for k = 1:K
        Bcurrent(k) = priceGrid{k}(currentState(k));
        packageExpectedCurrent(k) = ...
            expectedGrid{k}(currentState(k));
    end

    Ccurrent = sum(Bcurrent);
    Mcurrent = sum(packageExpectedCurrent);

    costUpperBound = ...
        (1 + eta3) * C2;

    Jcurrent = ...
        omega3 * (Mcurrent - M2) / max(n - M2, 1e-10) ...
        - (1 - omega3) * (Ccurrent - C2) / C2;

    history.iteration = 0;
    history.cost = Ccurrent;
    history.expected = Mcurrent;
    history.objective = Jcurrent;

    iteration = 0;

    while iteration < maxIter

        bestGain = 0;
        bestPackage = 0;
        bestNewState = 0;
        bestCandidateC = Ccurrent;
        bestCandidateM = Mcurrent;
        bestCandidateJ = Jcurrent;

        for k = 1:K

            currentPosition = currentState(k);

            % 分别尝试下降一步和上升一步
            directionList = [-1, 1];

            for direction = directionList

                newPosition = ...
                    currentPosition + direction;

                if newPosition < 1 || ...
                   newPosition > length(priceGrid{k})
                    continue;
                end

                newPackagePrice = ...
                    priceGrid{k}(newPosition);

                oldPackagePrice = ...
                    priceGrid{k}(currentPosition);

                deltaCost = ...
                    newPackagePrice - oldPackagePrice;

                candidateCost = ...
                    Ccurrent + deltaCost;

                if candidateCost > costUpperBound + 1e-8
                    continue;
                end

                newPackageExpected = ...
                    expectedGrid{k}(newPosition);

                oldPackageExpected = ...
                    expectedGrid{k}(currentPosition);

                deltaExpected = ...
                    newPackageExpected - oldPackageExpected;

                candidateExpected = ...
                    Mcurrent + deltaExpected;

                % 完成效果保护约束
                if candidateExpected < M2 - 1e-8
                    continue;
                end

                candidateObjective = ...
                    omega3 * ...
                    (candidateExpected - M2) / ...
                    max(n - M2, 1e-10) ...
                    - (1 - omega3) * ...
                    (candidateCost - C2) / C2;

                objectiveGain = ...
                    candidateObjective - Jcurrent;

                if objectiveGain > bestGain + 1e-12

                    bestGain = objectiveGain;
                    bestPackage = k;
                    bestNewState = newPosition;
                    bestCandidateC = candidateCost;
                    bestCandidateM = candidateExpected;
                    bestCandidateJ = candidateObjective;
                end
            end
        end

        % 所有调整均不能提高综合目标函数
        if bestPackage == 0 || bestGain <= 1e-12
            break;
        end

        currentState(bestPackage) = bestNewState;

        Ccurrent = bestCandidateC;
        Mcurrent = bestCandidateM;
        Jcurrent = bestCandidateJ;

        iteration = iteration + 1;

        history.iteration(end + 1, 1) = iteration;
        history.cost(end + 1, 1) = Ccurrent;
        history.expected(end + 1, 1) = Mcurrent;
        history.objective(end + 1, 1) = Jcurrent;
    end

    %% 根据最优任务包价格计算任务等效价格和概率

    Bopt = zeros(K, 1);
    P3 = zeros(n, 1);
    p3 = zeros(n, 1);

    for k = 1:K

        idx = packages{k};

        Bopt(k) = ...
            priceGrid{k}(currentState(k));

        P3(idx) = ...
            P2(idx) .* Bopt(k) ./ meta.S2(k);

        p3(idx) = predictProb( ...
            P3(idx), ...
            alpha, mu_logit, sigma_logit, ...
            di_min(idx), Ni(idx), ...
            avgC(idx), avgQ(idx), ...
            taskDensity(idx), ...
            competitionIndex(idx));
    end
end

function saveFigure300(fileName)
% 将当前图像保存为 300 dpi PNG 文件

    try
        exportgraphics( ...
            gcf, fileName, ...
            'Resolution', 300);
    catch
        saveas(gcf, fileName);
    end
end