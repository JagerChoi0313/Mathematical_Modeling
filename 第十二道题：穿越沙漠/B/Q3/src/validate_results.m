function validation = validate_results( ...
    simulation, gameResult, data)
%VALIDATE_RESULTS 对第三问结果进行逐日规则复核

n = data.numPlayers;
T = data.deadline;

loadPassed = true;
resourcePassed = true;
cashPassed = true;
pathPassed = true;
stormPassed = true;
deadlinePassed = true;
interactionPassed = true;

messages = strings(0, 1);


for i = 1:n

    P = simulation.players(i);

    for t = 0:T

        idx = t + 1;

        loadValue = ...
            data.waterWeight * P.water(idx) + ...
            data.foodWeight * P.food(idx);

        if loadValue > data.maxLoad + 1e-8
            loadPassed = false;

            messages(end + 1) = sprintf( ...
                '玩家%d第%d天负重超过上限。', i, t); %#ok<AGROW>
        end

        if P.water(idx) < -1e-8 || ...
                P.food(idx) < -1e-8

            resourcePassed = false;

            messages(end + 1) = sprintf( ...
                '玩家%d第%d天出现负资源。', i, t); %#ok<AGROW>
        end

        if P.cash(idx) < -1e-8

            cashPassed = false;

            messages(end + 1) = sprintf( ...
                '玩家%d第%d天现金为负。', i, t); %#ok<AGROW>
        end

    end


    for t = 1:T

        if t > P.arrivalDay
            continue;
        end

        from = P.region(t);
        to = P.region(t + 1);

        if from ~= to && ...
                ~ismember(to, data.neighbors{from})

            pathPassed = false;

            messages(end + 1) = sprintf( ...
                '玩家%d第%d天存在非相邻移动 %d→%d。', ...
                i, t, from, to); %#ok<AGROW>
        end

        if simulation.weather(t) == 3 && ...
                from ~= to

            stormPassed = false;

            messages(end + 1) = sprintf( ...
                '玩家%d第%d天沙暴期间发生移动。', ...
                i, t); %#ok<AGROW>
        end

    end


    if ~isfinite(P.arrivalDay) || ...
            P.arrivalDay > data.deadline

        deadlinePassed = false;

        messages(end + 1) = sprintf( ...
            '玩家%d未在截止日期前到达终点。', i); %#ok<AGROW>
    end

end


% 多人同行人数复核
for t = 1:T

    for i = 1:n

        Pi = simulation.players(i);

        if t > Pi.arrivalDay
            continue;
        end

        fromI = Pi.region(t);
        toI = Pi.region(t + 1);

        if fromI == toI
            continue;
        end

        k = 0;

        for j = 1:n

            Pj = simulation.players(j);

            if Pj.region(t) == fromI && ...
                    Pj.region(t + 1) == toI

                k = k + 1;

            end

        end

        if k < 1
            interactionPassed = false;
        end

    end

end


validation.loadPassed = loadPassed;
validation.resourcePassed = resourcePassed;
validation.cashPassed = cashPassed;
validation.pathPassed = pathPassed;
validation.stormPassed = stormPassed;
validation.deadlinePassed = deadlinePassed;
validation.interactionPassed = interactionPassed;

validation.strategyConverged = gameResult.converged;
validation.cycleDetected = gameResult.cycleDetected;

validation.messages = messages;

validation.allPassed = ...
    loadPassed && ...
    resourcePassed && ...
    cashPassed && ...
    pathPassed && ...
    stormPassed && ...
    deadlinePassed && ...
    interactionPassed;

end