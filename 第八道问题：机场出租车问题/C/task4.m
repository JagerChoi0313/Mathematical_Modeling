function question4_short_trip_priority()
%% 问题四：短途出租车优先返回与收益均衡模型
% -------------------------------------------------------------------------
% 模型目的：
%   只允许完成短途订单、并在规定时间 T 内返回机场的出租车进入优先通道，
%   在不超过第三问乘车区服务能力的条件下，使短途与长途订单的单位时间
%   毛收益尽量接近。
%
% 与前三问的衔接：
%   1. 沿用第一问的"单位时间收益"比较思想；
%   2. 沿用第二问广州东站型、广州南站型订单的车费和行驶时间；
%   3. 沿用第三问得到的乘车区服务能力 88.57 辆/小时。
%
% 重要口径：
%   T 从出租车载客驶离机场时开始计时，到出租车再次返回机场时结束。
%   只有短途车辆可获得优先权；长途车辆仍按普通规则排队。
%
% 数据说明：
%   公开资料没有提供返场时间样本、实时排队时间和短途订单比例，因此
%   这些参数在第1节中被明确设置为"情景参数"。程序会自动进行敏感性
%   分析，不能把某一组情景结果表述为唯一实测结论。
%
% 运行方法：
%   将本文件置于当前工作目录，在MATLAB命令窗口输入：
%       question4_short_trip_priority
%
% 运行环境：MATLAB R2018b及以上；不需要额外工具箱。
% -------------------------------------------------------------------------

clc;
close all;

%% 1. 输入参数

% 1.1 第二问的典型订单数据（毛收益口径）
fareShort = 143;             % 短途情景车费，元（广州东站型）
outboundShortMin = 38;       % 短途载客去程时间，min
fareLong = 215;              % 长途情景车费，元（广州南站型）
outboundLongMin = 84;        % 长途载客去程时间，min

% 1.2 返场时间情景参数
% 无真实返场样本时，基准情景取返程均值等于同路线去程时间。
% 短途订单"离开机场至再次返回机场"的总时间在均值上下20%内均匀分布。
returnShortMeanMin = outboundShortMin;
returnLongMeanMin = outboundLongMin;
uncertaintyRatio = 0.20;

% 1.3 第一问的等待时间参数
% 180 min仅为高峰期基准情景；必须用实际时段的预计等待时间替换。
regularWaitMin = 180;

% 1.4 第三问乘车区能力及管理参数
serviceCapacity = 88.57;     % 第三问结果，辆/h
priorityCapacityRatio = 0.30;% 优先通道最多占总服务能力的30%（管理参数）

% 返回车辆流量与短途比例均为情景参数，不能使用第三问的60%乘客打车率代替。
totalReturnFlow = 100;       % 高峰期返回机场出租车流量，辆/h
shortTripRatio = 0.30;       % 返回车辆中的短途订单比例

% 1.5 规则实施参数
maxPolicyTimeMin = 180;      % 管理上允许的最大优先返场时限，min
roundingStepMin = 1;         % 实际规则按整分钟发布

%% 2. 构造返场时间分布和收益函数

% 一个收益周期包括：载客离开机场、空载返回机场、等待下一次载客。
shortCycleNoWaitHour = ...
    (outboundShortMin + returnShortMeanMin) / 60;
longCycleNoWaitHour = ...
    (outboundLongMin + returnLongMeanMin) / 60;

% 短途车辆完成一次"机场—目的地—机场"往返的总时间范围。
shortRoundMeanMin = outboundShortMin + returnShortMeanMin;
shortRoundLowMin = shortRoundMeanMin * (1 - uncertaintyRatio);
shortRoundHighMin = shortRoundMeanMin * (1 + uncertaintyRatio);

% Fshort(T)：短途车辆在T分钟内返回机场的概率。
Fshort = @(T) uniform_cdf(T, shortRoundLowMin, shortRoundHighMin);

waitHour = regularWaitMin / 60;

% 短途车辆：按时返回的比例Fshort(T)免去常规排队；其余车辆仍等待。
Rshort = @(T) fareShort ./ ...
    (shortCycleNoWaitHour + waitHour .* (1 - Fshort(T)));

% 长途车辆不进入优先通道，因此其单位时间毛收益不随T变化。
Rlong = fareLong / (longCycleNoWaitHour + waitHour);

% 无优先机制时的基准收益。
Rshort0 = Rshort(0);
Rlong0 = Rlong;
gap0 = abs(Rshort0 - Rlong0);

%% 3. 计算容量约束允许的最大阈值

shortReturnFlow = totalReturnFlow * shortTripRatio;
priorityFlowLimit = priorityCapacityRatio * serviceCapacity;

% 容量约束：短途返场流量 × 按时返回比例 <= 优先通道容量上限。
if shortReturnFlow * Fshort(maxPolicyTimeMin) <= priorityFlowLimit
    capacityLimitMin = maxPolicyTimeMin;
    capacityIsBinding = false;
else
    allowedProbability = priorityFlowLimit / shortReturnFlow;
    capacityLimitMin = shortRoundLowMin + allowedProbability * ...
        (shortRoundHighMin - shortRoundLowMin);
    capacityLimitMin = min(max(capacityLimitMin, 0), maxPolicyTimeMin);
    capacityIsBinding = true;
end

%% 4. 求解使两类司机收益差最小的优先阈值

gapFunction = @(T) abs(Rshort(T) - Rlong);

if Rshort0 >= Rlong0
    % 若短途基准收益已不低于长途，则没有设置短途优先权的必要。
    theoreticalTimeMin = 0;
elseif capacityLimitMin <= shortRoundLowMin
    % 若容量上界尚未进入返场时间分布的有效区间，放宽T不能改善收益差。
    theoreticalTimeMin = 0;
else
    % 均匀分布在shortRoundLowMin以前的CDF恒为0，目标函数存在平坦区间。
    % 因此必须从分布下界开始搜索，避免fminbnd停留在平坦区间。
    theoreticalTimeMin = fminbnd( ...
        gapFunction, shortRoundLowMin, capacityLimitMin, ...
        optimset('TolX', 1e-8, 'Display', 'off'));

    % 若容量约束过紧，搜索结果也可能不优于不实施机制，此时取T=0。
    if gapFunction(theoreticalTimeMin) >= gapFunction(0)
        theoreticalTimeMin = 0;
    end
end

% 将理论结果转化为可发布的整分钟规则，并在相邻整数中选择收益差较小者。
candidateTime = unique([ ...
    0; ...
    floor(theoreticalTimeMin / roundingStepMin) * roundingStepMin; ...
    round(theoreticalTimeMin / roundingStepMin) * roundingStepMin; ...
    ceil(theoreticalTimeMin / roundingStepMin) * roundingStepMin; ...
    floor(capacityLimitMin / roundingStepMin) * roundingStepMin]);

candidateTime = candidateTime( ...
    candidateTime >= 0 & candidateTime <= capacityLimitMin + 1e-9);

candidateGap = gapFunction(candidateTime);
[~, bestIndex] = min(candidateGap);
recommendedTimeMin = candidateTime(bestIndex);

RshortFinal = Rshort(recommendedTimeMin);
RlongFinal = Rlong;
gapFinal = abs(RshortFinal - RlongFinal);

if gap0 > 1e-12
    gapReductionPct = max(0, (gap0 - gapFinal) / gap0 * 100);
else
    gapReductionPct = 0;
end

eligibleProbability = Fshort(recommendedTimeMin);
priorityFlowFinal = shortReturnFlow * eligibleProbability;
priorityCapacityUsePct = priorityFlowFinal / priorityFlowLimit * 100;

%% 5. 等待时间不确定性的敏感性分析

waitScenarioMin = (120:30:360)';
nScenario = numel(waitScenarioMin);
recommendedScenarioMin = zeros(nScenario, 1);
eligibleScenarioPct = zeros(nScenario, 1);
gapBeforeScenario = zeros(nScenario, 1);
gapAfterScenario = zeros(nScenario, 1);

for i = 1:nScenario
    waitNowHour = waitScenarioMin(i) / 60;

    RshortNow = @(T) fareShort ./ ...
        (shortCycleNoWaitHour + waitNowHour .* (1 - Fshort(T)));
    RlongNow = fareLong / (longCycleNoWaitHour + waitNowHour);
    gapNow = @(T) abs(RshortNow(T) - RlongNow);

    gapBeforeScenario(i) = gapNow(0);

    if RshortNow(0) >= RlongNow
        timeNow = 0;
    elseif capacityLimitMin <= shortRoundLowMin
        timeNow = 0;
    else
        timeNow = fminbnd( ...
            gapNow, shortRoundLowMin, capacityLimitMin, ...
            optimset('TolX', 1e-8, 'Display', 'off'));

        if gapNow(timeNow) >= gapNow(0)
            timeNow = 0;
        end
    end

    candidateNow = unique([ ...
        0; ...
        floor(timeNow / roundingStepMin) * roundingStepMin; ...
        round(timeNow / roundingStepMin) * roundingStepMin; ...
        ceil(timeNow / roundingStepMin) * roundingStepMin; ...
        floor(capacityLimitMin / roundingStepMin) * roundingStepMin]);

    candidateNow = candidateNow( ...
        candidateNow >= 0 & candidateNow <= capacityLimitMin + 1e-9);

    gapCandidateNow = gapNow(candidateNow);
    [~, indexNow] = min(gapCandidateNow);

    recommendedScenarioMin(i) = candidateNow(indexNow);
    eligibleScenarioPct(i) = ...
        100 * Fshort(recommendedScenarioMin(i));
    gapAfterScenario(i) = ...
        gapNow(recommendedScenarioMin(i));
end

%% 6. 输出计算结果

fprintf('\n============================================================\n');
fprintf('问题四：短途出租车优先返回与收益均衡模型\n');
fprintf('============================================================\n');
fprintf('计时口径：出租车载客离开机场至再次返回机场。\n');
fprintf('短途往返时间情景：%.1f～%.1f min，均值%.1f min。\n', ...
    shortRoundLowMin, shortRoundHighMin, shortRoundMeanMin);
fprintf('常规排队等待时间（情景值）：%.0f min。\n', regularWaitMin);
fprintf('第三问乘车区服务能力：%.2f 辆/h。\n', serviceCapacity);
fprintf('优先通道容量上限：%.2f 辆/h。\n', priorityFlowLimit);

fprintf('\n无优先机制：\n');
fprintf('  短途单位时间毛收益：%.2f 元/h。\n', Rshort0);
fprintf('  长途单位时间毛收益：%.2f 元/h。\n', Rlong0);
fprintf('  收益差：%.2f 元/h。\n', gap0);

fprintf('\n优化结果：\n');
fprintf('  理论最优阈值：%.2f min。\n', theoreticalTimeMin);
fprintf('  建议发布规则：在 %d min 内返回机场的短途车可优先载客。\n', ...
    round(recommendedTimeMin));
fprintf('  获得优先权的短途车比例：%.2f%%。\n', ...
    eligibleProbability * 100);
fprintf('  优先车辆流量：%.2f 辆/h。\n', priorityFlowFinal);
fprintf('  优先通道容量利用率：%.2f%%。\n', priorityCapacityUsePct);
fprintf('  实施后短途单位时间毛收益：%.2f 元/h。\n', RshortFinal);
fprintf('  实施后长途单位时间毛收益：%.2f 元/h。\n', RlongFinal);
fprintf('  实施后收益差：%.2f 元/h。\n', gapFinal);
fprintf('  收益差缩小比例：%.2f%%。\n', gapReductionPct);

if capacityIsBinding
    fprintf('  容量约束给出的最大阈值：%.2f min。\n', ...
        capacityLimitMin);

    if recommendedTimeMin < capacityLimitMin - 1e-6
        fprintf('  当前最优阈值低于容量上界，最优点处容量约束不紧。\n');
    else
        fprintf('  当前最优阈值达到容量上界，最优点处容量约束起限制作用。\n');
    end
else
    fprintf('  在管理上限%d min内，容量约束不构成限制。\n', ...
        maxPolicyTimeMin);
end

fprintf('\n注意：返场时间、排队时间、返回流量和短途比例为情景参数。\n');
fprintf('若获得实测数据，只需替换第1节参数，不需要修改模型结构。\n');
fprintf('============================================================\n');

%% 7. 保存结果表

outputFolder = fullfile(pwd, 'question4_output');
if exist(outputFolder, 'dir') ~= 7
    mkdir(outputFolder);
end

resultTable = table( ...
    regularWaitMin, shortRoundLowMin, shortRoundHighMin, ...
    serviceCapacity, priorityFlowLimit, shortReturnFlow, ...
    theoreticalTimeMin, recommendedTimeMin, ...
    eligibleProbability * 100, priorityFlowFinal, ...
    Rshort0, Rlong0, gap0, RshortFinal, RlongFinal, gapFinal, ...
    gapReductionPct, ...
    'VariableNames', { ...
    'RegularWaitMin', 'ShortRoundTripLowMin', 'ShortRoundTripHighMin', ...
    'ServiceCapacityVehPerHour', 'PriorityCapacityVehPerHour', ...
    'ShortReturnFlowVehPerHour', 'TheoreticalThresholdMin', ...
    'RecommendedThresholdMin', 'EligibleShortTripPct', ...
    'PriorityFlowVehPerHour', 'ShortRateBefore', 'LongRateBefore', ...
    'GapBefore', 'ShortRateAfter', 'LongRateAfter', 'GapAfter', ...
    'GapReductionPct'});

sensitivityTable = table( ...
    waitScenarioMin, recommendedScenarioMin, eligibleScenarioPct, ...
    gapBeforeScenario, gapAfterScenario, ...
    'VariableNames', { ...
    'RegularWaitMin', 'RecommendedThresholdMin', ...
    'EligibleShortTripPct', 'GapBefore', 'GapAfter'});

writetable(resultTable, ...
    fullfile(outputFolder, 'question4_result_summary.csv'));
writetable(sensitivityTable, ...
    fullfile(outputFolder, 'question4_wait_sensitivity.csv'));

%% 8. 绘图

% 收益图只绘制容量约束允许的可行区间；容量图略扩展至分布上界之外。
TplotProfit = linspace(0, capacityLimitMin, 800);
TplotCapacityMax = min(maxPolicyTimeMin, ...
    max(shortRoundHighMin * 1.10, capacityLimitMin * 1.10));
TplotCapacity = linspace(0, TplotCapacityMax, 800);

% 图1：短途收益提高，长途收益保持不变。
fig1 = figure('Color', 'w', 'Name', '图1 收益均衡');
h1 = plot(TplotProfit, Rshort(TplotProfit), 'b-', 'LineWidth', 1.8);
hold on;
h2 = plot(TplotProfit, Rlong * ones(size(TplotProfit)), ...
    'r-', 'LineWidth', 1.8);
h3 = xline(recommendedTimeMin, 'k--', '建议阈值', 'LineWidth', 1.3);
xlabel('优先返场时限 T/min');
ylabel('单位时间毛收益/(元·h^{-1})');
title('短途优先时限对两类订单单位时间收益的影响');
legend([h1, h2, h3], ...
    {'短途车辆', '长途车辆（无优先权）', '建议阈值'}, ...
    'Location', 'best');
grid on;
hide_axes_toolbars(fig1);
saveas(fig1, fullfile(outputFolder, 'figure1_profit_balance.png'));

% 图2：返场资格比例与乘车区容量校验。
fig2 = figure('Color', 'w', 'Name', '图2 容量校验');

subplot(2, 1, 1);
plot(TplotCapacity, 100 * Fshort(TplotCapacity), ...
    'b-', 'LineWidth', 1.8);
hold on;
xline(recommendedTimeMin, 'k--', '建议阈值', 'LineWidth', 1.2);
ylabel('按时返回比例/%');
title('短途车辆获得优先权的比例');
grid on;

subplot(2, 1, 2);
priorityFlowPlot = shortReturnFlow * Fshort(TplotCapacity);
plot(TplotCapacity, priorityFlowPlot, 'b-', 'LineWidth', 1.8);
hold on;
yline(priorityFlowLimit, 'r--', '优先通道容量上限', 'LineWidth', 1.3);
xline(recommendedTimeMin, 'k--', '建议阈值', 'LineWidth', 1.2);
if capacityIsBinding
    xline(capacityLimitMin, 'm--', '容量边界', 'LineWidth', 1.2);
end
xlabel('优先返场时限 T/min');
ylabel('优先车辆流量/(辆·h^{-1})');
title('优先通道流量与容量约束');
grid on;
hide_axes_toolbars(fig2);
saveas(fig2, fullfile(outputFolder, 'figure2_capacity_check.png'));

% 图3：常规等待时间变化时，建议阈值及收益差的变化。
fig3 = figure('Color', 'w', 'Name', '图3 等待时间敏感性');

subplot(2, 1, 1);
plot(waitScenarioMin, recommendedScenarioMin, ...
    'bo-', 'LineWidth', 1.6, 'MarkerFaceColor', 'b');
xlabel('常规排队等待时间/min');
ylabel('建议优先时限/min');
title('常规等待时间对优先返场时限的影响');
grid on;

subplot(2, 1, 2);
plot(waitScenarioMin, gapBeforeScenario, ...
    'r-o', 'LineWidth', 1.5, 'MarkerFaceColor', 'r');
hold on;
plot(waitScenarioMin, gapAfterScenario, ...
    'b-s', 'LineWidth', 1.5, 'MarkerFaceColor', 'b');
xlabel('常规排队等待时间/min');
ylabel('两类订单收益差/(元·h^{-1})');
legend('实施前', '实施后', 'Location', 'best');
title('机制实施前后的收益差比较');
grid on;
hide_axes_toolbars(fig3);
saveas(fig3, fullfile(outputFolder, 'figure3_wait_sensitivity.png'));

% 图4：基准情景实施前后收益对比。
fig4 = figure('Color', 'w', 'Name', '图4 实施前后收益');
barData = [Rshort0, Rlong0; RshortFinal, RlongFinal];
bar(barData, 'grouped');
set(gca, 'XTickLabel', {'实施前', '实施后'});
ylabel('单位时间毛收益/(元·h^{-1})');
legend('短途车辆', '长途车辆', 'Location', 'best');
title('短途优先机制实施前后收益比较');
ylim([0, max(barData(:)) * 1.20]);
grid on;
hide_axes_toolbars(fig4);
saveas(fig4, fullfile(outputFolder, 'figure4_before_after.png'));

fprintf('\n结果表和图片已保存至：\n%s\n', outputFolder);

end

%% 本地函数：均匀分布累积分布函数
function probability = uniform_cdf(value, lowerBound, upperBound)
% value可为标量或向量；输出为P(X<=value)。
probability = (value - lowerBound) ./ (upperBound - lowerBound);
probability = min(max(probability, 0), 1);
end

%% 本地函数：隐藏坐标区工具栏，避免其出现在导出的论文图片中
function hide_axes_toolbars(figureHandle)
axesHandle = findall(figureHandle, 'Type', 'axes');

for i = 1:numel(axesHandle)
    if isprop(axesHandle(i), 'Toolbar')
        toolbarHandle = axesHandle(i).Toolbar;

        if ~isempty(toolbarHandle)
            toolbarHandle.Visible = 'off';
        end
    end
end

drawnow;
end
