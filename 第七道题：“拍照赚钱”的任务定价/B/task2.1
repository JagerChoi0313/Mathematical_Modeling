%% Q2_MultiObjective_Pricing.m
% 第二问：基于 Logistic 回归与多目标优化的任务定价模型
%
% 模型思路：
% 1. 读取附件一任务数据和附件二会员数据；
% 2. 构造任务空间特征、会员资源特征和任务竞争特征；
% 3. 建立 Logistic 回归模型，预测任务完成概率；
% 4. 建立多目标优化模型：
%       目标1：最大化期望完成任务数；
%       目标2：最小化平台总成本；
% 5. 采用加权归一化方法将多目标模型转化为单目标模型；
% 6. 通过离散搜索和贪心迭代求解新任务价格；
% 7. 输出新旧方案对比结果和图像。

clear;
clc;
close all;

%% ===================== Step 0：参数设置 =====================

taskFile = '附件一：已结束项目任务数据.xls';
memberFile = '附件二：会员信息数据.xlsx';

% 任务周边特征统计半径
rMember = 3;              % 任务周边会员统计半径，单位 km
rTask = 3;                % 任务密度统计半径，单位 km

% Logistic 完成概率阈值
targetProb = 0.62;        % 第一问确定的较优阈值

% 多目标优化参数
omega = 0.70;             % 完成效果权重，越大越重视完成率
etaMax = 0.05;            % 总成本最大增长率
deltaMax = 10;            % 单任务最大涨价幅度
priceStep = 0.5;          % 价格搜索步长

% 权重敏感性分析
omegaList = 0.40:0.10:0.90;

fprintf('\n================ 第二问：多目标优化定价模型 ================\n');
fprintf('会员统计半径 rMember = %.2f km\n', rMember);
fprintf('任务密度半径 rTask = %.2f km\n', rTask);
fprintf('目标完成概率阈值 targetProb = %.2f\n', targetProb);
fprintf('完成效果权重 omega = %.2f\n', omega);
fprintf('总成本最大增长率 etaMax = %.2f%%\n', etaMax * 100);
fprintf('单任务最大涨价幅度 deltaMax = %.2f\n', deltaMax);
fprintf('价格搜索步长 priceStep = %.2f\n', priceStep);

%% ===================== Step 1：读取任务数据和会员数据 =====================

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
P0      = toNumericVector(Task.(price_col));
Y       = toNumericVector(Task.(finish_col));

validTask = ~isnan(taskLat) & ~isnan(taskLon) & ~isnan(P0) & ~isnan(Y);

taskID  = taskID(validTask);
taskLat = taskLat(validTask);
taskLon = taskLon(validTask);
P0      = P0(validTask);
Y       = Y(validTask);

n = length(P0);

fprintf('\n================ 基本任务数据统计 ================\n');
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
Q         = toNumericVector(Member.(quota_col));
C         = toNumericVector(Member.(credit_col));

% 自动解析会员 GPS 经纬度顺序
taskLatCenter = median(taskLat, 'omitnan');
taskLonCenter = median(taskLon, 'omitnan');

[memberLat, memberLon] = parseGPSAuto(memberGPS, taskLatCenter, taskLonCenter);

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

di_min = zeros(n, 1);
Ni     = zeros(n, 1);
Si     = zeros(n, 1);
Ui     = zeros(n, 1);

fprintf('\n开始计算任务与会员距离及周边会员特征...\n');

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

taskDistMat = zeros(n, n);

for i = 1:n
    taskDistMat(i, :) = geoDistanceKm(taskLat(i), taskLon(i), taskLat, taskLon);
end

taskDensity = zeros(n, 1);

for i = 1:n
    taskDensity(i) = sum(taskDistMat(i, :) <= rTask) - 1;
end

competitionIndex = taskDensity ./ max(Ni, 1);

pricePerDistance0 = P0 ./ (di_min + 0.1);
pricePerCompetition0 = P0 ./ (taskDensity + 1);

fprintf('任务密度与竞争特征构造完成。\n');

%% ===================== Step 6：建立 Logistic 完成概率模型 =====================

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

X_design = [ones(n, 1), X_logit];

alpha0 = zeros(size(X_design, 2), 1);

options = optimset('MaxIter', 10000, ...
                   'MaxFunEvals', 20000, ...
                   'Display', 'off');

alpha = fminsearch(@(a) logisticNLL(a, X_design, Y), alpha0, options);

p0 = predictProb(P0, alpha, mu_logit, sigma_logit, ...
    di_min, Ni, avgC, avgQ, taskDensity, competitionIndex);

fprintf('\n================ Logistic 完成概率模型 ================\n');

logitCoefNames = {'常数项', '任务价格', '最近会员距离', '周边会员数量', ...
                  '平均信誉值', '平均预订限额', '任务密度', ...
                  '竞争强度', '单位距离价格', '单位竞争价格'};

LogitCoefTable = table(logitCoefNames', alpha, ...
    'VariableNames', {'变量', 'Logistic回归系数'});

disp(LogitCoefTable);
writetable(LogitCoefTable, 'Q2_多目标_Logistic回归系数.xlsx');

%% ===================== Step 7：计算原方案评价指标 =====================

C0 = sum(P0);
avgP0 = mean(P0);
M0 = sum(p0);
R0 = mean(p0 >= targetProb);
L0 = sum(p0 < targetProb);

fprintf('\n================ 原定价方案评价 ================\n');
fprintf('原方案总成本 C0 = %.4f\n', C0);
fprintf('原方案平均价格 = %.4f\n', avgP0);
fprintf('原方案期望完成任务数 M0 = %.4f\n', M0);
fprintf('原方案预测完成率 R0 = %.2f%%\n', R0 * 100);
fprintf('原方案低完成概率任务数 L0 = %d\n', L0);

%% ===================== Step 8：多目标优化求解新价格 =====================

fprintf('\n开始进行多目标优化定价...\n');

[Pnew, pnew, adjustedFlag, history] = optimizeMultiObjectivePricing( ...
    P0, p0, targetProb, omega, etaMax, deltaMax, priceStep, ...
    alpha, mu_logit, sigma_logit, ...
    di_min, Ni, avgC, avgQ, taskDensity, competitionIndex);

fprintf('多目标优化定价完成。\n');

%% ===================== Step 9：计算新方案评价指标 =====================

Cnew = sum(Pnew);
avgPnew = mean(Pnew);
Mnew = sum(pnew);
Rnew = mean(pnew >= targetProb);
Lnew = sum(pnew < targetProb);

costIncrease = Cnew - C0;
costIncreaseRate = costIncrease / C0;

if abs(costIncrease) > 1e-8
    gainPerCost = (Mnew - M0) / costIncrease;
else
    gainPerCost = NaN;
end

F1 = (Mnew - M0) / max(n - M0, 1e-8);
F2 = (Cnew - C0) / C0;
Jnew = omega * F1 - (1 - omega) * F2;

fprintf('\n================ 多目标优化新方案评价 ================\n');
fprintf('新方案总成本 C = %.4f\n', Cnew);
fprintf('新方案平均价格 = %.4f\n', avgPnew);
fprintf('成本增加量 = %.4f\n', costIncrease);
fprintf('成本增长率 = %.2f%%\n', costIncreaseRate * 100);
fprintf('新方案期望完成任务数 M = %.4f\n', Mnew);
fprintf('新方案预测完成率 R = %.2f%%\n', Rnew * 100);
fprintf('新方案低完成概率任务数 L = %d\n', Lnew);
fprintf('期望完成任务数提升 = %.4f\n', Mnew - M0);
fprintf('预测完成率提升 = %.2f 个百分点\n', (Rnew - R0) * 100);
fprintf('低完成概率任务数变化 = %d\n', Lnew - L0);
fprintf('单位成本期望提升 = %.6f\n', gainPerCost);
fprintf('综合目标函数 J = %.6f\n', Jnew);
fprintf('调价任务数量 = %d\n', sum(adjustedFlag));

%% ===================== Step 10：权重敏感性分析 =====================

fprintf('\n开始进行权重敏感性分析...\n');

sensOmega = omegaList(:);
sensCost = zeros(length(omegaList), 1);
sensExpected = zeros(length(omegaList), 1);
sensRate = zeros(length(omegaList), 1);
sensLow = zeros(length(omegaList), 1);
sensAdjusted = zeros(length(omegaList), 1);

for t = 1:length(omegaList)
    
    w = omegaList(t);
    
    [Pt, pt, adjt, ~] = optimizeMultiObjectivePricing( ...
        P0, p0, targetProb, w, etaMax, deltaMax, priceStep, ...
        alpha, mu_logit, sigma_logit, ...
        di_min, Ni, avgC, avgQ, taskDensity, competitionIndex);
    
    sensCost(t) = sum(Pt);
    sensExpected(t) = sum(pt);
    sensRate(t) = mean(pt >= targetProb);
    sensLow(t) = sum(pt < targetProb);
    sensAdjusted(t) = sum(adjt);
end

SensitivityTable = table(sensOmega, sensCost, sensExpected, sensRate * 100, sensLow, sensAdjusted, ...
    'VariableNames', {'完成效果权重omega', '总成本', '期望完成任务数', '预测完成率百分比', '低完成概率任务数', '调价任务数'});

disp('权重敏感性分析结果：');
disp(SensitivityTable);

writetable(SensitivityTable, 'Q2_多目标_权重敏感性分析.xlsx');

fprintf('权重敏感性分析完成。\n');

%% ===================== Step 11：输出结果表格 =====================

CompareTable = table( ...
    {'总成本'; '平均价格'; '期望完成任务数'; '预测完成率'; '低完成概率任务数'}, ...
    [C0; avgP0; M0; R0 * 100; L0], ...
    [Cnew; avgPnew; Mnew; Rnew * 100; Lnew], ...
    [Cnew - C0; avgPnew - avgP0; Mnew - M0; (Rnew - R0) * 100; Lnew - L0], ...
    'VariableNames', {'指标', '原方案', '多目标优化方案', '变化量'});

disp('新旧方案比较表：');
disp(CompareTable);

writetable(CompareTable, 'Q2_多目标_新旧方案比较表.xlsx');

TaskResultTable = table(taskID, taskLat, taskLon, Y, ...
    P0, Pnew, Pnew - P0, ...
    p0, pnew, pnew - p0, ...
    p0 >= targetProb, pnew >= targetProb, ...
    adjustedFlag, ...
    di_min, Ni, avgC, avgQ, taskDensity, competitionIndex, ...
    'VariableNames', {'任务编号', '任务纬度', '任务经度', '实际完成情况', ...
    '原始价格', '新价格', '价格增加量', ...
    '原方案预测完成概率', '新方案预测完成概率', '预测概率提升量', ...
    '原方案是否达标', '新方案是否达标', ...
    '是否调价', ...
    '最近会员距离', '周边会员数量', '平均信誉值', '平均预订限额', '任务密度', '竞争强度'});

writetable(TaskResultTable, 'Q2_多目标_任务新定价结果.xlsx');

fprintf('\n结果文件已输出：\n');
fprintf('Q2_多目标_Logistic回归系数.xlsx\n');
fprintf('Q2_多目标_新旧方案比较表.xlsx\n');
fprintf('Q2_多目标_任务新定价结果.xlsx\n');
fprintf('Q2_多目标_权重敏感性分析.xlsx\n');

%% ===================== Step 12：绘制必要图像 =====================

%% 图1：原价格与新价格对比图
figure;
scatter(P0, Pnew, 30, 'filled');
hold on;
minP = min([P0; Pnew]);
maxP = max([P0; Pnew]);
plot([minP, maxP], [minP, maxP], 'LineWidth', 1.5);
xlabel('原始任务价格');
ylabel('多目标优化后价格');
title('原价格与多目标优化价格对比图');
grid on;
hold off;
saveFig('Q2_多目标_原价格与新价格对比图.png');

%% 图2：价格增加量分布图
figure;
histogram(Pnew - P0, 20);
xlabel('价格增加量');
ylabel('任务数量');
title('多目标优化价格增加量分布图');
grid on;
saveFig('Q2_多目标_价格增加量分布图.png');

%% 图3：原方案与新方案预测完成概率对比图
figure;
scatter(p0, pnew, 30, 'filled');
hold on;
plot([0, 1], [0, 1], 'LineWidth', 1.5);
xline(targetProb, '--', 'LineWidth', 1.2);
yline(targetProb, '--', 'LineWidth', 1.2);
xlabel('原方案预测完成概率');
ylabel('多目标优化方案预测完成概率');
title('原方案与多目标优化方案预测完成概率对比图');
grid on;
hold off;
saveFig('Q2_多目标_预测完成概率对比图.png');

%% 图4：预测完成概率分布图
figure;
hold on;
histogram(p0, 15, 'DisplayName', '原方案');
histogram(pnew, 15, 'DisplayName', '多目标优化方案');
xline(targetProb, 'LineWidth', 1.5, 'DisplayName', '目标阈值');
xlabel('预测完成概率');
ylabel('任务数量');
title('原方案与多目标优化方案预测完成概率分布图');
legend('Location', 'best');
grid on;
hold off;
saveFig('Q2_多目标_预测完成概率分布图.png');

%% 图5：低完成概率任务数对比图
figure;
bar([L0, Lnew]);
set(gca, 'XTickLabel', {'原方案', '多目标优化方案'});
ylabel('低完成概率任务数');
title('低完成概率任务数对比图');
grid on;
saveFig('Q2_多目标_低完成概率任务数对比图.png');

%% 图6：期望完成任务数对比图
figure;
bar([M0, Mnew]);
set(gca, 'XTickLabel', {'原方案', '多目标优化方案'});
ylabel('期望完成任务数');
title('期望完成任务数对比图');
grid on;
saveFig('Q2_多目标_期望完成任务数对比图.png');

%% 图7：总成本对比图
figure;
bar([C0, Cnew]);
set(gca, 'XTickLabel', {'原方案', '多目标优化方案'});
ylabel('总成本');
title('总成本对比图');
grid on;
saveFig('Q2_多目标_总成本对比图.png');

%% 图8：优化过程变化图
figure;
yyaxis left;
plot(history.step, history.M, 'LineWidth', 1.5);
ylabel('期望完成任务数');

yyaxis right;
plot(history.step, history.C, 'LineWidth', 1.5);
ylabel('总成本');

xlabel('迭代步数');
title('多目标优化过程变化图');
grid on;
saveFig('Q2_多目标_优化过程变化图.png');

%% 图9：权重敏感性折中曲线
figure;
plot(sensCost, sensExpected, '-o', 'LineWidth', 1.5);
xlabel('总成本');
ylabel('期望完成任务数');
title('不同权重下成本与期望完成任务数折中曲线');
grid on;

for t = 1:length(sensOmega)
    text(sensCost(t), sensExpected(t), ['  \omega=', num2str(sensOmega(t), '%.1f')]);
end

saveFig('Q2_多目标_权重敏感性折中曲线.png');

fprintf('\n图像已保存为 PNG 文件。\n');

%% ===================== Step 13：自动解释代码运行结果 =====================

fprintf('\n================ 代码运行结果解释 ================\n');

fprintf('1. Logistic 模型用于预测不同任务价格下的任务完成概率。\n');
fprintf('2. 多目标优化模型同时考虑两个目标：提高期望完成任务数、控制平台总成本。\n');
fprintf('3. omega = %.2f 表示当前模型更偏向提高任务完成效果。\n', omega);
fprintf('4. 若新方案期望完成任务数和预测完成率高于原方案，说明调价能够提高任务完成效果。\n');
fprintf('5. 若新方案成本增长率不超过 %.2f%%，说明平台总成本处于设定约束内。\n', etaMax * 100);
fprintf('6. 权重敏感性分析用于观察不同 omega 下成本和完成效果之间的折中关系。\n');
fprintf('7. 若 omega 越大时成本和期望完成任务数同时提高，说明完成效果和成本之间存在明显权衡。\n');

fprintf('\n全部计算完成。\n');

%% ===================== 局部函数区 =====================

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

        % 候选1：a 为纬度，b 为经度
        lat1 = a;
        lon1 = b;

        % 候选2：a 为经度，b 为纬度
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
    flag = ~isnan(lat) && ~isnan(lon) && ...
           lat >= -90 && lat <= 90 && ...
           lon >= -180 && lon <= 180;
end

function d = geoDistanceKm(lat1, lon1, lat2, lon2)
    d = 111 * sqrt( ...
        (lat1 - lat2).^2 + ...
        ((lon1 - lon2) .* cosd(lat1)).^2 ...
        );
end

function [Xstd, mu, sigma] = standardizeData(X)
    mu = mean(X, 1, 'omitnan');
    sigma = std(X, 0, 1, 'omitnan');

    sigma(sigma == 0) = 1;
    sigma(isnan(sigma)) = 1;

    Xstd = (X - mu) ./ sigma;
end

function loss = logisticNLL(alpha, X, Y)
    Z = X * alpha;
    p = sigmoid(Z);

    epsVal = 1e-10;
    p = min(max(p, epsVal), 1 - epsVal);

    loss = -sum(Y .* log(p) + (1 - Y) .* log(1 - p));

    % 加入很小正则项，增强数值稳定性
    loss = loss + 1e-6 * sum(alpha(2:end).^2);
end

function p = sigmoid(Z)
    p = 1 ./ (1 + exp(-Z));
end

function p = predictProb(P, alpha, mu_logit, sigma_logit, ...
    di_min, Ni, avgC, avgQ, taskDensity, competitionIndex)

    P = P(:);

    V = P ./ (di_min + 0.1);
    H = P ./ (taskDensity + 1);

    Xraw = [P, di_min, Ni, avgC, avgQ, taskDensity, competitionIndex, V, H];

    Xstd = (Xraw - mu_logit) ./ sigma_logit;

    Xdesign = [ones(size(Xstd, 1), 1), Xstd];

    p = sigmoid(Xdesign * alpha);
end

function [Pnew, pnew, adjustedFlag, history] = optimizeMultiObjectivePricing( ...
    P0, p0, targetProb, omega, etaMax, deltaMax, priceStep, ...
    alpha, mu_logit, sigma_logit, ...
    di_min, Ni, avgC, avgQ, taskDensity, competitionIndex)

    n = length(P0);

    C0 = sum(P0);
    M0 = sum(p0);

    denomM = max(n - M0, 1e-8);

    % 优先调整低完成概率任务
    candidateIdx = find(p0 < targetProb);

    Pnew = P0;
    pnew = p0;

    adjustedFlag = false(n, 1);

    budget = etaMax * C0;
    usedBudget = 0;

    maxIter = ceil(budget / priceStep) + 5;

    history.step = 0;
    history.C = C0;
    history.M = M0;
    history.J = 0;

    stepCount = 0;

    while stepCount < maxIter

        if usedBudget + priceStep > budget
            break;
        end

        % 当前仍可继续涨价的候选任务
        canMove = candidateIdx(Pnew(candidateIdx) + priceStep <= P0(candidateIdx) + deltaMax + 1e-9);

        if isempty(canMove)
            break;
        end

        priceCand = Pnew(canMove) + priceStep;

        pCand = predictProb(priceCand, alpha, mu_logit, sigma_logit, ...
            di_min(canMove), Ni(canMove), avgC(canMove), avgQ(canMove), ...
            taskDensity(canMove), competitionIndex(canMove));

        % 单步价格增加带来的综合目标函数增量
        deltaM = pCand - pnew(canMove);
        deltaC = priceStep;

        deltaJ = omega * (deltaM / denomM) - (1 - omega) * (deltaC / C0);

        [bestDeltaJ, loc] = max(deltaJ);

        % 如果所有候选调价都不能提高综合目标函数，则停止
        if bestDeltaJ <= 0
            break;
        end

        iBest = canMove(loc);

        Pnew(iBest) = Pnew(iBest) + priceStep;
        pnew(iBest) = pCand(loc);

        usedBudget = usedBudget + priceStep;
        adjustedFlag(iBest) = true;

        stepCount = stepCount + 1;

        Ccur = sum(Pnew);
        Mcur = sum(pnew);

        F1 = (Mcur - M0) / denomM;
        F2 = (Ccur - C0) / C0;
        Jcur = omega * F1 - (1 - omega) * F2;

        history.step(end + 1, 1) = stepCount;
        history.C(end + 1, 1) = Ccur;
        history.M(end + 1, 1) = Mcur;
        history.J(end + 1, 1) = Jcur;
    end
end

function saveFig(fileName)
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