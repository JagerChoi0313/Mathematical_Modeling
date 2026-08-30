function result = process_results(solution, data, index)
%PROCESS_RESULTS 将求解向量还原为逐日方案并进行规则复核

T = data.T;
xSol = solution.x;

positionValue = reshape(xSol(index.x(:)), size(index.x));
zValue = reshape(xSol(index.z(:)), size(index.z));
hValue = reshape(xSol(index.h(:)), size(index.h));
qWValue = reshape(xSol(index.qW(:)), size(index.qW));
qFValue = reshape(xSol(index.qF(:)), size(index.qF));

W = round(xSol(index.W(:)));
F = round(xSol(index.F(:)));
C = round(xSol(index.C(:)), 2);

initialWater = round(xSol(index.q0w));
initialFood = round(xSol(index.q0f));

position = zeros(T+1,1);
for tCol = 1:T+1
    [~,position(tCol)] = max(positionValue(:,tCol));
end

arrivalIndex = find(position == data.endNode,1,'first');
if isempty(arrivalIndex)
    error('结果中未找到终点。');
end
arrivalDay = arrivalIndex - 1;

action = strings(T,1);
startRegion = zeros(T,1);
endRegion = zeros(T,1);
mineFlag = false(T,1);
buyWater = zeros(T,1);
buyFood = zeros(T,1);
buyVillage = strings(T,1);

for t = 1:T

    [~,moveID] = max(zValue(:,t));

    fromNode = index.moveFrom(moveID);
    toNode = index.moveTo(moveID);

    startRegion(t) = fromNode;
    endRegion(t) = toNode;

    mineToday = false;
    mineID = find(data.mineNodes == fromNode,1);

    if fromNode == toNode && ~isempty(mineID)
        mineToday = hValue(mineID,t) > 0.5;
    end

    if fromNode ~= toNode
        action(t) = "行走";
    elseif mineToday
        action(t) = "挖矿";
    else
        action(t) = "停留";
    end

    mineFlag(t) = mineToday;

    buyWater(t) = round(sum(qWValue(:,t)));
    buyFood(t) = round(sum(qFValue(:,t)));

    villageUsed = find(qWValue(:,t) > 0.5 | qFValue(:,t) > 0.5);
    if ~isempty(villageUsed)
        buyVillage(t) = strjoin(string(data.villageNodes(villageUsed)), ",");
    end
end

refundValue = ...
    data.refundWaterPrice * W(arrivalIndex) + ...
    data.refundFoodPrice * F(arrivalIndex);

finalWealth = C(arrivalIndex) + refundValue;

days = (0:arrivalDay)';
weather = strings(arrivalDay+1,1);
weather(1) = "";
weather(2:end) = data.weatherName(1:arrivalDay)';

dailyAction = strings(arrivalDay+1,1);
dailyAction(1) = "初始购买";
dailyAction(2:end) = action(1:arrivalDay);

startDaily = nan(arrivalDay+1,1);
startDaily(1) = data.startNode;
startDaily(2:end) = startRegion(1:arrivalDay);

buyWaterDaily = zeros(arrivalDay+1,1);
buyFoodDaily = zeros(arrivalDay+1,1);
buyWaterDaily(1) = initialWater;
buyFoodDaily(1) = initialFood;
buyWaterDaily(2:end) = buyWater(1:arrivalDay);
buyFoodDaily(2:end) = buyFood(1:arrivalDay);

mineDaily = false(arrivalDay+1,1);
mineDaily(2:end) = mineFlag(1:arrivalDay);

villageDaily = strings(arrivalDay+1,1);
villageDaily(2:end) = buyVillage(1:arrivalDay);

dailyTable = table( ...
    days, weather, startDaily, dailyAction, ...
    position(1:arrivalDay+1), ...
    buyWaterDaily, buyFoodDaily, villageDaily, mineDaily, ...
    W(1:arrivalDay+1), F(1:arrivalDay+1), C(1:arrivalDay+1), ...
    'VariableNames', { ...
    'Day','Weather','StartRegion','Action','EndRegion', ...
    'BuyWater','BuyFood','Village','Mine', ...
    'WaterLeft','FoodLeft','CashLeft'});

mineDays = sum(mineFlag(1:arrivalDay));

summaryTable = table( ...
    data.caseID, arrivalDay, initialWater, initialFood, mineDays, ...
    W(arrivalIndex), F(arrivalIndex), C(arrivalIndex), ...
    refundValue, finalWealth, ...
    'VariableNames', { ...
    'CaseID','ArrivalDay','InitialWater','InitialFood','MineDays', ...
    'FinalWater','FinalFood','CashAtArrival', ...
    'RefundValue','FinalWealth'});

% 独立按规则逐日复核
tol = 1e-5;
checkPassed = true;
checkMessages = strings(0,1);

if abs(C(1) - (data.initialMoney ...
        - data.waterPrice*initialWater ...
        - data.foodPrice*initialFood)) > tol
    checkPassed = false;
    checkMessages(end+1) = "第0天资金与购买费用不一致。";
end

for t = 1:arrivalDay

    fromNode = startRegion(t);
    toNode = endRegion(t);

    if fromNode ~= toNode

        if data.adjacency(fromNode,toNode) == 0
            checkPassed = false;
            checkMessages(end+1) = sprintf("第%d天出现非相邻移动。",t);
        end

        if data.isStorm(t)
            checkPassed = false;
            checkMessages(end+1) = sprintf("第%d天沙暴日发生行走。",t);
        end

        multiplier = 2;

    else

        if mineFlag(t)
            if ~ismember(fromNode,data.mineNodes)
                checkPassed = false;
                checkMessages(end+1) = sprintf("第%d天在非矿山挖矿。",t);
            end
            multiplier = 3;
        else
            multiplier = 1;
        end
    end

    waterUse = data.waterBase(t) * multiplier;
    foodUse = data.foodBase(t) * multiplier;

    if W(t) + tol < waterUse
        checkPassed = false;
        checkMessages(end+1) = sprintf("第%d天行动前水量不足。",t);
    end

    if F(t) + tol < foodUse
        checkPassed = false;
        checkMessages(end+1) = sprintf("第%d天行动前食物不足。",t);
    end

    if (buyWater(t) > 0 || buyFood(t) > 0) ...
            && ~ismember(toNode,data.villageNodes)
        checkPassed = false;
        checkMessages(end+1) = sprintf("第%d天在非村庄购买。",t);
    end

    expectedWater = W(t) - waterUse + buyWater(t);
    expectedFood = F(t) - foodUse + buyFood(t);

    expectedCash = C(t) ...
        + data.mineIncome * double(mineFlag(t)) ...
        - data.villageWaterPrice * buyWater(t) ...
        - data.villageFoodPrice * buyFood(t);

    if abs(W(t+1) - expectedWater) > tol
        checkPassed = false;
        checkMessages(end+1) = sprintf("第%d天水量递推不一致。",t);
    end

    if abs(F(t+1) - expectedFood) > tol
        checkPassed = false;
        checkMessages(end+1) = sprintf("第%d天食物量递推不一致。",t);
    end

    if abs(C(t+1) - expectedCash) > tol
        checkPassed = false;
        checkMessages(end+1) = sprintf("第%d天资金递推不一致。",t);
    end

    totalWeight = data.waterWeight*W(t+1) + data.foodWeight*F(t+1);
    if totalWeight > data.capacity + tol
        checkPassed = false;
        checkMessages(end+1) = sprintf("第%d天负重超过上限。",t);
    end
end

result.arrivalDay = arrivalDay;
result.initialWater = initialWater;
result.initialFood = initialFood;
result.mineDays = mineDays;

result.position = position;
result.action = action;
result.startRegion = startRegion;
result.endRegion = endRegion;

result.water = W;
result.food = F;
result.cash = C;

result.buyWater = buyWater;
result.buyFood = buyFood;
result.buyVillage = buyVillage;
result.mineFlag = mineFlag;

result.refundValue = refundValue;
result.finalWealth = finalWealth;

result.dailyTable = dailyTable;
result.summaryTable = summaryTable;

result.checkPassed = checkPassed;
result.checkMessages = checkMessages;

end
