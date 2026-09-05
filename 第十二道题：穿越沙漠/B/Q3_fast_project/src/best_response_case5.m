function bestStrategy = best_response_case5(playerID, strategies, data)
%BEST_RESPONSE_CASE5 固定另一名玩家策略，求第五关完整策略最优响应

T = data.deadline;
emptyA = empty_action();

state.day = 0;
state.region = data.startRegion;
state.waterUse = 0;
state.foodUse = 0;
state.income = 0;
state.mineDays = 0;
state.actions = repmat(emptyA, 1, T);
state.regions = zeros(1, T + 1);
state.regions(1) = data.startRegion;

states = state;
terminal = struct([]);

for t = 1:T
    nextStates = struct([]);

    for s = 1:numel(states)
        S = states(s);
        actions = legal_actions(S.region, data.weather(t), data);

        for a = 1:numel(actions)
            A = actions(a);
            [dW, dF, income] = action_effect(playerID, t, A, strategies, data);

            N = S;
            N.day = t;
            N.region = A.to;
            N.waterUse = S.waterUse + dW;
            N.foodUse = S.foodUse + dF;
            N.income = S.income + income;
            N.actions(t) = A;
            N.regions(t + 1) = A.to;
            if strcmp(A.type, 'mine')
                N.mineDays = S.mineDays + 1;
            end

            loadKg = data.waterWeight * N.waterUse + data.foodWeight * N.foodUse;
            initialCost = data.waterPrice * N.waterUse + data.foodPrice * N.foodUse;
            if loadKg > data.maxLoad || initialCost > data.initialCash
                continue;
            end

            if N.region == data.endRegion
                terminal = append_struct(terminal, N);
            else
                nextStates = append_struct(nextStates, N);
            end
        end
    end

    if isempty(nextStates)
        break;
    end
    states = prune_states(nextStates);
end

if isempty(terminal)
    bestStrategy = infeasible_strategy(playerID, data);
    return;
end

bestValue = -inf;
bestIdx = 0;
for s = 1:numel(terminal)
    S = terminal(s);
    % 第五关无村庄，超额初始购买只会以半价退回，故最优初购=总消耗。
    finalWealth = data.initialCash ...
        - data.waterPrice * S.waterUse ...
        - data.foodPrice * S.foodUse ...
        + S.income;

    if finalWealth > bestValue + data.algorithm.wealthTolerance
        bestValue = finalWealth;
        bestIdx = s;
    elseif abs(finalWealth - bestValue) <= data.algorithm.wealthTolerance
        old = terminal(bestIdx);
        if S.day < old.day || (S.day == old.day && ...
                3*S.waterUse + 2*S.foodUse < 3*old.waterUse + 2*old.foodUse)
            bestIdx = s;
        end
    end
end

S = terminal(bestIdx);
bestStrategy = base_strategy(playerID, data);
bestStrategy.feasible = true;
bestStrategy.initialWater = S.waterUse;
bestStrategy.initialFood = S.foodUse;
bestStrategy.actions = S.actions;
bestStrategy.regions = S.regions;
bestStrategy.arrivalDay = S.day;
bestStrategy.mineDays = S.mineDays;
bestStrategy.finalWealth = bestValue;
bestStrategy.income = S.income;
bestStrategy.policyRoute = S.regions(1:S.day + 1);
bestStrategy.mineDaysTarget = S.mineDays;
bestStrategy.signature = strategy_signature(bestStrategy);
end


function actions = legal_actions(region, weather, data)
actions = struct([]);
a = empty_action(); a.type = 'stay'; a.from = region; a.to = region;
actions = append_struct(actions, a);

if weather ~= 3
    for v = data.neighbors{region}
        a = empty_action(); a.type = 'move'; a.from = region; a.to = v;
        actions = append_struct(actions, a);
    end
end

if ismember(region, data.mineRegions)
    a = empty_action(); a.type = 'mine'; a.from = region; a.to = region;
    actions = append_struct(actions, a);
end
end


function [dW, dF, income] = action_effect(playerID, day, action, strategies, data)
weather = data.weather(day);
baseW = data.waterBaseUse(weather);
baseF = data.foodBaseUse(weather);
income = 0;

switch action.type
    case 'stay'
        factor = 1;
    case 'move'
        k = 1;
        for p = 1:numel(strategies)
            if p == playerID || ~has_action(strategies, p, day), continue; end
            O = strategies(p).actions(day);
            if strcmp(O.type, 'move') && O.from == action.from && O.to == action.to
                k = k + 1;
            end
        end
        factor = 2 * k;
    case 'mine'
        k = 1;
        for p = 1:numel(strategies)
            if p == playerID || ~has_action(strategies, p, day), continue; end
            O = strategies(p).actions(day);
            if strcmp(O.type, 'mine') && O.from == action.from
                k = k + 1;
            end
        end
        factor = 3 * k;
        income = data.mineIncome / k;
    otherwise
        factor = 1;
end

dW = factor * baseW;
dF = factor * baseF;
end


function states = prune_states(states)
keys = strings(numel(states), 1);
for i = 1:numel(states)
    keys(i) = sprintf('%d_%d_%d_%d', states(i).day, states(i).region, ...
        states(i).waterUse, states(i).foodUse);
end
[~, ~, g] = unique(keys);
out = struct([]);
for k = 1:max(g)
    ids = find(g == k);
    [~, j] = max([states(ids).income]);
    out = append_struct(out, states(ids(j)));
end
states = out;
end


function tf = has_action(strategies, p, day)
tf = p <= numel(strategies) && isfield(strategies(p), 'feasible') ...
    && strategies(p).feasible && day <= numel(strategies(p).actions);
end


function s = base_strategy(playerID, data)
s.playerID = playerID;
s.feasible = false;
s.initialWater = 0;
s.initialFood = 0;
s.actions = repmat(empty_action(), 1, data.deadline);
s.regions = zeros(1, data.deadline + 1);
s.arrivalDay = inf;
s.mineDays = 0;
s.finalWealth = -inf;
s.income = 0;
s.representativeWeather = [];
s.caseID = data.caseID;
s.signature = 'EMPTY';
s.policyRoute = [];
s.mineDaysTarget = 0;
s.villageTargetPairs = 0;
end

function s = infeasible_strategy(playerID, data)
s = base_strategy(playerID, data);
s.signature = sprintf('P%d_INFEASIBLE', playerID);
end

function a = empty_action()
a.type = 'none'; a.from = 0; a.to = 0; a.buyPairs = 0;
end

function arr = append_struct(arr, item)
if isempty(arr), arr = item; else, arr(end + 1) = item; end
end

function sig = strategy_signature(s)
parts = strings(1, s.arrivalDay + 3);
parts(1) = sprintf('W%d', s.initialWater);
parts(2) = sprintf('F%d', s.initialFood);
parts(3) = sprintf('A%d', s.arrivalDay);
for t = 1:s.arrivalDay
    a = s.actions(t);
    parts(t + 3) = sprintf('%s_%d_%d', a.type, a.from, a.to);
end
sig = strjoin(parts, '|');
end
