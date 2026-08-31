function bestStrategy = best_response( ...
    playerID, strategies, data)
%BEST_RESPONSE 固定其他玩家策略，求当前玩家最优响应

if data.caseID == 5

    bestStrategy = ...
        best_response_case5( ...
        playerID, strategies, data);

    bestStrategy.representativeWeather = [];

elseif data.caseID == 6

    bestStrategy = ...
        best_response_case6_fast( ...
        playerID, strategies, data);

else

    error('caseID只能为5或6。');

end


if ~isfield(bestStrategy, 'income')
    bestStrategy.income = 0;
end

end


function bestStrategy = best_response_case5(playerID, strategies, data)
% 第五关：天气全部已知，采用前向状态动态规划

T = data.deadline;

% state字段：
% day, region, waterUse, foodUse, income, actions, regions
initialState.day = 0;
initialState.region = data.startRegion;
initialState.waterUse = 0;
initialState.foodUse = 0;
initialState.income = 0;
initialState.actions = repmat(empty_action(), 1, T);
initialState.regions = zeros(1, T + 1);
initialState.regions(1) = data.startRegion;
initialState.arrived = false;
initialState.arrivalDay = inf;
initialState.mineDays = 0;

states = initialState;
terminalStates = struct([]);

for t = 1:T

    newStates = struct([]);

    for sID = 1:numel(states)

        state = states(sID);

        if state.arrived
            terminalStates = append_state(terminalStates, state);
            continue;
        end

        weather = data.weather(t);
        actions = generate_case5_actions(state.region, weather, data);

        for aID = 1:numel(actions)

            action = actions(aID);

            [waterCost, foodCost, income] = ...
                case5_action_effect( ...
                playerID, t, action, strategies, data);

            newState = state;

            newState.day = t;
            newState.waterUse = state.waterUse + waterCost;
            newState.foodUse = state.foodUse + foodCost;
            newState.income = state.income + income;

            newState.actions(t) = action;
            newState.region = action.to;
            newState.regions(t + 1) = action.to;

            if strcmp(action.type, 'mine')
                newState.mineDays = state.mineDays + 1;
            end

            % 初始购买恰好覆盖整个行程消耗。
            initialLoad = ...
                data.waterWeight * newState.waterUse + ...
                data.foodWeight * newState.foodUse;

            initialCost = ...
                data.waterPrice * newState.waterUse + ...
                data.foodPrice * newState.foodUse;

            if initialLoad > data.maxLoad
                continue;
            end

            if initialCost > data.initialCash
                continue;
            end

            if newState.region == data.endRegion
                newState.arrived = true;
                newState.arrivalDay = t;
                terminalStates = append_state(terminalStates, newState);
                continue;
            end

            newStates = append_state(newStates, newState);

        end

    end

    if isempty(newStates)
        break;
    end

    % 同一天、同一区域、累计消耗相同时，仅保留收入较高状态。
    states = prune_case5_states(newStates);

end


if isempty(terminalStates)
    bestStrategy = infeasible_strategy(playerID, data);
    return;
end


bestWealth = -inf;
bestIndex = 0;

for sID = 1:numel(terminalStates)

    state = terminalStates(sID);

    initialWater = state.waterUse;
    initialFood = state.foodUse;

    initialCost = ...
        data.waterPrice * initialWater + ...
        data.foodPrice * initialFood;

    % 对一条固定路线，多购买资源只会以半价退回，
    % 因而不会提高最终财富，最优初始购买等于实际总消耗。
    finalWealth = ...
        data.initialCash - initialCost + state.income;

    if finalWealth > bestWealth + data.algorithm.wealthTolerance

        bestWealth = finalWealth;
        bestIndex = sID;

    elseif abs(finalWealth - bestWealth) <= ...
            data.algorithm.wealthTolerance

        oldState = terminalStates(bestIndex);

        if better_tie_break(state, oldState)
            bestIndex = sID;
        end

    end

end


bestState = terminalStates(bestIndex);

bestStrategy.playerID = playerID;
bestStrategy.feasible = true;
bestStrategy.initialWater = bestState.waterUse;
bestStrategy.initialFood = bestState.foodUse;
bestStrategy.actions = bestState.actions;
bestStrategy.regions = bestState.regions;
bestStrategy.arrivalDay = bestState.arrivalDay;
bestStrategy.mineDays = bestState.mineDays;
bestStrategy.finalWealth = bestWealth;
bestStrategy.income = bestState.income;
bestStrategy.caseID = 5;

bestStrategy.signature = strategy_signature(bestStrategy);

end


function bestStrategy = best_response_case6(playerID, strategies, data)
% 第六关：保证型滚动最优响应。
%
% 附件未给完整天气。这里沿用前面确定的保证型设定：
% 未来只考虑高温与沙暴，且沙暴总数最多为maxStormDays。
%
% 为使多人动态问题能够稳定运行，单次最优响应使用
% "高温主分支 + 沙暴可延迟移动"的保守策略搜索。
% 玩家实际在沙暴日不能移动，其他行动仍按题目规则执行。

T = data.deadline;

% 第六关最坏分支下高温、沙暴的水食物基础消耗相同，
% 因而最优初始方案不会主动购买单边多余资源。
% 用资源对 q 表示 q箱水+q箱食物。
maxPairs = floor(data.maxLoad / ...
    (data.waterWeight + data.foodWeight));

bestWealth = -inf;
bestPlan = [];

% 初始资源对不需要逐个从0扫到240后再完整搜索。
% 保留完整范围，程序仍是整数搜索。
for initialPairs = 1:maxPairs

    initialCost = ...
        initialPairs * (data.waterPrice + data.foodPrice);

    if initialCost > data.initialCash
        break;
    end

    state.day = 0;
    state.region = data.startRegion;
    state.pairs = initialPairs;
    state.cash = data.initialCash - initialCost;
    state.stormUsed = 0;
    state.mineDays = 0;

    memo = containers.Map('KeyType', 'char', 'ValueType', 'any');

    result = robust_value_case6( ...
        playerID, state, strategies, data, memo);

    if ~result.feasible
        continue;
    end

    finalWealth = result.value;

    if finalWealth > bestWealth + data.algorithm.wealthTolerance
        bestWealth = finalWealth;
        bestPlan = result;
        bestPlan.initialPairs = initialPairs;
    end

end


if isempty(bestPlan)
    bestStrategy = infeasible_strategy(playerID, data);
    return;
end


bestStrategy.playerID = playerID;
bestStrategy.feasible = true;
bestStrategy.initialWater = bestPlan.initialPairs;
bestStrategy.initialFood = bestPlan.initialPairs;
bestStrategy.actions = bestPlan.actions;
bestStrategy.regions = bestPlan.regions;
bestStrategy.arrivalDay = bestPlan.arrivalDay;
bestStrategy.mineDays = bestPlan.mineDays;
bestStrategy.finalWealth = bestPlan.value;
bestStrategy.caseID = 6;
bestStrategy.representativeWeather = bestPlan.weather;
bestStrategy.signature = strategy_signature(bestStrategy);

end


function result = robust_value_case6( ...
    playerID, state, strategies, data, memo)
% 第六关保证型递归动态规划

if state.region == data.endRegion

    result.feasible = true;

    result.value = ...
        state.cash + ...
        state.pairs * ...
        (data.returnWaterPrice + data.returnFoodPrice);

    result.actions = repmat( ...
        empty_action(), 1, data.deadline);

    result.regions = zeros( ...
        1, data.deadline + 1);

    result.regions(1:state.day + 1) = ...
        state.region;

    result.arrivalDay = state.day;
    result.mineDays = state.mineDays;

    result.weather = zeros( ...
        1, data.deadline);

    return;
end


if state.day >= data.deadline

    result = infeasible_dp_result(data);
    return;
end


key = sprintf('%d_%d_%d_%d_%d', ...
    state.day, ...
    state.region, ...
    state.pairs, ...
    round(state.cash * 100), ...
    state.stormUsed);

if isKey(memo, key)

    result = memo(key);
    return;

end


nextDay = state.day + 1;


% 保证型未来天气：
% 沙暴次数未用完时考虑高温和沙暴；
% 达到沙暴上限后仅考虑高温。
if state.stormUsed < data.maxStormDays

    weatherSet = [2, 3];

else

    weatherSet = 2;

end


% 用cell保存不同天气分支，避免MATLAB结构体数组字段冲突
weatherResults = cell(1, numel(weatherSet));


for wID = 1:numel(weatherSet)

    weather = weatherSet(wID);

    actions = generate_case6_actions( ...
        state.region, weather, data);

    bestForWeather = ...
        infeasible_dp_result(data);


    for aID = 1:numel(actions)

        action = actions(aID);

        [pairCost, income] = ...
            case6_action_effect( ...
            playerID, ...
            nextDay, ...
            weather, ...
            action, ...
            strategies, ...
            data);


        if pairCost > state.pairs
            continue;
        end


        newState = state;

        newState.day = nextDay;
        newState.region = action.to;

        newState.pairs = ...
            state.pairs - pairCost;

        newState.cash = ...
            state.cash + income;


        if weather == 3

            newState.stormUsed = ...
                state.stormUsed + 1;

        end


        if strcmp(action.type, 'mine')

            newState.mineDays = ...
                state.mineDays + 1;

        end


        % 默认当天不购买
        purchaseOptions = 0;


        % 只有到达村庄后才允许购买资源
        if newState.region == data.villageRegions

            maxBuy = ...
                maxPairs_from_state( ...
                newState.pairs, data);

            purchaseOptions = 0:maxBuy;

        end


        for buyPairs = purchaseOptions

            buyCost = village_pair_cost( ...
                playerID, ...
                nextDay, ...
                buyPairs, ...
                strategies, ...
                data);


            if buyCost > newState.cash
                continue;
            end


            purchasedState = newState;

            purchasedState.pairs = ...
                newState.pairs + buyPairs;

            purchasedState.cash = ...
                newState.cash - buyCost;


            maxPairs = floor( ...
                data.maxLoad / ...
                (data.waterWeight + ...
                 data.foodWeight));


            if purchasedState.pairs > maxPairs
                continue;
            end


            child = robust_value_case6( ...
                playerID, ...
                purchasedState, ...
                strategies, ...
                data, ...
                memo);


            if ~child.feasible
                continue;
            end


            if child.value > ...
                    bestForWeather.value + ...
                    data.algorithm.wealthTolerance

                bestForWeather = child;

                bestForWeather.actions(nextDay) = ...
                    action;

                bestForWeather.actions(nextDay).buyPairs = ...
                    buyPairs;

                bestForWeather.regions(nextDay + 1) = ...
                    action.to;

                bestForWeather.weather(nextDay) = ...
                    weather;


            elseif abs( ...
                    child.value - ...
                    bestForWeather.value) ...
                    <= data.algorithm.wealthTolerance

                % 收益相同时优先购买更少资源
                oldBuy = ...
                    bestForWeather.actions(nextDay).buyPairs;

                if buyPairs < oldBuy

                    bestForWeather = child;

                    bestForWeather.actions(nextDay) = ...
                        action;

                    bestForWeather.actions(nextDay).buyPairs = ...
                        buyPairs;

                    bestForWeather.regions(nextDay + 1) = ...
                        action.to;

                    bestForWeather.weather(nextDay) = ...
                        weather;

                end

            end

        end

    end


    weatherResults{wID} = bestForWeather;

end


% 若任一种允许天气下都无法完成游戏，
% 则当前状态不能形成保证型可行策略。
allFeasible = true;

for wID = 1:numel(weatherResults)

    if isempty(weatherResults{wID}) || ...
            ~weatherResults{wID}.feasible

        allFeasible = false;
        break;

    end

end


if ~allFeasible

    result = infeasible_dp_result(data);
    memo(key) = result;

    return;

end


% 保证型准则：
% 当前玩家分别针对已经观察到的天气作最优行动，
% 再取未来允许天气中的最小价值。
values = zeros(1, numel(weatherResults));

for wID = 1:numel(weatherResults)

    values(wID) = ...
        weatherResults{wID}.value;

end


[~, worstID] = min(values);

result = weatherResults{worstID};

memo(key) = result;

end

function actions = generate_case5_actions(region, weather, data)

actions = struct([]);

% 普通停留
action = empty_action();
action.type = 'stay';
action.from = region;
action.to = region;
actions = append_action(actions, action);


% 沙暴不能移动
if weather ~= 3

    for neighbor = data.neighbors{region}

        action = empty_action();
        action.type = 'move';
        action.from = region;
        action.to = neighbor;

        actions = append_action(actions, action);

    end

end


% 当天开始时已在矿山才能挖矿
if ismember(region, data.mineRegions)

    action = empty_action();
    action.type = 'mine';
    action.from = region;
    action.to = region;

    actions = append_action(actions, action);

end

end


function actions = generate_case6_actions(region, weather, data)

actions = generate_case5_actions(region, weather, data);

end


function [waterCost, foodCost, income] = ...
    case5_action_effect( ...
    playerID, day, action, strategies, data)

weather = data.weather(day);

baseWater = data.waterBaseUse(weather);
baseFood = data.foodBaseUse(weather);

income = 0;

switch action.type

    case 'stay'

        factor = 1;

    case 'move'

        k = 1;

        for p = 1:numel(strategies)

            if p == playerID || ~strategy_has_day(strategies, p, day)
                continue;
            end

            otherAction = strategies(p).actions(day);

            if strcmp(otherAction.type, 'move') && ...
                    otherAction.from == action.from && ...
                    otherAction.to == action.to
                k = k + 1;
            end

        end

        factor = 2 * k;

    case 'mine'

        k = 1;

        for p = 1:numel(strategies)

            if p == playerID || ~strategy_has_day(strategies, p, day)
                continue;
            end

            otherAction = strategies(p).actions(day);

            if strcmp(otherAction.type, 'mine') && ...
                    otherAction.from == action.from
                k = k + 1;
            end

        end

        factor = 3 * k;
        income = data.mineIncome / k;

    otherwise

        error('未知行动类型。');

end

waterCost = factor * baseWater;
foodCost = factor * baseFood;

end


function [pairCost, income] = ...
    case6_action_effect( ...
    playerID, day, weather, action, strategies, data)

baseUse = data.waterBaseUse(weather);

income = 0;

switch action.type

    case 'stay'

        factor = 1;

    case 'move'

        k = 1;

        for p = 1:numel(strategies)

            if p == playerID || ~strategy_has_day(strategies, p, day)
                continue;
            end

            otherAction = strategies(p).actions(day);

            if strcmp(otherAction.type, 'move') && ...
                    otherAction.from == action.from && ...
                    otherAction.to == action.to
                k = k + 1;
            end

        end

        factor = 2 * k;

    case 'mine'

        k = 1;

        for p = 1:numel(strategies)

            if p == playerID || ~strategy_has_day(strategies, p, day)
                continue;
            end

            otherAction = strategies(p).actions(day);

            if strcmp(otherAction.type, 'mine') && ...
                    otherAction.from == action.from
                k = k + 1;
            end

        end

        factor = 3 * k;
        income = data.mineIncome / k;

    otherwise

        factor = 1;

end

pairCost = factor * baseUse;

end


function cost = village_pair_cost( ...
    playerID, day, buyPairs, strategies, data)

if buyPairs == 0
    cost = 0;
    return;
end

k = 1;

for p = 1:numel(strategies)

    if p == playerID || ~strategy_has_day(strategies, p, day)
        continue;
    end

    otherAction = strategies(p).actions(day);

    if isfield(otherAction, 'buyPairs') && ...
            otherAction.buyPairs > 0
        k = k + 1;
    end

end

if k == 1
    factor = 2;
else
    factor = 4 * k;
end

pairPrice = ...
    factor * ...
    (data.waterPrice + data.foodPrice);

cost = pairPrice * buyPairs;

end


function maxBuy = maxPairs_from_state(currentPairs, data)

maxPairs = floor(data.maxLoad / ...
    (data.waterWeight + data.foodWeight));

maxBuy = maxPairs - currentPairs;

end


function states = prune_case5_states(states)

if isempty(states)
    return;
end

keys = strings(numel(states), 1);

for i = 1:numel(states)

    keys(i) = sprintf('%d_%d_%d_%d', ...
        states(i).day, ...
        states(i).region, ...
        states(i).waterUse, ...
        states(i).foodUse);

end

[uniqueKeys, ~, groupID] = unique(keys);

pruned = struct([]);

for g = 1:numel(uniqueKeys)

    IDs = find(groupID == g);

    incomes = [states(IDs).income];
    [~, bestLocal] = max(incomes);

    pruned = append_state(pruned, ...
        states(IDs(bestLocal)));

end

states = pruned;

end


function tf = better_tie_break(newState, oldState)

if newState.arrivalDay < oldState.arrivalDay
    tf = true;
elseif newState.arrivalDay > oldState.arrivalDay
    tf = false;
else
    newLoad = 3 * newState.waterUse + ...
        2 * newState.foodUse;

    oldLoad = 3 * oldState.waterUse + ...
        2 * oldState.foodUse;

    tf = newLoad < oldLoad;
end

end


function tf = strategy_has_day(strategies, playerID, day)

tf = false;

if playerID > numel(strategies)
    return;
end

if ~isfield(strategies(playerID), 'feasible') || ...
        ~strategies(playerID).feasible
    return;
end

if ~isfield(strategies(playerID), 'actions')
    return;
end

tf = day <= numel(strategies(playerID).actions);

end


function action = empty_action()

action.type = 'none';
action.from = 0;
action.to = 0;
action.buyPairs = 0;

end


function actions = append_action(actions, action)

if isempty(actions)
    actions = action;
else
    actions(end + 1) = action;
end

end


function states = append_state(states, state)

if isempty(states)
    states = state;
else
    states(end + 1) = state;
end

end


function result = infeasible_dp_result(data)

result.feasible = false;
result.value = -inf;
result.actions = repmat(empty_action(), 1, data.deadline);
result.regions = zeros(1, data.deadline + 1);
result.arrivalDay = inf;
result.mineDays = 0;
result.weather = zeros(1, data.deadline);

end


function strategy = infeasible_strategy(playerID, data)

action.type = 'none';
action.from = 0;
action.to = 0;
action.buyPairs = 0;

strategy.playerID = playerID;
strategy.feasible = false;

strategy.initialWater = 0;
strategy.initialFood = 0;

strategy.actions = repmat( ...
    action, 1, data.deadline);

strategy.regions = zeros( ...
    1, data.deadline + 1);

strategy.arrivalDay = inf;
strategy.mineDays = 0;

strategy.finalWealth = -inf;
strategy.income = 0;

strategy.representativeWeather = [];

strategy.caseID = data.caseID;

strategy.signature = ...
    sprintf('P%d_INFEASIBLE', playerID);

end


function signature = strategy_signature(strategy)

parts = strings(1, numel(strategy.actions) + 3);

parts(1) = sprintf('W%d', strategy.initialWater);
parts(2) = sprintf('F%d', strategy.initialFood);
parts(3) = sprintf('A%d', strategy.arrivalDay);

for t = 1:numel(strategy.actions)

    a = strategy.actions(t);

    parts(t + 3) = sprintf('%s_%d_%d_%d', ...
        a.type, a.from, a.to, a.buyPairs);

end

signature = strjoin(parts, '|');

end