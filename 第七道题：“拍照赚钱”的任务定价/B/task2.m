%% Q2_Pricing_Optimization.m
% 第二问：基于 Logistic 完成概率的任务定价优化模型
%
% 功能：
% 1. 读取附件一和附件二数据；
% 2. 构造任务周边会员特征和任务竞争特征；
% 3. 重新训练 Logistic 完成概率模型；
% 4. 以任务价格为决策变量，在成本约束下优化任务定价；
% 5. 输出新旧方案比较结果；
% 6. 绘制必要图像。

clear;
clc;
close all;

%% ===================== Step 0：参数设置 =====================

% 数据文件
taskFile = '附件一：已结束项目任务数据.xls';
memberFile = '附件二：会员信息数据.xlsx';

% 会员统计半径，单位 km
rMember = 3;

% 任务密度统计半径，单位 km
rTask = 3;

% 第二问定价优化参数
targetProb = 0.62;      % 目标完成概率阈值，采用第一问平衡准确率最优阈值
etaMax = 0.05;          % 总成本最大增长率，这里设为 5%，可根据需要修改
deltaMax = 10;          % 单个任务最大涨价幅度
priceStep = 0.5;        % 搜索价格时的步长

fprintf('\n================ 第二问：任务定价优化模型 ================\n');
fprintf('目标完成概率阈值 targetProb = %.2f\n', targetProb);
fprintf('总成本最大增长率 etaMax = %.2f%%\n', etaMax * 100);
fprintf('单任务最大涨价幅度 deltaMax = %.2f\n', deltaMax);
fprintf('价格搜索步长 priceStep = %.2f\n', priceStep);

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

% 删除任务缺失值
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
taskLatCenter = median(taskLat, 'omitnan');
taskLonCenter = median(taskLon, 'omitnan');

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

%% ===================== Step 5：构造任务竞争特征 =====================

taskDensity = zeros(n, 1);

fprintf('开始计算任务密度特征...\n');

for i = 1:n
    
    dTask = geoDistanceKm(taskLat(i), taskLon(i), taskLat, taskLon);
    
    % 半径 rTask 内除自身以外的任务数量
    taskDensity(i) = sum(dTask <= rTask) - 1;
end

competitionIndex = taskDensity ./ max(Ni, 1);

% 原价格下的单位距离价格、单位竞争价格
pricePerDistance0 = P0 ./ (di_min + 0.1);
pricePerCompetition0 = P0 ./ (taskDensity + 1);

fprintf('任务竞争特征构造完成。\n');

%% ===================== Step 6：重新训练 Logistic 完成概率模型 =====================

% Logistic 回归自变量：
% 任务价格、最近会员距离、周边会员数量、平均信誉值、平均预订限额、
% 任务密度、竞争强度、单位距离价格、单位竞争价格

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

% 原方案下的预测完成概率
p0 = sigmoid(X_design * alpha);

fprintf('\n================ Logistic 模型训练完成 ================\n');

coefNames = {'常数项', '任务价格', '最近会员距离', '周边会员数量', ...
             '平均信誉值', '平均预订限额', '任务密度', ...
             '竞争强度', '单位距离价格', '单位竞争价格'};

LogitCoefTable = table(coefNames', alpha, ...
    'VariableNames', {'变量', 'Logistic回归系数'});

disp(LogitCoefTable);
writetable(LogitCoefTable, 'Q2_Logistic回归系数.xlsx');

%% ===================== Step 7：计算原方案评价指标 =====================

C0 = sum(P0);                  % 原方案总成本
avgP0 = mean(P0);              % 原方案平均价格
M0 = sum(p0);                  % 原方案期望完成任务数
R0 = mean(p0 >= targetProb);   % 原方案预测完成率
lowTask0 = sum(p0 < targetProb);

fprintf('\n================ 原方案评价 ================\n');
fprintf('原方案总成本 C0 = %.4f\n', C0);
fprintf('原方案平均价格 = %.4f\n', avgP0);
fprintf('原方案期望完成任务数 M0 = %.4f\n', M0);
fprintf('原方案预测完成率 R0 = %.2f%%\n', R0 * 100);
fprintf('原方案低完成概率任务数 = %d\n', lowTask0);

%% ===================== Step 8：生成候选调价方案 =====================

% 对 p0 < targetProb 的任务进行候选调价
lowIdx = find(p0 < targetProb);

Pcand = P0;
pcand = p0;
deltaP = zeros(n, 1);
deltaProb = zeros(n, 1);
efficiency = -inf(n, 1);

fprintf('\n开始生成候选调价方案...\n');

for t = 1:length(lowIdx)
    
    i = lowIdx(t);
    
    % 从原价格逐步增加到最大允许价格
    priceGrid = P0(i):priceStep:(P0(i) + deltaMax);
    
    % 计算该任务在不同价格下的完成概率
    pGrid = predictProbByPrice(priceGrid, i, alpha, mu_logit, sigma_logit, ...
        di_min, Ni, avgC, avgQ, taskDensity, competitionIndex);
    
    % 找到第一个达到目标完成概率的价格
    hit = find(pGrid >= targetProb, 1, 'first');
    
    if ~isempty(hit)
        bestGridIdx = hit;
    else
        % 如果达不到目标完成概率，则选择概率最高的价格
        [~, bestGridIdx] = max(pGrid);
    end
    
    Pcand(i) = priceGrid(bestGridIdx);
    pcand(i) = pGrid(bestGridIdx);
    
    deltaP(i) = Pcand(i) - P0(i);
    deltaProb(i) = pcand(i) - p0(i);
    
    % 单位成本提升效果
    if deltaP(i) > 0 && deltaProb(i) > 0
        efficiency(i) = deltaProb(i) / deltaP(i);
    end
end

validCand = find(isfinite(efficiency) & efficiency > 0);

fprintf('候选调价任务数：%d\n', length(validCand));

%% ===================== Step 9：在总成本约束下进行贪心调价 =====================

Pnew = P0;
pnew = p0;

budget = etaMax * C0;
usedBudget = 0;

% 按单位成本提升效果从大到小排序
[~, order] = sort(efficiency(validCand), 'descend');
sortedIdx = validCand(order);

progressCost = [];
progressM = [];
progressR = [];

adjustedFlag = false(n, 1);

fprintf('开始按照单位成本提升效果进行贪心调价...\n');

for k = 1:length(sortedIdx)
    
    i = sortedIdx(k);
    
    fullIncrease = Pcand(i) - P0(i);
    
    if fullIncrease <= 0
        continue;
    end
    
    % 如果预算足够，则直接采用候选价格
    if usedBudget + fullIncrease <= budget
        
        Pnew(i) = Pcand(i);
        pnew(i) = pcand(i);
        usedBudget = usedBudget + fullIncrease;
        adjustedFlag(i) = true;
        
    else
        % 如果剩余预算不够，则尝试在剩余预算内进行部分调价
        remainBudget = budget - usedBudget;
        
        if remainBudget >= priceStep
            
            maxStepNum = floor(remainBudget / priceStep);
            partialPrice = P0(i) + maxStepNum * priceStep;
            partialPrice = min(partialPrice, P0(i) + deltaMax);
            
            partialProb = predictProbByPrice(partialPrice, i, alpha, mu_logit, sigma_logit, ...
                di_min, Ni, avgC, avgQ, taskDensity, competitionIndex);
            
            if partialProb > p0(i)
                Pnew(i) = partialPrice;
                pnew(i) = partialProb;
                usedBudget = usedBudget + (partialPrice - P0(i));
                adjustedFlag(i) = true;
            end
        end
        
        % 预算已经基本用完，结束调价
        break;
    end
    
    progressCost(end + 1, 1) = usedBudget;
    progressM(end + 1, 1) = sum(pnew);
    progressR(end + 1, 1) = mean(pnew >= targetProb);
end

fprintf('调价完成。\n');

%% ===================== Step 10：计算新方案评价指标 =====================

C1 = sum(Pnew);
avgP1 = mean(Pnew);
M1 = sum(pnew);
R1 = mean(pnew >= targetProb);
lowTask1 = sum(pnew < targetProb);

costIncrease = C1 - C0;
costIncreaseRate = costIncrease / C0;

adjustedNum = sum(adjustedFlag);
meanIncreaseAdjusted = mean(Pnew(adjustedFlag) - P0(adjustedFlag));

if isempty(meanIncreaseAdjusted) || isnan(meanIncreaseAdjusted)
    meanIncreaseAdjusted = 0;
end

if costIncrease > 0
    gainPerCost = (M1 - M0) / costIncrease;
else
    gainPerCost = NaN;
end

fprintf('\n================ 新方案评价 ================\n');
fprintf('新方案总成本 C1 = %.4f\n', C1);
fprintf('新方案平均价格 = %.4f\n', avgP1);
fprintf('成本增加量 = %.4f\n', costIncrease);
fprintf('成本增长率 = %.2f%%\n', costIncreaseRate * 100);
fprintf('调价任务数量 = %d\n', adjustedNum);
fprintf('调价任务平均涨价幅度 = %.4f\n', meanIncreaseAdjusted);
fprintf('新方案期望完成任务数 M1 = %.4f\n', M1);
fprintf('新方案预测完成率 R1 = %.2f%%\n', R1 * 100);
fprintf('新方案低完成概率任务数 = %d\n', lowTask1);
fprintf('期望完成任务数提升 = %.4f\n', M1 - M0);
fprintf('预测完成率提升 = %.2f 个百分点\n', (R1 - R0) * 100);
fprintf('单位成本期望提升 = %.6f\n', gainPerCost);

%% ===================== Step 11：输出结果表格 =====================

CompareTable = table( ...
    {'总成本'; '平均价格'; '期望完成任务数'; '预测完成率'; '低完成概率任务数'}, ...
    [C0; avgP0; M0; R0 * 100; lowTask0], ...
    [C1; avgP1; M1; R1 * 100; lowTask1], ...
    [C1 - C0; avgP1 - avgP0; M1 - M0; (R1 - R0) * 100; lowTask1 - lowTask0], ...
    'VariableNames', {'指标', '原方案', '新方案', '变化量'});

disp('新旧方案比较表：');
disp(CompareTable);

writetable(CompareTable, 'Q2_新旧方案比较表.xlsx');

ResultTable = table(taskID, taskLat, taskLon, Y, ...
    P0, Pnew, Pnew - P0, ...
    p0, pnew, pnew - p0, ...
    p0 >= targetProb, pnew >= targetProb, adjustedFlag, ...
    di_min, Ni, avgC, avgQ, taskDensity, competitionIndex, ...
    pricePerDistance0, pricePerCompetition0, ...
    'VariableNames', {'任务编号', '任务纬度', '任务经度', '实际完成情况', ...
    '原价格', '新价格', '价格增加量', ...
    '原预测完成概率', '新预测完成概率', '完成概率提升', ...
    '原方案是否达标', '新方案是否达标', '是否调价', ...
    '最近会员距离', '周边会员数量', '平均信誉值', '平均预订限额', ...
    '任务密度', '竞争强度', '原单位距离价格', '原单位竞争价格'});

writetable(ResultTable, 'Q2_任务新定价结果.xlsx');

fprintf('\n结果文件已输出：\n');
fprintf('Q2_新旧方案比较表.xlsx\n');
fprintf('Q2_任务新定价结果.xlsx\n');

%% ===================== Step 12：绘制必要图像 =====================

%% 图1：原价格与新价格对比
figure;
scatter(P0, Pnew, 35, 'filled');
hold on;
minP = min([P0; Pnew]);
maxP = max([P0; Pnew]);
plot([minP, maxP], [minP, maxP], 'LineWidth', 1.5);
xlabel('原任务价格');
ylabel('新任务价格');
title('原价格与新价格对比图');
grid on;
hold off;
saveFig('Q2_原价格与新价格对比图.png');

%% 图2：价格增加量分布
figure;
histogram(Pnew - P0, 20);
xlabel('价格增加量');
ylabel('任务数量');
title('任务价格增加量分布图');
grid on;
saveFig('Q2_价格增加量分布图.png');

%% 图3：原完成概率与新完成概率对比
figure;
scatter(p0, pnew, 35, 'filled');
hold on;
plot([0, 1], [0, 1], 'LineWidth', 1.5);
xline(targetProb, '--', 'LineWidth', 1.2);
yline(targetProb, '--', 'LineWidth', 1.2);
xlabel('原预测完成概率');
ylabel('新预测完成概率');
title('原方案与新方案预测完成概率对比图');
grid on;
hold off;
saveFig('Q2_预测完成概率对比图.png');

%% 图4：调价前后任务完成概率分布
figure;
hold on;
histogram(p0, 15, 'DisplayName', '原方案');
histogram(pnew, 15, 'DisplayName', '新方案');
xline(targetProb, 'LineWidth', 1.5, 'DisplayName', '目标阈值');
xlabel('预测完成概率');
ylabel('任务数量');
title('调价前后预测完成概率分布图');
legend('Location', 'best');
grid on;
hold off;
saveFig('Q2_调价前后完成概率分布图.png');

%% 图5：空间分布图，突出被调价任务
figure;
hold on;

scatter(taskLon(~adjustedFlag), taskLat(~adjustedFlag), 25, '.', ...
    'DisplayName', '未调价任务');
scatter(taskLon(adjustedFlag), taskLat(adjustedFlag), 45, 'filled', ...
    'DisplayName', '调价任务');

xlabel('经度');
ylabel('纬度');
title('调价任务空间分布图');
legend('Location', 'best');
grid on;
hold off;
saveFig('Q2_调价任务空间分布图.png');

%% 图6：贪心调价过程中的期望完成任务数变化
if ~isempty(progressCost)
    figure;
    yyaxis left;
    plot(progressCost, progressM, 'LineWidth', 1.5);
    ylabel('期望完成任务数');

    yyaxis right;
    plot(progressCost, progressR * 100, 'LineWidth', 1.5);
    ylabel('预测完成率 / %');

    xlabel('累计增加成本');
    title('调价过程中模型效果变化图');
    grid on;
    saveFig('Q2_调价过程效果变化图.png');
end

fprintf('\n图像已保存为 PNG 文件。\n');

%% ===================== Step 13：自动文字解释 =====================

fprintf('\n================ 代码运行结果解释 ================\n');

fprintf('1. 原方案总成本为 %.4f，新方案总成本为 %.4f，成本增长率为 %.2f%%。\n', ...
    C0, C1, costIncreaseRate * 100);

fprintf('2. 原方案期望完成任务数为 %.4f，新方案期望完成任务数为 %.4f，提升 %.4f。\n', ...
    M0, M1, M1 - M0);

fprintf('3. 原方案预测完成率为 %.2f%%，新方案预测完成率为 %.2f%%，提升 %.2f 个百分点。\n', ...
    R0 * 100, R1 * 100, (R1 - R0) * 100);

fprintf('4. 原方案低完成概率任务数为 %d，新方案低完成概率任务数为 %d。\n', ...
    lowTask0, lowTask1);

fprintf('5. 本方案主要对原预测完成概率低于 %.2f 的任务进行调价，并优先选择单位成本提升效果较高的任务。\n', ...
    targetProb);

fprintf('6. 如果新方案在成本增长较小的情况下提高了期望完成任务数和预测完成率，则说明新定价方案优于原方案。\n');

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
    % 输入可以为标量或向量
    % 输出单位：km

    d = 111 * sqrt( ...
        (lat1 - lat2).^2 + ...
        ((lon1 - lon2) .* cosd(lat1)).^2 ...
        );
end

function [Xstd, mu, sigma] = standardizeData(X)
    % 标准化数据
    mu = mean(X, 1, 'omitnan');
    sigma = std(X, 0, 1, 'omitnan');

    sigma(sigma == 0) = 1;

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
    % 给定某个任务的新价格，计算其 Logistic 预测完成概率
    %
    % priceValue 可以是标量，也可以是价格向量

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