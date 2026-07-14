%% 机场出租车司机决策模型
% 基于时变排队等待时间估计的预期净收益阈值决策模型
%
% 说明：
% 1. 本程序默认使用内置演示数据，因此下载后可直接运行；
% 2. 将 USE_DEMO_DATA 改为 false 后，可读取真实 Excel 数据；
% 3. 程序输出乘客需求、双队列状态、等待时间、临界等待时间、
%    临界排队车辆数以及司机选择策略，并自动绘制和保存图像。
%
% 适用版本：MATLAB R2016b 及以上（脚本末尾使用了局部函数）。

clear;
clc;
close all;

%% 0. 参数设置
USE_DEMO_DATA = true;       % true：使用演示数据；false：读取真实 Excel 数据

dtMin = 10;                % 离散时间步长，单位：分钟
oneDayMin = 24 * 60;        % 一天总分钟数
assert(mod(oneDayMin, dtMin) == 0, 'dtMin 必须能整除 1440。');

K = oneDayMin / dtMin;      % 一天的时间段数量
timeMin = (0:K-1)' * dtMin; % 每个时间段起点，单位：分钟
timeHour = timeMin / 60;    % 每个时间段起点，单位：小时
dtHour = dtMin / 60;

% 乘客从航班落地到到达出租车乘车区的时间分布参数
releaseMeanMin = 35;        % 平均释放时间，单位：分钟
releaseStdMin = 12;         % 标准差，单位：分钟

% 初始队列状态，可根据实际机场数据修改
initialTaxiQueue = 120;     % 0:00 时蓄车池中的出租车数
initialPassengerQueue = 0;  % 0:00 时等待出租车的乘客组数

% 重点分析的司机到达时刻
selectedDecisionMinute = 18 * 60; % 18:00

% 搜索临界排队车辆数时允许的最大车辆数
maxQueueSearch = 2500;

% 为保证晚间进入队列的司机也能计算到等待时间，将需求与服务能力延长若干天
repeatDaysForHorizon = 3;

%% 1. 读取或生成输入数据
if USE_DEMO_DATA
    [flightData, newTaxiDay, serviceCapacityDay] = ...
        createDemoData(timeMin, dtMin);
else
    % 真实数据模式需要以下两个文件：
    % 1) flight_data.xlsx
    % 2) queue_data.xlsx
    flightFile = 'flight_data.xlsx';
    queueFile = 'queue_data.xlsx';

    if exist(flightFile, 'file') ~= 2
        error('未找到 %s，请检查文件路径。', flightFile);
    end
    if exist(queueFile, 'file') ~= 2
        error('未找到 %s，请检查文件路径。', queueFile);
    end

    flightData = readtable(flightFile);
    queueData = readtable(queueFile);

    requiredFlightColumns = { ...
        'ArrivalMinute', 'Seats', 'LoadFactor', ...
        'ArrivalShare', 'TaxiShare', 'GroupSize'};
    requiredQueueColumns = { ...
        'TimeMinute', 'NewTaxis', 'ServiceCapacity'};

    checkRequiredColumns(flightData, requiredFlightColumns, flightFile);
    checkRequiredColumns(queueData, requiredQueueColumns, queueFile);

    % 将车辆到达量和服务能力对齐到统一的时间网格
    newTaxiDay = interp1( ...
        queueData.TimeMinute, queueData.NewTaxis, timeMin, ...
        'previous', 'extrap');

    serviceCapacityDay = interp1( ...
        queueData.TimeMinute, queueData.ServiceCapacity, timeMin, ...
        'previous', 'extrap');
end

% 转为列向量并进行基本检查
newTaxiDay = newTaxiDay(:);
serviceCapacityDay = serviceCapacityDay(:);

if any(newTaxiDay < 0) || any(serviceCapacityDay < 0)
    error('新增出租车数和服务能力不能为负数。');
end

%% 2. 根据航班信息计算分时出租车乘客需求
% 单架航班产生的出租车需求：
% q_i = Seats * LoadFactor * ArrivalShare * TaxiShare / GroupSize
%
% 再根据乘客释放时间分布，将每架航班的需求分配到各时间段。
passengerDemandDay = buildPassengerDemand( ...
    flightData, timeMin, dtMin, releaseMeanMin, releaseStdMin, oneDayMin);

%% 3. 建立时变双队列模型
% X_k = min{出租车供给量, 乘客需求量, 乘车区服务能力}
% Q_T(k+1) = Q_T(k) + B_k - X_k
% Q_P(k+1) = Q_P(k) + A_k - X_k
[taxiQueue, passengerQueue, matchedTaxis] = simulateDoubleQueue( ...
    passengerDemandDay, newTaxiDay, serviceCapacityDay, ...
    initialTaxiQueue, initialPassengerQueue);

%% 4. 设置收益模型参数
% 单位说明：
% 金额：元；距离：公里；时间：小时。
econ.unitDistanceCost = 0.75;  % 单位里程运营成本，元/公里
econ.unitTimeCost = 6.00;      % 行驶过程单位时间运营成本，元/小时

% 方案 A：机场排队后完成一笔机场订单
econ.airportFare = 130;        % 机场订单平均车费，元
econ.airportDistance = 38;     % 机场订单平均行驶距离，公里
econ.airportTravelTime = 0.80; % 机场订单平均行驶时间，小时
econ.loadingTime = 0.08;       % 乘客上车及驶离乘车区时间，小时
econ.airportFixedCost = 8;     % 机场订单过路费等固定成本，元

% 方案 B：空载返回市区后完成一笔市区订单
econ.cityFareBase = 70;        % 市区订单基础平均车费，元
econ.cityDistance = 18;        % 市区订单平均行驶距离，公里
econ.cityTravelTime = 0.55;    % 市区订单平均行驶时间，小时
econ.emptyDistance = 20;       % 机场至市区空驶距离，公里
econ.emptyTravelTime = 0.50;   % 机场至市区空驶时间，小时
econ.citySearchTimeBase = 0.18;% 市区基础寻客时间，小时
econ.cityFixedCost = 2;        % 返回市区过程中的固定成本，元

% 市区收益具有时变性：早晚高峰车费提高、寻客时间缩短；凌晨相反
fareMultiplier = ones(K, 1);
fareMultiplier(timeHour >= 7 & timeHour < 9) = 1.15;
fareMultiplier(timeHour >= 17 & timeHour < 20) = 1.18;
fareMultiplier(timeHour >= 1 & timeHour < 5) = 0.88;

citySearchTime = econ.citySearchTimeBase * ones(K, 1);
citySearchTime(timeHour >= 7 & timeHour < 9) = ...
    max(0.05, econ.citySearchTimeBase - 0.07);
citySearchTime(timeHour >= 17 & timeHour < 20) = ...
    max(0.05, econ.citySearchTimeBase - 0.07);
citySearchTime(timeHour >= 1 & timeHour < 5) = ...
    econ.citySearchTimeBase + 0.15;

cityFare = econ.cityFareBase .* fareMultiplier;

%% 5. 计算两种方案的预期净收益
% 机场订单单次循环净利润 Pi_A
airportNetProfit = econ.airportFare ...
    - econ.unitDistanceCost * econ.airportDistance ...
    - econ.unitTimeCost * econ.airportTravelTime ...
    - econ.airportFixedCost;

% 返回市区并完成一笔市区订单的单次循环净利润 Pi_B(t)
cityNetProfit = cityFare ...
    - econ.unitDistanceCost * ...
      (econ.emptyDistance + econ.cityDistance) ...
    - econ.unitTimeCost * ...
      (econ.emptyTravelTime + econ.cityTravelTime) ...
    - econ.cityFixedCost;

cityCycleTime = econ.emptyTravelTime ...
    + citySearchTime ...
    + econ.cityTravelTime;

% 返回市区方案单位时间预期净收益 r_B(t)
cityNetRate = cityNetProfit ./ cityCycleTime;

% 临界等待时间：
% T_w^* = Pi_A / r_B - T_L - E(T_A)
criticalWaitHour = nan(K, 1);

if airportNetProfit <= 0
    % 机场订单本身净利润非正，原则上不应选择机场方案
    criticalWaitHour(:) = -Inf;
else
    positiveCityRate = cityNetRate > 0;
    criticalWaitHour(positiveCityRate) = ...
        airportNetProfit ./ cityNetRate(positiveCityRate) ...
        - econ.loadingTime ...
        - econ.airportTravelTime;

    % 若返回市区方案单位时间净收益非正，而机场订单净利润为正，
    % 则机场方案在理论上没有有限的等待时间上限。
    criticalWaitHour(~positiveCityRate) = Inf;
end

%% 6. 估计各时段当前司机的等待时间及临界排队车辆数
% 延长需求和服务能力，以免晚间司机在一天结束前尚未得到服务。
passengerDemandExt = repmat(passengerDemandDay, repeatDaysForHorizon, 1);
serviceCapacityExt = repmat(serviceCapacityDay, repeatDaysForHorizon, 1);

currentWaitHour = nan(K, 1);
criticalQueue = nan(K, 1);
airportNetRateCurrent = nan(K, 1);

for k = 1:K
    % 假设目标司机在第 k 个时间段开始时进入蓄车池，
    % 前方车辆数取该时段开始时的蓄车池车辆数。
    nAhead = max(0, round(taxiQueue(k)));
    passengerQueueNow = max(0, passengerQueue(k));

    % 在"始终有足够出租车等待"的条件下，计算未来各时段可完成的服务量。
    servicePotential = buildServicePotential( ...
        k, passengerQueueNow, passengerDemandExt, serviceCapacityExt);

    % 根据累计服务量反求目标司机的等待时间。
    currentWaitHour(k) = invertServiceToWait( ...
        nAhead, servicePotential, dtHour);

    % 计算当前排队方案单位时间预期净收益 r_A(t)
    if isfinite(currentWaitHour(k))
        airportNetRateCurrent(k) = airportNetProfit / ...
            (currentWaitHour(k) ...
            + econ.loadingTime ...
            + econ.airportTravelTime);
    else
        airportNetRateCurrent(k) = 0;
    end

    % 将临界等待时间转化为临界排队车辆数 N*(t)
    if criticalWaitHour(k) < 0
        % 即使没有车辆排队，机场方案仍不优于返回市区方案。
        criticalQueue(k) = -1;
    elseif isinf(criticalWaitHour(k))
        % 理论上机场方案始终占优；此处用搜索上限表示。
        criticalQueue(k) = maxQueueSearch;
    else
        serviceByThreshold = serviceCompletedByTime( ...
            servicePotential, criticalWaitHour(k), dtHour);

        % 若阈值时间内最多可服务 M 辆车，司机前方最多允许 M-1 辆。
        criticalQueue(k) = floor(serviceByThreshold) - 1;
        criticalQueue(k) = min(maxQueueSearch, criticalQueue(k));
        criticalQueue(k) = max(-1, criticalQueue(k));
    end
end

%% 7. 输出司机选择策略
strategy = repmat("空载返回市区", K, 1);
strategy(airportNetRateCurrent >= cityNetRate) = "进入蓄车池排队";

% 重点时刻索引
selectedIndex = floor(selectedDecisionMinute / dtMin) + 1;
selectedIndex = min(max(selectedIndex, 1), K);

selectedHour = floor(selectedDecisionMinute / 60);
selectedMinute = mod(selectedDecisionMinute, 60);

fprintf('\n============================================================\n');
fprintf('机场出租车司机决策模型关键结果\n');
fprintf('============================================================\n');
fprintf('时间步长：%d 分钟\n', dtMin);
fprintf('全天预计出租车需求组数：%.2f 组\n', sum(passengerDemandDay));
fprintf('全天新增进入蓄车池出租车数：%.2f 辆\n', sum(newTaxiDay));
fprintf('蓄车池最大出租车队列：%.2f 辆\n', max(taxiQueue));
fprintf('乘客最大等待队列：%.2f 组\n', max(passengerQueue));
fprintf('机场订单单次预期净利润：%.2f 元\n', airportNetProfit);

fprintf('\n重点分析时刻：%02d:%02d\n', selectedHour, selectedMinute);
fprintf('当前蓄车池车辆数：%.0f 辆\n', round(taxiQueue(selectedIndex)));
fprintf('当前等待乘客组数：%.2f 组\n', passengerQueue(selectedIndex));
fprintf('目标司机预计等待时间：%.2f 分钟\n', ...
    currentWaitHour(selectedIndex) * 60);
fprintf('临界等待时间：%.2f 分钟\n', ...
    criticalWaitHour(selectedIndex) * 60);
fprintf('临界排队车辆数：%.0f 辆\n', criticalQueue(selectedIndex));
fprintf('机场排队方案单位时间净收益：%.2f 元/小时\n', ...
    airportNetRateCurrent(selectedIndex));
fprintf('返回市区方案单位时间净收益：%.2f 元/小时\n', ...
    cityNetRate(selectedIndex));
fprintf('建议策略：%s\n', char(strategy(selectedIndex)));
fprintf('============================================================\n\n');

%% 8. 生成典型时段决策结果表
selectedHours = [6; 9; 12; 18; 22];
selectedIndices = floor(selectedHours * 60 / dtMin) + 1;
selectedIndices = min(max(selectedIndices, 1), K);

nSelected = numel(selectedIndices);
timeLabel = strings(nSelected, 1);
for i = 1:nSelected
    timeLabel(i) = sprintf('%02d:00', selectedHours(i));
end

ResultTable = table( ...
    timeLabel, ...
    passengerDemandDay(selectedIndices), ...
    taxiQueue(selectedIndices), ...
    passengerQueue(selectedIndices), ...
    currentWaitHour(selectedIndices) * 60, ...
    criticalWaitHour(selectedIndices) * 60, ...
    criticalQueue(selectedIndices), ...
    airportNetRateCurrent(selectedIndices), ...
    cityNetRate(selectedIndices), ...
    strategy(selectedIndices), ...
    'VariableNames', { ...
    'Time', 'PassengerDemand', 'TaxiQueue', 'PassengerQueue', ...
    'ExpectedWaitMin', 'CriticalWaitMin', 'CriticalQueue', ...
    'AirportRate', 'CityRate', 'Strategy'});

disp('典型时段决策结果表：');
disp(ResultTable);

%% 9. 保存结果
outputFolder = 'airport_taxi_output';
if ~exist(outputFolder, 'dir')
    mkdir(outputFolder);
end

writetable(ResultTable, fullfile(outputFolder, 'decision_results.xlsx'));

fullResult = table( ...
    timeMin, timeHour, passengerDemandDay, newTaxiDay, ...
    serviceCapacityDay, taxiQueue(1:K), passengerQueue(1:K), ...
    matchedTaxis, currentWaitHour * 60, criticalWaitHour * 60, ...
    criticalQueue, airportNetRateCurrent, cityNetRate, strategy, ...
    'VariableNames', { ...
    'TimeMinute', 'TimeHour', 'PassengerDemand', 'NewTaxis', ...
    'ServiceCapacity', 'TaxiQueue', 'PassengerQueue', ...
    'MatchedTaxis', 'ExpectedWaitMin', 'CriticalWaitMin', ...
    'CriticalQueue', 'AirportRate', 'CityRate', 'Strategy'});

writetable(fullResult, fullfile(outputFolder, 'full_time_series_results.xlsx'));

%% 10. 绘制图 1：机场出租车乘客需求随时间变化
figure('Name', 'Passenger Demand', 'Color', 'w');
plot(timeHour, passengerDemandDay, 'LineWidth', 1.6);
xlabel('时刻/小时');
ylabel('新增出租车需求组数');
title('机场出租车乘客需求随时间变化');
grid on;
xlim([0, 24]);
xticks(0:2:24);
saveas(gcf, fullfile(outputFolder, 'figure1_passenger_demand.png'));

%% 11. 绘制图 2：出租车队列与乘客队列变化
figure('Name', 'Queue Evolution', 'Color', 'w');
plot([timeHour; 24], taxiQueue, 'LineWidth', 1.6, ...
    'DisplayName', '蓄车池出租车队列');
hold on;
plot([timeHour; 24], passengerQueue, 'LineWidth', 1.6, ...
    'DisplayName', '乘客等待队列');
xlabel('时刻/小时');
ylabel('队列长度');
title('机场出租车与乘客队列动态变化');
legend('Location', 'best');
grid on;
xlim([0, 24]);
xticks(0:2:24);
saveas(gcf, fullfile(outputFolder, 'figure2_queue_evolution.png'));

%% 12. 绘制图 3：不同时段排队车辆数与等待时间关系
plotHours = [6, 12, 18, 22];
plotIndices = floor(plotHours * 60 / dtMin) + 1;

maxObservedQueue = max(taxiQueue(1:K));
maxPlotQueue = max(300, ceil(maxObservedQueue / 50) * 50 + 50);
maxPlotQueue = min(maxQueueSearch, maxPlotQueue);
queueCandidates = (0:5:maxPlotQueue)';

figure('Name', 'Waiting Time Curves', 'Color', 'w');
hold on;
for i = 1:numel(plotIndices)
    k = plotIndices(i);
    servicePotential = buildServicePotential( ...
        k, passengerQueue(k), passengerDemandExt, serviceCapacityExt);

    waitCurve = invertServiceVectorToWait( ...
        queueCandidates, servicePotential, dtHour);

    plot(queueCandidates, waitCurve * 60, 'LineWidth', 1.5, ...
        'DisplayName', sprintf('%02d:00', plotHours(i)));

    if criticalQueue(k) >= 0 && isfinite(criticalWaitHour(k))
        plot(criticalQueue(k), criticalWaitHour(k) * 60, 'o', ...
            'HandleVisibility', 'off');
    end
end
xlabel('司机前方排队车辆数/辆');
ylabel('预计等待时间/分钟');
title('不同时段排队车辆数与预计等待时间的关系');
legend('Location', 'best');
grid on;
saveas(gcf, fullfile(outputFolder, 'figure3_waiting_time_curves.png'));

%% 13. 绘制图 4：重点时刻两种方案收益比较
servicePotentialSelected = buildServicePotential( ...
    selectedIndex, passengerQueue(selectedIndex), ...
    passengerDemandExt, serviceCapacityExt);

waitCurveSelected = invertServiceVectorToWait( ...
    queueCandidates, servicePotentialSelected, dtHour);

airportRateCurve = airportNetProfit ./ ...
    (waitCurveSelected + econ.loadingTime + econ.airportTravelTime);
airportRateCurve(~isfinite(waitCurveSelected)) = 0;

figure('Name', 'Profit Rate Comparison', 'Color', 'w');
plot(queueCandidates, airportRateCurve, 'LineWidth', 1.7, ...
    'DisplayName', '机场排队方案');
hold on;
plot([queueCandidates(1), queueCandidates(end)], ...
    [cityNetRate(selectedIndex), cityNetRate(selectedIndex)], '--', ...
    'LineWidth', 1.5, 'DisplayName', '返回市区方案');

if criticalQueue(selectedIndex) >= 0 && ...
        criticalQueue(selectedIndex) <= maxPlotQueue
    currentYLim = ylim;
    plot([criticalQueue(selectedIndex), criticalQueue(selectedIndex)], ...
        currentYLim, '--', 'LineWidth', 1.3, ...
        'DisplayName', '临界排队车辆数');
    ylim(currentYLim);
end

xlabel('司机前方排队车辆数/辆');
ylabel('单位时间预期净收益/(元/小时)');
title(sprintf('%02d:%02d 两种方案单位时间净收益比较', ...
    selectedHour, selectedMinute));
legend('Location', 'best');
grid on;
saveas(gcf, fullfile(outputFolder, 'figure4_profit_rate_comparison.png'));

fprintf('结果文件和图像已保存到文件夹：%s\n', outputFolder);

%% ======================== 局部函数 ========================

function [flightData, newTaxiDay, serviceCapacityDay] = ...
    createDemoData(timeMin, dtMin)
% createDemoData 生成一套可以直接运行的演示数据。
% 演示数据仅用于检验程序流程，正式论文应替换为真实机场数据。

    K = numel(timeMin);
    timeHour = timeMin / 60;

    % 构造 72 架到达航班，覆盖全天并带有小幅时刻波动
    nFlights = 72;
    flightIndex = (1:nFlights)';
    arrivalMinute = round( ...
        linspace(20, 1420, nFlights)' ...
        + 8 * sin(1.7 * flightIndex));

    seats = 160 + 20 * mod(flightIndex, 6);
    loadFactor = 0.78 + 0.03 * mod(flightIndex, 5);
    arrivalShare = 0.92 * ones(nFlights, 1);

    taxiShare = 0.18 * ones(nFlights, 1);
    taxiShare(arrivalMinute < 360 | arrivalMinute >= 1260) = 0.26;
    taxiShare(arrivalMinute >= 1080 & arrivalMinute < 1260) = 0.21;

    groupSize = 1.8 * ones(nFlights, 1);

    flightData = table( ...
        arrivalMinute, seats, loadFactor, arrivalShare, taxiShare, groupSize, ...
        'VariableNames', { ...
        'ArrivalMinute', 'Seats', 'LoadFactor', ...
        'ArrivalShare', 'TaxiShare', 'GroupSize'});

    % 构造每个 10 分钟时段新进入蓄车池的出租车数量
    newTaxiDay = 8 ...
        + 3 * (timeHour >= 6 & timeHour < 10) ...
        + 3 * (timeHour >= 16 & timeHour < 22) ...
        + round(1.2 * (1 + sin(2 * pi * (timeHour - 3) / 24)));
    newTaxiDay = max(newTaxiDay, 0);

    % 构造乘车区服务能力
    % 上车点数随时段变化，平均上车时间为 2.2 分钟，效率系数为 0.85。
    stationCount = 3 ...
        + 2 * (timeHour >= 6 & timeHour < 23) ...
        + 1 * (timeHour >= 17 & timeHour < 21);

    averageServiceMin = 2.2;
    efficiency = 0.85;
    serviceCapacityDay = ...
        efficiency .* stationCount .* dtMin ./ averageServiceMin;

    % 保证列向量
    newTaxiDay = reshape(newTaxiDay, K, 1);
    serviceCapacityDay = reshape(serviceCapacityDay, K, 1);
end

function checkRequiredColumns(dataTable, requiredColumns, fileName)
% checkRequiredColumns 检查 Excel 表格是否包含必需字段。
    missingColumns = setdiff(requiredColumns, dataTable.Properties.VariableNames);
    if ~isempty(missingColumns)
        error('%s 缺少字段：%s', fileName, strjoin(missingColumns, ', '));
    end
end

function passengerDemand = buildPassengerDemand( ...
    flightData, timeMin, dtMin, releaseMeanMin, releaseStdMin, oneDayMin)
% buildPassengerDemand 根据航班信息和乘客释放时间分布，
% 计算每个时间段内新增的出租车需求组数。

    requiredColumns = { ...
        'ArrivalMinute', 'Seats', 'LoadFactor', ...
        'ArrivalShare', 'TaxiShare', 'GroupSize'};
    checkRequiredColumns(flightData, requiredColumns, 'flightData');

    if any(flightData.GroupSize <= 0)
        error('GroupSize 必须大于 0。');
    end

    if any(flightData.LoadFactor < 0 | flightData.LoadFactor > 1) || ...
       any(flightData.ArrivalShare < 0 | flightData.ArrivalShare > 1) || ...
       any(flightData.TaxiShare < 0 | flightData.TaxiShare > 1)
        error('LoadFactor、ArrivalShare、TaxiShare 必须位于 [0,1]。');
    end

    K = numel(timeMin);
    passengerDemand = zeros(K, 1);

    taxiDemandPerFlight = ...
        flightData.Seats ...
        .* flightData.LoadFactor ...
        .* flightData.ArrivalShare ...
        .* flightData.TaxiShare ...
        ./ flightData.GroupSize;

    % 将前一天、当天和后一天的同类航班同时纳入，
    % 以处理午夜附近的乘客释放跨日问题。
    dayShift = [-oneDayMin, 0, oneDayMin];

    for i = 1:height(flightData)
        for shift = dayShift
            arrival = flightData.ArrivalMinute(i) + shift;

            lowerDelay = timeMin - arrival;
            upperDelay = timeMin + dtMin - arrival;

            lowerCDF = normalCDF( ...
                (lowerDelay - releaseMeanMin) / releaseStdMin);
            upperCDF = normalCDF( ...
                (upperDelay - releaseMeanMin) / releaseStdMin);

            releaseProbability = upperCDF - lowerCDF;
            passengerDemand = passengerDemand ...
                + taxiDemandPerFlight(i) .* releaseProbability;
        end
    end

    passengerDemand = max(passengerDemand, 0);
end

function value = normalCDF(z)
% normalCDF 标准正态分布函数，不依赖 Statistics Toolbox。
    value = 0.5 .* (1 + erf(z ./ sqrt(2)));
end

function [taxiQueue, passengerQueue, matchedTaxis] = ...
    simulateDoubleQueue(passengerDemand, newTaxis, serviceCapacity, ...
    initialTaxiQueue, initialPassengerQueue)
% simulateDoubleQueue 递推模拟出租车队列和乘客队列。

    K = numel(passengerDemand);
    taxiQueue = zeros(K + 1, 1);
    passengerQueue = zeros(K + 1, 1);
    matchedTaxis = zeros(K, 1);

    taxiQueue(1) = max(0, initialTaxiQueue);
    passengerQueue(1) = max(0, initialPassengerQueue);

    for k = 1:K
        availableTaxis = taxiQueue(k) + newTaxis(k);
        availablePassengers = passengerQueue(k) + passengerDemand(k);

        matchedTaxis(k) = min([ ...
            availableTaxis, availablePassengers, serviceCapacity(k)]);

        taxiQueue(k + 1) = ...
            availableTaxis - matchedTaxis(k);
        passengerQueue(k + 1) = ...
            availablePassengers - matchedTaxis(k);

        taxiQueue(k + 1) = max(0, taxiQueue(k + 1));
        passengerQueue(k + 1) = max(0, passengerQueue(k + 1));
    end
end

function servicePotential = buildServicePotential( ...
    startIndex, initialPassengerQueue, passengerDemandExt, serviceCapacityExt)
% buildServicePotential 计算目标司机进入队列后，未来各时段可供
% "当前队列中的车辆"使用的服务量。
%
% 未来新进入蓄车池的出租车均排在目标司机后方，因此不会影响
% 目标司机的服务顺序。只需要考察乘客到达量和乘车区服务能力。

    nSlots = numel(passengerDemandExt) - startIndex + 1;
    servicePotential = zeros(nSlots, 1);
    passengerQueue = max(0, initialPassengerQueue);

    for localIndex = 1:nSlots
        globalIndex = startIndex + localIndex - 1;

        availablePassengers = ...
            passengerQueue + passengerDemandExt(globalIndex);

        servicePotential(localIndex) = min( ...
            availablePassengers, serviceCapacityExt(globalIndex));

        passengerQueue = ...
            availablePassengers - servicePotential(localIndex);
        passengerQueue = max(0, passengerQueue);
    end
end

function waitHour = invertServiceToWait(nAhead, servicePotential, dtHour)
% invertServiceToWait 根据未来累计服务量，反求前方有 nAhead 辆车时
% 目标司机的等待时间。

    targetPosition = nAhead + 1;
    cumulativeService = cumsum(servicePotential);
    serviceSlot = find(cumulativeService >= targetPosition, 1, 'first');

    if isempty(serviceSlot)
        waitHour = Inf;
        return;
    end

    if serviceSlot == 1
        serviceBefore = 0;
    else
        serviceBefore = cumulativeService(serviceSlot - 1);
    end

    serviceInSlot = servicePotential(serviceSlot);
    if serviceInSlot <= 0
        waitHour = Inf;
        return;
    end

    fractionOfSlot = ...
        (targetPosition - serviceBefore) / serviceInSlot;

    waitHour = ...
        ((serviceSlot - 1) + fractionOfSlot) * dtHour;
end

function waitHours = invertServiceVectorToWait( ...
    nAheadVector, servicePotential, dtHour)
% invertServiceVectorToWait 对多个排队车辆数同时计算等待时间。

    waitHours = nan(size(nAheadVector));
    cumulativeService = cumsum(servicePotential);

    for i = 1:numel(nAheadVector)
        targetPosition = nAheadVector(i) + 1;
        serviceSlot = find( ...
            cumulativeService >= targetPosition, 1, 'first');

        if isempty(serviceSlot)
            waitHours(i) = Inf;
            continue;
        end

        if serviceSlot == 1
            serviceBefore = 0;
        else
            serviceBefore = cumulativeService(serviceSlot - 1);
        end

        serviceInSlot = servicePotential(serviceSlot);
        if serviceInSlot <= 0
            waitHours(i) = Inf;
        else
            fractionOfSlot = ...
                (targetPosition - serviceBefore) / serviceInSlot;
            waitHours(i) = ...
                ((serviceSlot - 1) + fractionOfSlot) * dtHour;
        end
    end
end

function totalService = serviceCompletedByTime( ...
    servicePotential, thresholdHour, dtHour)
% serviceCompletedByTime 计算从目标司机进入队列开始，到 thresholdHour
% 时刻累计能够完成的服务量。假定每个离散时段内服务均匀发生。

    if thresholdHour <= 0
        totalService = 0;
        return;
    end

    nSlots = numel(servicePotential);
    fullSlots = floor(thresholdHour / dtHour);
    fullSlots = min(fullSlots, nSlots);

    totalService = sum(servicePotential(1:fullSlots));

    remainingHour = thresholdHour - fullSlots * dtHour;
    if fullSlots < nSlots && remainingHour > 0
        totalService = totalService ...
            + servicePotential(fullSlots + 1) ...
            * remainingHour / dtHour;
    end
end
