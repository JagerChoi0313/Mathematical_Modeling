function simulation = simulate_strategy(strategies, data)
%SIMULATE_STRATEGY 正向还原所有玩家的稳定策略

n = data.numPlayers;
T = data.deadline;

if data.caseID == 5
    weather = data.weather;
else
    weather = representative_weather(strategies, data);
end


players = repmat(empty_player_result(T), 1, n);

for i = 1:n

    players(i).initialWater = strategies(i).initialWater;
    players(i).initialFood = strategies(i).initialFood;

    players(i).region(1) = data.startRegion;
    players(i).water(1) = strategies(i).initialWater;
    players(i).food(1) = strategies(i).initialFood;

    players(i).cash(1) = ...
        data.initialCash ...
        - data.waterPrice * strategies(i).initialWater ...
        - data.foodPrice * strategies(i).initialFood;

end


interactionRows = struct([]);

for t = 1:T

    actions = repmat(empty_action(), 1, n);

    for i = 1:n

        if players(i).arrived
            actions(i).type = 'finished';
            actions(i).from = players(i).region(t);
            actions(i).to = players(i).region(t);
            continue;
        end

        actions(i) = strategies(i).actions(t);

        % 若策略后半段为空，则保持原地。
        if strcmp(actions(i).type, 'none')
            actions(i).type = 'stay';
            actions(i).from = players(i).region(t);
            actions(i).to = players(i).region(t);
        end

        % 保证行动起点与当前实际区域一致。
        if actions(i).from ~= players(i).region(t)

            actions(i).from = players(i).region(t);

            if strcmp(actions(i).type, 'move') && ...
                    ~ismember(actions(i).to, ...
                    data.neighbors{players(i).region(t)})

                actions(i).type = 'stay';
                actions(i).to = players(i).region(t);

            end

        end

        if weather(t) == 3 && strcmp(actions(i).type, 'move')

            actions(i).type = 'stay';
            actions(i).to = players(i).region(t);

        end

    end


    % 统计多人同行、挖矿和购买
    moveCount = containers.Map('KeyType', 'char', 'ValueType', 'double');
    mineCount = containers.Map('KeyType', 'char', 'ValueType', 'double');
    buyCount = containers.Map('KeyType', 'char', 'ValueType', 'double');

    for i = 1:n

        a = actions(i);

        if strcmp(a.type, 'move')

            key = sprintf('%d_%d', a.from, a.to);
            moveCount(key) = get_count(moveCount, key) + 1;

        elseif strcmp(a.type, 'mine')

            key = sprintf('%d', a.from);
            mineCount(key) = get_count(mineCount, key) + 1;

        end

        if a.buyPairs > 0

            key = sprintf('%d', a.to);
            buyCount(key) = get_count(buyCount, key) + 1;

        end

    end


    for i = 1:n

        players(i).region(t + 1) = players(i).region(t);
        players(i).water(t + 1) = players(i).water(t);
        players(i).food(t + 1) = players(i).food(t);
        players(i).cash(t + 1) = players(i).cash(t);

        if players(i).arrived
            players(i).action{t} = '已到终点';
            continue;
        end

        a = actions(i);

        baseWater = data.waterBaseUse(weather(t));
        baseFood = data.foodBaseUse(weather(t));

        factor = 0;
        income = 0;

        switch a.type

            case 'stay'

                factor = 1;

            case 'move'

                key = sprintf('%d_%d', a.from, a.to);
                k = moveCount(key);
                factor = 2 * k;

            case 'mine'

                key = sprintf('%d', a.from);
                k = mineCount(key);

                factor = 3 * k;
                income = data.mineIncome / k;

            otherwise

                factor = 0;

        end

        waterUse = factor * baseWater;
        foodUse = factor * baseFood;

        players(i).water(t + 1) = ...
            players(i).water(t) - waterUse;

        players(i).food(t + 1) = ...
            players(i).food(t) - foodUse;

        players(i).cash(t + 1) = ...
            players(i).cash(t) + income;

        players(i).region(t + 1) = a.to;

        if a.buyPairs > 0

            key = sprintf('%d', a.to);
            k = buyCount(key);

            if k == 1
                priceFactor = 2;
            else
                priceFactor = 4 * k;
            end

            buyCost = ...
                a.buyPairs * priceFactor * ...
                (data.waterPrice + data.foodPrice);

            players(i).water(t + 1) = ...
                players(i).water(t + 1) + a.buyPairs;

            players(i).food(t + 1) = ...
                players(i).food(t + 1) + a.buyPairs;

            players(i).cash(t + 1) = ...
                players(i).cash(t + 1) - buyCost;

        end

        players(i).action{t} = action_text(a);

        if strcmp(a.type, 'mine')
            players(i).mineDays = players(i).mineDays + 1;
        end

        if a.to == data.endRegion

            players(i).arrived = true;
            players(i).arrivalDay = t;

            players(i).finalWealth = ...
                players(i).cash(t + 1) + ...
                data.returnWaterPrice * ...
                players(i).water(t + 1) + ...
                data.returnFoodPrice * ...
                players(i).food(t + 1);

        end

    end


    row.day = t;
    row.weather = weather(t);
    row.moveCount = moveCount;
    row.mineCount = mineCount;
    row.buyCount = buyCount;

    interactionRows = append_struct(interactionRows, row);

end


for i = 1:n

    if ~players(i).arrived
        players(i).arrivalDay = inf;
        players(i).finalWealth = -inf;
    end

end


simulation.players = players;
simulation.weather = weather;
simulation.interactions = interactionRows;
simulation.data = data;

end


function weather = representative_weather(strategies, data)

weather = zeros(1, data.deadline);

if isfield(strategies(1), 'representativeWeather')

    temp = strategies(1).representativeWeather;
    weather(1:min(numel(temp), data.deadline)) = ...
        temp(1:min(numel(temp), data.deadline));

end

weather(weather == 0) = 2;

end


function player = empty_player_result(T)

player.initialWater = 0;
player.initialFood = 0;

player.region = zeros(1, T + 1);
player.water = zeros(1, T + 1);
player.food = zeros(1, T + 1);
player.cash = zeros(1, T + 1);

player.action = cell(1, T);

player.arrived = false;
player.arrivalDay = inf;
player.finalWealth = -inf;
player.mineDays = 0;

end


function action = empty_action()

action.type = 'none';
action.from = 0;
action.to = 0;
action.buyPairs = 0;

end


function textValue = action_text(action)

switch action.type

    case 'stay'
        textValue = '停留';

    case 'move'
        textValue = sprintf('%d→%d', ...
            action.from, action.to);

    case 'mine'
        textValue = '挖矿';

    otherwise
        textValue = action.type;

end

if action.buyPairs > 0
    textValue = sprintf('%s；补给%d对', ...
        textValue, action.buyPairs);
end

end


function value = get_count(mapObj, key)

if isKey(mapObj, key)
    value = mapObj(key);
else
    value = 0;
end

end


function array = append_struct(array, item)

if isempty(array)
    array = item;
else
    array(end + 1) = item;
end

end