%% Q1_Model_Revised.m
% 问题一：任务定价规律与任务未完成原因分析
% 模型：多元线性回归 + Logistic 回归
%
% 主要功能：
% 1. 读取附件一任务数据和附件二会员数据；
% 2. 自动识别并修正会员 GPS 经纬度顺序；
% 3. 构造任务周边会员特征和任务密度特征；
% 4. 建立多元线性回归模型分析原始定价规律；
% 5. 建立 Logistic 回归模型分析任务完成概率；
% 6. 输出关键结果、Excel 表格和图片。

clear;
clc;
close all;

%% ===================== Step 1：读取数据 =====================

taskFile = '附件一：已结束项目任务数据.xls';
memberFile = '附件二：会员信息数据.xlsx';

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
P       = toNumericVector(Task.(price_col));
Y       = toNumericVector(Task.(finish_col));

% 删除任务缺失值
validTask = ~isnan(taskLat) & ~isnan(taskLon) & ~isnan(P) & ~isnan(Y);

taskID  = taskID(validTask);
taskLat = taskLat(validTask);
taskLon = taskLon(validTask);
P       = P(validTask);
Y       = Y(validTask);

n = length(P);

fprintf('\n================ 基本数据统计 ================\n');
fprintf('任务总数：%d\n', n);
fprintf('完成任务数：%d\n', sum(Y == 1));
fprintf('未完成任务数：%d\n', sum(Y == 0));
fprintf('原始任务完成率：%.2f%%\n', mean(Y) * 100);

%% ===================== Step 3：提取会员数据 =====================

memberID_col  = findCol(Member, {'会员编号', '编号'});
memberGPS_col = findCol(Member, {'会员位置', 'GPS', '位置'});
quota_col     = findCol(Member, {'预订任务限额', '任务限额', '限额'});
credit_col    = findCol(Member, {'信誉值', '信誉'});

memberID  = Member.(memberID_col);
memberGPS = Member.(memberGPS_col);
Q         = toNumericVector(Member.(quota_col));
C         = toNumericVector(Member.(credit_col));

% 自动解析会员 GPS
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

% 删除明显离任务区域很远的异常会员点
% 这里用任务区域外扩 5 度作为粗筛，避免经纬度读反造成图像和距离异常
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

% 会员影响半径，单位 km
rMember = 3;

di_min = zeros(n, 1);       % 最近会员距离
Ni     = zeros(n, 1);       % 周边会员数量
Si     = zeros(n, 1);       % 周边会员信誉值总和
Ui     = zeros(n, 1);       % 周边会员预订限额总和
Wi     = zeros(n, 1);       % 有效会员吸引力指标

fprintf('\n开始计算任务与会员距离及周边会员特征...\n');

for i = 1:n
    
    d = geoDistanceKm(taskLat(i), taskLon(i), memberLat, memberLon);
    
    di_min(i) = min(d);
    
    idx = d <= rMember;
    
    Ni(i) = sum(idx);
    Si(i) = sum(C(idx));
    Ui(i) = sum(Q(idx));
    
    % 有效会员吸引力：信誉值、预订限额越大，距离越近，吸引力越强
    Wi(i) = sum((C(idx) .* Q(idx)) ./ (d(idx) + 1));
end

% 平均信誉值和平均预订限额
avgC = Si ./ max(Ni, 1);
avgQ = Ui ./ max(Ni, 1);

% 综合吸引力
Ai = P .* Wi;

fprintf('周边会员特征构造完成。\n');

%% ===================== Step 5：构造任务密度特征 =====================

% 任务密度半径，单位 km
rTask = 3;

taskDensity = zeros(n, 1);

fprintf('开始计算任务密度特征...\n');

for i = 1:n
    
    dTask = geoDistanceKm(taskLat(i), taskLon(i), taskLat, taskLon);
    
    % 半径 rTask 内其他任务数量
    taskDensity(i) = sum(dTask <= rTask) - 1;
end

% 任务竞争强度：任务越多，会员平均可选择的任务越多
competitionIndex = taskDensity ./ max(Ni, 1);

% 单位距离价格
pricePerDistance = P ./ (di_min + 0.1);

% 单位竞争价格
pricePerCompetition = P ./ (taskDensity + 1);

fprintf('任务密度特征构造完成。\n');

%% ===================== Step 6：完成任务与未完成任务特征对比 =====================

featureNames = {'任务价格P', ...
                '最近会员距离di_min', ...
                '周边会员数量Ni', ...
                '平均信誉值avgC', ...
                '平均预订限额avgQ', ...
                '任务密度taskDensity', ...
                '竞争强度competitionIndex', ...
                '单位距离价格pricePerDistance', ...
                '单位竞争价格pricePerCompetition'};

FeatureMatrix = [P, di_min, Ni, avgC, avgQ, taskDensity, ...
                 competitionIndex, pricePerDistance, pricePerCompetition];

meanFinished = mean(FeatureMatrix(Y == 1, :), 1);
meanUnfinished = mean(FeatureMatrix(Y == 0, :), 1);

CompareTable = table(featureNames', meanFinished', meanUnfinished', ...
    'VariableNames', {'指标', '完成任务均值', '未完成任务均值'});

disp('完成任务与未完成任务特征均值对比：');
disp(CompareTable);

writetable(CompareTable, 'Q1_完成与未完成任务特征对比_修正版.xlsx');

%% ===================== Step 7：多元线性回归模型 =====================

% 多元线性回归用于分析原始定价规律
% 因变量：任务价格 P
% 自变量：最近会员距离、周边会员数量、平均信誉值、平均预订限额、
%         任务密度、竞争强度、任务经度、任务纬度

X_linear_raw = [di_min, Ni, avgC, avgQ, taskDensity, competitionIndex, taskLon, taskLat];

[X_linear, mu_linear, sigma_linear] = standardizeData(X_linear_raw);

X_linear_design = [ones(n, 1), X_linear];

% 最小二乘法估计
beta = (X_linear_design' * X_linear_design) \ (X_linear_design' * P);

% 预测价格
P_hat = X_linear_design * beta;

% 残差
residual = P - P_hat;

% R2
SSE = sum((P - P_hat).^2);
SST = sum((P - mean(P)).^2);
R2 = 1 - SSE / SST;

fprintf('\n================ 多元线性回归结果 ================\n');
fprintf('多元线性回归 R2 = %.4f\n', R2);

linearCoefNames = {'常数项', ...
                   '最近会员距离', ...
                   '周边会员数量', ...
                   '平均信誉值', ...
                   '平均预订限额', ...
                   '任务密度', ...
                   '竞争强度', ...
                   '任务经度', ...
                   '任务纬度'};

LinearCoefTable = table(linearCoefNames', beta, ...
    'VariableNames', {'变量', '回归系数'});

disp(LinearCoefTable);

writetable(LinearCoefTable, 'Q1_多元线性回归系数_修正版.xlsx');

%% ===================== Step 8：定价残差分析 =====================

underPrice = residual < 0;

unfinishedUnderPriceRate = mean(underPrice(Y == 0)) * 100;
finishedUnderPriceRate   = mean(underPrice(Y == 1)) * 100;

fprintf('\n================ 定价残差分析 ================\n');
fprintf('未完成任务中定价偏低比例：%.2f%%\n', unfinishedUnderPriceRate);
fprintf('完成任务中定价偏低比例：%.2f%%\n', finishedUnderPriceRate);

%% ===================== Step 9：Logistic 回归模型 =====================

% Logistic 回归用于分析任务完成概率
% 为避免多重共线性，这里不再同时放入 Si、Ui、Wi、Ai
% 使用更加稳定、解释性更强的变量

X_logit_raw = [P, ...
               di_min, ...
               Ni, ...
               avgC, ...
               avgQ, ...
               taskDensity, ...
               competitionIndex, ...
               pricePerDistance, ...
               pricePerCompetition];

[X_logit, mu_logit, sigma_logit] = standardizeData(X_logit_raw);

X_logit_design = [ones(n, 1), X_logit];

alpha0 = zeros(size(X_logit_design, 2), 1);

options = optimset('MaxIter', 10000, ...
                   'MaxFunEvals', 20000, ...
                   'Display', 'off');

alpha = fminsearch(@(a) logisticNLL(a, X_logit_design, Y), alpha0, options);

Z = X_logit_design * alpha;
p = sigmoid(Z);

% 先计算默认阈值 0.5 的结果
Y_pred_05 = double(p >= 0.5);

accuracy05 = mean(Y_pred_05 == Y) * 100;
TP05 = sum((Y == 1) & (Y_pred_05 == 1));
TN05 = sum((Y == 0) & (Y_pred_05 == 0));
FP05 = sum((Y == 0) & (Y_pred_05 == 1));
FN05 = sum((Y == 1) & (Y_pred_05 == 0));

finishRecall05 = TP05 / max(sum(Y == 1), 1) * 100;
unfinishRecall05 = TN05 / max(sum(Y == 0), 1) * 100;

% 自动寻找平衡准确率最高的阈值
thresholdList = 0.05:0.01:0.95;
balAccList = zeros(length(thresholdList), 1);
accList = zeros(length(thresholdList), 1);
finishRecallList = zeros(length(thresholdList), 1);
unfinishRecallList = zeros(length(thresholdList), 1);

for k = 1:length(thresholdList)
    th = thresholdList(k);
    ytmp = double(p >= th);
    
    TP = sum((Y == 1) & (ytmp == 1));
    TN = sum((Y == 0) & (ytmp == 0));
    
    recall1 = TP / max(sum(Y == 1), 1);
    recall0 = TN / max(sum(Y == 0), 1);
    
    finishRecallList(k) = recall1 * 100;
    unfinishRecallList(k) = recall0 * 100;
    accList(k) = mean(ytmp == Y) * 100;
    balAccList(k) = (recall1 + recall0) / 2 * 100;
end

[bestBalAcc, bestIdx] = max(balAccList);
bestThreshold = thresholdList(bestIdx);

Y_pred = double(p >= bestThreshold);

accuracy = mean(Y_pred == Y) * 100;

TP = sum((Y == 1) & (Y_pred == 1));
TN = sum((Y == 0) & (Y_pred == 0));
FP = sum((Y == 0) & (Y_pred == 1));
FN = sum((Y == 1) & (Y_pred == 0));

finishRecall = TP / max(sum(Y == 1), 1) * 100;
unfinishRecall = TN / max(sum(Y == 0), 1) * 100;

fprintf('\n================ Logistic 回归结果 ================\n');

fprintf('默认阈值 0.5 下：\n');
fprintf('分类准确率：%.2f%%\n', accuracy05);
fprintf('完成任务识别率：%.2f%%\n', finishRecall05);
fprintf('未完成任务识别率：%.2f%%\n', unfinishRecall05);

fprintf('\n平衡准确率最优阈值下：\n');
fprintf('最优阈值：%.2f\n', bestThreshold);
fprintf('分类准确率：%.2f%%\n', accuracy);
fprintf('平衡准确率：%.2f%%\n', bestBalAcc);
fprintf('完成任务识别率：%.2f%%\n', finishRecall);
fprintf('未完成任务识别率：%.2f%%\n', unfinishRecall);

fprintf('\n混淆矩阵：\n');
fprintf('实际完成且预测完成 TP = %d\n', TP);
fprintf('实际完成但预测未完成 FN = %d\n', FN);
fprintf('实际未完成但预测完成 FP = %d\n', FP);
fprintf('实际未完成且预测未完成 TN = %d\n', TN);

logitCoefNames = {'常数项', ...
                  '任务价格', ...
                  '最近会员距离', ...
                  '周边会员数量', ...
                  '平均信誉值', ...
                  '平均预订限额', ...
                  '任务密度', ...
                  '竞争强度', ...
                  '单位距离价格', ...
                  '单位竞争价格'};

LogitCoefTable = table(logitCoefNames', alpha, ...
    'VariableNames', {'变量', 'Logistic回归系数'});

disp(LogitCoefTable);

writetable(LogitCoefTable, 'Q1_Logistic回归系数_修正版.xlsx');

%% ===================== Step 10：输出任务特征与预测结果 =====================

ResultTable = table(taskID, taskLat, taskLon, P, Y, ...
    di_min, Ni, Si, Ui, avgC, avgQ, Wi, Ai, taskDensity, ...
    competitionIndex, pricePerDistance, pricePerCompetition, ...
    P_hat, residual, p, Y_pred_05, Y_pred, ...
    'VariableNames', {'任务编号', '任务纬度', '任务经度', '原始价格', '实际完成情况', ...
    '最近会员距离', '周边会员数量', '信誉值总和', '预订限额总和', ...
    '平均信誉值', '平均预订限额', '有效会员吸引力', '综合吸引力', ...
    '任务密度', '竞争强度', '单位距离价格', '单位竞争价格', ...
    '回归预测价格', '价格残差', 'Logistic完成概率', ...
    '阈值0_5预测完成情况', '最优阈值预测完成情况'});

writetable(ResultTable, 'Q1_任务特征与预测结果_修正版.xlsx');

fprintf('\n任务特征和预测结果已输出到：Q1_任务特征与预测结果_修正版.xlsx\n');

%% ===================== Step 11：绘制图像 =====================

%% 图1：任务与会员空间分布图，修正版
figure;
hold on;

lonMin = min(taskLon) - 0.3;
lonMax = max(taskLon) + 0.3;
latMin = min(taskLat) - 0.3;
latMax = max(taskLat) + 0.3;

memberPlotIdx = memberLon >= lonMin & memberLon <= lonMax & ...
                memberLat >= latMin & memberLat <= latMax;

scatter(memberLon(memberPlotIdx), memberLat(memberPlotIdx), 8, '.', ...
    'DisplayName', '会员位置');
scatter(taskLon(Y == 1), taskLat(Y == 1), 35, 'filled', ...
    'DisplayName', '完成任务');
scatter(taskLon(Y == 0), taskLat(Y == 0), 45, 'x', 'LineWidth', 1.5, ...
    'DisplayName', '未完成任务');

xlabel('经度');
ylabel('纬度');
title('任务与会员空间分布图');
legend('Location', 'best');
grid on;
xlim([lonMin, lonMax]);
ylim([latMin, latMax]);
hold off;

saveas(gcf, 'Q1_任务与会员空间分布图_修正版.png');

%% 图2：原始价格与回归预测价格对比
figure;

scatter(P, P_hat, 35, 'filled');
hold on;

minP = min([P; P_hat]);
maxP = max([P; P_hat]);
plot([minP, maxP], [minP, maxP], 'LineWidth', 1.5);

xlabel('原始任务价格');
ylabel('回归预测价格');
title(['原始价格与回归预测价格对比，R2 = ', num2str(R2, '%.4f')]);
grid on;
hold off;

saveas(gcf, 'Q1_原始价格与预测价格对比_修正版.png');

%% 图3：任务定价残差分布图
figure;
hold on;

scatter(find(Y == 1), residual(Y == 1), 35, 'filled', ...
    'DisplayName', '完成任务');
scatter(find(Y == 0), residual(Y == 0), 45, 'x', 'LineWidth', 1.5, ...
    'DisplayName', '未完成任务');

yline(0, 'LineWidth', 1.5);

xlabel('任务编号序号');
ylabel('价格残差：实际价格 - 预测价格');
title('任务定价残差分布图');
legend('Location', 'best');
grid on;
hold off;

saveas(gcf, 'Q1_任务定价残差分布图_修正版.png');

%% 图4：完成任务与未完成任务特征标准化均值对比
figure;

FeatureStd = standardizeData(FeatureMatrix);

meanFinishedStd = mean(FeatureStd(Y == 1, :), 1);
meanUnfinishedStd = mean(FeatureStd(Y == 0, :), 1);

barDataStd = [meanFinishedStd; meanUnfinishedStd]';

bar(barDataStd);

set(gca, 'XTick', 1:length(featureNames));
set(gca, 'XTickLabel', featureNames);
xtickangle(35);

ylabel('标准化均值');
title('完成任务与未完成任务特征标准化均值对比');
legend('完成任务', '未完成任务', 'Location', 'best');
grid on;

saveas(gcf, 'Q1_完成与未完成任务特征对比图_标准化.png');

%% 图5：Logistic 完成概率分布
figure;
hold on;

histogram(p(Y == 1), 15, 'DisplayName', '实际完成任务');
histogram(p(Y == 0), 15, 'DisplayName', '实际未完成任务');

xline(bestThreshold, 'LineWidth', 1.5, 'DisplayName', '最优阈值');

xlabel('Logistic 预测完成概率');
ylabel('任务数量');
title('完成任务与未完成任务的预测完成概率分布');
legend('Location', 'best');
grid on;
hold off;

saveas(gcf, 'Q1_Logistic完成概率分布图_修正版.png');

%% 图6：各任务 Logistic 预测完成概率
figure;
hold on;

scatter(find(Y == 1), p(Y == 1), 35, 'filled', ...
    'DisplayName', '实际完成任务');
scatter(find(Y == 0), p(Y == 0), 45, 'x', 'LineWidth', 1.5, ...
    'DisplayName', '实际未完成任务');

yline(0.5, '--', 'LineWidth', 1.2, 'DisplayName', '阈值0.5');
yline(bestThreshold, 'LineWidth', 1.5, 'DisplayName', '最优阈值');

xlabel('任务编号序号');
ylabel('预测完成概率');
title('各任务 Logistic 预测完成概率');
legend('Location', 'best');
grid on;
hold off;

saveas(gcf, 'Q1_各任务预测完成概率图_修正版.png');

%% 图7：阈值变化与模型识别效果
figure;
hold on;

plot(thresholdList, accList, 'LineWidth', 1.5, 'DisplayName', '总体准确率');
plot(thresholdList, finishRecallList, 'LineWidth', 1.5, 'DisplayName', '完成任务识别率');
plot(thresholdList, unfinishRecallList, 'LineWidth', 1.5, 'DisplayName', '未完成任务识别率');
plot(thresholdList, balAccList, 'LineWidth', 1.5, 'DisplayName', '平衡准确率');

xline(bestThreshold, 'LineWidth', 1.5, 'DisplayName', '最优阈值');

xlabel('分类阈值');
ylabel('百分比 / %');
title('不同分类阈值下的模型识别效果');
legend('Location', 'best');
grid on;
hold off;

saveas(gcf, 'Q1_阈值变化与模型识别效果.png');

fprintf('\n图像已保存为 PNG 文件。\n');

%% ===================== Step 12：自动输出文字解释 =====================

fprintf('\n================ 模型结果解释 ================\n');

fprintf('1. 原始任务完成率为 %.2f%%。\n', mean(Y) * 100);

fprintf('2. 多元线性回归 R2 = %.4f。\n', R2);

if R2 >= 0.6
    fprintf('   说明原始任务价格与距离、会员分布、任务密度等因素之间存在较明显的线性关系。\n');
elseif R2 >= 0.3
    fprintf('   说明原始任务价格与距离、会员分布、任务密度等因素之间存在一定关系，但解释能力一般。\n');
else
    fprintf('   说明原始任务价格与所选因素之间关系较弱，原定价规律可能不明显。\n');
end

fprintf('3. 未完成任务中定价偏低比例为 %.2f%%。\n', unfinishedUnderPriceRate);
fprintf('   完成任务中定价偏低比例为 %.2f%%。\n', finishedUnderPriceRate);

if abs(unfinishedUnderPriceRate - finishedUnderPriceRate) <= 5
    fprintf('   两类任务定价偏低比例接近，说明单纯价格偏低不能完全解释任务未完成。\n');
elseif unfinishedUnderPriceRate > finishedUnderPriceRate
    fprintf('   未完成任务定价偏低比例更高，说明价格偏低可能是任务未完成的重要原因之一。\n');
else
    fprintf('   完成任务定价偏低比例反而更高，说明任务完成还受到会员分布和任务竞争影响。\n');
end

fprintf('4. Logistic 模型默认阈值 0.5 下分类准确率为 %.2f%%。\n', accuracy05);
fprintf('5. 平衡准确率最优阈值为 %.2f，该阈值下平衡准确率为 %.2f%%。\n', bestThreshold, bestBalAcc);
fprintf('6. 该阈值下完成任务识别率为 %.2f%%，未完成任务识别率为 %.2f%%。\n', finishRecall, unfinishRecall);

fprintf('7. 论文中应重点结合 Logistic 系数、特征均值对比和任务空间分布图，解释任务未完成原因。\n');

fprintf('\n全部计算完成。\n');

%% ===================== 局部函数 =====================

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
    % 支持：
    % 1. "纬度 经度"
    % 2. "经度 纬度"
    % 3. "纬度,经度"
    % 4. "经度,纬度"
    %
    % 解析原则：
    % 对每一个 GPS 点，比较两种经纬度顺序到任务中心的距离，
    % 选择距离任务中心更近的一种顺序。

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
    % 输入可以是标量，也可以是向量
    % 输出单位：km

    d = 111 * sqrt( ...
        (lat1 - lat2).^2 + ...
        ((lon1 - lon2) .* cosd(lat1)).^2 ...
        );
end

function [Xstd, mu, sigma] = standardizeData(X)
    % 标准化数据
    % 输出：
    % Xstd = 标准化后的数据
    % mu = 均值
    % sigma = 标准差

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

    % 很小的正则项，增强数值稳定性
    loss = loss + 1e-6 * sum(alpha(2:end).^2);
end

function p = sigmoid(Z)
    % Sigmoid 函数
    p = 1 ./ (1 + exp(-Z));
end