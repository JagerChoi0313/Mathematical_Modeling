function dpResult = solve_case4(data)
%SOLVE_CASE4 保证型Bellman动态规划
%
% 价值函数记录“从当前状态开始，未来可保证获得的净现金变化+终点退款”。
% 为避免无来源的天气概率，未来天气采用高温/沙暴的最不利分支；
% 沙暴累计不超过 data.maxStormDays。

T = data.deadline;
N = data.numRegions;
Qmax = data.maxPairs;
K = data.maxStormDays;

qGrid = 0:Qmax;
refundValue = data.refundPairPrice * qGrid;

% U_next(region, q+1, stormUsed+1)
% 表示下一天尚未知道天气时的保证价值。
U_next = -Inf(N, Qmax+1, K+1);

for k = 0:K
    U_next(data.endRegion, :, k+1) = refundValue;
end

% 完整策略规模较小，可直接保存。
policyAction = zeros(T, 2, N, Qmax+1, K+1, 'uint8');
policyRefill = zeros(T, 2, N, Qmax+1, K+1, 'uint16');

startTime = tic;

for t = T:-1:1

    weatherValue = cell(1, 2);

    for weatherID = 1:2

        V = -Inf(N, Qmax+1, K+1);
        P = zeros(N, Qmax+1, K+1, 'uint8');
        Rfill = zeros(N, Qmax+1, K+1, 'uint16');

        for kUsed = 0:K

            if weatherID == data.robustStormID && kUsed >= K
                continue;
            end

            kNext = kUsed + (weatherID == data.robustStormID);

            % 若当天行动结束在村庄，购买发生在当天消耗之后。
            % 对所有可能的补给后资源量预先做后缀最大值，避免逐状态枚举购买量。
            villageFuture = squeeze( ...
                U_next(data.villageRegions, :, kNext+1));
            villageFuture = reshape(villageFuture, 1, []);

            refillBase = villageFuture ...
                - data.villagePairPrice * qGrid;

            [suffixValue, suffixArg] = suffix_best_case4(refillBase);

            for region = 1:N

                if region == data.endRegion
                    V(region, :, kUsed+1) = refundValue;
                    continue;
                end

                actions = generate_actions_case4(region, weatherID, data);

                bestValue = -Inf(1, Qmax+1);
                bestCode = zeros(1, Qmax+1, 'uint8');
                bestRefill = zeros(1, Qmax+1, 'uint16');

                for a = 1:numel(actions)

                    usePairs = actions(a).pairUse;

                    if usePairs > Qmax
                        continue;
                    end

                    qBefore = usePairs:Qmax;
                    qRemain = qBefore - usePairs;
                    nextRegion = actions(a).nextRegion;

                    if nextRegion == data.endRegion

                        future = data.refundPairPrice * qRemain;
                        refillTarget = zeros(size(qRemain));

                    elseif nextRegion == data.villageRegions

                        future = data.villagePairPrice * qRemain ...
                            + suffixValue(qRemain + 1);

                        refillTarget = suffixArg(qRemain + 1);

                    else

                        future = squeeze( ...
                            U_next(nextRegion, qRemain+1, kNext+1));

                        future = reshape(future, 1, []);
                        refillTarget = zeros(size(qRemain));
                    end

                    candidate = actions(a).reward + future;

                    idx = qBefore + 1;
                    better = candidate > bestValue(idx);

                    idxBetter = idx(better);
                    bestValue(idxBetter) = candidate(better);
                    bestCode(idxBetter) = actions(a).code;
                    bestRefill(idxBetter) = uint16(refillTarget(better));
                end

                V(region, :, kUsed+1) = bestValue;
                P(region, :, kUsed+1) = bestCode;
                Rfill(region, :, kUsed+1) = bestRefill;
            end
        end

        weatherValue{weatherID} = V;
        policyAction(t, weatherID, :, :, :) = reshape( ...
            P, 1, 1, N, Qmax+1, K+1);
        policyRefill(t, weatherID, :, :, :) = reshape( ...
            Rfill, 1, 1, N, Qmax+1, K+1);
    end

    Vhigh = weatherValue{data.robustHighID};
    Vstorm = weatherValue{data.robustStormID};

    U_current = Vhigh;

    % 尚未达到沙暴上限时，自然状态在高温和沙暴中取不利者。
    for kUsed = 0:(K-1)
        U_current(:, :, kUsed+1) = min( ...
            Vhigh(:, :, kUsed+1), ...
            Vstorm(:, :, kUsed+1));
    end

    % 已用完全部沙暴额度后，最不利非沙暴天气为高温。
    U_current(:, :, K+1) = Vhigh(:, :, K+1);

    U_next = U_current;

    fprintf('  已完成第 %d 天的倒推。\n', t);
end

% 第0天购买。保证型计算中水和食物按相同箱数购买。
initialCash = data.initialCash - data.startPairPrice * qGrid;
startValue = squeeze(U_next(data.startRegion, :, 1));
startValue = reshape(startValue, 1, []);

objective = initialCash + startValue;
objective(initialCash < 0) = -Inf;

[bestValue, idx] = max(objective);
bestPairs = idx - 1;
bestCash = initialCash(idx);

if ~isfinite(bestValue)
    error('第四关在当前保证型设定下没有找到可行初始方案。');
end

dpResult.policyAction = policyAction;
dpResult.policyRefill = policyRefill;
dpResult.bestInitialPairs = bestPairs;
dpResult.bestInitialWater = bestPairs;
dpResult.bestInitialFood = bestPairs;
dpResult.bestInitialCash = bestCash;
dpResult.guaranteedWealth = bestValue;
dpResult.maxStormDays = K;
dpResult.runtime = toc(startTime);

dpResult.stateSize = [N, Qmax+1, K+1];

fprintf('动态规划完成，用时 %.2f s。\n', dpResult.runtime);

end


function [suffixValue, suffixArg] = suffix_best_case4(values)
% 从右向左计算 max(values(q:end)) 及其对应的资源对数量q。

n = numel(values);
suffixValue = -Inf(1, n);
suffixArg = zeros(1, n);

bestValue = -Inf;
bestArg = 0;

for i = n:-1:1
    if values(i) >= bestValue
        bestValue = values(i);
        bestArg = i - 1;
    end

    suffixValue(i) = bestValue;
    suffixArg(i) = bestArg;
end

end
