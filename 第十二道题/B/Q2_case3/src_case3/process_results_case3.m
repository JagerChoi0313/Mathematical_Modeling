function result = process_results_case3(dpResult, data)
%PROCESS_RESULTS_CASE3 将动态规划策略整理为可读结果

T = data.deadline;
weatherChoices = data.allowedWeather;
nScenario = numel(weatherChoices)^T;

% 第三关只有晴朗、高温，两种天气序列共2^10=1024种
bits = dec2bin(0:(nScenario - 1), T) - '0';
weatherMatrix = bits + 1;

scenarioID = (1:nScenario)';
weatherSequence = strings(nScenario, 1);
arrivalDay = nan(nScenario, 1);
mineDays = zeros(nScenario, 1);
finalWater = nan(nScenario, 1);
finalFood = nan(nScenario, 1);
cashAtArrival = nan(nScenario, 1);
refundValue = nan(nScenario, 1);
finalWealth = -Inf(nScenario, 1);
feasible = false(nScenario, 1);

for s = 1:nScenario
    seq = weatherMatrix(s, :);
    sim = simulate_case3_sequence(seq, dpResult, data, false);

    weatherSequence(s) = strjoin(data.weatherNames(seq), "-");
    arrivalDay(s) = sim.arrivalDay;
    mineDays(s) = sim.mineDays;
    finalWater(s) = sim.finalWater;
    finalFood(s) = sim.finalFood;
    cashAtArrival(s) = sim.cashAtArrival;
    refundValue(s) = sim.refundValue;
    finalWealth(s) = sim.finalWealth;
    feasible(s) = sim.feasible;
end

scenarioTable = table(scenarioID, weatherSequence, arrivalDay, mineDays, ...
    finalWater, finalFood, cashAtArrival, refundValue, finalWealth, feasible, ...
    'VariableNames', {'ScenarioID','WeatherSequence','ArrivalDay','MineDays', ...
    'FinalWater','FinalFood','CashAtArrival','RefundValue','FinalWealth','Feasible'});

[worstFinalWealth, worstIndex] = min(finalWealth);
[bestFinalWealth, bestIndex] = max(finalWealth);

worstSeq = weatherMatrix(worstIndex, :);
bestSeq = weatherMatrix(bestIndex, :);
worstSim = simulate_case3_sequence(worstSeq, dpResult, data, true);
bestSim = simulate_case3_sequence(bestSeq, dpResult, data, true);

% 从最优初始状态出发，整理所有可达状态下的"天气-行动"策略
policyRows = cell(0, 11);
currentStates = [data.startRegion, dpResult.bestInitialWater, ...
    dpResult.bestInitialFood, dpResult.bestInitialCash];

for t = 1:T
    nextStates = zeros(0, 4);

    for r = 1:size(currentStates, 1)
        region = currentStates(r, 1);
        water = currentStates(r, 2);
        food = currentStates(r, 3);
        cash = currentStates(r, 4);

        if region == data.endRegion
            continue;
        end

        for weatherID = weatherChoices
            code = dpResult.policy{t, weatherID}(region, water + 1, food + 1);
            step = apply_case3_action(region, water, food, cash, ...
                weatherID, code, data);

            policyRows(end+1, :) = {t, data.weatherNames(weatherID), region, ...
                water, food, cash, step.action, step.nextRegion, ...
                step.nextWater, step.nextFood, step.nextCash}; %#ok<AGROW>

            if step.feasible && step.nextRegion ~= data.endRegion
                nextStates(end+1, :) = [step.nextRegion, step.nextWater, ...
                    step.nextFood, step.nextCash]; %#ok<AGROW>
            end
        end
    end

    if isempty(nextStates)
        currentStates = zeros(0, 4);
    else
        currentStates = unique(nextStates, 'rows', 'stable');
    end
end

policyTable = cell2table(policyRows, 'VariableNames', ...
    {'Day','Weather','Region','Water','Food','Cash','Action', ...
    'NextRegion','NextWater','NextFood','NextCash'});

initialLoad = data.waterWeight * dpResult.bestInitialWater ...
    + data.foodWeight * dpResult.bestInitialFood;
allScenariosFeasible = all(feasible);
consistencyGap = worstFinalWealth - dpResult.guaranteedWealth;

summary = table(data.caseID, dpResult.bestInitialWater, ...
    dpResult.bestInitialFood, initialLoad, dpResult.bestInitialCash, ...
    dpResult.guaranteedWealth, worstFinalWealth, bestFinalWealth, ...
    allScenariosFeasible, consistencyGap, dpResult.runtime, ...
    'VariableNames', {'CaseID','InitialWater','InitialFood','InitialLoad', ...
    'InitialCash','GuaranteedWealth','WorstScenarioWealth','BestScenarioWealth', ...
    'AllScenariosFeasible','ConsistencyGap','RuntimeSeconds'});

result.summary = summary;
result.policyTable = policyTable;
result.scenarioTable = scenarioTable;
result.worstDaily = worstSim.dailyTable;
result.bestDaily = bestSim.dailyTable;
result.worstWeatherText = strjoin(data.weatherNames(worstSeq), "-");
result.bestWeatherText = strjoin(data.weatherNames(bestSeq), "-");
result.worstFinalWealth = worstFinalWealth;
result.bestFinalWealth = bestFinalWealth;
end

function sim = simulate_case3_sequence(weatherSeq, dpResult, data, keepLog)
region = data.startRegion;
water = dpResult.bestInitialWater;
food = dpResult.bestInitialFood;
cash = dpResult.bestInitialCash;

mineDays = 0;
arrivalDay = NaN;
feasible = true;

if keepLog
    dailyRows = cell(0, 12);
    dailyRows(end+1, :) = {0, "", region, "初始购买", region, ...
        0, 0, false, water, food, cash, ...
        data.waterWeight * water + data.foodWeight * food};
end

for t = 1:data.deadline
    if region == data.endRegion
        break;
    end

    weatherID = weatherSeq(t);
    code = dpResult.policy{t, weatherID}(region, water + 1, food + 1);
    step = apply_case3_action(region, water, food, cash, weatherID, code, data);

    if ~step.feasible
        feasible = false;
        break;
    end

    if step.mineFlag
        mineDays = mineDays + 1;
    end

    if keepLog
        loadLeft = data.waterWeight * step.nextWater + ...
            data.foodWeight * step.nextFood;
        dailyRows(end+1, :) = {t, data.weatherNames(weatherID), region, ...
            step.action, step.nextRegion, step.waterUse, step.foodUse, ...
            step.mineFlag, step.nextWater, step.nextFood, step.nextCash, ...
            loadLeft}; %#ok<AGROW>
    end

    region = step.nextRegion;
    water = step.nextWater;
    food = step.nextFood;
    cash = step.nextCash;

    if region == data.endRegion
        arrivalDay = t;
        break;
    end
end

if region == data.endRegion && feasible
    refundValue = data.refundWaterPrice * water ...
        + data.refundFoodPrice * food;
    finalWealth = cash + refundValue;
else
    refundValue = NaN;
    finalWealth = -Inf;
    feasible = false;
end

sim.arrivalDay = arrivalDay;
sim.mineDays = mineDays;
sim.finalWater = water;
sim.finalFood = food;
sim.cashAtArrival = cash;
sim.refundValue = refundValue;
sim.finalWealth = finalWealth;
sim.feasible = feasible;

if keepLog
    sim.dailyTable = cell2table(dailyRows, 'VariableNames', ...
        {'Day','Weather','StartRegion','Action','EndRegion', ...
        'WaterUsed','FoodUsed','Mine','WaterLeft','FoodLeft', ...
        'CashLeft','LoadLeft'});
else
    sim.dailyTable = table();
end
end

function step = apply_case3_action(region, water, food, cash, weatherID, code, data)
step.feasible = true;
step.mineFlag = false;
step.action = "";
step.nextRegion = region;
step.nextWater = water;
step.nextFood = food;
step.nextCash = cash;
step.waterUse = 0;
step.foodUse = 0;

if code == 0
    step.feasible = false;
    step.action = "不可行";
    return;
elseif code == 1
    step.action = "停留";
    multiplier = data.stayMultiplier;
    nextRegion = region;
    reward = 0;
elseif code == 2
    step.action = "挖矿";
    multiplier = data.mineMultiplier;
    nextRegion = region;
    reward = data.mineIncome;
    step.mineFlag = true;
else
    step.action = "行走";
    multiplier = data.moveMultiplier;
    nextRegion = double(code) - 2;
    reward = 0;
end

waterUse = data.waterBaseUse(weatherID) * multiplier;
foodUse = data.foodBaseUse(weatherID) * multiplier;
nextWater = water - waterUse;
nextFood = food - foodUse;
nextCash = cash + reward;

if nextWater < 0 || nextFood < 0
    step.feasible = false;
    return;
end

if nextRegion ~= data.endRegion && (nextWater == 0 || nextFood == 0)
    step.feasible = false;
    return;
end

if data.waterWeight * nextWater + data.foodWeight * nextFood > data.maxLoad
    step.feasible = false;
    return;
end

step.nextRegion = nextRegion;
step.nextWater = nextWater;
step.nextFood = nextFood;
step.nextCash = nextCash;
step.waterUse = waterUse;
step.foodUse = foodUse;
end
