function [cost, feasible, E] = Q4_tree_evaluate(P, D, rates)
%Q4_TREE_EVALUATE 装配树递推；同时评价多行固定策略，不写文件。
% P.parts=[题目名义次品率,采购费,检测费]；P.assembly=[名义条件次品率,装配费,检测费,拆解费]。
% P.children{j} 是节点 n+j 的直接子节点；根为 n+k。
% D 每行=[零件检测x(1:n),装配品检测y(1:k),拆解z(1:k)]。
% rates=[零件次品率;各装配节点的条件次品率]，覆盖P中的名义率。
% [cost,feasible] 支持全部候选一起评价；第三输出E只用于单个策略，含事件成本核验。
% 口径：取得一个合格交付订单的期望成本，已知合格投入物免复检。
% 未检测半成品直接向上输出；其拆解位不触发。拆解不改变原投入物质量。

n=size(P.parts,1); k=size(P.assembly,1); N=n+k; m=size(D,1);
rates=double(rates(:)); D=double(D);
assert(numel(rates)==N && all(isfinite(rates)) && all(rates>=0 & rates<=1), ...
    '次品率必须为n+k个[0,1]实数。');
assert(size(D,2)==n+2*k && all(D(:)==0 | D(:)==1),'策略维数或0-1取值错误。');
if nargout>2, assert(m==1,'详细输出E仅接受单行策略。'); end
x=D(:,1:n); y=D(:,n+(1:k)); z=D(:,n+k+(1:k));
C=inf(m,N); G=nan(m,N); certain=false(m,N); F=false(m,N);
firstGood=nan(m,N); inputCost=nan(m,N);

%% 步骤1：叶节点；检测后的合格供给不是免费取得的
for i=1:n
    p=rates(i); b=P.parts(i,2); t=P.parts(i,3);
    denom=1-x(:,i)*p; ok=denom>0;
    C(ok,i)=(b+x(ok,i)*t)./denom(ok);
    G(ok,i)=1-(1-x(ok,i))*p;
    certain(ok,i)=logical(x(ok,i)) | p==0;
    F(:,i)=ok; firstGood(:,i)=1-p; % 新采购一件的合格率，区别于筛选后输出合格率
end

%% 步骤2：自底向上的半成品/成品递推
for j=1:k
    v=n+j; ch=P.children{j}; root=(j==k);
    p=rates(v); a=P.assembly(j,2); t=P.assembly(j,3); w=P.assembly(j,4);
    B=sum(C(:,ch),2); q=(1-p)*prod(G(:,ch),2);
    available=all(F(:,ch),2); goodInputs=all(certain(:,ch),2);
    inputCost(:,v)=B; firstGood(:,v)=q;
    % 情形A：不检测的半成品仅组装一次，可以输出不合格半成品。
    pass=available & ~root & y(:,j)==0;
    C(pass,v)=B(pass)+a; G(pass,v)=q(pass);
    certain(pass,v)=goodInputs(pass) & p==0; F(pass,v)=true;
    needsGood=available & (root | y(:,j)==1);
    % 情形B：失败报废，重新取得一套直接投入物；几何更新方程。
    discard=needsGood & z(:,j)==0 & q>0;
    run=a+y(discard,j)*t+root*(1-y(discard,j)).*(1-q(discard))*P.loss;
    C(discard,v)=(B(discard)+run)./q(discard);
    G(discard,v)=1; certain(discard,v)=true; F(discard,v)=true;
    % 情形C：失败拆解。必须保证原直接投入物合格，并且本层p<1。
    % 否则有正概率永远复用坏物料，或本层装配永远失败；成本为Inf。
    reuse=needsGood & z(:,j)==1 & goodInputs & p<1;
    run=a+y(reuse,j)*t+p*(w+root*(1-y(reuse,j))*P.loss);
    C(reuse,v)=B(reuse)+run/(1-p);
    G(reuse,v)=1; certain(reuse,v)=true; F(reuse,v)=true;
    % 有限参数算出了溢出时必须报错，不把数值溢出误称为模型不可行。
    if any(F(:,v) & ~isfinite(C(:,v)))
        error('Q4:Overflow','节点%d成本溢出，无法在当前数值精度下可靠求解。',v);
    end
end
cost=C(:,N); feasible=F(:,N);
assert(all(isfinite(cost(feasible))) && all(cost(feasible)>=0),'成本或可行性不一致。');
if nargout<3, return; end

%% 步骤3：代表策略的事件次数；与成本公式独立累加核对
M=2*n+3*k+1; counts=nan(N,M);
unit=[P.parts(:,2).',P.parts(:,3).',P.assembly(:,2).', ...
    P.assembly(:,3).',P.assembly(:,4).',P.loss];
group=[ones(1,n),2*ones(1,n),3*ones(1,k-1),6, ...
    4*ones(1,k-1),7,5*ones(1,k-1),8,9];
for i=1:n
    if ~F(i), continue; end
    counts(i,:)=0; den=1-x(i)*rates(i);
    counts(i,i)=1/den; counts(i,n+i)=x(i)/den;
end
for j=1:k
    v=n+j; if ~F(v), continue; end
    base=sum(counts(P.children{j},:),1); now=zeros(1,M);
    now(2*n+j)=1; root=(j==k); p=rates(v); q=firstGood(v);
    if ~root && ~y(j)
        counts(v,:)=base+now;
    elseif ~z(j)
        now(2*n+k+j)=y(j); now(M)=root*(1-y(j))*(1-q);
        counts(v,:)=(base+now)/q;
    else
        now(2*n+k+j)=y(j); now(2*n+2*k+j)=p;
        now(M)=root*(1-y(j))*p; counts(v,:)=base+now/(1-p);
    end
end
E=struct('nodeCost',C(:),'nodeGood',G(:),'nodeFeasible',F(:), ...
    'firstAttemptGood',firstGood(:),'inputCost',inputCost(:), ...
    'eventCounts',counts(N,:),'eventUnitCost',unit,'costBreakdown',nan(1,9));
E.costCheckError=0;
if any(F)
    E.costCheckError=max(abs(C(F).'-counts(F,:)*unit.'));
    assert(E.costCheckError<=1e-9*max(1,max(C(F))),'节点成本与事件次数乘单价不一致。');
end
if feasible
    eventCost=counts(N,:).*unit;
    for h=1:9, E.costBreakdown(h)=sum(eventCost(group==h)); end
    assert(abs(sum(E.costBreakdown)-cost)<=1e-9*max(1,cost),'根节点成本分解不一致。');
end
end
