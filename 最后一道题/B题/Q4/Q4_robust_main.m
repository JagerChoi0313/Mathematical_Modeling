function R = Q4_robust_main(samples, options)
%Q4_ROBUST_MAIN 第四问：精确二项置信域 + 置信上界降维 + 装配树全策略枚举。
% 直接运行：R = Q4_robust_main; 默认生成模拟抽样示例，不是实测结果！
% 真实输入：samples.Q2_n, samples.Q2_x 为6×3；Q3_n,Q3_x为12×1。
% 第二问各行对应情形1~6，列为[零件1,零件2,成品条件次品率]。
% 第三问行顺序=[零件1~8,半成品1~3,成品条件次品率]。
% MATLAB R2020a及以上；仅使用基础MATLAB，无统计/优化工具箱依赖。
% 同文件夹还需Q4_tree_evaluate.m、Q4_export_results.m。完整说明见Q4_README.md。

if nargin<1, samples=[]; end
if nargin<2, options=struct(); end
opts=defaults(options); models=problemModels();
previousRng=rng; cleanupRng=onCleanup(@()rng(previousRng)); %#ok<NASGU>
rng(opts.randomSeed,'twister');
R=struct(); R.options=opts; R.problems=cell(7,1);

%% 步骤1：读取固定样本量和次品数；无输入时仅生成可复现模拟示例
if isempty(samples)
    R.dataSource=sprintf('模拟抽样示例：每类预设n=%d，种子%d；不是实际检测数据', ...
        opts.exampleSampleSize,opts.randomSeed);
    samples.Q2_n=opts.exampleSampleSize*ones(6,3); samples.Q2_x=zeros(6,3);
    samples.Q3_n=opts.exampleSampleSize*ones(12,1); samples.Q3_x=zeros(12,1);
    for s=1:7
        p=[models{s}.parts(:,1);models{s}.assembly(:,1)];
        for h=1:numel(p)
            x=sum(rand(opts.exampleSampleSize,1)<p(h));
            if s<=6, samples.Q2_x(s,h)=x; else, samples.Q3_x(h)=x; end
        end
    end
else
    R.dataSource='用户输入抽样计数：程序未独立验证其采样来源与条件';
end
validateSamples(samples); R.samples=samples;
if strcmp(opts.confidenceFamily,'all30')
    R.coverageNote='30个率组成一个置信域，总覆盖率至少1-alpha（Bonferroni）';
else
    R.coverageNote='每个第二问情形的3个率分别联合覆盖；第三问12个率联合覆盖；不宣称30个率同时达到该水平';
end
fprintf('\n第四问：基于置信上界降维的装配树鲁棒全策略枚举\n%s\n',R.dataSource);
fprintf('总体显著性水平alpha=%.4f；%s\n',opts.alpha,R.coverageNote);
fprintf('成本/利润单位：元/完成一个合格交付订单，售价只计一次。\n');

% 数字表统一用英文内部字段+中文VariableDescriptions，Excel导出中文表头。
sampleRows={}; summaryRows={}; costRows={}; eventRows={}; decisionRows={};
nodeRows={}; inputRows={}; encodingRows={}; confidenceRows={}; checkRows={};
groupNames={'零件采购','零件检测','半成品装配','半成品检测','半成品拆解', ...
    '成品装配','成品检测','成品拆解','调换损失'};

%% 步骤2：依次重新求解第二问六个情形与第三问
for s=1:7
    P=models{s}; n=size(P.parts,1); k=size(P.assembly,1); K=n+k;
    if s<=6
        ns=samples.Q2_n(s,:).'; xs=samples.Q2_x(s,:).'; name=sprintf('第二问情形%d',s);
    else
        ns=samples.Q3_n; xs=samples.Q3_x; name='第三问';
    end
    familyK=K; if strcmp(opts.confidenceFamily,'all30'), familyK=30; end
    [lo,hi,phat,cpError]=exactIntervals(ns,xs,opts.alpha/familyK);
    names=[arrayfun(@(i)sprintf('零件%d',i),1:n,'UniformOutput',false), ...
        arrayfun(@(j)sprintf('半成品%d',j),1:k-1,'UniformOutput',false),{'成品'}];
    bitNames=[strcat('检测',names(1:n)),strcat('检测',names(n+1:end)),strcat('拆解',names(n+1:end))];
    eventNames=[strcat('采购',names(1:n)),strcat('检测',names(1:n)), ...
        strcat('装配',names(n+1:end)),strcat('检测',names(n+1:end)), ...
        strcat('拆解',names(n+1:end)),{'调换'}];
    for h=1:K
        type='零件总体次品率'; if h>n, type='直接投入物全合格时的条件次品率'; end
        sampleRows(end+1,:)={name,h,names{h},type,ns(h),xs(h),phat(h),lo(h),hi(h), ...
            opts.alpha/familyK,R.dataSource}; %#ok<AGROW>
        if h<=n
            inputRows(end+1,:)={name,h,names{h},P.parts(h,1),P.parts(h,2),0,P.parts(h,3),0,''}; %#ok<AGROW>
        else
            j=h-n; inputRows(end+1,:)={name,h,names{h},P.assembly(j,1),0, ...
                P.assembly(j,2),P.assembly(j,3),P.assembly(j,4),num2str(P.children{j})}; %#ok<AGROW>
        end
    end
    for h=1:numel(bitNames)
        encodingRows(end+1,:)={name,h,bitNames{h}}; %#ok<AGROW>
    end

    %% 步骤3：生成全部策略，并合并未检测半成品的无效拆解位
    [D,ids,weights,rawMap]=enumerateStrategies(n,k);
    % 点估计评价与鲁棒评价完全分开：样本零次品不等于真实次品率为0。
    [cPoint,fPoint]=Q4_tree_evaluate(P,D,phat);
    [cWorst,fRobust]=Q4_tree_evaluate(P,D,hi);
    % 本模型固定策略成本对各次品率单调不减，因此最坏情形在全上界。
    % 这一降维结论依赖递推结构，不是任意非线性模型都可只检查上界。
    assert(all(~fRobust | fPoint),'鲁棒可行策略在点估计处却不可行。');
    assert(all(cWorst(fRobust)>=cPoint(fRobust)-1e-8),'单调性检查失败。');
    pointBest=bestRows(cPoint,fPoint,opts.tieTolerance);
    robustBest=bestRows(cWorst,fRobust,opts.tieTolerance);
    [~,ix]=sortrows([cWorst(fRobust),ids(fRobust)],[1,2]);
    validRows=find(fRobust); ranked=validRows(ix);
    isPoint=false(numel(ids),1); isPoint(pointBest)=true;
    isRobust=false(numel(ids),1); isRobust(robustBest)=true;
    status=repmat({'鲁棒可行'},numel(ids),1);
    status(~fRobust & fPoint)={'点估计可行；置信域内无有限成本保证'};
    status(~fPoint)={'点估计处也不能以有限期望成本完成交付'};
    allT=makeTable([num2cell(ids),cellstr(char(D+'0')),num2cell(weights), ...
        num2cell(fPoint),num2cell(fRobust),num2cell(cPoint),num2cell(P.price-cPoint), ...
        num2cell(cWorst),num2cell(P.price-cWorst),num2cell(isPoint),num2cell(isRobust),status], ...
        {'StrategyID','Code','EquivalentCount','PointFeasible','RobustFeasible','PointCost', ...
        'PointProfit','WorstCost','WorstProfit','PointOptimal','RobustOptimal','Status'}, ...
        {'策略编号','四位或十六位编码','等价原始编码数','点估计可行','鲁棒可行','点估计成本', ...
        '点估计利润','最坏情形成本','最坏情形利润','点估计最优','鲁棒最优','状态说明'});
    A=struct('name',name,'P',P,'nodeNames',{names},'bitNames',{bitNames}, ...
        'n',ns,'x',xs,'lower',lo,'upper',hi,'estimate',phat,'decisions',D, ...
        'ids',ids,'weights',weights,'rawMap',rawMap,'pointRows',pointBest, ...
        'robustRows',robustBest,'rankedRobustRows',ranked, ...
        'pointCost',cPoint,'worstCost',cWorst,'pointFeasible',fPoint,'robustFeasible',fRobust);
    A.tables.allStrategies=allT; A.tables.pointOptimal=allT(pointBest,:);
    A.tables.robustOptimal=allT(robustBest,:);
    R.problems{s}=A;

    %% 步骤4：记录全部并列最优；图表代表取其中编号最小者
    pb=NaN; rb=NaN; pp=NaN; pw=NaN; rp=NaN; rw=NaN; gain=NaN;
    if ~isempty(pointBest)
        row=pointBest(1); pb=ids(row); pp=P.price-cPoint(row); pw=P.price-cWorst(row);
    end
    if ~isempty(robustBest)
        row=robustBest(1); rb=ids(row); rp=P.price-cPoint(row); rw=P.price-cWorst(row);
    end
    if ~isempty(pointBest) && ~isempty(robustBest), gain=rw-pw; end
    summaryRows(end+1,:)={name,P.price,numel(ids),sum(fPoint),sum(fRobust),pb,rb, ...
        pp,pw,rp,rw,gain,numel(pointBest),numel(robustBest)}; %#ok<AGROW>
    fprintf('\n%s：%d个候选；点估计可行%d个，鲁棒可行%d个。\n',name,numel(ids),sum(fPoint),sum(fRobust));
    if ~isempty(robustBest)
        fprintf('鲁棒代表策略ID %.0f；编码 %s；最坏成本 %.8f，利润下界 %.8f。\n', ...
            rb,allT.Code{robustBest(1)},cWorst(robustBest(1)),rw);
        fprintf('全部鲁棒最优ID：%s\n',strtrim(sprintf('%d ',ids(robustBest))));
    else
        fprintf('当前置信域内不存在有限期望成本的保证；不得将上界1改小后声称原保证成立。\n');
    end
    for mode=1:2
        rows=pointBest; modeName='点估计最优';
        if mode==2, rows=robustBest; modeName='鲁棒最优'; end
        for row=rows(:).'
            decisionRows(end+1,:)={name,modeName,ids(row),allT.Code{row}, ...
                P.price-cPoint(row),P.price-cWorst(row),row==rows(1)}; %#ok<AGROW>
        end
        if isempty(rows), continue; end
        row=rows(1);
        for scene=1:2
            p=phat; sceneName='样本点估计'; if scene==2, p=hi; sceneName='全部置信上界'; end
            [cc,ff,E]=Q4_tree_evaluate(P,D(row,:),p);
            for h=1:9
                costRows(end+1,:)={name,modeName,sceneName,ids(row),groupNames{h},E.costBreakdown(h),ff}; %#ok<AGROW>
            end
            for h=1:numel(eventNames)
                eventRows(end+1,:)={name,modeName,sceneName,ids(row),eventNames{h}, ...
                    E.eventCounts(h),E.eventUnitCost(h),E.eventCounts(h)*E.eventUnitCost(h),ff}; %#ok<AGROW>
            end
            for h=1:K
                nodeRows(end+1,:)={name,modeName,sceneName,ids(row),names{h}, ...
                    E.nodeCost(h),E.nodeGood(h),E.firstAttemptGood(h),E.nodeFeasible(h)}; %#ok<AGROW>
            end
            if ff, assert(abs(sum(E.costBreakdown)-cc)<1e-8*max(1,cc),'成本分解失败。'); end
        end
    end

    %% 步骤5：第二问8个顶点核验；它是实现核验，不替代单调性证明
    vertexError=NaN;
    if s<=6 && opts.checkVertices
        vmax=-inf(size(ids));
        for v=0:2^K-1
            bits=double(bitget(uint32(v),1:K)).'; p=lo+(hi-lo).*bits;
            vc=Q4_tree_evaluate(P,D,p); vmax=max(vmax,vc);
        end
        assert(isequal(isfinite(vmax),fRobust),'顶点可行性与上界评价不一致。');
        vertexError=0;
        if any(fRobust), vertexError=max(abs(vmax(fRobust)-cWorst(fRobust))); end
        assert(vertexError<1e-7,'顶点最坏成本与置信上界结果不一致。');
    end
    % 置信域内部若干参数点核查，仅检验实现，不赋予抽样点概率含义。
    interiorError=0;
    for trial=1:3
        pc=lo+(hi-lo).*rand(K,1); ci=Q4_tree_evaluate(P,D,pc);
        assert(all(isfinite(ci(fRobust))),'鲁棒策略在内部点不可行。');
        if any(fRobust), interiorError=max(interiorError,max(ci(fRobust)-cWorst(fRobust))); end
    end
    assert(interiorError<1e-7,'置信域内部成本超过上界成本。');
    checkRows(end+1,:)={name,cpError,vertexError,interiorError,true}; %#ok<AGROW>

    %% 步骤6：保持同一份样本，比较不同预设置信水平的鲁棒最优值
    for alpha=sort(unique([opts.alpha,1-opts.confidenceLevels(:).']))
        [~,hu]=exactIntervals(ns,xs,alpha/familyK);
        [cu,fu]=Q4_tree_evaluate(P,D,hu); br=bestRows(cu,fu,opts.tieTolerance);
        id=NaN; profit=NaN; cmin=Inf;
        if ~isempty(br), id=ids(br(1)); cmin=cu(br(1)); profit=P.price-cmin; end
        confidenceRows(end+1,:)={name,1-alpha,id,profit,cmin,sum(fu),numel(br)}; %#ok<AGROW>
    end
end

%% 步骤7：回归核验原第二、三问；只作为检查，求解不使用这些最优答案
R.regression=regressionChecks(models,1e-8); % 回归容差独立于用户的并列最优展示容差
checkRows(end+1,:)={'原第二三问及端点回归',NaN,NaN,NaN,R.regression.passed};
R.checksPassed=all(cell2mat(checkRows(:,5)));
R.tables.samples=makeTable(sampleRows, ...
    {'Problem','NodeID','Node','RateMeaning','SampleSize','Defects','Estimate','Lower','Upper','MarginalAlpha','Source'}, ...
    {'问题','节点编号','节点','次品率定义','样本量','次品数','样本次品率','置信下界','置信上界','单率显著性水平','数据来源'});
R.tables.summary=makeTable(summaryRows, ...
    {'Problem','Price','Candidates','PointFeasible','RobustFeasible','PointID','RobustID','PointOwnProfit', ...
    'PointWorstProfit','RobustPointProfit','RobustWorstProfit','WorstGain','PointTies','RobustTies'}, ...
    {'问题','售价','去重候选数','点估计可行数','鲁棒可行数','点估计代表ID','鲁棒代表ID', ...
    '点估计方案的点估计利润','点估计方案的最坏利润','鲁棒方案的点估计利润','鲁棒方案的最坏利润', ...
    '代表方案最坏利润改善','点估计并列数','鲁棒并列数'});
R.tables.costs=makeTable(costRows,{'Problem','PolicyType','RateScene','StrategyID','Category','ExpectedCost','Feasible'}, ...
    {'问题','方案类型','参数情景','策略编号','成本类别','期望成本','该情景可行'});
R.tables.events=makeTable(eventRows,{'Problem','PolicyType','RateScene','StrategyID','Event','ExpectedCount','UnitCost','ExpectedCost','Feasible'}, ...
    {'问题','方案类型','参数情景','策略编号','事件','期望次数','单次费用','期望费用','该情景可行'});
R.tables.nodes=makeTable(nodeRows,{'Problem','PolicyType','RateScene','StrategyID','Node','SupplyCost','OutputGood','FirstGood','Feasible'}, ...
    {'问题','方案类型','参数情景','策略编号','节点','独立取得节点输出的费用','节点输出合格率','本次新采购或装配合格率','节点可供给'});
R.tables.decisions=makeTable(decisionRows,{'Problem','PolicyType','StrategyID','Code','PointProfit','WorstProfit','Representative'}, ...
    {'问题','最优类型','策略编号','策略编码','点估计利润','最坏情形利润','是否图表代表'});
R.tables.inputs=makeTable(inputRows,{'Problem','NodeID','Node','NominalRate','PurchaseCost','AssemblyCost','TestCost','DisassemblyCost','Children'}, ...
    {'问题','节点编号','节点','题目名义次品率','采购费','装配费','检测费','拆解费','直接子节点'});
R.tables.encoding=makeTable(encodingRows,{'Problem','Bit','Decision'},{'问题','位次','决策含义'});
R.tables.confidenceSensitivity=makeTable(confidenceRows, ...
    {'Problem','Confidence','StrategyID','WorstProfit','WorstCost','FeasibleCount','Ties'}, ...
    {'问题','联合置信水平','鲁棒代表策略ID','最坏情形利润','最坏情形成本','鲁棒可行数','并列最优数'});
R.tables.checks=makeTable(checkRows,{'Problem','BetaTailError','VertexCostError','InteriorViolation','Passed'}, ...
    {'问题','置信限尾概率残差','顶点成本核验误差','内部参数点超界量','核验通过'});
R=Q4_export_results(R);
fprintf('\n核验通过。鲁棒保证以置信域覆盖真实参数和既定固定策略规则为条件。\n');
fprintf('点估计与鲁棒方案相同，不等于已经证明整个置信域内策略排名不变。\n');
disp(R.tables.summary(:,[1,6,7,8,9,10,11]));
end

function [L,U,phat,err]=exactIntervals(n,x,alphaOne)
% Clopper-Pearson双侧精确区间；Bonferroni由调用者分配alphaOne。
% U用Beta分布对称性计算：1-BetaInv(alpha/2,n-x,x+1)。无需betainv工具箱。
n=double(n(:)); x=double(x(:)); phat=x./n; L=zeros(size(n)); U=ones(size(n)); tail=alphaOne/2;
i=x>0; L(i)=betaincinv(tail,x(i),n(i)-x(i)+1);
i=x<n; U(i)=1-betaincinv(tail,n(i)-x(i),x(i)+1);
assert(all(L<=phat+1e-12 & phat<=U+1e-12),'置信区间端点异常。');
err=0;
i=x>0; if any(i), err=max(err,max(abs(betainc(L(i),x(i),n(i)-x(i)+1)-tail))); end
i=x<n; if any(i), err=max(err,max(abs(betainc(1-U(i),n(i)-x(i),x(i)+1)-tail))); end
assert(err<1e-7,'Beta反函数精度核验失败。');
end

function [D,ids,w,map]=enumerateStrategies(n,k)
b=n+2*k; raw=(0:2^b-1).'; rawD=zeros(numel(raw),b);
for j=1:b, rawD(:,j)=bitget(uint32(raw),b-j+1); end
canonical=rawD;
canonical(:,n+k+(1:k-1))=rawD(:,n+k+(1:k-1)).*rawD(:,n+(1:k-1));
map=1+canonical*(2.^(b-1:-1:0)).'; keep=map==raw+1;
D=rawD(keep,:); ids=raw(keep)+1; w=accumarray(map,1,[2^b,1]); w=w(ids);
assert(size(D,1)==2^n*3^(k-1)*4 && sum(w)==2^b,'等价策略去重核验失败。');
end

function rows=bestRows(c,f,tol)
rows=[]; if any(f), best=min(c(f)); rows=find(f & abs(c-best)<=tol); end
end

function T=makeTable(C,fields,labels)
if isempty(C), C=cell(0,numel(fields)); end
T=cell2table(C,'VariableNames',fields); T.Properties.VariableDescriptions=labels;
end

function validateSamples(S)
names={'Q2_n','Q2_x','Q3_n','Q3_x'}; sizes={[6,3],[6,3],[12,1],[12,1]};
for j=1:4
    assert(isfield(S,names{j}),'缺少字段samples.%s。',names{j}); a=S.(names{j});
    assert(isnumeric(a) && isreal(a) && isequal(size(a),sizes{j}), ...
        'samples.%s的尺寸不正确。',names{j});
    assert(all(isfinite(a(:))) && all(a(:)==fix(a(:))) && all(a(:)>=0) && ...
        all(double(a(:))<=flintmax),'样本输入须为可精确表示的有限非负整数。');
end
assert(all(S.Q2_n(:)>0) && all(S.Q3_n(:)>0),'样本量必须大于0。');
assert(all(S.Q2_x(:)<=S.Q2_n(:)) && all(S.Q3_x(:)<=S.Q3_n(:)),'次品数不能大于样本量。');
end

function o=defaults(user)
o=struct('alpha',0.05,'confidenceFamily','perProblem','exampleSampleSize',200, ...
    'randomSeed',20240908,'tieTolerance',1e-8,'checkVertices',true, ...
    'confidenceLevels',[0.90,0.95,0.99],'makeFigures',true,'saveFiles',true, ...
    'figureVisible','on','fontName','','outputRoot',fullfile(fileparts(mfilename('fullpath')),'Q4_results'));
assert(isstruct(user) && isscalar(user),'options须为标量结构体。');
f=fieldnames(user);
for j=1:numel(f), assert(isfield(o,f{j}),'未知选项：%s',f{j}); o.(f{j})=user.(f{j}); end
assert(isscalar(o.alpha) && isfinite(o.alpha) && o.alpha>0 && o.alpha<1,'alpha须在(0,1)。');
assert(any(strcmp(o.confidenceFamily,{'perProblem','all30'})),'confidenceFamily只能为perProblem或all30。');
assert(isscalar(o.exampleSampleSize) && isfinite(o.exampleSampleSize) && o.exampleSampleSize>=1 && ...
    o.exampleSampleSize==fix(o.exampleSampleSize),'示例样本量须为正整数。');
assert(all(isfinite(o.confidenceLevels(:))) && all(o.confidenceLevels(:)>0 & o.confidenceLevels(:)<1), ...
    'confidenceLevels须在(0,1)。');
assert(isscalar(o.tieTolerance) && isfinite(o.tieTolerance) && o.tieTolerance>0,'并列判定容差须为正数。');
assert(any(strcmp(o.figureVisible,{'on','off'})),'figureVisible只能是on或off。');
assert(isscalar(o.randomSeed) && isnumeric(o.randomSeed) && isfinite(o.randomSeed) && ...
    o.randomSeed>=0 && o.randomSeed==fix(o.randomSeed) && o.randomSeed<=2^32-1,'随机种子须为0~2^32-1整数。');
for name={'checkVertices','makeFigures','saveFiles'}
    value=o.(name{1}); assert(isscalar(value) && (islogical(value) || isnumeric(value)) && ...
        (value==0 || value==1),'%s须为true或false。',name{1});
end
end

function M=problemModels()
% 2024年全国大学生数学建模竞赛B题表1、表2；所有费用均为元/次或件。
q2=[.1 4 2 .1 18 3 .1 6 3 56 6 5; ...
    .2 4 2 .2 18 3 .2 6 3 56 6 5; ...
    .1 4 2 .1 18 3 .1 6 3 56 30 5; ...
    .2 4 1 .2 18 1 .2 6 2 56 30 5; ...
    .1 4 8 .2 18 1 .1 6 2 56 10 5; ...
    .05 4 2 .05 18 3 .05 6 3 56 10 40];
M=cell(7,1);
for s=1:6
    v=q2(s,:); P=struct(); P.parts=[v(1:3);v(4:6)];
    P.assembly=[v(7:9),v(12)]; P.children={[1,2]}; P.price=v(10); P.loss=v(11); M{s}=P;
end
P=struct(); P.parts=[.1 2 1;.1 8 1;.1 12 2;.1 2 1;.1 8 1;.1 12 2;.1 8 1;.1 12 2];
P.assembly=[.1 8 4 6;.1 8 4 6;.1 8 4 6;.1 8 6 10];
P.children={[1,2,3],[4,5,6],[7,8],[9,10,11]}; P.price=200; P.loss=40; M{7}=P;
end

function G=regressionChecks(models,tol)
profits=[18.1111111111111,12,15.4444444444444,14.75,11.9876543209877,21.6786703601108,60.2222222222222];
expectedIDs={[14],[14],[14;16],[16],[5],[1],[65520]};
G=struct(); G.nominalProfits=zeros(7,1); G.nominalIDs=cell(7,1);
for s=1:7
    P=models{s}; n=size(P.parts,1); k=size(P.assembly,1);
    [D,ids]=enumerateStrategies(n,k); p=[P.parts(:,1);P.assembly(:,1)];
    [c,f]=Q4_tree_evaluate(P,D,p); br=bestRows(c,f,tol);
    G.nominalProfits(s)=P.price-c(br(1)); G.nominalIDs{s}=ids(br);
    assert(abs(G.nominalProfits(s)-profits(s))<1e-7 && isequal(ids(br),expectedIDs{s}(:)), ...
        '原题名义参数回归失败：问题%d。',s);
    if s==7, assert(sum(f)==6012,'第三问名义参数可行数应为6012。'); end
end
P=models{1}; [D,~]=enumerateStrategies(2,1);
[c,f]=Q4_tree_evaluate(P,D,zeros(3,1)); assert(all(f) && all(isfinite(c)),'零次品率端点失败。');
[~,f]=Q4_tree_evaluate(P,D,[1;0.1;0.1]); assert(~any(f),'零件次品率1应无法完成交付。');
[~,f]=Q4_tree_evaluate(P,D,[0.1;0.1;1]); assert(~any(f),'成品条件次品率1应无法完成交付。');
[lo,hi]=exactIntervals([20;20],[0;20],.05);
assert(lo(1)==0 && hi(2)==1 && hi(1)>0 && lo(2)<1,'全好/全坏样本置信端点失败。');
G.passed=true;
end
