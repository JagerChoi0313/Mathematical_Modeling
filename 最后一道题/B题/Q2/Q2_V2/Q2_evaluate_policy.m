function E = Q2_evaluate_policy(row, decision, options)
%Q2_EVALUATE_POLICY 固定策略的吸收马尔可夫链期望成本评估。
% 输入 row = [情形,p1,b1,t1,p2,b2,t2,pf,a,tf,S,L,D]，共 13 列。
% decision = [x1,x2,y,z]：检测零件1、检测零件2、检测成品、拆解。
% 1 表示是，0 表示否。四项决策在同一订单的循环中保持不变。
% 状态次序：待采购、双合格、件1合格件2不合格、件1不合格件2合格、
%           双不合格；另有吸收态“完成合格交付”。
% 质量状态是计算用隐状态，企业不能直接观察或据此改变策略。
% 本函数不画图、不写文件，不需要统计或优化工具箱。

if nargin < 3, options = struct(); end
if ~isfield(options,'checkTolerance'), options.checkTolerance = 1e-9; end
if ~isfield(options,'minRcond'), options.minRcond = 1e-12; end
if ~isfield(options,'iterationMax'), options.iterationMax = 100000; end
validateattributes(row,{'numeric'},{'real','finite','vector','numel',13});
validateattributes(decision,{'numeric','logical'}, ...
    {'real','finite','vector','numel',4});
assert(all(decision == 0 | decision == 1),'策略必须为四个 0 或 1。');
row = double(row(:).'); decision = double(decision(:).');
p1=row(2); b1=row(3); t1=row(4); p2=row(5); b2=row(6); t2=row(7);
pf=row(8); a=row(9); tf=row(10); price=row(11); loss=row(12); dis=row(13);
assert(all([p1,p2,pf] >= 0 & [p1,p2,pf] < 1),'次品率必须位于 [0,1)。');
assert(all(row([3,4,6,7,9:13]) >= 0) && a > 0, ...
    '成本和售价不得为负，装配成本必须大于零。');
x1=decision(1); x2=decision(2); y=decision(3); z=decision(4);

%% 步骤 1：新采购零配件的质量分布和取得成本
% 被检测的零件：逐件采购和检测，检出次品则丢弃，直到取得合格件。
% 采购和检测的期望次数均为 1/(1-p_i)，不是只计一次检测费用。
bad1=(1-x1)*p1; bad2=(1-x2)*p2;
g1=1-bad1; g2=1-bad2;
purchaseCount=[1/(1-x1*p1), 1/(1-x2*p2)];
piQuality=[g1*g2, g1*bad2, bad1*g2, bad1*bad2];
goodProbability=[1-pf;0;0;0];  % 两个零件均合格时仍可能装配失败
badProbability=1-goodProbability;

%% 步骤 2：构造转移矩阵和单次状态访问的成本/事件次数
Q=zeros(5); Q(1,2:5)=piQuality;
Q(2:5,1)=(1-z)*badProbability;
Q(2:5,2:5)=diag(z*badProbability);
absorbStep=[0;goodProbability];
% 八列依次为：采购件1、采购件2、检测件1、检测件2、装配、
%             成品检测、调换、拆解。事件次数与成本分开存储。
stageEvents=zeros(5,8);
stageEvents(1,1:2)=purchaseCount;
stageEvents(1,3:4)=purchaseCount.*[x1,x2];
stageEvents(2:5,5)=1;
stageEvents(2:5,6)=y;
stageEvents(2:5,7)=(1-y)*badProbability;
stageEvents(2:5,8)=z*badProbability;
unitCost=[b1,b2,t1,t2,a,tf,loss,dis];
stageCost=bsxfun(@times,stageEvents,unitCost);
c=sum(stageCost,2);
assert(all(Q(:)>=0) && all(abs(sum(Q,2)+absorbStep-1)<1e-12), ...
    '转移概率非负性或行和检查失败。');

%% 步骤 3：只保留从初始“待采购”状态能够到达的状态
% 必须先筛可达状态！例如两种零件都检测时，不合格零件状态不可达；
% 这些不可达状态即使有自循环，也不能据此否定当前策略。
reachable=false(5,1); reachable(1)=true;
while true
    next=reachable | any(Q(reachable,:)>0,1).';
    if isequal(next,reachable), break; end
    reachable=next;
end
idx=find(reachable); Qr=Q(idx,idx);

% 反向搜索：哪些状态存在到“完成交付”的正概率路径？
% 有限状态链中，每个可达状态均能到达吸收态，才保证最终吸收概率为1。
canFinish=absorbStep>0;
while true
    next=canFinish | any(Q(:,canFinish)>0,2);
    if isequal(next,canFinish), break; end
    canFinish=next;
end
proper=all(canFinish(reachable));

E=struct();
E.decision=decision; E.Q=Q; E.absorbStep=absorbStep;
E.P=[Q,absorbStep;zeros(1,5),1];
E.stateNames={'待采购','两件均合格','件1合格件2不合格', ...
    '件1不合格件2合格','两件均不合格','完成合格交付'};
E.reachable=reachable; E.reachableIndices=idx; E.Qreachable=Qr;
E.canFinish=canFinish; E.stageCost=stageCost; E.stageEvents=stageEvents;
E.initialQuality=piQuality; E.firstPassYield=piQuality(1)*(1-pf);
E.rhoFull=max(abs(eig(Q))); E.rhoReachable=max(abs(eig(Qr)));
E.feasible=proper; E.status='可行';
E.expectedCost=Inf; E.expectedProfit=-Inf;
E.costBreakdown=nan(1,8); E.eventCounts=nan(1,8);
E.value=nan(5,1); E.expectedVisits=nan(5,1);
E.absorptionProbability=NaN; E.rcond=NaN;
E.closedFormCost=NaN; E.closedFormError=NaN;
E.iterationCost=NaN; E.iterationError=NaN; E.iterations=0;
E.residual=NaN; E.costSumError=NaN;
E.checksPassed=true;

% 即使策略不可行，也计算其最终完成交付的概率。
% 无法到达吸收态的状态完成概率为0；其余状态满足 h=b+Qh。
finishIdx=find(reachable & canFinish);
h=zeros(5,1);
if ~isempty(finishIdx)
    Ah=eye(numel(finishIdx))-Q(finishIdx,finishIdx);
    assert(rcond(Ah)>=options.minRcond, ...
        '吸收概率方程数值病态，请检查极端输入；未将其当作经济不可行。');
    h(finishIdx)=Ah\absorbStep(finishIdx);
end
E.absorptionProbability=h(1);
if ~proper
    E.status='不可行：可达循环无法保证合格交付';
    % 正的装配成本加上非零概率的永久循环，导致期望成本为正无穷。
    assert(z==1 && any(piQuality(2:4)>0),'不可行状态与当前固定策略结构不一致。');
    assert(abs(h(1)-piQuality(1))<options.checkTolerance, ...
        '不可行策略的最终交付概率检查失败。');
    return;
end

%% 步骤 4：求解期望成本，而不是用有限循环截断代替无限期望
A=eye(numel(idx))-Qr;
E.rcond=rcond(A);
assert(E.rcond>=options.minRcond, ...
    '成本方程数值病态；请检查输入，不能直接将此策略排除后选最优。');
cr=c(idx);
v=A\cr;                         % (I-Qr)v=c；禁止使用 inv(A)*c
componentValue=A\stageCost(idx,:);
countValue=A\stageEvents(idx,:);
start=find(idx==1,1);
E.value(idx)=v;
E.expectedCost=v(start);
E.expectedProfit=price-E.expectedCost; % 同一订单售价仅计入一次
E.costBreakdown=componentValue(start,:);
E.eventCounts=countValue(start,:);
e=zeros(numel(idx),1); e(start)=1;
E.expectedVisits(idx)=A.'\e;
E.residual=norm(A*v-cr,Inf);
E.costSumError=abs(sum(E.costBreakdown)-E.expectedCost);

%% 步骤 5：闭式公式交叉验证（按更新周期推导，不再调用转移矩阵）
freshCost=sum(stageCost(1,:));
if z==0
    success=E.firstPassYield;
    E.closedFormCost=(freshCost+a+y*tf+(1-y)*(1-success)*loss)/success;
else
    % 可行的永久复用策略必须确保进入装配的零件均合格。
    % 新零件仅取得一次；后续仅重装配，已知合格零件不重复检测。
    E.closedFormCost=freshCost+(a+y*tf+pf*(dis+(1-y)*loss))/(1-pf);
end
E.closedFormError=abs(E.closedFormCost-E.expectedCost);

%% 步骤 6：固定策略成本迭代复核数值解
% 这是“固定策略评估迭代”，不是重新优化行动的 Bellman 价值迭代。
% 同一矩阵的迭代一致性只能核验数值求解，不能单独证明状态建模正确。
vk=zeros(size(v)); tol=options.checkTolerance*max(1,abs(E.expectedCost));
for k=1:options.iterationMax
    vk=cr+Qr*vk;
    if norm(vk-v,Inf)<=tol/10, break; end
end
E.iterationCost=vk(start); E.iterations=k;
E.iterationError=abs(vk(start)-v(start));
E.checksPassed=E.closedFormError<=tol && E.residual<=tol && ...
    E.costSumError<=tol && norm(vk-v,Inf)<=tol && ...
    abs(E.absorptionProbability-1)<=options.checkTolerance && ...
    all(E.costBreakdown>=-tol) && all(E.eventCounts>=-tol);
assert(E.checksPassed,'闭式公式、矩阵残差、成本分解或迭代核验失败。');
end
