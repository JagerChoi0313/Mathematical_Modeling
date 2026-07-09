%% Q3_Bundle_Pricing_Model.m
% 第三问：基于多元线性回归 + Logistic 回归的任务打包定价模型
%
% 模型思路：
% 1. 构造任务与会员特征；
% 2. 用多元线性回归估计任务基础价格；
% 3. 用 Logistic 回归预测任务完成概率；
% 4. 复现第二问单任务优化定价方案；
% 5. 根据任务距离进行打包；
% 6. 计算任务包价格；
% 7. 将任务包价格分摊到任务；
% 8. 用 Logistic 模型评价打包方案效果；
% 9. 与原方案、第二问单任务优化方案比较。

clear;
clc;
close all;

%% ===================== Step 0：参数设置 =====================

% 数据文件
taskFile = '附件一：已结束项目任务数据.xls';
memberFile = '附件二：会员信息数据.xlsx';

% 第一问、第二问使用的特征半径
rMember = 3;          % 任务周边会员统计半径，单位 km
rTask   = 3;          % 任务密度统计半径，单位 km

% 第二问单任务优化参数
targetProb = 0.62;    % 目标完成概率阈值
etaMax2 = 0.05;       % 第二问总成本最大增长率
deltaMax = 10;        % 单任务最大涨价幅度
priceStep = 0.5;      % 价格搜索步长

% 第三问打包参数
rBundle = 0.8;        % 打包距离阈值，单位 km，可根据结果调整
minBundleSize = 2;    % 至少几个任务才形成任务包
maxBundleSize = 5;    % 每个任务包最多包含几个任务

% 第三问打包定价参数搜索范围
% rho 表示空间集中带来的共享成本折扣强度
% gamma 表示低完成概率任务的补偿强度
rhoGrid = 0:0.02:0.20;
gammaGrid = 0:0.02:0.50;

% 第三问相对第二问的最大成本增长率
etaMax3 = 0.05;

fprintf('\n================ 第三问：任务打包定价模型 ================\n');
fprintf('会员统计半径 rMember = %.2f km\n', rMember);
fprintf('任务密度半径 rTask = %.2f km\n', rTask);
fprintf('打包距离阈值 rBundle = %.2f km\n', rBundle);
fprintf('最小任务包规模 minBundleSize = %d\n', minBundleSize);
fprintf('最大任务包规模 maxBundleSize = %d\n', maxBundleSize);
fprintf('目标完成概率阈值 targetProb = %.2f\n', targetProb);

%% ===================== Step 1：读取数据 =====================

Task = readSmartTable(taskFile);
Member = readSmartTable(memberFile);

disp('附件一字段名：');
disp(Task.Properties.VariableNames');

disp('附件二字段名：');
disp(Member.Properties.VariableNames');

%% ===================== Step 2：提取任务数据 =====================

taskID_col  = findCol(Task, {'任务号码', '任务编号', '编号'});
taskLat_col = findCol(Task, {'任务gps 纬度', '任务gps纬度', 'gps 纬度', '纬度'});
taskLon_col = findCol(Task, {'任务gps经度', '任务gps 经度', 'gps 经度', '经度'});
price_col   = findCol(Task, {'任务标价', '标价', '定价', '价格'});
finish_col  = findCol(Task, {'任务执行情况', '执行情况', '完成情况', '是否完成'});

taskID  = Task.(taskID_col);
taskLat = toNumericVector(Task.(taskLat_col));
taskLon = toNumericVector(Task.(taskLon_col));
P0      = toNumericVector(Task.(price_col));       % 原始价格
Y       = toNumericVector(Task.(finish_col));      % 实际完成情况

% 删除任务缺失数据
validTask = ~isnan(taskLat) & ~isnan(taskLon) & ~isnan(P0) & ~isnan(Y);

taskID  = taskID(validTask);
taskLat = taskLat(validTask);
taskLon = taskLon(validTask);
P0      = P0(validTask);
Y       = Y(validTask);

n = length(P0);

fprintf('\n================ 基本数据统计 ================\n');
fprintf('任务总数：%d\n', n);
fprintf('完成任务数：%d\n', sum(Y == 1));
fprintf('未完成任务数：%d\n', sum(Y == 0));
fprintf('原始实际完成率：%.2f%%\n', mean(Y) * 100);

%% ===================== Step 3：提取并清洗会员数据 =====================

memberID_col  = findCol(Member, {'会员编号', '编号'});
memberGPS_col = findCol(Member, {'会员位置', 'GPS', '位置'});
quota_col     = findCol(Member, {'预订任务限额', '任务限额', '限额'});
credit_col    = findCol(Member, {'信誉值', '信誉'});

memberID  = Member.(memberID_col);
memberGPS = Member.(memberGPS_col);
Q         = toNumericVector(Member.(quota_col));     % 预订任务限额
C         = toNumericVector(Member.(credit_col));    % 信誉值

% 根据任务中心位置自动判断会员 GPS 经纬度顺序
taskLatCenter = median(taskLat);
taskLonCenter = median(taskLon);

[memberLat, memberLon] = parseGPSAuto(memberGPS, taskLatCenter, taskLonCenter);

% 删除缺失会员
validMember = ~isnan(memberLat) & ~isnan(memberLon) & ~isnan(Q) & ~isnan(C);

memberID  = memberID(validMember);
memberLat = memberLat(validMember);
memberLon = memberLon(validMember);
Q         = Q(validMember);
C         = C(validMember);

% 删除明显远离任务区域的异常会员点
lonMinWide = min(taskLon) - 5;
lonMaxWide = max(taskLon) + 5;
latMinWide = min(taskLat) - 5;
latMaxWide = max(taskLat) + 5;

validRange = memberLon >= lonMinWide & memberLon <= lonMaxWide & ...
             memberLat >= latMinWide & memberLat <= latMaxWide;

removedMember = sum(~validRange);

memberID  = memberID(validRange);
memberLat = memberLat(validRange);
memberLon = memberLon(validRange);
Q         = Q(validRange);
C         = C(validRange);

m = length(C);

fprintf('有效会员总数：%d\n', m);
fprintf('剔除异常会员点数量：%d\n', removedMember);

%% ===================== Step 4：构造任务周边会员特征 =====================

di_min = zeros(n, 1);       % 最近会员距离
Ni     = zeros(n, 1);       % 周边会员数量
Si     = zeros(n, 1);       % 周边会员信誉值总和
Ui     = zeros(n, 1);       % 周边会员预订限额总和

fprintf('\n开始计算任务周边会员特征...\n');

for i = 1:n
    
    d = geoDistanceKm(taskLat(i), taskLon(i), memberLat, memberLon);
    
    di_min(i) = min(d);
    
    idx = d <= rMember;
    
    Ni(i) = sum(idx);
    Si(i) = sum(C(idx));
    Ui(i) = sum(Q(idx));
end

avgC = Si ./ max(Ni, 1);
avgQ = Ui ./ max(Ni, 1);

fprintf('任务周边会员特征构造完成。\n');

%% ===================== Step 5：构造任务密度与竞争特征 =====================

fprintf('开始计算任务之间距离矩阵和任务密度...\n');

DistTask = zeros(n, n);

for i = 1:n
    DistTask(i, :) = geoDistanceKm(taskLat(i), taskLon(i), taskLat, taskLon)';
end

taskDensity = sum(DistTask <= rTask, 2) - 1;
competitionIndex = taskDensity ./ max(Ni, 1);

pricePerDistance0 = P0 ./ (di_min + 0.1);
pricePerCompetition0 = P0 ./ (taskDensity + 1);

fprintf('任务密度与竞争特征构造完成。\n');

%% ===================== Step 6：多元线性回归定价模型 =====================

% 用于估计任务基础价格的自变量
X_lin_raw = [di_min, ...
             Ni, ...
             avgC, ...
             avgQ, ...
             taskDensity, ...
             competitionIndex, ...
             taskLon, ...
             taskLat];

[X_lin, mu_lin, sigma_lin] = standardizeData(X_lin_raw);

X_lin_design = [ones(n, 1), X_lin];

% 最小二乘估计回归系数
beta = X_lin_design \ P0;

% 线性回归预测价格，即任务基础价格
P_hat = X_lin_design * beta;

% 防止极少数预测价格过低
P_hat = max(P_hat, 1);

% 计算 R2
SSE = sum((P0 - P_hat).^2);
SST = sum((P0 - mean(P0)).^2);
R2 = 1 - SSE / SST;

fprintf('\n================ 多元线性回归定价模型 ================\n');
fprintf('多元线性回归 R2 = %.4f\n', R2);

linNames = {'常数项', '最近会员距离', '周边会员数量', '平均信誉值', ...
            '平均预订限额', '任务密度', '竞争强度', '任务经度', '任务纬度'};

LinCoefTable = table(linNames', beta, ...
    'VariableNames', {'变量', '回归系数'});

disp(LinCoefTable);
writetable(LinCoefTable, 'Q3_多元线性回归系数.xlsx');

%% ===================== Step 7：Logistic 完成概率模型 =====================

X_logit_raw = [P0, ...
               di_min, ...
               Ni, ...
               avgC, ...
               avgQ, ...
               taskDensity, ...
               competitionIndex, ...
               pricePerDistance0, ...
               pricePerCompetition0];

[X_logit, mu_logit, sigma_logit] = standardizeData(X_logit_raw);

X_logit_design = [ones(n, 1), X_logit];

alpha0 = zeros(size(X_logit_design, 2), 1);

options = optimset('MaxIter', 10000, ...
                   'MaxFunEvals', 20000, ...
                   'Display', 'off');

alpha = fminsearch(@(a) logisticNLL(a, X_logit_design, Y), alpha0, options);

p0 = sigmoid(X_logit_design * alpha);

fprintf('\n================ Logistic 完成概率模型 ================\n');

logitNames = {'常数项', '任务价格', '最近会员距离', '周边会员数量', ...
              '平均信誉值', '平均预订限额', '任务密度', ...
              '竞争强度', '单位距离价格', '单位竞争价格'};

LogitCoefTable = table(logitNames', alpha, ...
    'VariableNames', {'变量', 'Logistic回归系数'});

disp(LogitCoefTable);
writetable(LogitCoefTable, 'Q3_Logistic回归系数.xlsx');

%% ===================== Step 8：复现第二问单任务优化方案 =====================

fprintf('\n开始复现第二问单任务优化定价方案...\n');

[P2, p2, adjustedFlag2] = optimizeSingleTaskPricing( ...
    P0, p0, targetProb, etaMax2, deltaMax, priceStep, ...
    alpha, mu_logit, sigma_logit, ...
    di_min, Ni, avgC, avgQ, taskDensity, competitionIndex);

C0 = sum(P0);
M0 = sum(p0);
R0 = mean(p0 >= targetProb);
low0 = sum(p0 < targetProb);

C2 = sum(P2);
M2 = sum(p2);
R2_prob = mean(p2 >= targetProb);
low2 = sum(p2 < targetProb);

fprintf('第二问单任务优化方案复现完成。\n');
fprintf('第二问总成本 C2 = %.4f\n', C2);
fprintf('第二问期望完成任务数 M2 = %.4f\n', M2);
fprintf('第二问预测完成率 R2 = %.2f%%\n', R2_prob * 100);
fprintf('第二问低完成概率任务数 = %d\n', low2);

%% ===================== Step 9：根据任务距离进行打包 =====================

fprintf('\n开始根据任务空间距离生成任务包...\n');

% 优先从第二问下仍低完成概率、任务密度较高的任务开始打包
priorityScore = (p2 < targetProb) * 1000 + taskDensity;
[~, seedOrder] = sort(priorityScore, 'descend');

packageID = zeros(n, 1);
currentPackage = 0;
assigned = false(n, 1);

for s = 1:n
    
    seed = seedOrder(s);
    
    if assigned(seed)
        continue;
    end
    
    % 找到与种子任务距离较近的未分配任务
    nearIdx = find(~assigned & DistTask(seed, :)' <= rBundle);
    
    % 按距离从近到远排序
    [~, ord] = sort(DistTask(seed, nearIdx), 'ascend');
    nearIdx = nearIdx(ord);
    
    % 控制任务包最大规模
    if length(nearIdx) > maxBundleSize
        nearIdx = nearIdx(1:maxBundleSize);
    end
    
    currentPackage = currentPackage + 1;
    
    if length(nearIdx) >= minBundleSize
        % 形成任务包
        packageID(nearIdx) = currentPackage;
        assigned(nearIdx) = true;
    else
        % 不能形成任务包，作为单任务包
        packageID(seed) = currentPackage;
        assigned(seed) = true;
    end
end

K = currentPackage;
bundleSize = zeros(K, 1);

for k = 1:K
    bundleSize(k) = sum(packageID == k);
end

realBundleNum = sum(bundleSize >= minBundleSize);
bundledTaskNum = sum(bundleSize(packageID) >= minBundleSize);

fprintf('总发布单元数量：%d\n', K);
fprintf('实际任务包数量：%d\n', realBundleNum);
fprintf('被打包任务数量：%d\n', bundledTaskNum);
fprintf('单独发布任务数量：%d\n', n - bundledTaskNum);

%% ===================== Step 10：计算任务包特征 =====================

bundleCenterLat = zeros(K, 1);
bundleCenterLon = zeros(K, 1);
bundleCompact = zeros(K, 1);
bundleLambda = zeros(K, 1);
bundleLowRatio = zeros(K, 1);
bundleBaseSum = zeros(K, 1);

for k = 1:K
    
    idx = find(packageID == k);
    
    bundleCenterLat(k) = mean(taskLat(idx));
    bundleCenterLon(k) = mean(taskLon(idx));
    
    dToCenter = geoDistanceKm(bundleCenterLat(k), bundleCenterLon(k), ...
                              taskLat(idx), taskLon(idx));
    
    bundleCompact(k) = mean(dToCenter);
    
    % 空间紧凑度修正系数
    bundleLambda(k) = 1 / (1 + bundleCompact(k));
    
    % 包内低完成概率任务比例
    bundleLowRatio(k) = mean(p2(idx) < targetProb);
    
    % 包内基础价格总和
    bundleBaseSum(k) = sum(P_hat(idx));
end

fprintf('任务包特征计算完成。\n');

%% ===================== Step 11：搜索最优打包定价参数 =====================

fprintf('\n开始搜索打包定价参数 rho 和 gamma...\n');

bestM3 = -inf;
bestR3 = -inf;
bestC3 = inf;
bestLow3 = inf;
bestRho = NaN;
bestGamma = NaN;
bestP3 = [];
bestp3 = [];
bestBundlePrice = [];

for rr = 1:length(rhoGrid)
    
    rho = rhoGrid(rr);
    
    for gg = 1:length(gammaGrid)
        
        gamma = gammaGrid(gg);
        
        [P3_temp, bundlePrice_temp] = computeBundlePrice( ...
            P2, P_hat, packageID, bundleSize, bundleLambda, bundleLowRatio, ...
            bundleBaseSum, rho, gamma, minBundleSize);
        
        p3_temp = predictProbAll(P3_temp, alpha, mu_logit, sigma_logit, ...
            di_min, Ni, avgC, avgQ, taskDensity, competitionIndex);
        
        C3_temp = sum(P3_temp);
        M3_temp = sum(p3_temp);
        R3_temp = mean(p3_temp >= targetProb);
        low3_temp = sum(p3_temp < targetProb);
        
        % 成本约束：第三问总成本不超过第二问总成本的 1 + etaMax3
        if C3_temp <= (1 + etaMax3) * C2
            
            % 以期望完成任务数最大为首要目标
            % 若期望完成任务数相同，则选择成本更低的方案
            if M3_temp > bestM3 || ...
                    (abs(M3_temp - bestM3) < 1e-8 && C3_temp < bestC3)
                
                bestM3 = M3_temp;
                bestR3 = R3_temp;
                bestC3 = C3_temp;
                bestLow3 = low3_temp;
                bestRho = rho;
                bestGamma = gamma;
                bestP3 = P3_temp;
                bestp3 = p3_temp;
                bestBundlePrice = bundlePrice_temp;
            end
        end
    end
end

P3 = bestP3;
p3 = bestp3;
bundlePrice = bestBundlePrice;

fprintf('打包定价参数搜索完成。\n');
fprintf('最优 rho = %.4f\n', bestRho);
fprintf('最优 gamma = %.4f\n', bestGamma);

%% ===================== Step 12：计算第三问方案评价指标 =====================

C3 = sum(P3);
M3 = sum(p3);
R3 = mean(p3 >= targetProb);
low3 = sum(p3 < targetProb);

avgP0 = mean(P0);
avgP2 = mean(P2);
avgP3 = mean(P3);

costChange32 = C3 - C2;
costRate32 = costChange32 / C2;

fprintf('\n================ 第三问打包方案评价 ================\n');
fprintf('第三问总成本 C3 = %.4f\n', C3);
fprintf('第三问平均等效价格 = %.4f\n', avgP3);
fprintf('相对第二问成本变化量 = %.4f\n', costChange32);
fprintf('相对第二问成本变化率 = %.2f%%\n', costRate32 * 100);
fprintf('第三问期望完成任务数 M3 = %.4f\n', M3);
fprintf('第三问预测完成率 R3 = %.2f%%\n', R3 * 100);
fprintf('第三问低完成概率任务数 = %d\n', low3);
fprintf('相对第二问期望完成任务数提升 = %.4f\n', M3 - M2);
fprintf('相对第二问预测完成率提升 = %.2f 个百分点\n', (R3 - R2_prob) * 100);
fprintf('相对第二问低完成概率任务数变化 = %d\n', low3 - low2);

%% ===================== Step 13：输出结果表格 =====================

SchemeCompareTable = table( ...
    {'总成本'; '平均价格'; '期望完成任务数'; '预测完成率'; '低完成概率任务数'}, ...
    [C0; avgP0; M0; R0 * 100; low0], ...
    [C2; avgP2; M2; R2_prob * 100; low2], ...
    [C3; avgP3; M3; R3 * 100; low3], ...
    'VariableNames', {'指标', '原方案', '第二问单任务优化方案', '第三问打包方案'});

disp('三种方案比较表：');
disp(SchemeCompareTable);

writetable(SchemeCompareTable, 'Q3_三种方案比较表.xlsx');

TaskResultTable = table(taskID, taskLat, taskLon, Y, ...
    packageID, bundleSize(packageID), ...
    P0, P2, P3, P_hat, ...
    p0, p2, p3, ...
    p0 >= targetProb, p2 >= targetProb, p3 >= targetProb, ...
    di_min, Ni, avgC, avgQ, taskDensity, competitionIndex, ...
    adjustedFlag2, ...
    'VariableNames', {'任务编号', '任务纬度', '任务经度', '实际完成情况', ...
    '任务包编号', '任务包规模', ...
    '原价格', '第二问价格', '第三问等效价格', '线性回归基础价格', ...
    '原预测完成概率', '第二问预测完成概率', '第三问预测完成概率', ...
    '原方案是否达标', '第二问是否达标', '第三问是否达标', ...
    '最近会员距离', '周边会员数量', '平均信誉值', '平均预订限额', ...
    '任务密度', '竞争强度', '第二问是否调价'});

writetable(TaskResultTable, 'Q3_任务打包定价结果.xlsx');

BundleInfoTable = table((1:K)', bundleSize, bundleCenterLat, bundleCenterLon, ...
    bundleCompact, bundleLambda, bundleLowRatio, bundleBaseSum, bundlePrice, ...
    'VariableNames', {'任务包编号', '任务包规模', '中心纬度', '中心经度', ...
    '空间紧凑度', '紧凑度系数', '低完成概率任务比例', ...
    '基础价格总和', '任务包价格'});

writetable(BundleInfoTable, 'Q3_任务包信息表.xlsx');

fprintf('\n结果文件已输出：\n');
fprintf('Q3_三种方案比较表.xlsx\n');
fprintf('Q3_任务打包定价结果.xlsx\n');
fprintf('Q3_任务包信息表.xlsx\n');

%% ===================== Step 14：绘制必要图像 =====================

%% 图1：任务打包空间分布图
figure;
scatter(taskLon, taskLat, 35, packageID, 'filled');
xlabel('经度');
ylabel('纬度');
title('第三问任务打包空间分布图');
colorbar;
grid on;
saveFig('Q3_任务打包空间分布图.png');

%% 图2：任务包规模分布图
figure;
histogram(bundleSize, 1:(max(bundleSize)+1));
xlabel('任务包规模');
ylabel('发布单元数量');
title('任务包规模分布图');
grid on;
saveFig('Q3_任务包规模分布图.png');

%% 图3：第二问价格与第三问等效价格对比图
figure;
scatter(P2, P3, 35, 'filled');
hold on;
minP = min([P2; P3]);
maxP = max([P2; P3]);
plot([minP, maxP], [minP, maxP], 'LineWidth', 1.5);
xlabel('第二问单任务优化价格');
ylabel('第三问打包等效价格');
title('第二问价格与第三问等效价格对比图');
grid on;
hold off;
saveFig('Q3_第二问与第三问价格对比图.png');

%% 图4：第二问与第三问预测完成概率对比图
figure;
scatter(p2, p3, 35, 'filled');
hold on;
plot([0, 1], [0, 1], 'LineWidth', 1.5);
xline(targetProb, '--', 'LineWidth', 1.2);
yline(targetProb, '--', 'LineWidth', 1.2);
xlabel('第二问预测完成概率');
ylabel('第三问预测完成概率');
title('第二问与第三问预测完成概率对比图');
grid on;
hold off;
saveFig('Q3_第二问与第三问完成概率对比图.png');

%% 图5：三种方案期望完成任务数对比图
figure;
bar([M0, M2, M3]);
set(gca, 'XTickLabel', {'原方案', '第二问方案', '第三问方案'});
ylabel('期望完成任务数');
title('三种方案期望完成任务数对比图');
grid on;
saveFig('Q3_期望完成任务数对比图.png');

%% 图6：三种方案预测完成率对比图
figure;
bar([R0, R2_prob, R3] * 100);
set(gca, 'XTickLabel', {'原方案', '第二问方案', '第三问方案'});
ylabel('预测完成率 / %');
title('三种方案预测完成率对比图');
grid on;
saveFig('Q3_预测完成率对比图.png');

%% 图7：三种方案低完成概率任务数对比图
figure;
bar([low0, low2, low3]);
set(gca, 'XTickLabel', {'原方案', '第二问方案', '第三问方案'});
ylabel('低完成概率任务数');
title('三种方案低完成概率任务数对比图');
grid on;
saveFig('Q3_低完成概率任务数对比图.png');

fprintf('\n图像已保存为 PNG 文件。\n');

%% ===================== Step 15：自动解释结果 =====================

fprintf('\n================ 代码运行结果解释 ================\n');

fprintf('1. 第三问先根据任务之间的空间距离，将位置接近的任务划分为任务包。\n');
fprintf('2. 多元线性回归模型用于计算每个任务的基础价格，作为任务包定价依据。\n');
fprintf('3. Logistic 模型用于预测原方案、第二问方案和第三问打包方案下的任务完成概率。\n');
fprintf('4. 若第三问的期望完成任务数和预测完成率高于第二问，说明打包方案能够进一步改善任务完成效果。\n');
fprintf('5. 若第三问成本变化较小，且低完成概率任务数减少，说明打包方案在成本和完成效果之间更优。\n');
fprintf('6. 若第三问效果不如第二问，可适当调整 rBundle、maxBundleSize、rhoGrid、gammaGrid 等参数。\n');

fprintf('\n全部计算完成。\n');

%% ===================== 局部函数区 =====================

function T = readSmartTable(fileName)
    % 兼容不同 MATLAB 版本的 readtable 读取方式
    try
        T = readtable(fileName, 'VariableNamingRule', 'preserve');
    catch
        T = readtable(fileName);
    end
end

function colName = findCol(T, keys)
    % 根据关键词自动寻找表格字段名
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

    error('没有找到字段，请检查表格列名。需要字段关键词：%s', strjoin(keys, ', '));
end

function x = toNumericVector(col)
    % 将表格列统一转为数值列
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

function [lat, lon] = parseGPSAuto(gpsCol, taskLatCenter, taskLonCenter)
    % 自动解析会员 GPS
    % 支持 "纬度 经度"、"经度 纬度"、逗号分隔等格式
    % 通过比较两种顺序到任务中心的距离，自动选择更合理的顺序

    gpsStr = string(gpsCol);
    N = length(gpsStr);

    lat = nan(N, 1);
    lon = nan(N, 1);

    for i = 1:N
        s = gpsStr(i);

        nums = regexp(s, '[-+]?\d+\.?\d*', 'match');
        
        if length(nums) < 2
            continue;
        end

        a = str2double(nums{1});
        b = str2double(nums{2});

        % 候选 1：a 是纬度，b 是经度
        lat1 = a;
        lon1 = b;

        % 候选 2：a 是经度，b 是纬度
        lat2 = b;
        lon2 = a;

        valid1 = isValidLatLon(lat1, lon1);
        valid2 = isValidLatLon(lat2, lon2);

        d1 = inf;
        d2 = inf;

        if valid1
            d1 = geoDistanceKm(taskLatCenter, taskLonCenter, lat1, lon1);
        end

        if valid2
            d2 = geoDistanceKm(taskLatCenter, taskLonCenter, lat2, lon2);
        end

        if d1 <= d2
            lat(i) = lat1;
            lon(i) = lon1;
        else
            lat(i) = lat2;
            lon(i) = lon2;
        end
    end
end

function flag = isValidLatLon(lat, lon)
    % 判断经纬度是否合法
    flag = ~isnan(lat) && ~isnan(lon) && ...
           lat >= -90 && lat <= 90 && ...
           lon >= -180 && lon <= 180;
end

function d = geoDistanceKm(lat1, lon1, lat2, lon2)
    % 经纬度近似距离公式
    % 输入可以为标量或向量，输出单位 km
    d = 111 * sqrt( ...
        (lat1 - lat2).^2 + ...
        ((lon1 - lon2) .* cosd(lat1)).^2 ...
        );
end

function [Xstd, mu, sigma] = standardizeData(X)
    % 标准化数据，避免不同量纲影响模型
    mu = zeros(1, size(X, 2));
    sigma = zeros(1, size(X, 2));

    for j = 1:size(X, 2)
        v = X(:, j);
        v = v(~isnan(v));
        mu(j) = mean(v);
        sigma(j) = std(v);
        if sigma(j) == 0 || isnan(sigma(j))
            sigma(j) = 1;
        end
    end

    Xstd = (X - mu) ./ sigma;
end

function loss = logisticNLL(alpha, X, Y)
    % Logistic 回归负对数似然函数

    Z = X * alpha;
    p = sigmoid(Z);

    epsVal = 1e-10;
    p = min(max(p, epsVal), 1 - epsVal);

    loss = -sum(Y .* log(p) + (1 - Y) .* log(1 - p));

    % 加入很小的正则项，增强数值稳定性
    loss = loss + 1e-6 * sum(alpha(2:end).^2);
end

function p = sigmoid(Z)
    % Sigmoid 函数
    p = 1 ./ (1 + exp(-Z));
end

function p = predictProbByPrice(priceValue, i, alpha, mu_logit, sigma_logit, ...
    di_min, Ni, avgC, avgQ, taskDensity, competitionIndex)
    % 给定某个任务的新价格，计算该任务预测完成概率
    % priceValue 可以是标量，也可以是向量

    priceValue = priceValue(:);

    di = di_min(i) * ones(size(priceValue));
    ni = Ni(i) * ones(size(priceValue));
    ac = avgC(i) * ones(size(priceValue));
    aq = avgQ(i) * ones(size(priceValue));
    td = taskDensity(i) * ones(size(priceValue));
    ci = competitionIndex(i) * ones(size(priceValue));

    v = priceValue ./ (di + 0.1);
    h = priceValue ./ (td + 1);

    Xraw = [priceValue, di, ni, ac, aq, td, ci, v, h];

    Xstd = (Xraw - mu_logit) ./ sigma_logit;
    Xdesign = [ones(size(Xstd, 1), 1), Xstd];

    p = sigmoid(Xdesign * alpha);
end

function p = predictProbAll(priceVector, alpha, mu_logit, sigma_logit, ...
    di_min, Ni, avgC, avgQ, taskDensity, competitionIndex)
    % 给定所有任务的价格，计算所有任务预测完成概率

    priceVector = priceVector(:);

    v = priceVector ./ (di_min + 0.1);
    h = priceVector ./ (taskDensity + 1);

    Xraw = [priceVector, di_min, Ni, avgC, avgQ, ...
            taskDensity, competitionIndex, v, h];

    Xstd = (Xraw - mu_logit) ./ sigma_logit;
    Xdesign = [ones(size(Xstd, 1), 1), Xstd];

    p = sigmoid(Xdesign * alpha);
end

function [P2, p2, adjustedFlag] = optimizeSingleTaskPricing( ...
    P0, p0, targetProb, etaMax, deltaMax, priceStep, ...
    alpha, mu_logit, sigma_logit, ...
    di_min, Ni, avgC, avgQ, taskDensity, competitionIndex)
    % 复现第二问单任务优化定价方案

    n = length(P0);
    lowIdx = find(p0 < targetProb);

    Pcand = P0;
    pcand = p0;
    efficiency = -inf(n, 1);

    for t = 1:length(lowIdx)
        
        i = lowIdx(t);

        priceGrid = P0(i):priceStep:(P0(i) + deltaMax);

        pGrid = predictProbByPrice(priceGrid, i, alpha, mu_logit, sigma_logit, ...
            di_min, Ni, avgC, avgQ, taskDensity, competitionIndex);

        hit = find(pGrid >= targetProb, 1, 'first');

        if ~isempty(hit)
            bestIdx = hit;
        else
            [~, bestIdx] = max(pGrid);
        end

        Pcand(i) = priceGrid(bestIdx);
        pcand(i) = pGrid(bestIdx);

        dP = Pcand(i) - P0(i);
        dp = pcand(i) - p0(i);

        if dP > 0 && dp > 0
            efficiency(i) = dp / dP;
        end
    end

    validCand = find(isfinite(efficiency) & efficiency > 0);
    [~, order] = sort(efficiency(validCand), 'descend');
    sortedIdx = validCand(order);

    P2 = P0;
    p2 = p0;
    adjustedFlag = false(n, 1);

    C0 = sum(P0);
    budget = etaMax * C0;
    usedBudget = 0;

    for k = 1:length(sortedIdx)

        i = sortedIdx(k);

        increase = Pcand(i) - P0(i);

        if increase <= 0
            continue;
        end

        if usedBudget + increase <= budget

            P2(i) = Pcand(i);
            p2(i) = pcand(i);
            usedBudget = usedBudget + increase;
            adjustedFlag(i) = true;

        else

            remainBudget = budget - usedBudget;

            if remainBudget >= priceStep

                maxStepNum = floor(remainBudget / priceStep);
                partialPrice = P0(i) + maxStepNum * priceStep;
                partialPrice = min(partialPrice, P0(i) + deltaMax);

                partialProb = predictProbByPrice(partialPrice, i, alpha, mu_logit, sigma_logit, ...
                    di_min, Ni, avgC, avgQ, taskDensity, competitionIndex);

                if partialProb > p0(i)
                    P2(i) = partialPrice;
                    p2(i) = partialProb;
                    adjustedFlag(i) = true;
                end
            end

            break;
        end
    end
end

function [P3, bundlePrice] = computeBundlePrice( ...
    P2, P_hat, packageID, bundleSize, bundleLambda, bundleLowRatio, ...
    bundleBaseSum, rho, gamma, minBundleSize)
    % 根据 rho 和 gamma 计算第三问打包方案价格
    %
    % 对于实际任务包：
    % B_k = S_k * (1 - rho * lambda_k) + gamma * q_k * S_k
    %
    % 对于单独任务：
    % 保持第二问单任务优化价格

    n = length(P2);
    K = max(packageID);

    P3 = P2;
    bundlePrice = zeros(K, 1);

    for k = 1:K
        
        idx = find(packageID == k);

        if bundleSize(k) >= minBundleSize

            S = bundleBaseSum(k);
            lambda = bundleLambda(k);
            q = bundleLowRatio(k);

            B = S * (1 - rho * lambda) + gamma * q * S;

            % 防止任务包价格异常过低
            B = max(B, 0.5 * S);

            weights = P_hat(idx) / sum(P_hat(idx));

            P3(idx) = B * weights;

            bundlePrice(k) = sum(P3(idx));

        else

            P3(idx) = P2(idx);
            bundlePrice(k) = sum(P3(idx));
        end
    end
end

function saveFig(fileName)
    % 保存图像，尽量避免坐标区工具栏被导出
    try
        ax = gca;
        ax.Toolbar.Visible = 'off';
    catch
    end

    try
        exportgraphics(gcf, fileName, 'Resolution', 300);
    catch
        saveas(gcf, fileName);
    end
end