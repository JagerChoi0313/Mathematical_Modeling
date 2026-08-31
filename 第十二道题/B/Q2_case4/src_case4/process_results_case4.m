function result = process_results_case4(dpResult, data)
%PROCESS_RESULTS_CASE4 枚举不超过K个沙暴日的情景并复核保证型策略

T = data.deadline;
K = data.maxStormDays;

nScenario = 0;
for r = 0:K
    nScenario = nScenario + nchoosek(T, r);
end

scenarioID = zeros(nScenario, 1);
stormCount = zeros(nScenario, 1);
stormDaysText = strings(nScenario, 1);
arrivalDay = nan(nScenario, 1);
mineDays = zeros(nScenario, 1);
villagePurchasePairs = zeros(nScenario, 1);
finalPairs = nan(nScenario, 1);
cashAtArrival = nan(nScenario, 1);
refundValue = nan(nScenario, 1);
finalWealth = -Inf(nScenario, 1);
feasible = false(nScenario, 1);
cashFeasible = false(nScenario, 1);

scenarioNo = 0;

for r = 0:K

    if r == 0
        combinations = zeros(1, 0);
    else
        combinations = nchoosek(1:T, r);
    end

    for row = 1:size(combinations, 1)

        scenarioNo = scenarioNo + 1;

        if r == 0
            stormDays = [];
        else
            stormDays = combinations(row, :);
        end

        sim = simulate_case4_scenario( ...
            stormDays, dpResult, data, false);

        scenarioID(scenarioNo) = scenarioNo;
        stormCount(scenarioNo) = r;

        if isempty(stormDays)
            stormDaysText(scenarioNo) = "无";
        else
            stormDaysText(scenarioNo) = strjoin(string(stormDays), ',');
        end

        arrivalDay(scenarioNo) = sim.arrivalDay;
        mineDays(scenarioNo) = sim.mineDays;
        villagePurchasePairs(scenarioNo) = sim.villagePurchasePairs;
        finalPairs(scenarioNo) = sim.finalPairs;
        cashAtArrival(scenarioNo) = sim.cashAtArrival;
        refundValue(scenarioNo) = sim.refundValue;
        finalWealth(scenarioNo) = sim.finalWealth;
        feasible(scenarioNo) = sim.feasible;
        cashFeasible(scenarioNo) = sim.cashFeasible;
    end
end

scenarioTable = table( ...
    scenarioID, ...
    stormCount, ...
    stormDaysText, ...
    arrivalDay, ...
    mineDays, ...
    villagePurchasePairs, ...
    finalPairs, ...
    cashAtArrival, ...
    refundValue, ...
    finalWealth, ...
    feasible, ...
    cashFeasible, ...
    'VariableNames', ...
    { ...
    'ScenarioID', ...
    'StormCount', ...
    'StormDays', ...
    'ArrivalDay', ...
    'MineDays', ...
    'VillagePurchasePairs', ...
    'FinalPairs', ...
    'CashAtArrival', ...
    'RefundValue', ...
    'FinalWealth', ...
    'Feasible', ...
    'CashFeasible'});

[worstFinalWealth, worstIndex] = min(finalWealth);
[bestFinalWealth, bestIndex] = max(finalWealth);

worstStormDays = parse_storm_days_case4(stormDaysText(worstIndex));
bestStormDays = parse_storm_days_case4(stormDaysText(bestIndex));

worstSim = simulate_case4_scenario( ...
    worstStormDays, dpResult, data, true);

bestSim = simulate_case4_scenario( ...
    bestStormDays, dpResult, data, true);

initialLoad = data.pairWeight * dpResult.bestInitialPairs;

allFeasible = all(feasible);
allCashFeasible = all(cashFeasible);
consistencyGap = worstFinalWealth - dpResult.guaranteedWealth;

summary = table( ...
    data.caseID, ...
    data.maxStormDays, ...
    dpResult.bestInitialWater, ...
    dpResult.bestInitialFood, ...
    initialLoad, ...
    dpResult.bestInitialCash, ...
    dpResult.guaranteedWealth, ...
    worstFinalWealth, ...
    bestFinalWealth, ...
    allFeasible, ...
    allCashFeasible, ...
    consistencyGap, ...
    dpResult.runtime, ...
    'VariableNames', ...
    { ...
    'CaseID', ...
    'MaxStormDays', ...
    'InitialWater', ...
    'InitialFood', ...
    'InitialLoad', ...
    'InitialCash', ...
    'GuaranteedWealth', ...
    'WorstScenarioWealth', ...
    'BestScenarioWealth', ...
    'AllScenariosFeasible', ...
    'AllCashFeasible', ...
    'ConsistencyGap', ...
    'RuntimeSeconds'});

result.summary = summary;
result.scenarioTable = scenarioTable;
result.worstDaily = worstSim.dailyTable;
result.bestDaily = bestSim.dailyTable;
result.worstFinalWealth = worstFinalWealth;
result.bestFinalWealth = bestFinalWealth;
result.worstStormDaysText = stormDaysText(worstIndex);
result.bestStormDaysText = stormDaysText(bestIndex);
result.worstCount = sum(abs(finalWealth - worstFinalWealth) < 1e-9);
result.bestCount = sum(abs(finalWealth - bestFinalWealth) < 1e-9);

if ~allCashFeasible
    warning(['存在现金为负的情景。当前DP在求值时放松了现金约束，' ...
        '因此若出现该警告，不能把结果作为最终答案。']);
end

end


function sim = simulate_case4_scenario(stormDays, dpResult, data, keepLog)

region = data.startRegion;
pairs = dpResult.bestInitialPairs;
cash = dpResult.bestInitialCash;
stormUsed = 0;

mineDays = 0;
villagePurchasePairs = 0;
arrivalDay = NaN;
feasible = true;
cashFeasible = true;

if keepLog
    dailyRows = cell(0, 16);
    dailyRows(end+1, :) = { ...
        0, "", region, "初始购买", region, ...
        0, 0, false, 0, ...
        pairs, pairs, cash, ...
        data.pairWeight * pairs, ...
        stormUsed, pairs, cash};
end

for day = 1:data.deadline

    if region == data.endRegion
        break;
    end

    isStorm = ismember(day, stormDays);

    if isStorm
        weatherID = data.robustStormID;
        weatherName = "沙暴";
    else
        weatherID = data.robustHighID;
        weatherName = "高温";
    end

    code = dpResult.policyAction( ...
        day, weatherID, region, pairs+1, stormUsed+1);

    refillTarget = double(dpResult.policyRefill( ...
        day, weatherID, region, pairs+1, stormUsed+1));

    step = apply_case4_action( ...
        region, pairs, cash, stormUsed, ...
        weatherID, code, refillTarget, data);

    if ~step.feasible
        feasible = false;
        break;
    end

    if ~step.cashFeasible
        cashFeasible = false;
    end

    if step.mineFlag
        mineDays = mineDays + 1;
    end

    villagePurchasePairs = villagePurchasePairs + step.purchasePairs;

    if keepLog
        dailyRows(end+1, :) = { ...
            day, weatherName, region, step.action, step.nextRegion, ...
            step.pairUse, step.purchasePairs, step.mineFlag, step.reward, ...
            step.nextPairs, step.nextPairs, step.nextCash, ...
            data.pairWeight * step.nextPairs, ...
            step.nextStormUsed, pairs, cash}; %#ok<AGROW>
    end

    region = step.nextRegion;
    pairs = step.nextPairs;
    cash = step.nextCash;
    stormUsed = step.nextStormUsed;

    if region == data.endRegion
        arrivalDay = day;
        break;
    end
end

if region == data.endRegion && feasible
    refundValue = data.refundPairPrice * pairs;
    finalWealth = cash + refundValue;
else
    refundValue = NaN;
    finalWealth = -Inf;
    feasible = false;
end

sim.arrivalDay = arrivalDay;
sim.mineDays = mineDays;
sim.villagePurchasePairs = villagePurchasePairs;
sim.finalPairs = pairs;
sim.cashAtArrival = cash;
sim.refundValue = refundValue;
sim.finalWealth = finalWealth;
sim.feasible = feasible;
sim.cashFeasible = cashFeasible;

if keepLog
    sim.dailyTable = cell2table( ...
        dailyRows, ...
        'VariableNames', ...
        { ...
        'Day', ...
        'Weather', ...
        'StartRegion', ...
        'Action', ...
        'EndRegion', ...
        'ResourcePairsUsed', ...
        'PurchasePairs', ...
        'Mine', ...
        'Income', ...
        'WaterLeft', ...
        'FoodLeft', ...
        'CashLeft', ...
        'LoadLeft', ...
        'StormDaysUsed', ...
        'PairsBefore', ...
        'CashBefore'});
else
    sim.dailyTable = table();
end

end


function step = apply_case4_action( ...
    region, pairs, cash, stormUsed, ...
    weatherID, code, refillTarget, data)

step.feasible = true;
step.cashFeasible = true;
step.mineFlag = false;
step.action = "";
step.nextRegion = region;
step.nextPairs = pairs;
step.nextCash = cash;
step.nextStormUsed = stormUsed + (weatherID == data.robustStormID);
step.pairUse = 0;
step.purchasePairs = 0;
step.reward = 0;

if code == 0
    step.feasible = false;
    step.action = "不可行";
    return;
elseif code == 1
    step.action = "停留";
    nextRegion = region;
    pairUse = data.pairUse(weatherID, 1);
    reward = 0;
elseif code == 2
    step.action = "挖矿";
    nextRegion = region;
    pairUse = data.pairUse(weatherID, 3);
    reward = data.mineIncome;
    step.mineFlag = true;
else
    step.action = "行走";
    nextRegion = double(code) - 2;
    pairUse = data.pairUse(weatherID, 2);
    reward = 0;
end

pairsRemain = pairs - pairUse;

if pairsRemain < 0
    step.feasible = false;
    return;
end

cashNext = cash + reward;
purchasePairs = 0;

if nextRegion == data.villageRegions
    purchasePairs = max(0, refillTarget - pairsRemain);
    cashNext = cashNext - data.villagePairPrice * purchasePairs;
    pairsNext = pairsRemain + purchasePairs;
else
    pairsNext = pairsRemain;
end

if pairsNext > data.maxPairs
    step.feasible = false;
    return;
end

if cashNext < 0
    step.cashFeasible = false;
end

% 未到终点而资源对耗尽，意味着水和食物均为0，按题意判定失败。
if nextRegion ~= data.endRegion && pairsNext == 0
    step.feasible = false;
    return;
end

step.nextRegion = nextRegion;
step.nextPairs = pairsNext;
step.nextCash = cashNext;
step.pairUse = pairUse;
step.purchasePairs = purchasePairs;
step.reward = reward;

end


function stormDays = parse_storm_days_case4(textValue)

if textValue == "无"
    stormDays = [];
else
    parts = split(textValue, ',');
    stormDays = str2double(parts)';
end

end
