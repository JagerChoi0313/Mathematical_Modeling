function simulation = simulate_strategy(strategies, gameResult, data)
%SIMULATE_STRATEGY 正向执行最终策略，形成逐日结果

if data.caseID == 5
    weather = data.weather;
else
    weather = gameResult.representativeWeather;
end

n = data.numPlayers;
T = data.deadline;
players = repmat(empty_player(T), 1, n);

for p = 1:n
    players(p).initialWater = strategies(p).initialWater;
    players(p).initialFood = strategies(p).initialFood;
    players(p).region(1) = data.startRegion;
    players(p).water(1) = strategies(p).initialWater;
    players(p).food(1) = strategies(p).initialFood;
    players(p).cash(1) = data.initialCash ...
        - data.waterPrice * strategies(p).initialWater ...
        - data.foodPrice * strategies(p).initialFood;
end

interactions = strings(T, 1);

for t = 1:T
    actions = repmat(empty_action(), 1, n);
    desiredBuy = zeros(1, n);

    for p = 1:n
        if players(p).arrived
            actions(p).type = 'finished';
            actions(p).from = players(p).region(t);
            actions(p).to = players(p).region(t);
        elseif data.caseID == 5
            actions(p) = strategies(p).actions(t);
            if strcmp(actions(p).type, 'none')
                actions(p).type = 'stay';
                actions(p).from = players(p).region(t);
                actions(p).to = players(p).region(t);
            end
            if weather(t) == 3 && strcmp(actions(p).type, 'move')
                actions(p).type = 'stay';
                actions(p).to = players(p).region(t);
            end
        else
            actions(p) = policy_action( ...
                strategies(p), players(p).region(t), players(p).routeIndex, ...
                players(p).mineDays, weather(t), data);
        end
    end

    moveKeys = strings(1, n);
    mineKeys = strings(1, n);
    for p = 1:n
        if strcmp(actions(p).type, 'move')
            moveKeys(p) = sprintf('%d_%d', actions(p).from, actions(p).to);
        elseif strcmp(actions(p).type, 'mine')
            mineKeys(p) = sprintf('%d', actions(p).from);
        end
    end

    eventText = strings(0, 1);
    uMove = unique(moveKeys(moveKeys ~= ""));
    for k = 1:numel(uMove)
        cnt = sum(moveKeys == uMove(k));
        if cnt >= 2
            eventText(end+1) = sprintf('同行%s:%d人', uMove(k), cnt); %#ok<AGROW>
        end
    end
    uMine = unique(mineKeys(mineKeys ~= ""));
    for k = 1:numel(uMine)
        cnt = sum(mineKeys == uMine(k));
        if cnt >= 2
            eventText(end+1) = sprintf('同矿%s:%d人', uMine(k), cnt); %#ok<AGROW>
        end
    end

    for p = 1:n
        % 先把上一日状态复制到今日末状态
        players(p).region(t+1) = players(p).region(t);
        players(p).water(t+1) = players(p).water(t);
        players(p).food(t+1) = players(p).food(t);
        players(p).cash(t+1) = players(p).cash(t);

        if players(p).arrived
            players(p).action(t) = "已到终点";
            continue;
        end

        A = actions(p);
        baseW = data.waterBaseUse(weather(t));
        baseF = data.foodBaseUse(weather(t));
        income = 0;

        switch A.type
            case 'stay'
                factor = 1;
            case 'move'
                factor = 2 * sum(moveKeys == moveKeys(p));
            case 'mine'
                kk = sum(mineKeys == mineKeys(p));
                factor = 3 * kk;
                income = data.mineIncome / kk;
            otherwise
                factor = 0;
        end

        players(p).water(t+1) = players(p).water(t) - factor * baseW;
        players(p).food(t+1) = players(p).food(t) - factor * baseF;
        players(p).cash(t+1) = players(p).cash(t) + income;
        players(p).region(t+1) = A.to;
        players(p).action(t) = action_text(A);

        if strcmp(A.type, 'move')
            players(p).routeIndex = players(p).routeIndex + 1;
        elseif strcmp(A.type, 'mine')
            players(p).mineDays = players(p).mineDays + 1;
        end

        if data.caseID == 6 && players(p).region(t+1) == data.villageRegions ...
                && strategies(p).villageTargetPairs > 0
            cur = min(players(p).water(t+1), players(p).food(t+1));
            desiredBuy(p) = max(0, strategies(p).villageTargetPairs - cur);
        end
    end

    buyers = find(desiredBuy > 0 & ~[players.arrived]);
    if ~isempty(buyers)
        if numel(buyers) == 1
            priceFactor = 2;
        else
            priceFactor = 4 * numel(buyers);
            eventText(end+1) = sprintf('同村购买:%d人', numel(buyers)); %#ok<AGROW>
        end
        pairPrice = priceFactor * (data.waterPrice + data.foodPrice);

        for p = buyers
            maxCash = floor(max(0, players(p).cash(t+1)) / pairPrice);
            maxLoad = floor((data.maxLoad ...
                - 3*players(p).water(t+1) - 2*players(p).food(t+1)) / 5);
            buy = min([desiredBuy(p), maxCash, maxLoad]);
            if buy > 0
                players(p).water(t+1) = players(p).water(t+1) + buy;
                players(p).food(t+1) = players(p).food(t+1) + buy;
                players(p).cash(t+1) = players(p).cash(t+1) - buy * pairPrice;
                players(p).action(t) = players(p).action(t) + sprintf('；补给%d对', buy);
            end
        end
    end

    for p = 1:n
        if players(p).arrived
            continue;
        end

        if players(p).water(t+1) < -1e-8 || players(p).food(t+1) < -1e-8 ...
                || players(p).cash(t+1) < -1e-8
            players(p).feasible = false;
        end

        if players(p).region(t+1) == data.endRegion
            players(p).arrived = true;
            players(p).arrivalDay = t;
            players(p).finalWealth = players(p).cash(t+1) ...
                + data.returnWaterPrice * players(p).water(t+1) ...
                + data.returnFoodPrice * players(p).food(t+1);
        end
    end

    if isempty(eventText)
        interactions(t) = "无";
    else
        interactions(t) = strjoin(eventText, '；');
    end
end

simulation.players = players;
simulation.weather = weather;
simulation.interactions = interactions;
end


function A = policy_action(strategy, region, routeIndex, mineDone, weather, data)
A = empty_action();
A.from = region;
A.to = region;

if region == data.mineRegions && mineDone < strategy.mineDaysTarget
    A.type = 'mine';
    return;
end

if weather == 3
    A.type = 'stay';
    return;
end

route = strategy.policyRoute;
idx = min(routeIndex, numel(route));
if idx < numel(route)
    nxt = route(idx + 1);
    if ismember(nxt, data.neighbors{region})
        A.type = 'move';
        A.to = nxt;
        return;
    end
end
A.type = 'stay';
end


function P = empty_player(T)
P.initialWater=0; P.initialFood=0;
P.region=zeros(1,T+1); P.water=zeros(1,T+1); P.food=zeros(1,T+1); P.cash=zeros(1,T+1);
P.action=strings(1,T); P.arrived=false; P.arrivalDay=inf; P.finalWealth=-inf;
P.mineDays=0; P.feasible=true; P.routeIndex=1;
end

function A = empty_action()
A.type='none'; A.from=0; A.to=0; A.buyPairs=0;
end

function txt = action_text(A)
switch A.type
    case 'stay', txt="停留";
    case 'move', txt=sprintf('%d→%d',A.from,A.to);
    case 'mine', txt="挖矿";
    otherwise, txt=string(A.type);
end
end
