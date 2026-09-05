function [model, index] = build_model(data)
%BUILD_MODEL 构造时间展开的混合整数线性规划

N = data.numNodes;
T = data.T;

moves = data.allowedMoves;
moveFrom = moves(:,1);
moveTo = moves(:,2);
M = size(moves,1);

mineNodes = data.mineNodes(:)';
villageNodes = data.villageNodes(:)';
nMine = numel(mineNodes);
nVillage = numel(villageNodes);

offset = 0;

index.x = reshape(offset + (1:N*(T+1)), N, T+1);
offset = offset + N*(T+1);

index.z = reshape(offset + (1:M*T), M, T);
offset = offset + M*T;

index.h = reshape(offset + (1:nMine*T), nMine, T);
offset = offset + nMine*T;

index.q0w = offset + 1;
index.q0f = offset + 2;
offset = offset + 2;

index.qW = reshape(offset + (1:nVillage*T), nVillage, T);
offset = offset + nVillage*T;

index.qF = reshape(offset + (1:nVillage*T), nVillage, T);
offset = offset + nVillage*T;

index.W = offset + (1:T+1);
offset = offset + T + 1;

index.F = offset + (1:T+1);
offset = offset + T + 1;

index.C = offset + (1:T+1);
offset = offset + T + 1;

nVar = offset;

index.moves = moves;
index.moveFrom = moveFrom;
index.moveTo = moveTo;

% intlinprog 默认最小化，因此对最终财富取负号
f = zeros(nVar,1);
f(index.C(end)) = -1;
f(index.W(end)) = -data.refundWaterPrice;
f(index.F(end)) = -data.refundFoodPrice;

lb = zeros(nVar,1);
ub = inf(nVar,1);

ub(index.x(:)) = 1;
ub(index.z(:)) = 1;
ub(index.h(:)) = 1;

ub(index.q0w) = data.maxWaterBoxes;
ub(index.q0f) = data.maxFoodBoxes;
ub(index.qW(:)) = data.maxWaterBoxes;
ub(index.qF(:)) = data.maxFoodBoxes;
ub(index.W(:)) = data.maxWaterBoxes;
ub(index.F(:)) = data.maxFoodBoxes;

% 沙暴日不能跨区域行走
crossMove = moveFrom ~= moveTo;
for t = 1:T
    if data.isStorm(t)
        ub(index.z(crossMove,t)) = 0;
    end
end

% 到达终点后不能再离开
leaveEnd = moveFrom == data.endNode & moveTo ~= data.endNode;
for t = 1:T
    ub(index.z(leaveEnd,t)) = 0;
end

% 整数变量
intcon = [
    index.x(:)
    index.z(:)
    index.h(:)
    index.q0w
    index.q0f
    index.qW(:)
    index.qF(:)
    index.W(:)
    index.F(:)
    ];
intcon = unique(intcon(:))';

% 每个区域对应的流入、流出及自循环
outMoves = cell(N,1);
inMoves = cell(N,1);
selfMove = zeros(N,1);

for i = 1:N
    outMoves{i} = find(moveFrom == i);
    inMoves{i} = find(moveTo == i);
    selfMove(i) = find(moveFrom == i & moveTo == i, 1);
end

% z 对资源消耗倍率的贡献
% 行走2倍，普通停留1倍，终点吸收状态0倍
lambdaZ = 2 * ones(M,1);
lambdaZ(moveFrom == moveTo) = 1;
lambdaZ(moveFrom == data.endNode & moveTo == data.endNode) = 0;

nEq = (T+1) + 1 + 2*N*T + 3 + 3*T + 1;
nIneq = nMine*T + 2*T + 2*nVillage*T + (T+1);

Aeq = sparse(nEq,nVar);
beq = zeros(nEq,1);
A = sparse(nIneq,nVar);
b = zeros(nIneq,1);

eqRow = 0;

% 每天只能位于一个区域
for tCol = 1:T+1
    eqRow = eqRow + 1;
    Aeq(eqRow,index.x(:,tCol)) = 1;
    beq(eqRow) = 1;
end

% 第0天位于起点
eqRow = eqRow + 1;
Aeq(eqRow,index.x(data.startNode,1)) = 1;
beq(eqRow) = 1;

% 路径连续
for t = 1:T

    for i = 1:N
        eqRow = eqRow + 1;
        Aeq(eqRow,index.z(outMoves{i},t)) = 1;
        Aeq(eqRow,index.x(i,t)) = -1;
    end

    for j = 1:N
        eqRow = eqRow + 1;
        Aeq(eqRow,index.z(inMoves{j},t)) = 1;
        Aeq(eqRow,index.x(j,t+1)) = -1;
    end
end

% 第0天购买后状态
eqRow = eqRow + 1;
Aeq(eqRow,index.W(1)) = 1;
Aeq(eqRow,index.q0w) = -1;

eqRow = eqRow + 1;
Aeq(eqRow,index.F(1)) = 1;
Aeq(eqRow,index.q0f) = -1;

eqRow = eqRow + 1;
Aeq(eqRow,index.C(1)) = 1;
Aeq(eqRow,index.q0w) = data.waterPrice;
Aeq(eqRow,index.q0f) = data.foodPrice;
beq(eqRow) = data.initialMoney;

% 每日资源与资金平衡
for t = 1:T

    zIdx = index.z(:,t);
    hIdx = index.h(:,t);

    % 水
    eqRow = eqRow + 1;
    Aeq(eqRow,index.W(t+1)) = 1;
    Aeq(eqRow,index.W(t)) = -1;
    Aeq(eqRow,zIdx) = data.waterBase(t) * lambdaZ';
    Aeq(eqRow,hIdx) = 2 * data.waterBase(t);
    Aeq(eqRow,index.qW(:,t)) = -1;

    % 食物
    eqRow = eqRow + 1;
    Aeq(eqRow,index.F(t+1)) = 1;
    Aeq(eqRow,index.F(t)) = -1;
    Aeq(eqRow,zIdx) = data.foodBase(t) * lambdaZ';
    Aeq(eqRow,hIdx) = 2 * data.foodBase(t);
    Aeq(eqRow,index.qF(:,t)) = -1;

    % 资金
    eqRow = eqRow + 1;
    Aeq(eqRow,index.C(t+1)) = 1;
    Aeq(eqRow,index.C(t)) = -1;
    Aeq(eqRow,hIdx) = -data.mineIncome;
    Aeq(eqRow,index.qW(:,t)) = data.villageWaterPrice;
    Aeq(eqRow,index.qF(:,t)) = data.villageFoodPrice;
end

% 截止日期时必须已经处于终点
eqRow = eqRow + 1;
Aeq(eqRow,index.x(data.endNode,T+1)) = 1;
beq(eqRow) = 1;

ineqRow = 0;

% 只有整日在矿山原地停留才能挖矿
for t = 1:T
    for k = 1:nMine
        node = mineNodes(k);

        ineqRow = ineqRow + 1;
        A(ineqRow,index.h(k,t)) = 1;
        A(ineqRow,index.z(selfMove(node),t)) = -1;
    end
end

% 行动开始前必须有足够资源
for t = 1:T

    zIdx = index.z(:,t);
    hIdx = index.h(:,t);

    ineqRow = ineqRow + 1;
    A(ineqRow,zIdx) = data.waterBase(t) * lambdaZ';
    A(ineqRow,hIdx) = 2 * data.waterBase(t);
    A(ineqRow,index.W(t)) = -1;

    ineqRow = ineqRow + 1;
    A(ineqRow,zIdx) = data.foodBase(t) * lambdaZ';
    A(ineqRow,hIdx) = 2 * data.foodBase(t);
    A(ineqRow,index.F(t)) = -1;
end

% 只能在当天结束时所在村庄购买
for t = 1:T
    for k = 1:nVillage

        node = villageNodes(k);

        ineqRow = ineqRow + 1;
        A(ineqRow,index.qW(k,t)) = 1;
        A(ineqRow,index.x(node,t+1)) = -data.maxWaterBoxes;

        ineqRow = ineqRow + 1;
        A(ineqRow,index.qF(k,t)) = 1;
        A(ineqRow,index.x(node,t+1)) = -data.maxFoodBoxes;
    end
end

% 每日负重
for tCol = 1:T+1

    ineqRow = ineqRow + 1;
    A(ineqRow,index.W(tCol)) = data.waterWeight;
    A(ineqRow,index.F(tCol)) = data.foodWeight;
    b(ineqRow) = data.capacity;
end

if eqRow ~= nEq || ineqRow ~= nIneq
    error('模型约束行数不一致，请检查 build_model.m。');
end

model.f = f;
model.intcon = intcon;
model.A = A;
model.b = b;
model.Aeq = Aeq;
model.beq = beq;
model.lb = lb;
model.ub = ub;

model.nVar = nVar;
model.nEq = nEq;
model.nIneq = nIneq;

index.lambdaZ = lambdaZ;

end
