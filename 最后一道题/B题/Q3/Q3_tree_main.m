function R = Q3_tree_main(P, options)
%Q3_TREE_MAIN 第三问：装配树分层递推 + 固定策略全枚举。
% 用法：R = Q3_tree_main;  所有题目参数已内置，不需要外部数据文件。
%       R = Q3_tree_main([],struct('mcOrders',20000));
%       R = Q3_tree_main(P,options);  自定义参数格式见 README.md。
% MATLAB R2020a及以上；不需要统计、优化、并行计算工具箱。
% 结果为当前固定规则内的最优方案，不包含拆解后自适应改检等策略。

if nargin<1 || isempty(P), P=defaultParameters(); end
if nargin<2, options=struct(); end
opts=defaultOptions(options);
validateParameters(P);
n=size(P.parts,1); k=size(P.assembly,1); N=n+k; nBits=n+2*k;
assert(nBits<=20,'本枚举程序限定至20个决策位；更大问题应另行设计搜索。');
names=[arrayfun(@(i)sprintf('零配件%d',i),1:n,'UniformOutput',false), ...
    arrayfun(@(j)sprintf('半成品%d',j),1:k-1,'UniformOutput',false),{'成品'}];
bitNames=[arrayfun(@(i)sprintf('检测件%d',i),1:n,'UniformOutput',false), ...
    arrayfun(@(j)sprintf('检测半%d',j),1:k-1,'UniformOutput',false), ...
    {'检测成品'},arrayfun(@(j)sprintf('拆解半%d',j),1:k-1,'UniformOutput',false),{'拆解成品'}];
fprintf('\n第三问：装配树分层递推与固定策略全枚举\n');
fprintf('口径：元/完成一个合格交付订单；一次订单只计一次收入。\n');

%% 步骤1：生成全部原始策略，并合并不影响行为的半成品拆解位
raw=(0:2^nBits-1).'; D=zeros(numel(raw),nBits);
for j=1:nBits, D(:,j)=bitget(uint32(raw),nBits-j+1); end
canonical=D;
% 半成品未检测时拆解位不触发；最终成品因可能退回，不做此合并。
canonical(:,n+k+(1:k-1))=D(:,n+k+(1:k-1)).*D(:,n+(1:k-1));
canonicalID=1+canonical*(2.^(nBits-1:-1:0)).';
keep=(canonicalID==raw+1);
ids=raw(keep)+1; D=D(keep,:); M=size(D,1);
weights=accumarray(canonicalID,1,[2^nBits,1]); weights=weights(ids);
assert(M==2^n*3^(k-1)*4 && sum(weights)==2^nBits,'策略去重计数异常。');
fprintf('原始编码 %d 种；去重候选 %d 种（尚未筛可行性）。\n',2^nBits,M);

%% 步骤2：逐个策略按“零配件—半成品—成品”评价
profits=-inf(M,1); costs=inf(M,1); feasible=false(M,1);
reasons=cell(M,1); codes=cell(M,1); breakdown=nan(M,9);
counts=nan(M,2*n+3*k+1); residual=zeros(M,1); costError=zeros(M,1); passed=false(M,1);
for row=1:M
    E=Q3_tree_evaluate(P,D(row,:));
    profits(row)=E.expectedProfit; costs(row)=E.expectedCost;
    feasible(row)=E.feasible; reasons{row}=E.reason; codes{row}=E.code;
    breakdown(row,:)=E.costBreakdown; counts(row,:)=E.eventCounts;
    residual(row)=E.maxRenewalResidual; costError(row)=E.maxCostError; passed(row)=E.checksPassed;
    if mod(row,5000)==0 || row==M
        fprintf('已评价 %d/%d 种候选策略。\n',row,M);
    end
end

%% 步骤3：比较精确期望利润，保留全部并列最优
assert(any(feasible),'没有可行策略，请检查参数与处理规则。');
bestProfit=max(profits(feasible)); bestRows=find(feasible & abs(profits-bestProfit)<=opts.tieTolerance);
isOptimal=false(M,1); isOptimal(bestRows)=true;
finiteRows=find(feasible);
[~,ord]=sortrows([-profits(finiteRows),ids(finiteRows)],[1 2]);
ranked=finiteRows(ord); topRows=ranked(1:min(opts.topCount,numel(ranked)));
bestE=Q3_tree_evaluate(P,D(bestRows(1),:));
rawFeasible=sum(weights(feasible));
fprintf('\n去重候选中：%d种可行，%d种不可行。\n',sum(feasible),sum(~feasible));
fprintf('最高期望利润：%.10f 元；最低期望成本：%.10f 元。\n',bestProfit,bestE.expectedCost);
fprintf('并列最优行为方案 %d 种；对应原始编码 %d 种。\n',numel(bestRows),sum(weights(bestRows)));
for j=1:min(10,numel(bestRows))
    rr=bestRows(j); fprintf('策略ID %d，编码 %s，利润 %.10f 元。\n',ids(rr),codes{rr},profits(rr));
end

%% 步骤4：组织全部表格；编号始终是原始二进制整数加1，不是去重行号
T=table(ids,codes,feasible,costs,profits,weights,isOptimal,reasons, ...
    'VariableNames',{'StrategyID','Code','Feasible','ExpectedCost','ExpectedProfit', ...
    'EquivalentRawCount','IsOptimal','Status'});
bitFields=arrayfun(@(j)sprintf('Decision%d',j),1:nBits,'UniformOutput',false);
DT=array2table(D,'VariableNames',bitFields);
DT.Properties.VariableDescriptions=bitNames;
R=struct(); R.parameters=P; R.options=opts; R.nodeNames=names; R.bitNames=bitNames;
R.decisions=D; R.bestRows=bestRows; R.bestIDs=ids(bestRows); R.bestEvaluation=bestE;
R.rawCount=2^nBits; R.candidateCount=M; R.feasibleCount=sum(feasible);
R.rawFeasibleCount=rawFeasible; R.equivalentMap=canonicalID;
R.costGroupNames={'零件采购','零件检测','半成品装配','半成品检测','半成品拆解', ...
    '成品装配','成品检测','成品拆解','调换损失'};
R.eventNames=[arrayfun(@(i)sprintf('采购件%d',i),1:n,'UniformOutput',false), ...
    arrayfun(@(i)sprintf('检测件%d',i),1:n,'UniformOutput',false), ...
    strcat('装配',names(n+1:end)),strcat('检测',names(n+1:end)), ...
    strcat('拆解',names(n+1:end)),{'调换'}];
R.tables.allStrategies=[T,DT];
R.tables.optimal=R.tables.allStrategies(bestRows,:);
R.tables.top=R.tables.allStrategies(topRows,:);
R.tables.parts=array2table([(1:n).',P.parts], ...
    'VariableNames',{'PartID','DefectRate','PurchaseCost','TestCost'});
R.tables.assembly=array2table([(n+(1:k)).',P.assembly], ...
    'VariableNames',{'NodeID','DefectRate','AssemblyCost','TestCost','DisassemblyCost'});
childText=cellfun(@(v)strtrim(sprintf('%d ',v)),P.children(:),'UniformOutput',false);
R.tables.tree=table((n+(1:k)).',names(n+1:end).',childText, ...
    'VariableNames',{'NodeID','NodeName','Children'});
R.tables.encoding=table((1:nBits).',bitNames(:),'VariableNames',{'Position','Decision'});
ct=array2table(breakdown(feasible,:),'VariableNames',arrayfun(@(j)sprintf('Cost%d',j),1:9,'UniformOutput',false));
ct.Properties.VariableDescriptions=R.costGroupNames;
R.tables.costs=[T(feasible,1:2),ct];
et=array2table(counts(feasible,:),'VariableNames',arrayfun(@(j)sprintf('Event%d',j),1:size(counts,2),'UniformOutput',false));
et.Properties.VariableDescriptions=R.eventNames;
R.tables.events=[T(feasible,1:2),et];
R.tables.checks=table(ids,residual,costError,'VariableNames',{'StrategyID','RenewalResidual','CostSumError'});
nodeID=[]; strategyID=[]; outG=[]; firstPass=[]; nodeC=[];
for rr=bestRows(:).'
    ee=Q3_tree_evaluate(P,D(rr,:));
    nodeID=[nodeID;(1:N).']; strategyID=[strategyID;repmat(ids(rr),N,1)]; %#ok<AGROW>
    outG=[outG;ee.nodeG]; firstPass=[firstPass;ee.nodeSuccess]; nodeC=[nodeC;ee.nodeCost]; %#ok<AGROW>
end
R.tables.nodes=table(strategyID,nodeID,reshape(names(nodeID),[],1),outG,firstPass,nodeC, ...
    'VariableNames',{'StrategyID','NodeID','NodeName','OutputGoodProbability','FirstPassGoodProbability','ExpectedSupplyCost'});
rawOptimal=find(ismember(canonicalID,ids(bestRows)));
R.tables.rawOptimal=table(rawOptimal,cellstr(dec2bin(rawOptimal-1,nBits)),canonicalID(rawOptimal), ...
    'VariableNames',{'RawStrategyID','RawCode','CanonicalStrategyID'});

%% 步骤5：递推特殊情形核验（不是将预期最优答案硬编码进求解）
d0=zeros(1,nBits); e0=Q3_tree_evaluate(P,d0);
q0=prod(1-P.parts(:,1))*prod(1-P.assembly(:,1));
baseline=(sum(P.parts(:,2))+sum(P.assembly(:,2))+(1-q0)*P.loss)/q0;
assert(abs(e0.expectedCost-baseline)<1e-8*max(1,baseline),'全不检测不拆解基准核验失败。');
R.checksPassed=all(passed);
assert(R.checksPassed,'默认数值精度核验未通过。');

%% 步骤6：独立事件仿真，用真实质量抽样核验，而非抽样期望费用
R.tables.monteCarlo=table(); R.mcHistory=[];
if opts.runMonteCarlo
    % 代表最优、全不检测不拆解、全检测不拆解、全检测全拆解。
    testD=[D(bestRows(1),:);zeros(1,nBits);ones(1,n+k),zeros(1,k);ones(1,nBits)];
    testD=unique(testD,'rows','stable');
    nr=size(testD,1); sid=zeros(nr,1); theory=zeros(nr,1); avg=zeros(nr,1); se=zeros(nr,1);
    previousRng=rng; restoreRng=onCleanup(@()rng(previousRng));
    rng(opts.randomSeed,'twister');
    for j=1:nr
        ee=Q3_tree_evaluate(P,testD(j,:)); assert(ee.feasible,'仿真代表方案必须可行。');
        sample=zeros(opts.mcOrders,1);
        for order=1:opts.mcOrders
            ev=simulateOrder(P,testD(j,:),opts.maxEventsPerOrder);
            sample(order)=ev*ee.eventUnitCost.';
        end
        sid(j)=ee.strategyID; theory(j)=ee.expectedCost;
        avg(j)=mean(sample); se(j)=std(sample,0)/sqrt(opts.mcOrders);
        if j==1, R.mcHistory=cumsum(sample)./(1:opts.mcOrders).'; end
        fprintf('仿真策略%d：均值%.5f元，理论%.5f元，标准误%.5f元。\n',sid(j),avg(j),theory(j),se(j));
    end
    clear restoreRng;
    R.tables.monteCarlo=table(sid,repmat(opts.mcOrders,nr,1),theory,avg,se,avg-1.96*se,avg+1.96*se, ...
        'VariableNames',{'StrategyID','Orders','ExactCost','MeanCost','StandardError','Lower95','Upper95'});
    % 95%区间偶尔不覆盖是随机现象，不据此修改样本、重置种子或强行判失败。
end
R.modelScope='固定策略；仅复用原直接投入物；已知合格件免复检；元/合格交付订单';
R=Q3_tree_export(R);
fprintf('\n精确递推与成本核验通过。结果目录：%s\n',R.outputDir);
end

function P=defaultParameters()
% 2024年国赛B题表2，次品率为小数；装配次品率是输入全部合格时的条件概率。
P.parts=[.10 2 1;.10 8 1;.10 12 2;.10 2 1;.10 8 1;.10 12 2;.10 8 1;.10 12 2];
P.assembly=[.10 8 4 6;.10 8 4 6;.10 8 4 6;.10 8 6 10];
P.children={ [1 2 3],[4 5 6],[7 8],[9 10 11] };
P.price=200; P.loss=40;
end

function opts=defaultOptions(given)
opts=struct('runMonteCarlo',true,'mcOrders',10000,'randomSeed',20240907, ...
    'maxEventsPerOrder',200000,'makeFigures',true,'saveFiles',true, ...
    'figureVisible','on','fontName','','topCount',12,'tieTolerance',1e-8, ...
    'outputRoot',fullfile(fileparts(mfilename('fullpath')),'Q3_results'));
assert(isstruct(given)&&isscalar(given),'options必须为标量结构体。');
f=fieldnames(given);
for j=1:numel(f)
    assert(isfield(opts,f{j}),'未知选项：%s',f{j}); opts.(f{j})=given.(f{j});
end
validateattributes(opts.mcOrders,{'numeric'},{'scalar','integer','>=',2});
validateattributes(opts.topCount,{'numeric'},{'scalar','integer','positive'});
validateattributes(opts.tieTolerance,{'numeric'},{'scalar','real','finite','nonnegative'});
validateattributes(opts.randomSeed,{'numeric'},{'scalar','integer','nonnegative','<=',2^32-1});
validateattributes(opts.maxEventsPerOrder,{'numeric'},{'scalar','integer','positive','finite'});
for name={'runMonteCarlo','makeFigures','saveFiles'}
    value=opts.(name{1});
    assert(isscalar(value)&&(islogical(value)||(isnumeric(value)&&(value==0||value==1))), ...
        '选项%s必须为true或false。',name{1});
end
assert(any(strcmp(opts.figureVisible,{'on','off'})),'figureVisible须为on或off。');
end

function validateParameters(P)
assert(isstruct(P)&&isscalar(P)&&all(isfield(P,{'parts','assembly','children','price','loss'})),'缺少参数字段或P不是标量结构体。');
validateattributes(P.parts,{'numeric'},{'2d','real','finite','nonnegative','nonempty'});
validateattributes(P.assembly,{'numeric'},{'2d','real','finite','nonnegative','nonempty'});
assert(size(P.parts,2)==3 && size(P.assembly,2)==4,'parts为n×3，assembly为k×4。');
n=size(P.parts,1); k=size(P.assembly,1);
assert(all(P.parts(:,1)<1)&&all(P.assembly(:,1)<1),'次品率须在[0,1)内，不能填写10表示10%。');
assert(all(P.assembly(:,2)>0),'装配费用必须为正。');
validateattributes(P.price,{'numeric'},{'scalar','real','finite','nonnegative'});
validateattributes(P.loss,{'numeric'},{'scalar','real','finite','nonnegative'});
assert(iscell(P.children)&&numel(P.children)==k,'children必须为k个单元的cell数组。');
used=[];
for j=1:k
    ch=P.children{j}; validateattributes(ch,{'numeric'},{'vector','integer','positive','nonempty'});
    assert(all(ch<n+j),'节点必须按先子节点、后父节点编号。');
    used=[used,ch(:).']; %#ok<AGROW>
end
assert(isequal(sort(used),1:n+k-1),'每个非根节点必须恰好有一个父节点，输入必须是一棵装配树。');
end

function events=simulateOrder(P,decision,limit)
% 独立递归事件模拟：保存本次取得的直接子物料质量，拆解不重新抽质量。
n=size(P.parts,1); k=size(P.assembly,1); M=2*n+3*k+1;
x=decision(1:n); y=decision(n+(1:k)); z=decision(n+k+(1:k));
events=zeros(1,M); operations=0;
finish=produce(n+k); assert(finish,'仿真未完成合格交付。');
    function good=produce(v)
        if v<=n
            while true
                tick(); events(v)=events(v)+1;
                good=(rand>=P.parts(v,1));
                if x(v), events(n+v)=events(n+v)+1; end
                if ~x(v) || good, return; end
            end
        end
        j=v-n; childQuality=[];
        while true
            if isempty(childQuality)
                ch=P.children{j}; childQuality=false(1,numel(ch));
                for t=1:numel(ch), childQuality(t)=produce(ch(t)); end
            end
            tick(); events(2*n+j)=events(2*n+j)+1;
            good=all(childQuality) && rand>=P.assembly(j,1);
            if y(j), events(2*n+k+j)=events(2*n+k+j)+1; end
            if (j<k && ~y(j)) || good, return; end
            if j==k && ~y(j), events(M)=events(M)+1; end
            if z(j)
                events(2*n+2*k+j)=events(2*n+2*k+j)+1;
                % 本模型的可行拆解策略复用质量有保证的投入物，不收复检费。
                assert(all(childQuality),'可行性筛选与仿真复用条件不一致。');
            else
                childQuality=[];
            end
        end
    end
    function tick()
        operations=operations+1;
        assert(operations<=limit,'单订单超过仿真保护上限；未将截断订单记为完成，请提高上限或检查参数。');
    end
end
