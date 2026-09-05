function solution = solve_policy_case6(value, data)
%SOLVE_POLICY_CASE6
% 三玩家分解式保证动态策略：
% 单玩家Bellman价值作为未来价值，逐日枚举三玩家联合动作，
% 当天精确计入同边移动、同矿挖矿和同村购买的多人规则。

P = data.numPlayers;
Qmax = data.maxPairs;

% 先枚举三名玩家采用相同初始采购量的方案，得到稳定的可行起点
bestTotal = -Inf;
bestSim = [];
q0 = repmat(value.singlePlayerBestPairs,1,P);

for q = 0:Qmax
    if data.initialCash - data.startPairPrice*q < 0
        continue;
    end

    trial = repmat(q,1,P);
    [sim,total] = simulate_joint(trial,value,data,false);

    if sim.feasible && total > bestTotal + 1e-9
        bestTotal = total;
        bestSim = sim;
        q0 = trial;
    end
end

if ~isfinite(bestTotal)
    error('第六关没有找到可行的共同初始采购方案。');
end

% 再逐玩家枚举其初始资源量，在不改变其他玩家采购量时进行一次坐标改进
for p = 1:P
    bestQ = q0(p);
    bestLocal = bestTotal;
    bestLocalSim = bestSim;

    for q = 0:Qmax
        if data.initialCash - data.startPairPrice*q < 0
            continue;
        end

        trial = q0;
        trial(p) = q;
        [sim,total] = simulate_joint(trial,value,data,false);

        if sim.feasible && total > bestLocal + 1e-9
            bestLocal = total;
            bestQ = q;
            bestLocalSim = sim;
        end
    end

    q0(p) = bestQ;
    bestTotal = bestLocal;
    bestSim = bestLocalSim;
end

% 用改进后的初始采购重新生成完整逐日记录
[bestSim,bestTotal] = simulate_joint(q0,value,data,true);

solution.initialPairs = q0;
solution.totalFinalWealth = bestTotal;
solution.simulation = bestSim;
solution.weatherText = strjoin(bestSim.weatherNames,"-");

fprintf('第六关初始资源对：[%s]\n',num2str(q0));
fprintf('代表性最不利情形总最终资金：%.2f 元\n',bestTotal);
end

function [sim,totalFinalWealth] = simulate_joint(q0,value,data,keepLog)

P = data.numPlayers;
T = data.deadline;
K = data.maxStormDays;

region = repmat(data.startRegion,1,P);
pairs = q0;
cash = data.initialCash - data.startPairPrice*q0;
stormUsed = 0;

feasible = all(cash >= 0);
weatherNames = strings(1,0);

if keepLog
    logRows = cell(P,1);
    for p = 1:P
        logRows{p} = {0,"",region(p),"初始购买",region(p), ...
            pairs(p),pairs(p),cash(p),0,1,0};
    end
else
    logRows = [];
end

for day = 1:T
    if all(region == data.endRegion)
        break;
    end

    [scoreHigh,planHigh] = best_joint_action( ...
        day,data.robustHighID,region,pairs,cash,stormUsed,value,data);

    scoreStorm = Inf;
    planStorm = [];
    if stormUsed < K
        [scoreStorm,planStorm] = best_joint_action( ...
            day,data.robustStormID,region,pairs,cash,stormUsed,value,data);
    end

    if scoreStorm < scoreHigh
        weatherID = data.robustStormID;
        plan = planStorm;
        stormUsed = stormUsed + 1;
        weatherNames(end+1) = "沙暴"; %#ok<AGROW>
    else
        weatherID = data.robustHighID;
        plan = planHigh;
        weatherNames(end+1) = "高温"; %#ok<AGROW>
    end

    if isempty(plan) || ~isfinite(plan.score)
        feasible = false;
        break;
    end

    oldRegion = region;
    region = plan.nextRegion;
    pairs = plan.nextPairs;
    cash = plan.nextCash;

    if any(pairs < 0) || any(cash < -1e-9)
        feasible = false;
        break;
    end

    if keepLog
        for p = 1:P
            logRows{p}(end+1,:) = {day,data.robustWeatherNames(weatherID), ...
                oldRegion(p),plan.actionText(p),region(p), ...
                pairs(p),pairs(p),cash(p),plan.mineFlag(p), ...
                plan.groupSize(p),plan.purchasePairs(p)}; %#ok<AGROW>
        end
    end
end

if feasible && all(region == data.endRegion)
    finalWealth = cash + data.refundPairPrice*pairs;
    totalFinalWealth = sum(finalWealth);
else
    finalWealth = -Inf(1,P);
    totalFinalWealth = -Inf;
    feasible = false;
end

sim.feasible = feasible;
sim.finalWealth = finalWealth;
sim.finalRegion = region;
sim.finalPairs = pairs;
sim.finalCash = cash;
sim.weatherNames = weatherNames;
sim.stormUsed = stormUsed;

if keepLog
    dailyTables = cell(P,1);
    for p = 1:P
        dailyTables{p} = cell2table(logRows{p}, ...
            'VariableNames', {'Day','Weather','StartRegion','Action','EndRegion', ...
            'WaterLeft','FoodLeft','CashLeft','Mine','GroupSize','PurchasePairs'});
    end
    sim.dailyTables = dailyTables;
else
    sim.dailyTables = {};
end
end

function [bestScore,bestPlan] = best_joint_action( ...
    day,weatherID,region,pairs,cash,stormUsed,value,data)

P = data.numPlayers;
kNext = stormUsed + (weatherID == data.robustStormID);

actions = cell(P,1);
for p = 1:P
    actions{p} = generate_actions_case6(region(p),weatherID,data);
end

bestScore = -Inf;
bestPlan = [];

for a1 = 1:numel(actions{1})
    for a2 = 1:numel(actions{2})
        for a3 = 1:numel(actions{3})
            chosen = [actions{1}(a1),actions{2}(a2),actions{3}(a3)];

            [ok,plan,score] = evaluate_joint_candidate( ...
                day,weatherID,chosen,pairs,cash,kNext,value,data);

            if ok && score > bestScore + 1e-9
                bestScore = score;
                bestPlan = plan;
            end
        end
    end
end
end

function [ok,bestPlan,bestScore] = evaluate_joint_candidate( ...
    day,weatherID,chosen,pairs,cash,kNext,value,data)

P = data.numPlayers;
baseUse = data.robustBaseUse(weatherID);

nextRegion = zeros(1,P);
qRemain = zeros(1,P);
income = zeros(1,P);
mineFlag = false(1,P);
groupSize = ones(1,P);
actionText = strings(1,P);

minePlayers = find(arrayfun(@(a) a.type=="mine",chosen));
mineGroup = numel(minePlayers);

for p = 1:P
    a = chosen(p);
    nextRegion(p) = a.to;

    if a.type == "move"
        same = 0;
        for q = 1:P
            if chosen(q).type=="move" ...
                    && chosen(q).from==a.from ...
                    && chosen(q).to==a.to
                same = same + 1;
            end
        end
        groupSize(p) = same;
        multiplier = 2*same;
        actionText(p) = "行走";

    elseif a.type == "mine"
        groupSize(p) = mineGroup;
        multiplier = 3;
        income(p) = data.baseIncome/mineGroup;
        mineFlag(p) = true;
        actionText(p) = "挖矿";

    elseif a.type == "terminal"
        multiplier = 0;
        actionText(p) = "已到终点";

    else
        multiplier = 1;
        actionText(p) = "停留";
    end

    qRemain(p) = pairs(p) - baseUse*multiplier;

    if qRemain(p) < 0
        ok = false; bestPlan = []; bestScore = -Inf; return;
    end

    if nextRegion(p) ~= data.endRegion && qRemain(p) == 0
        ok = false; bestPlan = []; bestScore = -Inf; return;
    end
end

cashBeforeBuy = cash + income;
if any(cashBeforeBuy < -1e-9)
    ok = false; bestPlan = []; bestScore = -Inf; return;
end

villagePlayers = find(nextRegion == data.villageRegion);
m = numel(villagePlayers);

bestScore = -Inf;
bestPlan = [];

% 枚举村庄内哪些玩家实际购买。没有到村庄时只执行一次。
for mask = 0:(2^m-1)
    buyFlag = false(1,P);
    for j = 1:m
        if bitget(mask,j)
            buyFlag(villagePlayers(j)) = true;
        end
    end

    numBuyers = sum(buyFlag);
    if numBuyers >= 2
        pairPrice = data.villagePairPriceGroup;
    else
        pairPrice = data.villagePairPriceSolo;
    end

    nextPairs = qRemain;
    purchasePairs = zeros(1,P);
    purchaseCost = zeros(1,P);
    future = zeros(1,P);
    subsetOK = true;

    for p = 1:P
        if nextRegion(p) == data.endRegion
            future(p) = data.refundPairPrice*qRemain(p);
            continue;
        end

        if buyFlag(p)
            maxTarget = min(data.maxPairs, ...
                qRemain(p) + floor(cashBeforeBuy(p)/pairPrice));

            if maxTarget <= qRemain(p)
                subsetOK = false;
                break;
            end

            bestVal = -Inf;
            bestTarget = qRemain(p);

            for qTarget = (qRemain(p)+1):maxTarget
                v = value.U(day+1,data.villageRegion,qTarget+1,kNext+1) ...
                    - pairPrice*(qTarget-qRemain(p));

                if v > bestVal
                    bestVal = v;
                    bestTarget = qTarget;
                end
            end

            if ~isfinite(bestVal)
                subsetOK = false;
                break;
            end

            nextPairs(p) = bestTarget;
            purchasePairs(p) = bestTarget-qRemain(p);
            purchaseCost(p) = pairPrice*purchasePairs(p);
            future(p) = value.U(day+1,data.villageRegion,bestTarget+1,kNext+1);

        else
            future(p) = value.U(day+1,nextRegion(p),qRemain(p)+1,kNext+1);
        end

        if ~isfinite(future(p))
            subsetOK = false;
            break;
        end
    end

    if ~subsetOK
        continue;
    end

    nextCash = cashBeforeBuy - purchaseCost;
    if any(nextCash < -1e-9)
        continue;
    end

    score = sum(income - purchaseCost + future);

    if score > bestScore + 1e-9
        bestScore = score;
        bestPlan.score = score;
        bestPlan.nextRegion = nextRegion;
        bestPlan.nextPairs = nextPairs;
        bestPlan.nextCash = nextCash;
        bestPlan.actionText = actionText;
        bestPlan.mineFlag = mineFlag;
        bestPlan.groupSize = groupSize;
        bestPlan.purchasePairs = purchasePairs;
    end
end

ok = isfinite(bestScore);
end
