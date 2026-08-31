function bestStrategy = best_response_case6_fast(playerID, strategies, data)
%BEST_RESPONSE_CASE6_FAST 第六关快速滚动/场景鲁棒最优响应近似
%
% 说明：第六关未来天气没有概率和完整序列。为避免30天完整博弈树爆炸，
% 本程序保持“高温+不超过3天沙暴”的保守思想，但只对一组覆盖早/中/晚
% 沙暴位置的代表性场景求最小收益，再在有限的路线、挖矿天数和补给目标
% 中选最好响应。该实现适合比赛快速计算，但不宣称是完整动态博弈的全局均衡。

routes = build_route_candidates(data);
weatherScenarios = build_weather_scenarios(data.deadline, data.maxStormDays);

pairMax = floor(data.maxLoad / (data.waterWeight + data.foodWeight));
step = data.algorithm.case6InitialPairStep;
initialPairsSet = 120:step:pairMax;
mineDaySet = 0:data.algorithm.case6MineDayMax;
villageTargets = data.algorithm.case6VillageTargets;

bestScore = -inf;
bestWorstArrival = inf;
bestCandidate = [];
numTest = 0;

fprintf('  玩家%d：快速场景鲁棒搜索，%d条路线，%d个天气场景。\n', ...
    playerID, numel(routes), size(weatherScenarios, 1));

for r = 1:numel(routes)
    route = routes{r};
    hasVillage = any(route == data.villageRegions);
    hasMine = any(route == data.mineRegions);

    if hasVillage
        targetSet = villageTargets;
    else
        targetSet = 0;
    end
    if ~hasMine
        mineSet = 0;
    else
        mineSet = mineDaySet;
    end

    for mineDays = mineSet
        for initialPairs = initialPairsSet
            if initialPairs * (data.waterPrice + data.foodPrice) > data.initialCash
                continue;
            end

            for villageTarget = targetSet
                C = make_candidate(playerID, route, mineDays, initialPairs, villageTarget, data);
                [score, worstArrival, worstWeather] = evaluate_candidate( ...
                    C, playerID, strategies, weatherScenarios, data);
                numTest = numTest + 1;

                if score > bestScore + data.algorithm.wealthTolerance || ...
                        (abs(score - bestScore) <= data.algorithm.wealthTolerance && ...
                         worstArrival < bestWorstArrival)
                    bestScore = score;
                    bestWorstArrival = worstArrival;
                    bestCandidate = C;
                    bestCandidate.representativeWeather = worstWeather;
                end
            end
        end
    end

    fprintf('    已完成路线 %d/%d，累计候选%d，当前最好 %.2f 元。\n', ...
        r, numel(routes), numTest, bestScore);
    drawnow;
end

if isempty(bestCandidate) || ~isfinite(bestScore)
    bestStrategy = infeasible_strategy(playerID, data);
    return;
end

bestCandidate.finalWealth = bestScore;
bestCandidate.arrivalDay = bestWorstArrival;
bestCandidate.signature = strategy_signature(bestCandidate);
bestStrategy = bestCandidate;

fprintf(['  玩家%d完成：初始水/食物各%d箱，挖矿目标%d天，' ...
         '保证型近似收益%.2f元。\n'], ...
    playerID, bestStrategy.initialWater, bestStrategy.mineDaysTarget, bestScore);
end


function routes = build_route_candidates(data)
s = data.startRegion; v = data.villageRegions; m = data.mineRegions; e = data.endRegion;
routes = {};
routes{end+1} = shortest_path(data.neighbors, s, e);
routes{end+1} = stitch_paths(data.neighbors, [s v e]);
routes{end+1} = stitch_paths(data.neighbors, [s m e]);
routes{end+1} = stitch_paths(data.neighbors, [s v m e]);
routes{end+1} = stitch_paths(data.neighbors, [s m v e]);

% 去重
sig = strings(numel(routes), 1);
for i = 1:numel(routes), sig(i) = strjoin(string(routes{i}), '-'); end
[~, ia] = unique(sig, 'stable');
routes = routes(ia);
end


function scenarios = build_weather_scenarios(T, maxStorm)
% 非沙暴日取高温；构造覆盖早/中/晚与均匀分布的代表性沙暴场景。
sets = {[]};
anchors = unique(round(linspace(1, T, 5)));
for k = 1:maxStorm
    comb = nchoosek(anchors, k);
    for i = 1:size(comb, 1)
        sets{end+1} = comb(i, :); %#ok<AGROW>
    end
end
% 额外加入前三天、后三天、均匀三天等保守模式
if maxStorm >= 3
    sets{end+1} = 1:3;
    sets{end+1} = T-2:T;
    sets{end+1} = round([T/4 T/2 3*T/4]);
end

scenarios = 2 * ones(numel(sets), T); % 2=高温
for i = 1:numel(sets)
    days = unique(sets{i});
    days = days(days >= 1 & days <= T);
    scenarios(i, days) = 3; % 3=沙暴
end
scenarios = unique(scenarios, 'rows', 'stable');
end


function C = make_candidate(playerID, route, mineDays, initialPairs, villageTarget, data)
C = base_strategy(playerID, data);
C.feasible = true;
C.initialWater = initialPairs;
C.initialFood = initialPairs;
C.policyRoute = route;
C.mineDaysTarget = mineDays;
C.villageTargetPairs = villageTarget;
C.mineDays = mineDays;
end


function [score, worstArrival, worstWeather] = evaluate_candidate( ...
    candidate, playerID, strategies, weatherScenarios, data)
profile = strategies;
if isempty(profile)
    profile = repmat(base_strategy(0, data), 1, data.numPlayers);
end
candidate = ensure_policy(candidate, data);
profile(playerID) = candidate;
for p = 1:data.numPlayers
    if p == playerID, continue; end
    if ~isfield(profile(p), 'feasible') || ~profile(p).feasible
        profile(p) = fallback_strategy(p, data);
    else
        profile(p) = ensure_policy(profile(p), data);
    end
end

score = inf;
worstArrival = 0;
worstWeather = weatherScenarios(1, :);
for s = 1:size(weatherScenarios, 1)
    sim = simulate_profile_fast(profile, weatherScenarios(s, :), data);
    P = sim.players(playerID);
    if ~P.feasible || ~P.arrived
        score = -inf;
        worstArrival = inf;
        worstWeather = weatherScenarios(s, :);
        return;
    end
    if P.finalWealth < score
        score = P.finalWealth;
        worstArrival = P.arrivalDay;
        worstWeather = weatherScenarios(s, :);
    elseif abs(P.finalWealth - score) <= data.algorithm.wealthTolerance
        worstArrival = max(worstArrival, P.arrivalDay);
    end
end
end


function sim = simulate_profile_fast(profile, weather, data)
n = data.numPlayers; T = data.deadline;
state = repmat(struct('region',data.startRegion,'water',0,'food',0,'cash',0, ...
    'routeIndex',1,'mineDone',0,'arrived',false,'arrivalDay',inf,'finalWealth',-inf,'feasible',true), 1, n);

for p = 1:n
    state(p).water = profile(p).initialWater;
    state(p).food = profile(p).initialFood;
    state(p).cash = data.initialCash ...
        - data.waterPrice*profile(p).initialWater ...
        - data.foodPrice*profile(p).initialFood;
    if state(p).cash < -1e-8 || ...
       3*state(p).water + 2*state(p).food > data.maxLoad
        state(p).feasible = false;
    end
end

for t = 1:T
    actions = repmat(empty_action(), 1, n);
    desiredBuy = zeros(1, n);

    for p = 1:n
        if ~state(p).feasible || state(p).arrived
            actions(p).type = 'finished'; actions(p).from = state(p).region; actions(p).to = state(p).region;
            continue;
        end
        actions(p) = policy_action(profile(p), state(p), weather(t), data);
    end

    % 统计移动和挖矿人数
    moveKeys = strings(1,n); mineKeys = strings(1,n);
    for p = 1:n
        if strcmp(actions(p).type,'move')
            moveKeys(p) = sprintf('%d_%d', actions(p).from, actions(p).to);
        elseif strcmp(actions(p).type,'mine')
            mineKeys(p) = sprintf('%d', actions(p).from);
        end
    end

    for p = 1:n
        if ~state(p).feasible || state(p).arrived, continue; end
        A = actions(p); baseW = data.waterBaseUse(weather(t)); baseF = data.foodBaseUse(weather(t)); income = 0;
        switch A.type
            case 'stay'
                factor = 1;
            case 'move'
                factor = 2 * sum(moveKeys == moveKeys(p));
            case 'mine'
                k = sum(mineKeys == mineKeys(p)); factor = 3*k; income = data.mineIncome/k;
            otherwise
                factor = 0;
        end
        state(p).water = state(p).water - factor*baseW;
        state(p).food = state(p).food - factor*baseF;
        state(p).cash = state(p).cash + income;
        state(p).region = A.to;
        if strcmp(A.type,'move'), state(p).routeIndex = state(p).routeIndex + 1; end
        if strcmp(A.type,'mine'), state(p).mineDone = state(p).mineDone + 1; end

        if state(p).water < -1e-8 || state(p).food < -1e-8
            state(p).feasible = false; continue;
        end
        if state(p).region == data.villageRegions && profile(p).villageTargetPairs > 0
            currentPairs = min(state(p).water, state(p).food);
            desiredBuy(p) = max(0, profile(p).villageTargetPairs - currentPairs);
        end
    end

    buyers = find(desiredBuy > 0 & [state.feasible]);
    kBuy = numel(buyers);
    if kBuy == 1, priceFactor = 2; else, priceFactor = 4*kBuy; end
    if kBuy > 0
        onePairPrice = priceFactor * (data.waterPrice + data.foodPrice);
        for p = buyers
            maxByCash = floor(max(0,state(p).cash)/onePairPrice);
            maxPairsLoad = floor((data.maxLoad - 3*state(p).water - 2*state(p).food)/5);
            buy = min([desiredBuy(p), maxByCash, maxPairsLoad]);
            if buy > 0
                state(p).water = state(p).water + buy;
                state(p).food = state(p).food + buy;
                state(p).cash = state(p).cash - buy*onePairPrice;
            end
        end
    end

    for p = 1:n
        if ~state(p).feasible || state(p).arrived, continue; end
        if state(p).region == data.endRegion
            state(p).arrived = true; state(p).arrivalDay = t;
            state(p).finalWealth = state(p).cash ...
                + data.returnWaterPrice*state(p).water ...
                + data.returnFoodPrice*state(p).food;
        end
    end
end

sim.players = state;
end


function A = policy_action(strategy, S, weather, data)
A = empty_action(); A.from = S.region; A.to = S.region;
if S.region == data.mineRegions && S.mineDone < strategy.mineDaysTarget
    A.type = 'mine'; return;
end
if weather == 3
    A.type = 'stay'; return;
end
route = strategy.policyRoute;
idx = min(S.routeIndex, numel(route));
if idx < numel(route)
    next = route(idx + 1);
    if ismember(next, data.neighbors{S.region})
        A.type = 'move'; A.to = next; return;
    end
end
A.type = 'stay';
end


function s = ensure_policy(s, data)
if ~isfield(s,'policyRoute') || isempty(s.policyRoute)
    if isfield(s,'regions') && any(s.regions)
        k = find(s.regions>0,1,'last'); s.policyRoute = s.regions(1:k);
    else
        s.policyRoute = shortest_path(data.neighbors,data.startRegion,data.endRegion);
    end
end
if ~isfield(s,'mineDaysTarget'), s.mineDaysTarget = s.mineDays; end
if ~isfield(s,'villageTargetPairs'), s.villageTargetPairs = 0; end
end

function s = fallback_strategy(playerID, data)
s = base_strategy(playerID,data); s.feasible=true;
s.initialWater=220; s.initialFood=220;
s.policyRoute=shortest_path(data.neighbors,data.startRegion,data.endRegion);
s.mineDaysTarget=0; s.villageTargetPairs=0;
end

function path = stitch_paths(neighbors, waypoints)
path = waypoints(1);
for i=1:numel(waypoints)-1
    q = shortest_path(neighbors,waypoints(i),waypoints(i+1));
    path = [path q(2:end)]; %#ok<AGROW>
end
end

function path = shortest_path(neighbors, s, t)
n=numel(neighbors); prev=zeros(1,n); seen=false(1,n); q=zeros(1,n); h=1; tt=1; q(1)=s; seen(s)=true;
while h<=tt
    u=q(h); h=h+1; if u==t, break; end
    for v=neighbors{u}
        if ~seen(v), seen(v)=true; prev(v)=u; tt=tt+1; q(tt)=v; end
    end
end
if ~seen(t), path=[]; return; end
path=t; u=t;
while u~=s, u=prev(u); path=[u path]; end %#ok<AGROW>
end

function s = base_strategy(playerID, data)
s.playerID=playerID; s.feasible=false; s.initialWater=0; s.initialFood=0;
s.actions=repmat(empty_action(),1,data.deadline); s.regions=zeros(1,data.deadline+1);
s.arrivalDay=inf; s.mineDays=0; s.finalWealth=-inf; s.income=0;
s.representativeWeather=[]; s.caseID=data.caseID; s.signature='EMPTY';
s.policyRoute=[]; s.mineDaysTarget=0; s.villageTargetPairs=0;
end

function s = infeasible_strategy(playerID,data)
s=base_strategy(playerID,data); s.signature=sprintf('P%d_INFEASIBLE',playerID);
end

function a=empty_action(), a.type='none'; a.from=0; a.to=0; a.buyPairs=0; end

function sig=strategy_signature(s)
sig=sprintf('P%d|I%d|M%d|V%d|R%s',s.playerID,s.initialWater,s.mineDaysTarget, ...
    s.villageTargetPairs,strjoin(string(s.policyRoute),'-'));
end
