function E = Q3_tree_evaluate(P, decision)
%Q3_TREE_EVALUATE 装配树自底向上的固定策略评价（无绘图、无文件写入）。
% P.parts: n×3，[次品率，购买单价，检测费用]。
% P.assembly: k×4，[条件装配次品率，装配费，检测费，拆解费]。
% P.children{j}: 装配节点 n+j 的直接子节点编号，必须小于 n+j。
% 根节点为 n+k，每个其他节点恰好有一个父节点，每种投入物用一件。
% decision = [x(1:n), y(1:k), z(1:k)]，最后一个装配节点是成品。
% 与已建立模型一致：半成品未检测时，其拆解决策不触发；拆解仅复用
% 原直接投入物，已确认合格物料免复检，不新增自适应检测/限次返工。

n=size(P.parts,1); k=size(P.assembly,1); N=n+k;
decision=double(decision(:).');
assert(numel(decision)==n+2*k && all(decision==0 | decision==1), ...
    '策略长度或0-1取值错误。');
x=decision(1:n); y=decision(n+(1:k)); z=decision(n+k+(1:k));
% 事件列：购零件n列、检零件n列、装配k列、检装配品k列、拆解k列、调换1列。
M=2*n+3*k+1;
buy=1:n; testPart=n+(1:n); assemble=2*n+(1:k);
testAssembly=2*n+k+(1:k); dismantle=2*n+2*k+(1:k); exchange=M;
unit=[P.parts(:,2).',P.parts(:,3).',P.assembly(:,2).', ...
    P.assembly(:,3).',P.assembly(:,4).',P.loss];
group=[ones(1,n),2*ones(1,n),3*ones(1,k-1),6, ...
    4*ones(1,k-1),7,5*ones(1,k-1),8,9];
G=nan(N,1); C=inf(N,1); certain=false(N,1); possible=false(N,1);
counts=nan(N,M); success=nan(N,1); inputCost=nan(N,1);
residual=nan(N,1); reason=repmat({''},N,1);

%% 步骤1：零配件取得成本和进入装配时的质量，式（3-1）
for i=1:n
    p=P.parts(i,1); b=P.parts(i,2); t=P.parts(i,3);
    G(i)=1-(1-x(i))*p;
    % 用结构条件判断质量保证，避免把接近1的小数四舍五入成1。
    certain(i)=logical(x(i)) || p==0;
    C(i)=(b+x(i)*t)/(1-x(i)*p);
    counts(i,:)=0;
    counts(i,buy(i))=1/(1-x(i)*p);
    counts(i,testPart(i))=x(i)/(1-x(i)*p);
    success(i)=G(i); possible(i)=true; residual(i)=0;
end

%% 步骤2：按拓扑顺序评价半成品，最后评价根节点
for j=1:k
    v=n+j; ch=P.children{j}; isRoot=(j==k);
    if any(~possible(ch))
        reason{v}='下层物料不能以有限期望成本取得';
        continue;
    end
    p=P.assembly(j,1); a=P.assembly(j,2);
    t=P.assembly(j,3); d=P.assembly(j,4);
    B=sum(C(ch)); base=sum(counts(ch,:),1);
    s=(1-p)*prod(G(ch)); allGood=all(certain(ch));
    assert(s>0 && s<=1,'装配成功概率数值异常，请检查输入规模或参数。');
    inputCost(v)=B; success(v)=s;
    now=zeros(1,M); now(assemble(j))=1;

    if ~isRoot && y(j)==0
        % 式（3-4）：不检测的半成品一次装配后直接向上提供。
        G(v)=s; certain(v)=allGood && p==0;
        C(v)=B+a; counts(v,:)=base+now;
        residual(v)=abs(C(v)-(B+a));
    elseif z(j)==0
        % 式（3-5）或（3-10）：失败则丢弃，并重新取得全部子物料。
        now(testAssembly(j))=y(j);
        if isRoot, now(exchange)=(1-y(j))*(1-s); end
        running=a+y(j)*t+isRoot*(1-y(j))*(1-s)*P.loss;
        G(v)=1; certain(v)=true;
        C(v)=(B+running)/s; counts(v,:)=(base+now)/s;
        residual(v)=abs(C(v)-(B+running+(1-s)*C(v)));
    elseif ~allGood
        % 式（3-8）或（3-12）：不合格直接投入物可能被永久复用。
        reason{v}='拆解后可能永久复用未检出的不合格投入物';
        continue;
    else
        % 式（3-7）或（3-11）：合格子物料仅取得一次，后续重复装配。
        now(testAssembly(j))=y(j); now(dismantle(j))=p;
        if isRoot, now(exchange)=p*(1-y(j)); end
        running=a+y(j)*t+p*(d+isRoot*(1-y(j))*P.loss);
        G(v)=1; certain(v)=true;
        C(v)=B+running/(1-p); counts(v,:)=base+now/(1-p);
        residual(v)=abs((C(v)-B)-(running+p*(C(v)-B)));
    end
    possible(v)=true;
end

%% 步骤3：根节点利润、成本分解及数值核验
E=struct(); E.decision=decision;
E.code=char(decision+'0'); E.strategyID=1+decision*(2.^(numel(decision)-1:-1:0)).';
E.feasible=possible(N); E.expectedCost=C(N); E.expectedProfit=P.price-C(N);
E.nodeG=G; E.nodeCertain=certain; E.nodeCost=C; E.nodeFeasible=possible;
E.nodeSuccess=success; E.nodeInputCost=inputCost; E.nodeCounts=counts;
E.nodeReasons=reason; E.eventUnitCost=unit; E.eventGroup=group;
E.costBreakdown=nan(1,9); E.eventCounts=nan(1,M);
E.maxRenewalResidual=max(residual(possible));
E.maxCostError=max(abs(C(possible)-counts(possible,:)*unit.'));
E.reason='可行';
if E.feasible
    E.eventCounts=counts(N,:); eventCost=E.eventCounts.*unit;
    for j=1:9, E.costBreakdown(j)=sum(eventCost(group==j)); end
    E.maxCostError=max(E.maxCostError,abs(sum(E.costBreakdown)-C(N)));
else
    bad=find(~possible,n+k,'first');
    E.reason=sprintf('节点%d：%s',bad(1),reason{bad(1)});
end
scale=max(1,max(C(possible)));
E.checksPassed=E.maxCostError<1e-9*scale && ...
    E.maxRenewalResidual<1e-9*scale && all(G(possible)>=0 & G(possible)<=1);
assert(E.checksPassed,'成本分解或更新方程核验失败。');
end
