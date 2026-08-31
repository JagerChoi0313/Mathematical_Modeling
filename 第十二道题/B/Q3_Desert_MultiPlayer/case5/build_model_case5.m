function model = build_model_case5(data)
%BUILD_MODEL_CASE5 建立第五关两玩家时空网络MILP

P = data.numPlayers;
N = data.numRegions;
T = data.deadline;
Acount = data.numActions;
M = numel(data.moveActionIndices);

prob = optimproblem('ObjectiveSense','maximize');

loc = optimvar('loc',P,N,T+1, ...
    'Type','integer','LowerBound',0,'UpperBound',1);

act = optimvar('act',P,Acount,T, ...
    'Type','integer','LowerBound',0,'UpperBound',1);

buyWater = optimvar('buyWater',P,1, ...
    'Type','integer','LowerBound',0,'UpperBound',400);
buyFood = optimvar('buyFood',P,1, ...
    'Type','integer','LowerBound',0,'UpperBound',600);

water = optimvar('water',P,T+1,'LowerBound',0,'UpperBound',400);
food = optimvar('food',P,T+1,'LowerBound',0,'UpperBound',600);
cash = optimvar('cash',P,T+1,'LowerBound',0);

% sameMove(m,t)=1 表示两名玩家同日走同一有向边
sameMove = optimvar('sameMove',M,T, ...
    'Type','integer','LowerBound',0,'UpperBound',1);

% mineTogether(t)=1 表示两名玩家同日在9号矿山挖矿
mineTogether = optimvar('mineTogether',1,T, ...
    'Type','integer','LowerBound',0,'UpperBound',1);

% 初始位置与初始采购
for p = 1:P
    for i = 1:N
        prob.Constraints.(sprintf('initLoc_p%d_i%d',p,i)) = ...
            loc(p,i,1) == double(i == data.startRegion);
    end

    prob.Constraints.(sprintf('initWater_p%d',p)) = water(p,1) == buyWater(p);
    prob.Constraints.(sprintf('initFood_p%d',p)) = food(p,1) == buyFood(p);
    prob.Constraints.(sprintf('initCash_p%d',p)) = ...
        cash(p,1) == data.initialCash ...
        - data.waterPrice*buyWater(p) ...
        - data.foodPrice*buyFood(p);

    prob.Constraints.(sprintf('initLoad_p%d',p)) = ...
        data.waterWeight*water(p,1) + data.foodWeight*food(p,1) <= data.maxLoad;
end

% 时空网络流守恒：每天从当前区域执行且只执行一个动作
for t = 1:T
    for p = 1:P
        for i = 1:N
            fromIdx = find([data.actions.from] == i);
            prob.Constraints.(sprintf('flowOut_p%d_i%d_t%d',p,i,t)) = ...
                sum(act(p,fromIdx,t)) == loc(p,i,t);
        end

        for j = 1:N
            toIdx = find([data.actions.to] == j);
            prob.Constraints.(sprintf('flowIn_p%d_i%d_t%d',p,j,t)) = ...
                loc(p,j,t+1) == sum(act(p,toIdx,t));
        end
    end
end

% 沙暴日不能移动
for t = 1:T
    if data.weather(t) == 3
        for p = 1:P
            prob.Constraints.(sprintf('stormMove_p%d_t%d',p,t)) = ...
                sum(act(p,data.moveActionIndices,t)) == 0;
        end
    end
end

% 两人同走同一有向边的AND线性化
for m = 1:M
    aIdx = data.moveActionIndices(m);
    for t = 1:T
        prob.Constraints.(sprintf('sameMoveU1_m%d_t%d',m,t)) = ...
            sameMove(m,t) <= act(1,aIdx,t);
        prob.Constraints.(sprintf('sameMoveU2_m%d_t%d',m,t)) = ...
            sameMove(m,t) <= act(2,aIdx,t);
        prob.Constraints.(sprintf('sameMoveL_m%d_t%d',m,t)) = ...
            sameMove(m,t) >= act(1,aIdx,t) + act(2,aIdx,t) - 1;
    end
end

% 两人同时挖矿的AND线性化
mineA = data.mineActionIndex;
for t = 1:T
    prob.Constraints.(sprintf('mineTogetherU1_t%d',t)) = ...
        mineTogether(t) <= act(1,mineA,t);
    prob.Constraints.(sprintf('mineTogetherU2_t%d',t)) = ...
        mineTogether(t) <= act(2,mineA,t);
    prob.Constraints.(sprintf('mineTogetherL_t%d',t)) = ...
        mineTogether(t) >= act(1,mineA,t) + act(2,mineA,t) - 1;
end

% 资源与资金递推
for t = 1:T
    w0 = data.waterBaseUse(data.weather(t));
    f0 = data.foodBaseUse(data.weather(t));

    for p = 1:P
        normalMultiplier = sum(data.actionMultiplier .* act(p,:,t));

        % 同一有向边两人同时移动时，移动倍率由2变为4，因此额外增加2倍基础消耗
        extraMove = 2 * sum(sameMove(:,t));

        prob.Constraints.(sprintf('waterBal_p%d_t%d',p,t)) = ...
            water(p,t+1) == water(p,t) - w0*(normalMultiplier + extraMove);

        prob.Constraints.(sprintf('foodBal_p%d_t%d',p,t)) = ...
            food(p,t+1) == food(p,t) - f0*(normalMultiplier + extraMove);

        % 两人同日挖矿时，每人收益为基础收益的1/2
        prob.Constraints.(sprintf('cashBal_p%d_t%d',p,t)) = ...
            cash(p,t+1) == cash(p,t) ...
            + data.baseIncome*act(p,mineA,t) ...
            - 0.5*data.baseIncome*mineTogether(t);

        prob.Constraints.(sprintf('load_p%d_t%d',p,t)) = ...
            data.waterWeight*water(p,t+1) ...
            + data.foodWeight*food(p,t+1) <= data.maxLoad;

        % 未到终点时水和食物不能耗尽
        prob.Constraints.(sprintf('waterPositive_p%d_t%d',p,t)) = ...
            water(p,t+1) >= 1 - loc(p,data.endRegion,t+1);
        prob.Constraints.(sprintf('foodPositive_p%d_t%d',p,t)) = ...
            food(p,t+1) >= 1 - loc(p,data.endRegion,t+1);
    end
end

% 截止日两名玩家都必须到达终点
for p = 1:P
    prob.Constraints.(sprintf('finish_p%d',p)) = ...
        loc(p,data.endRegion,T+1) == 1;
end

finalWealth = cash(:,T+1) ...
    + data.refundWaterPrice*water(:,T+1) ...
    + data.refundFoodPrice*food(:,T+1);

prob.Objective = sum(finalWealth);

model.problem = prob;
model.variables.loc = loc;
model.variables.act = act;
model.variables.buyWater = buyWater;
model.variables.buyFood = buyFood;
model.variables.water = water;
model.variables.food = food;
model.variables.cash = cash;
model.variables.sameMove = sameMove;
model.variables.mineTogether = mineTogether;
end
