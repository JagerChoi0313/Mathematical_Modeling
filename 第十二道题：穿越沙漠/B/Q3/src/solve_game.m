function gameResult = solve_game(data)
%SOLVE_GAME 多玩家最优响应迭代

n = data.numPlayers;

template = empty_strategy(data);
emptyProfile = repmat(template, 1, n);

fprintf('正在生成初始可行策略...\n');


% 所有玩家初始条件完全相同。
% 先在"其他玩家尚未产生影响"的情况下求一个基准策略，
% 再复制给其他玩家，减少重复动态规划。
baseStrategy = ...
    best_response(1, emptyProfile, data);

baseStrategy = ...
    standardize_strategy( ...
    baseStrategy, data);


if ~baseStrategy.feasible

    error('未找到初始保证型可行策略。');

end


strategies = repmat(baseStrategy, 1, n);

for playerID = 1:n

    strategies(playerID).playerID = playerID;

end


history = zeros(0, n);

signatureHistory = strings(0, 1);

signatureHistory(end + 1, 1) = ...
    joint_signature(strategies);


converged = false;
cycleDetected = false;


for iteration = 1:data.algorithm.maxGameIterations

    fprintf('\n开始第 %d 轮最优响应迭代。\n', ...
        iteration);

    oldStrategies = strategies;


    for playerID = 1:n

        fprintf('  正在计算玩家 %d/%d 的最优响应...\n', ...
            playerID, n);

        newStrategy = ...
            best_response( ...
            playerID, ...
            strategies, ...
            data);

        newStrategy = ...
            standardize_strategy( ...
            newStrategy, data);


        if newStrategy.feasible

            strategies(playerID) = ...
                newStrategy;

        else

            fprintf(['  玩家%d未找到新的可行响应，' ...
                     '保留上一轮策略。\n'], ...
                playerID);

        end

    end


    newWealth = ...
        [strategies.finalWealth];

    history(end + 1, :) = ...
        newWealth; %#ok<AGROW>


    fprintf('第 %d 轮结果：', iteration);

    for playerID = 1:n

        fprintf(' 玩家%d %.2f元', ...
            playerID, ...
            newWealth(playerID));

    end

    fprintf('\n');


    strategySame = true;

    for playerID = 1:n

        if ~strcmp( ...
                oldStrategies(playerID).signature, ...
                strategies(playerID).signature)

            strategySame = false;
            break;

        end

    end


    if strategySame

        converged = true;

        fprintf('所有玩家策略均未发生变化，达到稳定状态。\n');

        break;

    end


    currentSignature = ...
        joint_signature(strategies);


    if any(signatureHistory == currentSignature)

        cycleDetected = true;

        fprintf(['检测到已出现过的策略组合，' ...
                 '最优响应进入循环。\n']);

        break;

    end


    signatureHistory(end + 1, 1) = ...
        currentSignature; %#ok<AGROW>

end


gameResult.strategies = strategies;

gameResult.iterationHistory = history;

gameResult.converged = converged;
gameResult.cycleDetected = cycleDetected;

gameResult.iterations = ...
    size(history, 1);


if data.caseID == 6

    if ~isempty( ...
            strategies(1).representativeWeather)

        gameResult.representativeWeather = ...
            strategies(1).representativeWeather;

    else

        gameResult.representativeWeather = [ ...
            repmat(3, 1, data.maxStormDays), ...
            repmat(2, 1, ...
            data.deadline - ...
            data.maxStormDays)];

    end

end

end



function strategy = empty_strategy(data)

action.type = 'none';
action.from = 0;
action.to = 0;
action.buyPairs = 0;

strategy.playerID = 0;
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
strategy.signature = 'EMPTY';

end



function strategy = ...
    standardize_strategy(strategy, data)

template = empty_strategy(data);

fieldNames = fieldnames(template);


for k = 1:numel(fieldNames)

    name = fieldNames{k};

    if ~isfield(strategy, name)

        strategy.(name) = ...
            template.(name);

    end

end


strategyFields = fieldnames(strategy);


for k = 1:numel(strategyFields)

    name = strategyFields{k};

    if ~isfield(template, name)

        strategy = ...
            rmfield(strategy, name);

    end

end


strategy = orderfields( ...
    strategy, template);

end



function signature = ...
    joint_signature(strategies)

parts = strings( ...
    1, numel(strategies));


for i = 1:numel(strategies)

    parts(i) = ...
        strategies(i).signature;

end


signature = strjoin(parts, '||');

end