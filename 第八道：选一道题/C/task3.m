function question3_milp_taxi_60pct_3person_fast()
%% 第三问：双车道上车点布局与协同调度（聚合加速版）
%
% 数据口径：
%   每个航班平均旅客数为153人，其中60%选择出租车。
%   选择出租车人数 = round(153 × 0.60) = 92人。
%   按每3人为一个乘客组，得到30个3人组和1个2人组，
%   共31个出租车上客任务。
%
% 本程序与最初第三问程序的模型目标一致，但进行了等价降维：
%   原程序为每个乘客组分别建立 x(i,s,t)，31个任务会产生大量
%   对称的0-1变量，导致求解器在120秒内无法证明最优。
%   由于本题中31个乘客组来自同一航班、同时到达，且其中30组
%   完全相同，因此本程序不再区分同类型组的编号，而只记录：
%       x3(s,t)：时刻t是否在上车点s服务一个3人组；
%       x2(s,t)：时刻t是否在上车点s服务唯一的2人组。
%   该处理不改变上车点布局、时间冲突和乘客数量，只消除无意义
%   的任务编号对称性，可显著缩短求解时间。
%
% 运行方式：
%   将本文件保存为：
%       question3_milp_taxi_60pct_3person_fast.m
%   在MATLAB命令窗口输入：
%       question3_milp_taxi_60pct_3person_fast
%
% 软件要求：
%   MATLAB Optimization Toolbox（intlinprog）

clc;
close all;

%% 0. 检查求解工具
if exist('intlinprog', 'file') ~= 2
    error('未检测到intlinprog，请确认已安装Optimization Toolbox。');
end

%% 1. 第二问传入第三问的乘客数据
passengersPerFlight = 153;
taxiChoiceRate = 0.60;
taxiPassengers = round(passengersPerFlight * taxiChoiceRate);

groupCapacity = 3;
nFullGroups = floor(taxiPassengers / groupCapacity);
remainingPassengers = mod(taxiPassengers, groupCapacity);

% 本题中：
% nFullGroups = 30，remainingPassengers = 2，总任务数 = 31
nSmallGroups = double(remainingPassengers > 0);
totalGroups = nFullGroups + nSmallGroups;

%% 2. 调度和车道参数
slotMin = 1;                  % 离散时间步长，分钟
horizonMin = 30;              % 调度规划时间，分钟
laneLengthM = 60;             % 单条车道有效长度，米
taxiSpeedMps = 4.0;           % 乘车区内出租车速度，米/秒
walkSpeedMps = 1.2;           % 乘客平均步行速度，米/秒
exitClearanceMin = 0.5;       % 驶离及安全清空时间，分钟
minPointSpacingM = 12;        % 同车道启用点最小纵向间距，米
crossConflictDistanceM = 5;   % 两车道纵向距离小于该值视为冲突
solverMaxTime = 120;          % 每层最大求解时间，秒

timeGrid = 0:slotMin:(horizonMin - slotMin);
nTime = numel(timeGrid);

%% 3. 两条车道候选上车点
lane1Position = [8, 15, 22, 29, 36, 43, 50, 57]';
lane2Position = [11.5, 18.5, 25.5, 32.5, 39.5, 46.5, 53.5]';

pointPositionM = [lane1Position; lane2Position];
pointLane = [ones(numel(lane1Position), 1); ...
             2 * ones(numel(lane2Position), 1)];
pointID = (1:numel(pointPositionM))';

% 候车区位于车道1一侧，外侧车道步行距离更长
walkDistanceM = zeros(numel(pointPositionM), 1);
walkDistanceM(pointLane == 1) = ...
    6 + 0.45 * pointPositionM(pointLane == 1);
walkDistanceM(pointLane == 2) = ...
    10 + 0.45 * pointPositionM(pointLane == 2);

nPoint = numel(pointID);

%% 4. 计算3人组和2人组在各上车点的服务时间
vehicleReachMin = pointPositionM / (taxiSpeedMps * 60);
passengerWalkMin = walkDistanceM / (walkSpeedMps * 60);
vehicleExitMin = (laneLengthM - pointPositionM) / ...
                 (taxiSpeedMps * 60) + exitClearanceMin;

boardingMin3 = 1.0 + 0.35 * 3;
boardingMin2 = 1.0 + 0.35 * 2;

serviceMin3 = max(vehicleReachMin, passengerWalkMin) ...
              + boardingMin3 + vehicleExitMin;
serviceMin2 = max(vehicleReachMin, passengerWalkMin) ...
              + boardingMin2 + vehicleExitMin;

serviceSlots3 = ceil(serviceMin3 / slotMin);
serviceSlots2 = ceil(serviceMin2 / slotMin);

%% 5. 决策变量
% x3(s,t)：一个3人乘客组是否在时刻t于点s开始服务
% x2(s,t)：唯一的2人乘客组是否在时刻t于点s开始服务
% y(s)：候选点s是否启用
% T：全部已服务任务的最晚完成时刻

nX = nPoint * nTime;
idxX3 = reshape(1:nX, [nPoint, nTime]);
idxX2 = reshape(nX + (1:nX), [nPoint, nTime]);
idxY = 2 * nX + (1:nPoint);
idxT = 2 * nX + nPoint + 1;
nVar = idxT;

lb = zeros(nVar, 1);
ub = ones(nVar, 1);
ub(idxT) = horizonMin;

% x3、x2和y为整数变量，T为连续变量
intcon = 1:(2 * nX + nPoint);

% 超出规划期的开始变量直接禁用
for s = 1:nPoint
    for t = 1:nTime
        startMin = timeGrid(t);

        if startMin + serviceSlots3(s) * slotMin > horizonMin
            ub(idxX3(s, t)) = 0;
        end

        if startMin + serviceSlots2(s) * slotMin > horizonMin
            ub(idxX2(s, t)) = 0;
        end
    end
end

%% 6. 构造不等式约束
ineqRow = [];
ineqCol = [];
ineqVal = [];
bineq = [];
nIneq = 0;

% 6.1 同一车道上距离过近的候选点不能同时启用
for s = 1:nPoint
    for r = (s + 1):nPoint
        if pointLane(s) == pointLane(r) && ...
                abs(pointPositionM(s) - pointPositionM(r)) ...
                < minPointSpacingM
            appendIneq([idxY(s), idxY(r)], [1, 1], 1);
        end
    end
end

% 6.2 只有启用的上车点才能安排任务
for s = 1:nPoint
    startCols = [idxX3(s, :), idxX2(s, :)];

    % sum(x3+x2) <= 2*nTime*y(s)
    appendIneq([startCols, idxY(s)], ...
        [ones(1, numel(startCols)), -2 * nTime], 0);

    % 启用的点至少承担一个任务：y(s) <= sum(x3+x2)
    appendIneq([startCols, idxY(s)], ...
        [-ones(1, numel(startCols)), 1], 0);
end

% 6.3 乘客组数量上限
appendIneq(idxX3(:)', ones(1, nX), nFullGroups);

if nSmallGroups > 0
    appendIneq(idxX2(:)', ones(1, nX), 1);
else
    ub(idxX2(:)) = 0;
end

% 6.4 同一上车点在同一时刻最多服务一个乘客组
for s = 1:nPoint
    for u = 1:nTime
        cols = [];

        % 3人组占用
        p3 = serviceSlots3(s);
        for t = max(1, u - p3 + 1):u
            if u < t + p3
                cols(end + 1) = idxX3(s, t); %#ok<AGROW>
            end
        end

        % 2人组占用
        p2 = serviceSlots2(s);
        for t = max(1, u - p2 + 1):u
            if u < t + p2
                cols(end + 1) = idxX2(s, t); %#ok<AGROW>
            end
        end

        appendIneq(cols, ones(1, numel(cols)), 1);
    end
end

% 6.5 两条车道纵向位置过近的上车点不能同时运行
crossConflictPairs = [];

for s = 1:nPoint
    for r = (s + 1):nPoint
        if pointLane(s) ~= pointLane(r) && ...
                abs(pointPositionM(s) - pointPositionM(r)) ...
                < crossConflictDistanceM
            crossConflictPairs(end + 1, :) = [s, r]; %#ok<AGROW>
        end
    end
end

for k = 1:size(crossConflictPairs, 1)
    s = crossConflictPairs(k, 1);
    r = crossConflictPairs(k, 2);

    for u = 1:nTime
        cols = [];

        for pointNow = [s, r]
            p3 = serviceSlots3(pointNow);
            for t = max(1, u - p3 + 1):u
                if u < t + p3
                    cols(end + 1) = idxX3(pointNow, t); %#ok<AGROW>
                end
            end

            p2 = serviceSlots2(pointNow);
            for t = max(1, u - p2 + 1):u
                if u < t + p2
                    cols(end + 1) = idxX2(pointNow, t); %#ok<AGROW>
                end
            end
        end

        appendIneq(cols, ones(1, numel(cols)), 1);
    end
end

% 6.6 最晚完成时刻约束
for s = 1:nPoint
    for t = 1:nTime
        finish3 = timeGrid(t) + serviceSlots3(s) * slotMin;
        finish2 = timeGrid(t) + serviceSlots2(s) * slotMin;

        appendIneq([idxX3(s, t), idxT], [finish3, -1], 0);
        appendIneq([idxX2(s, t), idxT], [finish2, -1], 0);
    end
end

Aineq = sparse(ineqRow, ineqCol, ineqVal, nIneq, nVar);

% 第一层没有额外等式约束
Aeq = sparse(0, nVar);
beq = zeros(0, 1);

%% 7. 求解器设置
options = optimoptions('intlinprog', ...
    'Display', 'iter', ...
    'MaxTime', solverMaxTime, ...
    'RelativeGapTolerance', 1e-4);

fprintf('\n====================================================\n');
fprintf('第三问：双车道混合整数规划模型（聚合加速版）\n');
fprintf('单航班旅客数：%d人\n', passengersPerFlight);
fprintf('选择出租车比例：%.0f%%\n', taxiChoiceRate * 100);
fprintf('选择出租车人数：%d人\n', taxiPassengers);
fprintf('乘客组划分：%d个3人组，%d个%d人组，共%d个任务\n', ...
    nFullGroups, nSmallGroups, remainingPassengers, totalGroups);
fprintf('模型0-1变量由原来的约12900个降为%d个\n', ...
    numel(intcon));
fprintf('====================================================\n');

%% 8. 第一层：最大化完成乘车人数
f1 = zeros(nVar, 1);
f1(idxX3(:)) = -3;
f1(idxX2(:)) = -remainingPassengers;

fprintf('\n第一层：最大化规划期内完成乘车人数\n');

[x1, ~, exitflag1, output1] = intlinprog( ...
    f1, intcon, Aineq, bineq, Aeq, beq, lb, ub, options);

if isempty(x1)
    error('第一层没有找到可行解：%s', output1.message);
end

if exitflag1 <= 0
    warning('第一层得到可行解但未证明最优：%s', output1.message);
end

maxPassengers = round( ...
    3 * sum(x1(idxX3(:))) + ...
    remainingPassengers * sum(x1(idxX2(:))));

fprintf('第一层完成乘车人数：%d / %d人\n', ...
    maxPassengers, taxiPassengers);

%% 9. 第二层：固定最大乘车人数，最小化最晚完成时刻
passengerCols = [idxX3(:); idxX2(:)]';
passengerVals = [ ...
    3 * ones(nX, 1); ...
    remainingPassengers * ones(nX, 1)]';

passengerRow = sparse( ...
    ones(1, numel(passengerCols)), ...
    passengerCols, passengerVals, 1, nVar);

Aeq2 = [Aeq; passengerRow];
beq2 = [beq; maxPassengers];

f2 = zeros(nVar, 1);
f2(idxT) = 1;

fprintf('\n第二层：固定最大乘车人数，最小化最晚完成时刻\n');

[x2, ~, exitflag2, output2] = intlinprog( ...
    f2, intcon, Aineq, bineq, Aeq2, beq2, lb, ub, options);

if isempty(x2)
    error('第二层没有找到可行解：%s', output2.message);
end

if exitflag2 <= 0
    warning('第二层得到可行解但未证明最优：%s', output2.message);
end

minMakespan = round(x2(idxT));
fprintf('第二层最晚完成时刻：%d min\n', minMakespan);

%% 10. 第三层：固定前两层结果，最小化乘客总步行距离
makespanRow = sparse(1, idxT, 1, 1, nVar);
Aineq3 = [Aineq; makespanRow];
bineq3 = [bineq; minMakespan];

f3 = zeros(nVar, 1);

for s = 1:nPoint
    f3(idxX3(s, :)) = 3 * walkDistanceM(s);
    f3(idxX2(s, :)) = remainingPassengers * walkDistanceM(s);
end

% 极小惩罚：避免启用未使用的上车点
f3(idxY) = 1e-3;

fprintf('\n第三层：固定前两层结果，最小化乘客总步行距离\n');

[xOpt, ~, exitflag3, output3] = intlinprog( ...
    f3, intcon, Aineq3, bineq3, Aeq2, beq2, lb, ub, options);

if isempty(xOpt)
    error('第三层没有找到可行解：%s', output3.message);
end

if exitflag3 <= 0
    warning('第三层得到可行解但未证明最优：%s', output3.message);
end

%% 11. 提取最优调度结果
X3 = xOpt(idxX3) > 0.5;
X2 = xOpt(idxX2) > 0.5;
pointEnabled = xOpt(idxY) > 0.5;

schedulePoint = [];
scheduleLane = [];
schedulePosition = [];
scheduleStart = [];
scheduleFinish = [];
schedulePassengers = [];
scheduleWalk = [];
scheduleType = strings(0, 1);

for s = 1:nPoint
    for t = 1:nTime
        if X3(s, t)
            schedulePoint(end + 1, 1) = pointID(s); %#ok<AGROW>
            scheduleLane(end + 1, 1) = pointLane(s); %#ok<AGROW>
            schedulePosition(end + 1, 1) = pointPositionM(s); %#ok<AGROW>
            scheduleStart(end + 1, 1) = timeGrid(t); %#ok<AGROW>
            scheduleFinish(end + 1, 1) = ...
                timeGrid(t) + serviceSlots3(s) * slotMin; %#ok<AGROW>
            schedulePassengers(end + 1, 1) = 3; %#ok<AGROW>
            scheduleWalk(end + 1, 1) = walkDistanceM(s); %#ok<AGROW>
            scheduleType(end + 1, 1) = "3人组"; %#ok<AGROW>
        end

        if X2(s, t)
            schedulePoint(end + 1, 1) = pointID(s); %#ok<AGROW>
            scheduleLane(end + 1, 1) = pointLane(s); %#ok<AGROW>
            schedulePosition(end + 1, 1) = pointPositionM(s); %#ok<AGROW>
            scheduleStart(end + 1, 1) = timeGrid(t); %#ok<AGROW>
            scheduleFinish(end + 1, 1) = ...
                timeGrid(t) + serviceSlots2(s) * slotMin; %#ok<AGROW>
            schedulePassengers(end + 1, 1) = remainingPassengers; %#ok<AGROW>
            scheduleWalk(end + 1, 1) = walkDistanceM(s); %#ok<AGROW>
            scheduleType(end + 1, 1) = ...
                string(remainingPassengers) + "人组"; %#ok<AGROW>
        end
    end
end

% 按开始时间、车道和位置排序
[~, order] = sortrows( ...
    [scheduleStart, scheduleLane, schedulePosition], [1, 2, 3]);

schedulePoint = schedulePoint(order);
scheduleLane = scheduleLane(order);
schedulePosition = schedulePosition(order);
scheduleStart = scheduleStart(order);
scheduleFinish = scheduleFinish(order);
schedulePassengers = schedulePassengers(order);
scheduleWalk = scheduleWalk(order);
scheduleType = scheduleType(order);

taskID = (1:numel(schedulePoint))';
waitMin = scheduleStart;  % 同一航班旅客均在0分钟到达
serviceMin = scheduleFinish - scheduleStart;

servedTasks = numel(taskID);
servedPassengers = sum(schedulePassengers);
actualMakespan = max(scheduleFinish);

vehicleEfficiency = servedTasks / actualMakespan * 60;
passengerEfficiency = servedPassengers / actualMakespan * 60;
averageWait = mean(waitMin);
averageWalk = sum(schedulePassengers .* scheduleWalk) ...
              / servedPassengers;

lane1Enabled = sum(pointEnabled & pointLane == 1);
lane2Enabled = sum(pointEnabled & pointLane == 2);

%% 12. 输出关键结果
fprintf('\n====================================================\n');
fprintf('最优求解结果\n');
fprintf('====================================================\n');
fprintf('启用上车点总数：%d\n', sum(pointEnabled));
fprintf('第1车道启用上车点数：%d\n', lane1Enabled);
fprintf('第2车道启用上车点数：%d\n', lane2Enabled);
fprintf('完成上客任务数：%d / %d\n', servedTasks, totalGroups);
fprintf('完成乘车人数：%d / %d\n', servedPassengers, taxiPassengers);
fprintf('最晚完成时刻：%.2f min\n', actualMakespan);
fprintf('车辆服务效率：%.2f 辆/h\n', vehicleEfficiency);
fprintf('乘客服务效率：%.2f 人/h\n', passengerEfficiency);
fprintf('平均等待时间：%.2f min\n', averageWait);
fprintf('乘客平均步行距离：%.2f m/人\n', averageWalk);

fprintf('\n启用的上车点：\n');
for s = find(pointEnabled)'
    fprintf('  P%d：车道%d，位置%.1f m，步行距离%.1f m\n', ...
        pointID(s), pointLane(s), ...
        pointPositionM(s), walkDistanceM(s));
end

%% 13. 结果表
resultTable = table( ...
    taskID, scheduleType, schedulePassengers, ...
    schedulePoint, scheduleLane, schedulePosition, ...
    scheduleStart, scheduleFinish, waitMin, serviceMin, scheduleWalk, ...
    'VariableNames', { ...
    'TaskID', 'GroupType', 'PassengerCount', ...
    'PointID', 'Lane', 'PositionM', ...
    'StartMin', 'FinishMin', 'WaitMin', ...
    'ServiceMin', 'WalkDistanceM'});

disp(resultTable);

pointResultTable = table( ...
    pointID, pointLane, pointPositionM, ...
    walkDistanceM, pointEnabled, ...
    'VariableNames', { ...
    'PointID', 'Lane', 'PositionM', ...
    'WalkDistanceM', 'Enabled'});

%% 14. 图1：最优上车点布局
figure('Color', 'w');
hold on;

plot([0, laneLengthM], [1, 1], 'k-', 'LineWidth', 2);
plot([0, laneLengthM], [2, 2], 'k-', 'LineWidth', 2);

scatter(pointPositionM(~pointEnabled), ...
        pointLane(~pointEnabled), 50, 'o', 'LineWidth', 1.2);
scatter(pointPositionM(pointEnabled), ...
        pointLane(pointEnabled), 90, 'filled');

for s = 1:nPoint
    text(pointPositionM(s), pointLane(s) + 0.10, ...
        sprintf('P%d', pointID(s)), ...
        'HorizontalAlignment', 'center', 'FontSize', 9);
end

xlim([0, laneLengthM]);
ylim([0.5, 2.5]);
yticks([1, 2]);
yticklabels({'车道1', '车道2'});
xlabel('沿车道方向的位置/m');
ylabel('车道');
title('双车道候选上车点及最优启用方案');
grid on;
box on;
saveCurrentFigure('question3_fast_figure1_layout.png');

%% 15. 图2：任务调度甘特图
figure('Color', 'w');
hold on;

for i = 1:servedTasks
    rectangle('Position', [ ...
        scheduleStart(i), i - 0.35, ...
        serviceMin(i), 0.70], ...
        'EdgeColor', 'k', ...
        'FaceColor', [0.45, 0.70, 0.85]);

    text(scheduleStart(i) + serviceMin(i) / 2, i, ...
        sprintf('车道%d-P%d', scheduleLane(i), schedulePoint(i)), ...
        'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'middle', ...
        'FontSize', 7);
end

xlim([0, max(horizonMin, actualMakespan + 1)]);
ylim([0.3, servedTasks + 0.7]);
yticks(1:servedTasks);
yticklabels(compose('任务%d', taskID));
xlabel('时间/min');
ylabel('上客任务');
title('最优出租车—乘客组调度甘特图');
grid on;
box on;
saveCurrentFigure('question3_fast_figure2_gantt.png');

%% 16. 图3：两条车道动态占用情况
laneOccupancy = zeros(2, nTime);

for i = 1:servedTasks
    for u = 1:nTime
        if timeGrid(u) >= scheduleStart(i) && ...
                timeGrid(u) < scheduleFinish(i)
            laneOccupancy(scheduleLane(i), u) = ...
                laneOccupancy(scheduleLane(i), u) + 1;
        end
    end
end

figure('Color', 'w');
stairs(timeGrid, laneOccupancy(1, :), 'LineWidth', 1.8);
hold on;
stairs(timeGrid, laneOccupancy(2, :), 'LineWidth', 1.8);
xlabel('时间/min');
ylabel('同时服务车辆数');
title('两条车道的动态占用情况');
legend('车道1', '车道2', 'Location', 'best');
grid on;
box on;
saveCurrentFigure('question3_fast_figure3_lane_occupancy.png');

%% 17. 保存Excel结果
outputFile = 'question3_fast_milp_results.xlsx';

if exist(outputFile, 'file') == 2
    delete(outputFile);
end

writetable(resultTable, outputFile, 'Sheet', '任务调度');
writetable(pointResultTable, outputFile, 'Sheet', '上车点布局');

indicator = [ ...
    "单航班旅客人数"; ...
    "选择出租车比例"; ...
    "选择出租车人数"; ...
    "3人乘客组数"; ...
    "剩余乘客组人数"; ...
    "完成任务数"; ...
    "完成乘车人数"; ...
    "启用上车点数"; ...
    "最晚完成时刻/min"; ...
    "车辆服务效率/辆每小时"; ...
    "乘客服务效率/人每小时"; ...
    "平均等待时间/min"; ...
    "乘客平均步行距离/m每人"];

value = [ ...
    passengersPerFlight; ...
    taxiChoiceRate; ...
    taxiPassengers; ...
    nFullGroups; ...
    remainingPassengers; ...
    servedTasks; ...
    servedPassengers; ...
    sum(pointEnabled); ...
    actualMakespan; ...
    vehicleEfficiency; ...
    passengerEfficiency; ...
    averageWait; ...
    averageWalk];

summaryTable = table(indicator, value, ...
    'VariableNames', {'Indicator', 'Value'});
writetable(summaryTable, outputFile, 'Sheet', '结果汇总');

fprintf('\n程序运行完成，已生成：\n');
fprintf('1. %s\n', outputFile);
fprintf('2. question3_fast_figure1_layout.png\n');
fprintf('3. question3_fast_figure2_gantt.png\n');
fprintf('4. question3_fast_figure3_lane_occupancy.png\n');
fprintf('====================================================\n');

%% 嵌套函数：添加不等式约束
    function appendIneq(cols, vals, rhs)
        nIneq = nIneq + 1;
        cols = cols(:);
        vals = vals(:);

        ineqRow = [ineqRow; repmat(nIneq, numel(cols), 1)]; %#ok<AGROW>
        ineqCol = [ineqCol; cols]; %#ok<AGROW>
        ineqVal = [ineqVal; vals]; %#ok<AGROW>
        bineq(nIneq, 1) = rhs;
    end

%% 嵌套函数：保存图片
    function saveCurrentFigure(fileName)
        try
            exportgraphics(gcf, fileName, 'Resolution', 300);
        catch
            saveas(gcf, fileName);
        end
    end

end
