function value = build_single_player_value_case6(data)
%BUILD_SINGLE_PLAYER_VALUE_CASE6
% 计算单玩家保证价值表，作为三玩家联合日决策的后续价值函数

T = data.deadline;
N = data.numRegions;
Qmax = data.maxPairs;
K = data.maxStormDays;

% U(t,region,q+1,k+1)：第t天行动前，从该状态出发的未来净价值
U = -Inf(T+1,N,Qmax+1,K+1);

refund = data.refundPairPrice*(0:Qmax);
for k = 0:K
    U(T+1,data.endRegion,:,k+1) = reshape(refund,1,1,Qmax+1,1);
end

for t = T:-1:1
    Vweather = cell(1,2);

    for weatherID = 1:2
        V = -Inf(N,Qmax+1,K+1);
        baseUse = data.robustBaseUse(weatherID);

        for kUsed = 0:K
            if weatherID == data.robustStormID && kUsed >= K
                continue;
            end

            kNext = kUsed + (weatherID == data.robustStormID);

            % 单玩家在村庄购买时价格为基准价格2倍
            villageFuture = reshape(U(t+1,data.villageRegion,:,kNext+1),1,[]);
            refillBase = villageFuture ...
                - data.villagePairPriceSolo*(0:Qmax);
            [suffixValue,~] = suffix_best(refillBase);

            for region = 1:N
                if region == data.endRegion
                    V(region,:,kUsed+1) = refund;
                    continue;
                end

                actions = generate_actions_case6(region,weatherID,data);

                for q = 0:Qmax
                    best = -Inf;

                    for a = 1:numel(actions)
                        type = actions(a).type;

                        if type == "stay"
                            multiplier = 1;
                            income = 0;
                        elseif type == "move"
                            multiplier = 2;
                            income = 0;
                        elseif type == "mine"
                            multiplier = 3;
                            income = data.baseIncome;
                        else
                            multiplier = 0;
                            income = 0;
                        end

                        qRemain = q - baseUse*multiplier;
                        if qRemain < 0
                            continue;
                        end

                        nextRegion = actions(a).to;

                        if nextRegion ~= data.endRegion && qRemain == 0
                            continue;
                        end

                        if nextRegion == data.villageRegion
                            future = data.villagePairPriceSolo*qRemain ...
                                + suffixValue(qRemain+1);
                        else
                            future = U(t+1,nextRegion,qRemain+1,kNext+1);
                        end

                        best = max(best,income+future);
                    end

                    V(region,q+1,kUsed+1) = best;
                end
            end
        end

        Vweather{weatherID} = V;
    end

    U(t,:,:,:) = reshape(Vweather{data.robustHighID},1,N,Qmax+1,K+1);

    for kUsed = 0:(K-1)
        U(t,:,:,kUsed+1) = min( ...
            Vweather{data.robustHighID}(:,:,kUsed+1), ...
            Vweather{data.robustStormID}(:,:,kUsed+1));
    end

    fprintf('  第六关后续价值：已完成第 %d 天倒推。\n',t);
end

value.U = U;

% 单玩家最优初始资源，用作多人初始搜索的起点
qGrid = 0:Qmax;
initialCash = data.initialCash - data.startPairPrice*qGrid;
startFuture = reshape(U(1,data.startRegion,:,1),1,[]);
obj = initialCash + startFuture;
obj(initialCash < 0) = -Inf;
[~,idx] = max(obj);
value.singlePlayerBestPairs = idx-1;
end

function [suffixValue,suffixArg] = suffix_best(values)
n = numel(values);
suffixValue = -Inf(1,n);
suffixArg = zeros(1,n);
bestVal = -Inf;
bestArg = 0;

for i = n:-1:1
    if values(i) >= bestVal
        bestVal = values(i);
        bestArg = i-1;
    end
    suffixValue(i) = bestVal;
    suffixArg(i) = bestArg;
end
end
