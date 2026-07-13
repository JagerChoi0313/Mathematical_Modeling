%% question2_baiyun_auto.m
% 第二问：广州白云机场出租车司机选择方案
%
% 本程序已经将《广州白云机场航班及出租车数据
% 2025年官方公开资料核验补充版》中的可核验数据直接写入程序，
% 运行时不需要手动输入任何参数。
%
% 说明：
% 1. 第二问不重新建立模型，直接应用第一问的收益阈值判据；
% 2. 由于官方资料未公开单位里程成本、市区寻客时间和机场排队日志，
%    本程序严格使用现有官方数据，计算"毛收益基准下的临界等待时间"；
% 3. 计算结果用于给出等待时间选择规则，不冒充净利润唯一结果。

clear;
clc;
close all;

%% 1. 录入文档中的2025年官方数据

% 白云机场全年运行数据
annualFlights = 550512;          % 全年起降架次
annualPassengers = 83587749;     % 全年旅客吞吐量

% 2025年各月起降架次
monthlyFlights = [ ...
    47807, 40096, 44165, 44371, 45583, 43787, ...
    48413, 48164, 43346, 48702, 46773, 49305];

% 2025年各月旅客吞吐量
monthlyPassengers = [ ...
    7139317, 6314694, 6603614, 6663566, 6863652, 6449890, ...
    7123014, 7338365, 6601024, 7642215, 7322805, 7524448];

% 广州市巡游出租车行业运营数据
cityDailyRevenue = [607.40, 574.99];    % 上、下半年单车日均营收，元
cityDailyTrips = [21.25, 20.87];        % 上、下半年单车日均载客次数
cityDailyDistance = [289.84, 280.11];   % 上、下半年单车日均行驶里程，km

periodName = {'2025年上半年'; '2025年下半年'};

% 将单车日均营收折算为自然日平均毛营收率
% 该值仅用于构造返回市区方案的官方数据基准
cityRevenueRate = cityDailyRevenue / 10;    % 元/小时

% 平均每载客次营收和平均每公里营收
cityRevenuePerTrip = cityDailyRevenue ./ cityDailyTrips;
cityRevenuePerKm = cityDailyRevenue ./ cityDailyDistance;

%% 2. 典型机场订单情景

% 情景1：白云机场T2至广州南站
% 官方推荐路线约59.3 km，正常打表约215元；
% 同时间段可比出租车行驶84 min。
routeName = {'广州南站情景'; '广州东站情景'};
routeFare = [215; 143];             % 元
routeTimeMin = [84; 38];            % min
routeDistance = [59.3; NaN];        % km，东站完整距离未公开

routeTimeHour = routeTimeMin / 60;

%% 3. 应用第一问临界等待时间公式

% 在仅使用现有官方数据的毛收益基准下：
%
% 机场方案单位时间毛收益：
% r_A = F_A / (T_w + T_A)
%
% 返回市区方案自然日平均毛营收率：
% r_B = 日均营收 / 24
%
% 两种方案收益相等时：
% T_w* = F_A / r_B - T_A

nRoute = length(routeFare);
nPeriod = length(cityRevenueRate);

criticalWaitMin = zeros(nRoute, nPeriod);

for i = 1:nRoute
    for j = 1:nPeriod
        criticalWaitHour = ...
            routeFare(i) / cityRevenueRate(j) - routeTimeHour(i);

        criticalWaitMin(i, j) = max(criticalWaitHour * 60, 0);
    end
end

%% 4. 输出机场基本运行指标

averagePassengersPerMovement = annualPassengers / annualFlights;

fprintf('\n====================================================\n');
fprintf('第二问：广州白云机场出租车司机选择方案\n');
fprintf('====================================================\n');
fprintf('2025年全年起降架次：%d 架次\n', annualFlights);
fprintf('2025年全年旅客吞吐量：%d 人次\n', annualPassengers);
fprintf('平均每起降架次旅客量：%.2f 人次/架次\n', ...
    averagePassengersPerMovement);

fprintf('\n广州市巡游出租车运营基准：\n');

for j = 1:nPeriod
    fprintf('%s：\n', periodName{j});
    fprintf('  单车日均营收：%.2f 元\n', cityDailyRevenue(j));
    fprintf('  平均每载客次营收：%.2f 元/次\n', ...
        cityRevenuePerTrip(j));
    fprintf('  平均每公里营收：%.2f 元/km\n', ...
        cityRevenuePerKm(j));
    fprintf('  自然日平均毛营收率：%.2f 元/h\n', ...
        cityRevenueRate(j));
end

%% 5. 输出临界等待时间和司机选择方案

fprintf('\n临界等待时间计算结果：\n');

for i = 1:nRoute
    fprintf('\n%s：车费%.2f元，行驶时间%.0f分钟\n', ...
        routeName{i}, routeFare(i), routeTimeMin(i));

    for j = 1:nPeriod
        fprintf('  %s临界等待时间：%.2f分钟\n', ...
            periodName{j}, criticalWaitMin(i, j));
    end

    lowerBound = min(criticalWaitMin(i, :));
    upperBound = max(criticalWaitMin(i, :));

    fprintf('  司机选择规则：\n');
    fprintf('  当预计等待时间不超过%.2f分钟时，进入蓄车池排队；\n', ...
        lowerBound);
    fprintf('  当预计等待时间超过%.2f分钟时，返回市区运营；\n', ...
        upperBound);
    fprintf('  当预计等待时间位于%.2f至%.2f分钟之间时，\n', ...
        lowerBound, upperBound);
    fprintf('  应结合上、下半年市区运营水平进一步判断。\n');
end

fprintf('\n说明：以上结果是严格基于现有官方数据得到的毛收益基准阈值。\n');
fprintf('由于公开资料未提供单位里程成本、市区寻客时间及机场排队日志，\n');
fprintf('本程序不虚构这些参数，也不将结果表述为唯一净利润阈值。\n');
fprintf('====================================================\n');

%% 6. 整理结果表

scenario = cell(nRoute * nPeriod, 1);
period = cell(nRoute * nPeriod, 1);
fare = zeros(nRoute * nPeriod, 1);
travelTime = zeros(nRoute * nPeriod, 1);
cityDailyRev = zeros(nRoute * nPeriod, 1);
cityHourlyRate = zeros(nRoute * nPeriod, 1);
criticalWait = zeros(nRoute * nPeriod, 1);

row = 0;

for i = 1:nRoute
    for j = 1:nPeriod
        row = row + 1;
        scenario{row} = routeName{i};
        period{row} = periodName{j};
        fare(row) = routeFare(i);
        travelTime(row) = routeTimeMin(i);
        cityDailyRev(row) = cityDailyRevenue(j);
        cityHourlyRate(row) = cityRevenueRate(j);
        criticalWait(row) = criticalWaitMin(i, j);
    end
end

resultTable = table( ...
    scenario, period, fare, travelTime, ...
    cityDailyRev, cityHourlyRate, criticalWait, ...
    'VariableNames', { ...
    'AirportOrderScenario', ...
    'Period', ...
    'AirportFareYuan', ...
    'AirportTravelTimeMin', ...
    'CityDailyRevenueYuan', ...
    'CityRevenueRateYuanPerHour', ...
    'CriticalWaitTimeMin'});

disp(resultTable);

%% 7. 图1：不同等待时间下两类机场订单的毛收益率

waitMin = 0:5:600;
waitHour = waitMin / 60;

airportRateSouth = routeFare(1) ./ ...
    (waitHour + routeTimeHour(1));

airportRateEast = routeFare(2) ./ ...
    (waitHour + routeTimeHour(2));

figure('Color', 'w');
plot(waitMin, airportRateSouth, 'LineWidth', 1.8);
hold on;
plot(waitMin, airportRateEast, 'LineWidth', 1.8);
yline(cityRevenueRate(1), '--', '上半年市区毛营收率', ...
    'LineWidth', 1.2);
yline(cityRevenueRate(2), '--', '下半年市区毛营收率', ...
    'LineWidth', 1.2);

xlabel('机场预计等待时间/min');
ylabel('单位时间毛收益/(元·h^{-1})');
title('机场等待时间与两种方案毛收益率比较');
legend('广州南站订单', '广州东站订单', ...
    'Location', 'northeast');
grid on;

saveas(gcf, 'question2_figure1_profit_rate.png');

%% 8. 图2：市区日均营收对临界等待时间的影响

cityRevenueRange = linspace( ...
    min(cityDailyRevenue), max(cityDailyRevenue), 100);

cityRateRange = cityRevenueRange / 24;

criticalSouth = ...
    (routeFare(1) ./ cityRateRange - routeTimeHour(1)) * 60;

criticalEast = ...
    (routeFare(2) ./ cityRateRange - routeTimeHour(2)) * 60;

figure('Color', 'w');
plot(cityRevenueRange, criticalSouth, 'LineWidth', 1.8);
hold on;
plot(cityRevenueRange, criticalEast, 'LineWidth', 1.8);

xlabel('市区单车日均营收/元');
ylabel('临界等待时间/min');
title('市区运营水平对临界等待时间的影响');
legend('广州南站订单', '广州东站订单', ...
    'Location', 'best');
grid on;

saveas(gcf, 'question2_figure2_sensitivity.png');

%% 9. 图3：不同情景临界等待时间比较

figure('Color', 'w');
bar(criticalWaitMin);

set(gca, 'XTickLabel', routeName);
ylabel('临界等待时间/min');
title('不同机场订单情景的临界等待时间');
legend(periodName, 'Location', 'best');
grid on;

saveas(gcf, 'question2_figure3_critical_wait.png');

%% 10. 保存Excel结果

writetable(resultTable, 'question2_baiyun_results.xlsx', ...
    'Sheet', '临界等待时间');

monthlyTable = table( ...
    (1:12)', monthlyFlights', monthlyPassengers', ...
    monthlyPassengers' ./ monthlyFlights', ...
    'VariableNames', { ...
    'Month', ...
    'FlightMovements', ...
    'PassengerThroughput', ...
    'PassengersPerMovement'});

writetable(monthlyTable, 'question2_baiyun_results.xlsx', ...
    'Sheet', '机场月度数据');

cityTable = table( ...
    periodName, cityDailyRevenue', cityDailyTrips', ...
    cityDailyDistance', cityRevenuePerTrip', ...
    cityRevenuePerKm', cityRevenueRate', ...
    'VariableNames', { ...
    'Period', ...
    'DailyRevenueYuan', ...
    'DailyTrips', ...
    'DailyDistanceKm', ...
    'RevenuePerTripYuan', ...
    'RevenuePerKmYuan', ...
    'RevenueRateYuanPerHour'});

writetable(cityTable, 'question2_baiyun_results.xlsx', ...
    'Sheet', '出租车运营数据');

fprintf('\n程序运行完成，已生成：\n');
fprintf('1. question2_baiyun_results.xlsx\n');
fprintf('2. question2_figure1_profit_rate.png\n');
fprintf('3. question2_figure2_sensitivity.png\n');
fprintf('4. question2_figure3_critical_wait.png\n');
