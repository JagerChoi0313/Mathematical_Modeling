function dpResult = solve_case3(data)
%SOLVE_CASE3 用Bellman倒推求第三关保证型动态策略

T = data.deadline;
nRegion = data.numRegions;
Wmax = data.maxWater;
Fmax = data.maxFood;

waterGrid = (0:Wmax)';
foodGrid = 0:Fmax;
loadMatrix = data.waterWeight * waterGrid + data.foodWeight * foodGrid;
validLoad = loadMatrix <= data.maxLoad;

refundMatrix = data.refundWaterPrice * waterGrid + ...
    data.refundFoodPrice * foodGrid;
refundMatrix(~validLoad) = -Inf;

% U_next表示下一天尚未观察天气时的保证价值。
% T+1时只有已经位于终点的状态有效。
U_next = -Inf(nRegion, Wmax + 1, Fmax + 1);
U_next(data.endRegion, :, :) = reshape(refundMatrix, 1, Wmax + 1, Fmax + 1);

% 每个元素保存该日期、该天气、该状态下的最优动作编码
policy = cell(T, 3);

startTime = tic;

for t = T:-1:1
    U_current = [];

    for weatherID = data.allowedWeather
        V = -Inf(nRegion, Wmax + 1, Fmax + 1);
        P = zeros(nRegion, Wmax + 1, Fmax + 1, 'uint8');

        % 到达终点后游戏已经结束，不再发生行动和资源消耗
        V(data.endRegion, :, :) = reshape(refundMatrix, 1, Wmax + 1, Fmax + 1);

        for region = 1:nRegion
            if region == data.endRegion
                continue;
            end

            actions = generate_actions_case3(region, weatherID, data);
            bestValue = squeeze(V(region, :, :));
            bestCode = squeeze(P(region, :, :));

            for a = 1:numel(actions)
                waterUse = data.waterBaseUse(weatherID) * actions(a).multiplier;
                foodUse = data.foodBaseUse(weatherID) * actions(a).multiplier;

                if waterUse > Wmax || foodUse > Fmax
                    continue;
                end

                nextRegion = actions(a).nextRegion;

                % 当前资源(w,f)完成行动后转移至(w-waterUse,f-foodUse)
                futureValue = squeeze(U_next(nextRegion, ...
                    1:(Wmax + 1 - waterUse), ...
                    1:(Fmax + 1 - foodUse)));

                candidate = -Inf(Wmax + 1, Fmax + 1);
                candidate((waterUse + 1):end, (foodUse + 1):end) = ...
                    futureValue + actions(a).reward;

                % 当前携带量本身也必须满足1200 kg负重限制
                candidate(~validLoad) = -Inf;

                better = candidate > bestValue;
                bestValue(better) = candidate(better);
                bestCode(better) = actions(a).code;
            end

            V(region, :, :) = reshape(bestValue, 1, Wmax + 1, Fmax + 1);
            P(region, :, :) = reshape(bestCode, 1, Wmax + 1, Fmax + 1);
        end

        policy{t, weatherID} = P;

        if isempty(U_current)
            U_current = V;
        else
            % 未来天气没有概率数据，按已确定模型取允许天气中的最小价值
            U_current = min(U_current, V);
        end
    end

    U_next = U_current;
    fprintf('  已完成第 %d 天的倒推。\n', t);
end

% 第0天枚举初始购买量。第三关没有村庄，后续不再发生购买。
U1Start = squeeze(U_next(data.startRegion, :, :));
initialCashMatrix = data.initialCash ...
    - data.waterPrice * waterGrid ...
    - data.foodPrice * foodGrid;

feasibleInitial = validLoad & (initialCashMatrix >= 0);
objective = -Inf(Wmax + 1, Fmax + 1);
objective(feasibleInitial) = initialCashMatrix(feasibleInitial) ...
    + U1Start(feasibleInitial);

[bestValue, bestIndex] = max(objective(:));
if isinf(bestValue) && bestValue < 0
    error('第三关在当前模型下没有找到可保证到达终点的初始方案。');
end

[waterIndex, foodIndex] = ind2sub(size(objective), bestIndex);
bestWater = waterIndex - 1;
bestFood = foodIndex - 1;
bestCash = data.initialCash ...
    - data.waterPrice * bestWater ...
    - data.foodPrice * bestFood;

elapsedTime = toc(startTime);

dpResult.policy = policy;
dpResult.bestInitialWater = bestWater;
dpResult.bestInitialFood = bestFood;
dpResult.bestInitialCash = bestCash;
dpResult.guaranteedWealth = bestValue;
dpResult.runtime = elapsedTime;

dpResult.stateSize = [nRegion, Wmax + 1, Fmax + 1];
dpResult.allowedWeather = data.allowedWeather;

fprintf('动态规划完成，用时 %.2f s。\n', elapsedTime);
end
