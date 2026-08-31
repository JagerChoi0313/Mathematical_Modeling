function bestStrategy = best_response_case6_fast( ...
    playerID, strategies, data)
%BEST_RESPONSE_CASE6_FAST
% 第六关保证型最优响应的加速实现

T = data.deadline;

pairWeight = data.waterWeight + data.foodWeight;
pairPrice = data.waterPrice + data.foodPrice;

maxPairs = floor(data.maxLoad / pairWeight);

% 最短路只用于严格可行性剪枝，不改变优化模型
distEnd = shortest_distances( ...
    data.neighbors, data.endRegion);

if isempty(data.villageRegions)
    distVillage = inf(data.numRegions, 1);
else
    distVillage = shortest_distances( ...
        data.neighbors, data.villageRegions(1));
end


% 在高温天气下，单人移动至少消耗18对资源。
% 从起点必须至少能够到达村庄或终点中的一个。
minTargetDistance = min( ...
    distEnd(data.startRegion), ...
    distVillage(data.startRegion));

if isfinite(minTargetDistance)
    minInitialPairs = max(1, 18 * minTargetDistance);
else
    minInitialPairs = 1;
end

minInitialPairs = min(minInitialPairs, maxPairs);


% 所有初始资源量共用同一个动态规划缓存
memo = containers.Map( ...
    'KeyType', 'uint64', ...
    'ValueType', 'any');


bestValue = -inf;
bestInitialPairs = 0;

fprintf(['  玩家%d：初始资源候选 %d～%d 对，' ...
         '开始保证型动态规划。\n'], ...
    playerID, minInitialPairs, maxPairs);


for initialPairs = minInitialPairs:maxPairs

    initialCost = initialPairs * pairPrice;

    if initialCost > data.initialCash
        break;
    end

    state.day = 0;
    state.region = data.startRegion;
    state.pairs = initialPairs;
    state.cash = data.initialCash - initialCost;
    state.stormUsed = 0;

    node = robust_node( ...
        playerID, ...
        state, ...
        strategies, ...
        data, ...
        memo, ...
        distEnd, ...
        distVillage);

    if node.feasible

        if node.value > bestValue + ...
                data.algorithm.wealthTolerance

            bestValue = node.value;
            bestInitialPairs = initialPairs;

        elseif abs(node.value - bestValue) <= ...
                data.algorithm.wealthTolerance

            % 资金相同时，优先初始携带更少的方案
            if bestInitialPairs == 0 || ...
                    initialPairs < bestInitialPairs

                bestInitialPairs = initialPairs;

            end

        end

    end


    if initialPairs == minInitialPairs || ...
            mod(initialPairs - minInitialPairs + 1, 10) == 0 || ...
            initialPairs == maxPairs

        fprintf(['    已计算初始资源 %d/%d 对，' ...
                 '缓存状态 %d，当前最好 %.2f 元。\n'], ...
            initialPairs, ...
            maxPairs, ...
            memo.Count, ...
            bestValue);

        drawnow;

    end

end


if bestInitialPairs == 0

    bestStrategy = infeasible_strategy( ...
        playerID, data);

    return;

end


% 从最优初始状态沿"代表性最不利天气分支"
% 正向恢复路线和天气。
initialState.day = 0;
initialState.region = data.startRegion;
initialState.pairs = bestInitialPairs;
initialState.cash = ...
    data.initialCash - bestInitialPairs * pairPrice;
initialState.stormUsed = 0;

[actions, regions, weather, arrivalDay, mineDays] = ...
    reconstruct_worst_path( ...
    playerID, ...
    initialState, ...
    strategies, ...
    data, ...
    memo, ...
    distEnd, ...
    distVillage);


bestStrategy.playerID = playerID;
bestStrategy.feasible = true;

bestStrategy.initialWater = bestInitialPairs;
bestStrategy.initialFood = bestInitialPairs;

bestStrategy.actions = actions;
bestStrategy.regions = regions;

bestStrategy.arrivalDay = arrivalDay;
bestStrategy.mineDays = mineDays;

bestStrategy.finalWealth = bestValue;
bestStrategy.income = 0;

bestStrategy.representativeWeather = weather;

bestStrategy.caseID = 6;
bestStrategy.signature = strategy_signature(bestStrategy);

fprintf(['  玩家%d最优响应完成：初始水%d箱，食物%d箱，' ...
         '保证型最终资金 %.2f 元。\n'], ...
    playerID, ...
    bestStrategy.initialWater, ...
    bestStrategy.initialFood, ...
    bestStrategy.finalWealth);

end



function node = robust_node( ...
    playerID, state, strategies, data, ...
    memo, distEnd, distVillage)
% 从当前状态开始计算保证型最终财富

T = data.deadline;


% 已经到达终点
if state.region == data.endRegion

    node = terminal_node();

    node.value = ...
        state.cash + ...
        state.pairs * ...
        (data.returnWaterPrice + ...
         data.returnFoodPrice);

    return;

end


% 到截止日期仍未到终点
if state.day >= T

    node = infeasible_node();
    return;

end


remainingDays = T - state.day;

% 即使每天都移动也来不及到达终点
if distEnd(state.region) > remainingDays

    node = infeasible_node();
    return;

end


% 资源严格下界剪枝：
% 在高温天气下，单人每移动一步至少消耗18对。
% 若当前连村庄或终点中的任意一个都无法到达，
% 则该状态必不可能形成保证型可行策略。
if ~ismember(state.region, data.villageRegions)

    targetDistance = min( ...
        distEnd(state.region), ...
        distVillage(state.region));

    if isfinite(targetDistance)

        minPairsNeeded = 18 * targetDistance;

        if state.pairs < minPairsNeeded

            node = infeasible_node();
            return;

        end

    end

end


key = state_key(state);

if isKey(memo, key)

    node = memo(key);
    return;

end


nextDay = state.day + 1;


% 高温始终属于未来最不利候选。
% 沙暴次数未达到上限时，还需考虑沙暴。
if state.stormUsed < data.maxStormDays

    weatherSet = [2, 3];

else

    weatherSet = 2;

end


weatherBranches = cell(1, numel(weatherSet));


for wID = 1:numel(weatherSet)

    weather = weatherSet(wID);

    actions = generate_actions( ...
        state.region, weather, data);

    bestBranch = infeasible_branch();


    for actionID = 1:numel(actions)

        action = actions(actionID);

        [pairUse, mineIncome] = ...
            action_effect( ...
            playerID, ...
            nextDay, ...
            weather, ...
            action, ...
            strategies, ...
            data);


        if pairUse > state.pairs
            continue;
        end


        nextState = state;

        nextState.day = nextDay;
        nextState.region = action.to;
        nextState.pairs = state.pairs - pairUse;
        nextState.cash = state.cash + mineIncome;

        if weather == 3

            nextState.stormUsed = ...
                state.stormUsed + 1;

        end


        % 到达村庄后允许购买资源。
        if ismember(nextState.region, ...
                data.villageRegions)

            onePairPrice = village_pair_price( ...
                playerID, ...
                nextDay, ...
                nextState.region, ...
                strategies, ...
                data);

            maxLoadPairs = ...
                floor(data.maxLoad / ...
                (data.waterWeight + ...
                 data.foodWeight));

            maxByLoad = ...
                maxLoadPairs - nextState.pairs;

            maxByCash = floor( ...
                (nextState.cash + 1e-9) / ...
                onePairPrice);

            maxBuy = max(0, ...
                min(maxByLoad, maxByCash));

            purchaseOptions = 0:maxBuy;

        else

            onePairPrice = 0;
            purchaseOptions = 0;

        end


        for buyPairs = purchaseOptions

            purchasedState = nextState;

            purchasedState.pairs = ...
                nextState.pairs + buyPairs;

            purchasedState.cash = ...
                nextState.cash - ...
                buyPairs * onePairPrice;


            if purchasedState.cash < -1e-8
                continue;
            end


            child = robust_node( ...
                playerID, ...
                purchasedState, ...
                strategies, ...
                data, ...
                memo, ...
                distEnd, ...
                distVillage);


            if ~child.feasible
                continue;
            end


            candidate.feasible = true;
            candidate.value = child.value;

            candidate.weather = weather;

            actionWithBuy = action;
            actionWithBuy.buyPairs = buyPairs;

            candidate.action = actionWithBuy;
            candidate.buyPairs = buyPairs;

            candidate.nextState = purchasedState;

            candidate.stepsToEnd = ...
                child.stepsToEnd + 1;


            if better_branch( ...
                    candidate, ...
                    bestBranch, ...
                    data.algorithm.wealthTolerance)

                bestBranch = candidate;

            end

        end

    end


    weatherBranches{wID} = bestBranch;

end


% 保证型模型要求所有允许天气都必须可行。
for wID = 1:numel(weatherBranches)

    if ~weatherBranches{wID}.feasible

        node = infeasible_node();
        memo(key) = node;

        return;

    end

end


% 先对每种已观测天气选择最优行动，
% 再由未来天气取其中最不利价值。
worstID = 1;

for wID = 2:numel(weatherBranches)

    candidate = weatherBranches{wID};
    currentWorst = weatherBranches{worstID};

    if candidate.value < ...
            currentWorst.value - ...
            data.algorithm.wealthTolerance

        worstID = wID;

    elseif abs(candidate.value - ...
            currentWorst.value) <= ...
            data.algorithm.wealthTolerance

        % 保证财富相同时，
        % 将需要更久才能到终点的天气作为代表性最不利分支。
        if candidate.stepsToEnd > ...
                currentWorst.stepsToEnd

            worstID = wID;

        end

    end

end


worstBranch = weatherBranches{worstID};

node.feasible = true;
node.value = worstBranch.value;

node.worstWeather = worstBranch.weather;
node.bestAction = worstBranch.action;
node.buyPairs = worstBranch.buyPairs;

node.nextState = worstBranch.nextState;
node.stepsToEnd = worstBranch.stepsToEnd;

memo(key) = node;

end



function [actions, regions, weather, arrivalDay, mineDays] = ...
    reconstruct_worst_path( ...
    playerID, initialState, strategies, data, ...
    memo, distEnd, distVillage)

T = data.deadline;

actions = repmat(empty_action(), 1, T);

regions = zeros(1, T + 1);
regions(1) = data.startRegion;

weather = zeros(1, T);

state = initialState;

arrivalDay = inf;
mineDays = 0;


while state.day < T && ...
        state.region ~= data.endRegion

    key = state_key(state);

    if isKey(memo, key)

        node = memo(key);

    else

        node = robust_node( ...
            playerID, ...
            state, ...
            strategies, ...
            data, ...
            memo, ...
            distEnd, ...
            distVillage);

    end


    if ~node.feasible || ...
            node.worstWeather == 0

        break;

    end


    day = state.day + 1;

    actions(day) = node.bestAction;
    weather(day) = node.worstWeather;

    state = node.nextState;

    regions(day + 1) = state.region;


    if strcmp(actions(day).type, 'mine')
        mineDays = mineDays + 1;
    end


    if state.region == data.endRegion

        arrivalDay = day;

        if day < T
            regions(day + 2:end) = ...
                data.endRegion;
        end

        break;

    end

end


% 到终点后的天气只用于数组完整性，
% 设为高温不会影响任何计算结果。
weather(weather == 0) = 2;

end



function actions = generate_actions(region, weather, data)

actions = struct([]);


% 原地停留
a = empty_action();
a.type = 'stay';
a.from = region;
a.to = region;

actions = append_action(actions, a);


% 晴朗/高温才能移动
if weather ~= 3

    neighbors = data.neighbors{region};

    for j = 1:numel(neighbors)

        a = empty_action();

        a.type = 'move';
        a.from = region;
        a.to = neighbors(j);

        actions = append_action(actions, a);

    end

end


% 当天开始时已经位于矿山才允许挖矿
if ismember(region, data.mineRegions)

    a = empty_action();

    a.type = 'mine';
    a.from = region;
    a.to = region;

    actions = append_action(actions, a);

end

end



function [pairUse, income] = ...
    action_effect( ...
    playerID, day, weather, ...
    action, strategies, data)

baseUse = data.waterBaseUse(weather);

income = 0;


switch action.type

    case 'stay'

        factor = 1;


    case 'move'

        k = 1;

        for p = 1:numel(strategies)

            if p == playerID || ...
                    ~strategy_has_day( ...
                    strategies, p, day)

                continue;
            end

            other = strategies(p).actions(day);

            % 沙暴日其他玩家的预定移动视为不能执行，
            % 不计入同行人数。
            if weather == 3 && ...
                    strcmp(other.type, 'move')

                continue;
            end

            if strcmp(other.type, 'move') && ...
                    other.from == action.from && ...
                    other.to == action.to

                k = k + 1;

            end

        end

        factor = 2 * k;


    case 'mine'

        k = 1;

        for p = 1:numel(strategies)

            if p == playerID || ...
                    ~strategy_has_day( ...
                    strategies, p, day)

                continue;
            end

            other = strategies(p).actions(day);

            if strcmp(other.type, 'mine') && ...
                    other.from == action.from

                k = k + 1;

            end

        end

        factor = 3 * k;
        income = data.mineIncome / k;


    otherwise

        factor = 1;

end


% 保证型未来分支只包含高温和沙暴，
% 这两种天气水、食物基础消耗相同，
% 因而可以使用"资源对"压缩状态。
pairUse = factor * baseUse;

end



function onePairPrice = village_pair_price( ...
    playerID, day, villageRegion, ...
    strategies, data)

k = 1;


for p = 1:numel(strategies)

    if p == playerID || ...
            ~strategy_has_day( ...
            strategies, p, day)

        continue;
    end


    other = strategies(p).actions(day);

    if other.buyPairs > 0 && ...
            other.to == villageRegion

        k = k + 1;

    end

end


if k == 1

    factor = 2;

else

    factor = 4 * k;

end


onePairPrice = ...
    factor * ...
    (data.waterPrice + data.foodPrice);

end



function tf = better_branch( ...
    candidate, currentBest, tolerance)

if ~candidate.feasible

    tf = false;
    return;

end


if ~currentBest.feasible

    tf = true;
    return;

end


if candidate.value > ...
        currentBest.value + tolerance

    tf = true;
    return;

end


if candidate.value < ...
        currentBest.value - tolerance

    tf = false;
    return;

end


% 最终财富相同时优先更早到达终点
if candidate.stepsToEnd < ...
        currentBest.stepsToEnd

    tf = true;
    return;

elseif candidate.stepsToEnd > ...
        currentBest.stepsToEnd

    tf = false;
    return;

end


% 再优先当日购买量较少
tf = candidate.buyPairs < ...
    currentBest.buyPairs;

end



function key = state_key(state)
% 使用uint64打包状态，比字符串Map明显更快

cashMicro = uint64( ...
    max(0, round(state.cash * 1e6)));

key = ...
    uint64(state.day) + ...
    uint64(32) * uint64(state.region) + ...
    uint64(1024) * uint64(state.pairs) + ...
    uint64(262144) * uint64(state.stormUsed) + ...
    uint64(1048576) * cashMicro;

end



function distance = shortest_distances(neighbors, target)

n = numel(neighbors);

distance = inf(n, 1);
distance(target) = 0;

queue = zeros(n, 1);

head = 1;
tail = 1;

queue(tail) = target;


while head <= tail

    current = queue(head);
    head = head + 1;

    nextDistance = distance(current) + 1;

    list = neighbors{current};

    for j = 1:numel(list)

        v = list(j);

        if isinf(distance(v))

            distance(v) = nextDistance;

            tail = tail + 1;
            queue(tail) = v;

        end

    end

end

end



function node = terminal_node()

node.feasible = true;
node.value = -inf;

node.worstWeather = 0;
node.bestAction = empty_action();

node.buyPairs = 0;
node.nextState = [];

node.stepsToEnd = 0;

end



function node = infeasible_node()

node.feasible = false;
node.value = -inf;

node.worstWeather = 0;
node.bestAction = empty_action();

node.buyPairs = 0;
node.nextState = [];

node.stepsToEnd = inf;

end



function branch = infeasible_branch()

branch.feasible = false;
branch.value = -inf;

branch.weather = 0;
branch.action = empty_action();

branch.buyPairs = 0;
branch.nextState = [];

branch.stepsToEnd = inf;

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



function tf = strategy_has_day( ...
    strategies, playerID, day)

tf = false;


if playerID > numel(strategies)
    return;
end


if ~isfield(strategies(playerID), ...
        'feasible') || ...
        ~strategies(playerID).feasible

    return;

end


if ~isfield(strategies(playerID), ...
        'actions')

    return;

end


if day > numel(strategies(playerID).actions)
    return;
end


tf = true;

end



function signature = strategy_signature(strategy)

parts = strings( ...
    1, numel(strategy.actions) + 3);

parts(1) = sprintf( ...
    'W%d', strategy.initialWater);

parts(2) = sprintf( ...
    'F%d', strategy.initialFood);

parts(3) = sprintf( ...
    'A%d', strategy.arrivalDay);


for t = 1:numel(strategy.actions)

    a = strategy.actions(t);

    parts(t + 3) = sprintf( ...
        '%s_%d_%d_%d', ...
        a.type, ...
        a.from, ...
        a.to, ...
        a.buyPairs);

end


signature = strjoin(parts, '|');

end



function strategy = infeasible_strategy( ...
    playerID, data)

strategy.playerID = playerID;
strategy.feasible = false;

strategy.initialWater = 0;
strategy.initialFood = 0;

strategy.actions = repmat( ...
    empty_action(), ...
    1, data.deadline);

strategy.regions = zeros( ...
    1, data.deadline + 1);

strategy.arrivalDay = inf;
strategy.mineDays = 0;

strategy.finalWealth = -inf;
strategy.income = 0;

strategy.representativeWeather = [];

strategy.caseID = data.caseID;

strategy.signature = ...
    sprintf('P%d_INFEASIBLE', ...
    playerID);

end