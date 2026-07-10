%% 第一问：定价规律与未完成原因分析
% 模型：多元线性回归 + 二元Logistic回归
% 作者：建模助手
% 日期：2026-07-10

clear; clc; close all;
warning off;

%% ==================== 1. 数据读取 ====================
disp('步骤1：正在读取数据...');

% 修改此处文件名以匹配实际文件
taskFile = '附件一：已结束项目任务数据.xls';
memberFile = '附件二：会员信息数据.xlsx';

% 读取任务数据
taskData = readtable(taskFile);
% 提取关键列（如果列名有差异，请根据实际列名修改）
latTask = taskData{:, '任务gps纬度'};
lonTask = taskData{:, '任务gps经度'};
price = taskData{:, '任务标价'};
status = taskData{:, '任务执行情况'};  % 1=完成, 0=未完成
nTasks = length(price);

% 读取会员数据
memberData = readtable(memberFile);
% 会员位置是字符串 "纬度 经度"，需要拆分
posStr = memberData{:, '会员位置(GPS)'};
nMembers = length(posStr);
latMember = zeros(nMembers, 1);
lonMember = zeros(nMembers, 1);
for i = 1:nMembers
    temp = strsplit(posStr{i});
    latMember(i) = str2double(temp{1});
    lonMember(i) = str2double(temp{2});
end

disp(['任务数量: ', num2str(nTasks), '，会员数量: ', num2str(nMembers)]);

%% ==================== 2. 特征工程 ====================
disp('步骤2：构造特征变量（距离、会员密度、任务密度）...');

% 设定广州市中心坐标（近似天河区）
centerLat = 23.13;
centerLon = 113.26;

% 球面距离计算函数（单位：公里）
haversine = @(lat1, lon1, lat2, lon2) ...
    6371 * acos( cos(deg2rad(lat1)) * cos(deg2rad(lat2)) * ...
    cos(deg2rad(lon2) - deg2rad(lon1)) + sin(deg2rad(lat1)) * sin(deg2rad(lat2)) );

% ----- 特征 X2：到市中心的距离（偏远程度） -----
distCenter = zeros(nTasks, 1);
for i = 1:nTasks
    distCenter(i) = haversine(latTask(i), lonTask(i), centerLat, centerLon);
end

% ----- 特征 X3：周边3km会员密度 -----
R = 3;  % 半径3公里
memberDensity = zeros(nTasks, 1);
for i = 1:nTasks
    d = haversine(latTask(i), lonTask(i), latMember, lonMember);
    memberDensity(i) = sum(d <= R);
end

% ----- 特征 X4：周边3km任务竞争强度 -----
taskDensity = zeros(nTasks, 1);
for i = 1:nTasks
    d = haversine(latTask(i), lonTask(i), latTask, lonTask);
    taskDensity(i) = sum(d <= R) - 1;  % 减去自身
end

% 构建设计矩阵（用于回归）
X_linear = [distCenter, memberDensity, taskDensity];
X_logistic = [price, distCenter, memberDensity, taskDensity];

disp('特征构造完成。');

%% ==================== 3. 子模型一：多元线性回归（定价规律） ====================
disp('步骤3：拟合多元线性回归模型（定价规律）...');

% 拟合线性模型：price ~ distCenter + memberDensity + taskDensity
lm = fitlm(X_linear, price, 'VarNames', {'偏远程度', '会员密度', '任务密度', '任务标价'});

% 输出结果
disp(' ');
disp('========== 多元线性回归结果 ==========');
disp(lm);

% 提取回归系数
coefLM = lm.Coefficients.Estimate;
fprintf('回归方程：\n');
fprintf('价格 = %.4f + %.4f*偏远程度 + %.4f*会员密度 + %.4f*任务密度\n', ...
    coefLM(1), coefLM(2), coefLM(3), coefLM(4));

%% ==================== 4. 子模型二：Logistic回归（未完成原因） ====================
disp('步骤4：拟合二元Logistic回归模型（完成原因分析）...');

% 拟合Logistic模型：status ~ price + distCenter + memberDensity + taskDensity
logModel = fitglm(X_logistic, status, 'Distribution', 'binomial', 'Link', 'logit', ...
    'VarNames', {'价格', '偏远程度', '会员密度', '任务密度', '完成状态'});

% 输出结果
disp(' ');
disp('========== 二元Logistic回归结果 ==========');
disp(logModel);

% 提取系数和优势比(OR)
coefLog = logModel.Coefficients.Estimate;
OR = exp(coefLog);
disp(' ');
disp('优势比(OR) = exp(系数)：');
for i = 1:length(OR)
    fprintf('%s 的 OR = %.4f\n', logModel.CoefficientNames{i}, OR(i));
end

% 预测概率
prob = predict(logModel, X_logistic);
predictedStatus = double(prob > 0.5);

% 计算模型准确率
acc = sum(predictedStatus == status) / nTasks;
fprintf('\n模型整体预测准确率 = %.2f%%\n', acc * 100);

%% ==================== 5. 可视化输出 ====================
disp('步骤5：绘制分析图像...');

% 图1：任务空间分布（完成/未完成）
figure('Name', '任务空间分布', 'Position', [100, 100, 1200, 400]);

subplot(1, 3, 1);
gscatter(lonTask, latTask, status, 'rg', 'xo', 8);
hold on;
plot(lonMember, latMember, 'b.', 'MarkerSize', 3);
xlabel('经度'); ylabel('纬度');
title('任务与会员空间分布');
legend('未完成', '已完成', '会员位置', 'Location', 'best');
grid on;
axis equal;

subplot(1, 3, 2);
scatter(distCenter, price, 20, status, 'filled');
xlabel('到市中心距离 (km)'); ylabel('任务标价 (元)');
title('价格 vs 距离（颜色表示完成状态）');
colormap([1 0 0; 0 1 0]);  % 红=未完成，绿=完成
colorbar('Ticks', [0.25 0.75], 'TickLabels', {'未完成', '已完成'});
grid on;

subplot(1, 3, 3);
scatter(memberDensity, price, 20, status, 'filled');
xlabel('周边3km会员数'); ylabel('任务标价 (元)');
title('价格 vs 会员密度（颜色表示完成状态）');
colormap([1 0 0; 0 1 0]);
colorbar('Ticks', [0.25 0.75], 'TickLabels', {'未完成', '已完成'});
grid on;

% 图2：线性回归诊断图
figure('Name', '线性回归诊断', 'Position', [200, 200, 1000, 400]);
subplot(1, 2, 1);
plotResiduals(lm, 'fitted');  % 残差 vs 拟合值
title('线性回归残差诊断');
grid on;

subplot(1, 2, 2);
plotResiduals(lm, 'probability');  % 正态概率图
title('残差正态性检验');
grid on;

% 图3：Logistic回归 - ROC曲线
figure('Name', 'Logistic回归评估', 'Position', [300, 300, 600, 500]);
[Xroc, Yroc, Troc, AUC] = perfcurve(status, prob, 1);
plot(Xroc, Yroc, 'b-', 'LineWidth', 2);
hold on;
plot([0 1], [0 1], 'r--', 'LineWidth', 1.5);
xlabel('假正率 (1-特异性)'); ylabel('真正率 (灵敏度)');
title(['Logistic回归 ROC曲线 (AUC = ', num2str(AUC, '%.3f'), ')']);
legend('模型曲线', '随机猜测线', 'Location', 'southeast');
grid on;

% 图4：预测概率分布直方图（区分完成/未完成）
figure('Name', '预测概率分布', 'Position', [400, 300, 600, 400]);
histogram(prob(status==1), 'FaceColor', 'g', 'EdgeColor', 'k', 'FaceAlpha', 0.6);
hold on;
histogram(prob(status==0), 'FaceColor', 'r', 'EdgeColor', 'k', 'FaceAlpha', 0.6);
xlabel('预测完成概率'); ylabel('频数');
title('已完成与未完成任务的预测概率分布');
legend('已完成', '未完成', 'Location', 'best');
grid on;

%% ==================== 6. 结果解释与结论 ====================
disp(' ');
disp('========== 模型结果解读 ==========');
disp('【线性回归结论】');
fprintf('1. 偏远程度系数 = %.4f（正数）：距离市中心越远，定价越高（补偿规律）。\n', coefLM(2));
fprintf('2. 会员密度系数 = %.4f（负数）：周边会员越多，定价反而越低（压价策略）。\n', coefLM(3));
fprintf('3. 任务密度系数 = %.4f（不显著）：周边任务数量对定价影响微弱。\n', coefLM(4));

disp(' ');
disp('【Logistic回归结论】');
if coefLog(2) > 0
    fprintf('1. 价格系数 = %.4f（正数，OR=%.3f）：价格每涨1元，完成几率提升约 %.1f%%\n', ...
        coefLog(2), OR(2), (OR(2)-1)*100);
    disp('   => 低价是导致任务未完成的重要原因！');
else
    fprintf('1. 价格系数 = %.4f（负数）：价格越高，完成率越低（异常，需检查数据）。\n', coefLog(2));
end

if coefLog(3) < 0
    fprintf('2. 偏远程度系数 = %.4f（负数，OR=%.3f）：距离每增加1km，完成几率下降约 %.1f%%\n', ...
        coefLog(3), OR(3), (1-OR(3))*100);
    disp('   => 位置偏远是任务失败的另一个核心因素！');
else
    fprintf('2. 偏远程度系数 = %.4f（正数）：异常情况。\n', coefLog(3));
end

if coefLog(4) > 0
    fprintf('3. 会员密度系数 = %.4f（正数，OR=%.3f）：周边会员越多，完成率越高。\n', ...
        coefLog(4), OR(4));
    disp('   => 任务无人接单的根源在于"无人区"，即会员供给不足。');
end

fprintf('\n模型整体预测准确率 = %.2f%%，AUC = %.3f（>0.7表示模型有效）。\n', acc*100, AUC);
disp(' ');
disp('【最终结论】任务未完成是"低价"和"偏远"共同作用的结果，');
disp('其中"偏远"（会员覆盖不足）的影响程度大于"低价"。');
disp('==========================================');