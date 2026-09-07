function R = Q2_markov_main(data, userOptions)
%Q2_MARKOV_MAIN 第二问：吸收马尔可夫链 + 16 种固定策略全枚举。
% 快速运行：将三个 .m 文件放在同一文件夹，进入该文件夹，执行
%   R = Q2_markov_main;
% 无需输入文件；题目表1的六种情形已内置，次品率用 0~1 小数。
% 可选：R = Q2_markov_main(data,struct('runMonteCarlo',false));
% data 每行 13 列：[情形,p1,b1,t1,p2,b2,t2,pf,a,tf,S,L,D]。
% 推荐 MATLAB R2020a 或更新版本；不需要统计/优化工具箱。
%
% 重要建模边界：
% 1. 利润口径：一个付费订单最终交付一件合格品，收入只计一次。
% 2. 策略 [x1 x2 y z] 在循环中固定；不是所有历史自适应策略的最优。
% 3. 完美检测；新采购独立；拆解不损坏零件，且不改变其真实质量。
% 4. 已检测合格零件的结果可追溯，回用时免重复检测。
% 5. 不检测的坏零件若永久拆解复用可能无法完成交付，不能随机变好。
% 6. 不计库存、时间和资金占用；替换新品成本由状态递推计算，
%    调换损失 L 仅为题目所给的额外损失，不能再重复加整件新品成本。

%% 步骤 1：读取题目参数与计算选项
builtinData=[ ...
    1,0.10,4,2,0.10,18,3,0.10,6,3,56, 6, 5;
    2,0.20,4,2,0.20,18,3,0.20,6,3,56, 6, 5;
    3,0.10,4,2,0.10,18,3,0.10,6,3,56,30, 5;
    4,0.20,4,1,0.20,18,1,0.20,6,2,56,30, 5;
    5,0.10,4,8,0.20,18,1,0.10,6,2,56,10, 5;
    6,0.05,4,2,0.05,18,3,0.05,6,3,56,10,40];
if nargin<1 || isempty(data), data=builtinData; end
if nargin<2 || isempty(userOptions), userOptions=struct(); end
validateattributes(data,{'numeric'},{'2d','real','finite','nonempty'});
assert(size(data,2)==13,'输入矩阵每行必须有 13 列。');
assert(all(data(:,1)>0 & data(:,1)==fix(data(:,1))) && ...
    numel(unique(data(:,1)))==size(data,1),'情形编号应为互不重复的正整数。');
assert(all(all(data(:,[2,5,8])>=0 & data(:,[2,5,8])<1)), ...
    '次品率请输入小数，例如 0.10，不能输入 10。');
assert(all(all(data(:,[3,4,6,7,9:13])>=0)) && all(data(:,9)>0), ...
    '成本和售价不能为负，装配成本必须大于零。');

baseDir=fileparts(mfilename('fullpath'));
opts=struct('saveFiles',true,'makeFigures',true,'figureVisible','on', ...
    'fontName','','outputRoot',fullfile(baseDir,'Q2_results'), ...
    'runMonteCarlo',true,'mcOrders',10000,'randomSeed',20240905, ...
    'maxAssembliesPerOrder',100000,'checkTolerance',1e-9, ...
    'minRcond',1e-12,'iterationMax',100000,'tieTolerance',1e-8);
assert(isstruct(userOptions) && isscalar(userOptions),'选项必须是标量结构体。');
keys=fieldnames(userOptions);
for k=1:numel(keys)
    assert(isfield(opts,keys{k}),'未知选项：%s',keys{k});
    opts.(keys{k})=userOptions.(keys{k});
end
validateattributes(opts.mcOrders,{'numeric'},{'scalar','integer','>=',2});
validateattributes(opts.randomSeed,{'numeric'},{'scalar','integer','nonnegative','<=',2^32-1});
validateattributes(opts.maxAssembliesPerOrder,{'numeric'},{'scalar','integer','positive'});
validateattributes(opts.iterationMax,{'numeric'},{'scalar','integer','positive'});
validateattributes(opts.checkTolerance,{'numeric'},{'scalar','finite','positive'});
validateattributes(opts.tieTolerance,{'numeric'},{'scalar','finite','nonnegative'});
validateattributes(opts.minRcond,{'numeric'},{'scalar','finite','positive','<',1});
for key={'saveFiles','makeFigures','runMonteCarlo'}
    v=opts.(key{1}); assert(isscalar(v) && (v==0 || v==1),'开关必须为 0 或 1。');
end
assert(any(strcmp(opts.figureVisible,{'on','off'})),'figureVisible 应为 on 或 off。');

%% 步骤 2：按四位二进制编码列出全部 16 种固定策略
% 编号 = 1 + 8*x1 + 4*x2 + 2*y + z；1 对应 0000，16 对应 1111。
decisions=dec2bin(0:15,4)-'0';
strategyNames=cell(16,1);
for j=1:16, strategyNames{j}=sprintf('%d%d%d%d',decisions(j,:)); end
nCase=size(data,1); total=nCase*16;
evaluations=cell(nCase,16);
numeric=zeros(total,13); status=cell(total,1); codes=cell(total,1);
costRows=nan(total,11); countRows=nan(total,11); checkRows=nan(total,13);
stateRows={}; transitionRows={};
fprintf('\n第二问：吸收马尔可夫链与全策略枚举\n');
fprintf('每种情形评估 16 种固定策略，共 %d 种情形。\n',nCase);
fprintf('利润单位：元/完成一个合格交付订单；并列最优全部保留。\n');

%% 步骤 3：逐策略构建状态链、筛选可达状态、求解与核验
for k=1:nCase
    for j=1:16
        E=Q2_evaluate_policy(data(k,:),decisions(j,:),opts);
        evaluations{k,j}=E; r=(k-1)*16+j;
        numeric(r,:)=[data(k,1),j,decisions(j,:),E.feasible, ...
            E.expectedCost,E.expectedProfit,E.absorptionProbability, ...
            E.firstPassYield,numel(E.reachableIndices),E.rhoReachable];
        status{r}=E.status; codes{r}=strategyNames{j};
        costRows(r,:)=[data(k,1),j,E.costBreakdown,E.expectedCost];
        countRows(r,:)=[data(k,1),j,E.eventCounts,E.absorptionProbability];
        checkRows(r,:)=[data(k,1),j,E.feasible,E.rhoFull,E.rhoReachable, ...
            E.rcond,E.residual,E.closedFormError,E.iterationError, ...
            E.costSumError,E.iterations,E.checksPassed,E.closedFormCost];
        for s=1:5
            stateRows(end+1,:)={data(k,1),j,E.stateNames{s}, ...
                E.reachable(s),E.canFinish(s),sum(E.stageCost(s,:)), ...
                E.value(s),E.expectedVisits(s)}; %#ok<AGROW>
        end
        for s=1:6
            for t=1:6
                if E.P(s,t)>0
                    if s==6, reachableSource=E.absorptionProbability>0;
                    else, reachableSource=E.reachable(s); end
                    transitionRows(end+1,:)={data(k,1),j,E.stateNames{s}, ...
                        E.stateNames{t},E.P(s,t),reachableSource}; %#ok<AGROW>
                end
            end
        end
    end
    fprintf('情形 %g：状态方程与核验已完成。\n',data(k,1));
end

%% 步骤 4：比较期望利润，保留全部并列最优方案
allT=array2table(numeric,'VariableNames',{'Scenario','StrategyID', ...
    'TestPart1','TestPart2','TestProduct','Disassemble','Feasible', ...
    'ExpectedCost','ExpectedProfit','AbsorptionProbability', ...
    'FirstPassYield','ReachableStates','SpectralRadius'});
allT.Code=codes; allT.Status=status;
isOptimal=false(total,1); bestRows=zeros(nCase,1); bestIDs=zeros(nCase,1);
for k=1:nCase
    group=(k-1)*16+(1:16);
    best=max(allT.ExpectedProfit(group));
    assert(isfinite(best),'情形 %g 没有可行策略。',data(k,1));
    ties=group(allT.Feasible(group)==1 & abs(allT.ExpectedProfit(group)-best)<=opts.tieTolerance);
    isOptimal(ties)=true; bestRows(k)=ties(1); bestIDs(k)=allT.StrategyID(ties(1));
    fprintf('情形 %g：最大期望利润 %.8f 元；最优策略编号 %s\n', ...
        data(k,1),best,strtrim(sprintf('%d ',allT.StrategyID(ties))));
end
allT.IsOptimal=isOptimal;
allT.Properties.VariableDescriptions={'情形','策略编号','检测零配件1', ...
    '检测零配件2','检测成品','拆解不合格成品','可行标志', ...
    '期望总成本_元每订单','期望利润_元每订单','最终合格交付概率', ...
    '新采购首次装配合格概率','可达非终止状态数','可达子链谱半径', ...
    '策略编码','可行性说明','最优标志'};

%% 步骤 5：默认数据回归检查，特别核对拆解可行性和情形3的并列最优
if isequal(double(data),builtinData)
    expectedProfit=[18.1111111111111;12;15.4444444444444;14.75; ...
        11.9876543209877;21.6786703601108];
    expectedIDs={14,14,[14,16],16,5,1};
    assert(all(abs(allT.ExpectedProfit(bestRows)-expectedProfit)<1e-8), ...
        '内置参数最优利润回归核验失败。');
    for k=1:nCase
        group=(k-1)*16+(1:16);
        actual=allT.StrategyID(group(isOptimal(group))).';
        assert(isequal(actual,expectedIDs{k}),'默认最优策略集合核验失败。');
        assert(sum(allT.Feasible(group))==10,'默认应有 10 种可行固定策略。');
    end
end

%% 步骤 6：可选的独立事件仿真，只验证各情形的代表最优策略
% 不依赖 Q 抽样，直接模拟采购、检测、装配、调换和拆解事件。
% Monte Carlo 只做统计核验，不替代精确期望优化；不属于实测数据。
mcRows=zeros(0,9);
if opts.runMonteCarlo
    originalRng=rng; rngCleanup=onCleanup(@()rng(originalRng)); %#ok<NASGU>
    rng(opts.randomSeed,'twister');
    for k=1:nCase
        j=bestIDs(k); E=evaluations{k,j};
        M=simulateOrders(data(k,:),decisions(j,:),opts);
        mcRows(end+1,:)=[data(k,1),j,opts.mcOrders,E.expectedCost, ...
            M.meanCost,M.standardError,M.ciLow,M.ciHigh,M.meanCost-E.expectedCost]; %#ok<AGROW>
        fprintf('情形 %g 仿真：平均成本 %.5f 元，标准误 %.5f 元。\n', ...
            data(k,1),M.meanCost,M.standardError);
    end
end

%% 步骤 7：整理全部结果表，供 Excel 输出与后续论文作图复用
T=struct();
T.parameters=makeNumericTable(data,{'Scenario','p1','b1','t1','p2','b2','t2', ...
    'pf','AssemblyCost','ProductTestCost','Price','ExchangeLoss','DisassemblyCost'}, ...
    {'情形','零件1次品率','零件1采购单价_元','零件1检测单价_元', ...
    '零件2次品率','零件2采购单价_元','零件2检测单价_元', ...
    '合格零件装配次品率','装配单价_元','成品检测单价_元', ...
    '售价_元','每次调换额外损失_元','拆解单价_元'});
T.strategies=makeNumericTable([(1:16).',decisions], ...
    {'StrategyID','TestPart1','TestPart2','TestProduct','Disassemble'}, ...
    {'策略编号','检测零配件1','检测零配件2','检测成品','拆解不合格成品'});
T.allStrategies=allT;
T.optimal=allT(isOptimal,:);
T.representative=allT(bestRows,:); % 仅用于绘图/仿真，选择并列集合中编号最小者
T.costBreakdown=makeNumericTable(costRows,{'Scenario','StrategyID','Purchase1', ...
    'Purchase2','Test1','Test2','Assembly','ProductTest','Exchange','Disassembly','Total'}, ...
    {'情形','策略编号','采购件1_元每订单','采购件2_元每订单', ...
    '检测件1_元每订单','检测件2_元每订单','装配_元每订单', ...
    '成品检测_元每订单','调换损失_元每订单','拆解_元每订单','总成本_元每订单'});
T.eventCounts=makeNumericTable(countRows,{'Scenario','StrategyID','Buy1','Buy2', ...
    'Test1','Test2','Assembly','ProductTest','Exchange','Disassembly','AbsorptionProbability'}, ...
    {'情形','策略编号','采购件1_件每订单','采购件2_件每订单', ...
    '检测件1_次每订单','检测件2_次每订单','装配_次每订单', ...
    '成品检测_次每订单','调换_次每订单','拆解_次每订单','最终交付概率'});
T.checks=makeNumericTable(checkRows,{'Scenario','StrategyID','Feasible','FullRho', ...
    'ReachableRho','Rcond','Residual','ClosedFormError','IterationError','CostSumError', ...
    'Iterations','Passed','ClosedFormCost'}, ...
    {'情形','策略编号','可行标志','全状态谱半径_仅参考','可达子链谱半径', ...
    '倒条件数','方程残差','闭式成本误差_元','迭代误差_元','成本加总误差_元', ...
    '核验迭代次数','适用检查通过标志','闭式公式成本_元'});
T.monteCarlo=makeNumericTable(mcRows,{'Scenario','StrategyID','Orders','ExactCost', ...
    'MeanCost','StandardError','CI95Low','CI95High','Difference'}, ...
    {'情形','策略编号','模拟订单数','精确期望成本_元','模拟平均成本_元', ...
    '模拟均值标准误_元','均值近似95区间下限_元','均值近似95区间上限_元','模拟减精确_元'});
T.states=cell2table(stateRows,'VariableNames',{'Scenario','StrategyID','State', ...
    'Reachable','CanFinish','ImmediateCost','RemainingCost','ExpectedVisits'});
T.states.Properties.VariableDescriptions={'情形','策略编号','状态', ...
    '从初始可达','存在完成路径','本次状态期望成本_元','状态剩余期望成本_元','期望访问次数'};
T.transitions=cell2table(transitionRows,'VariableNames',{'Scenario','StrategyID', ...
    'FromState','ToState','Probability','SourceReachable'});
T.transitions.Properties.VariableDescriptions={'情形','策略编号','起始状态','目标状态', ...
    '一步转移概率','起始状态从初始可达'};

R=struct('parameters',data,'options',opts,'tables',T,'evaluations',{evaluations}, ...
    'bestIDs',bestIDs,'bestRows',bestRows,'checksPassed',all(checkRows(:,12)==1));
R.modelScope='四项固定决策循环复用；已知合格件免复检；每个合格交付订单的期望利润';
%% 步骤 8：中文作图、输出 Excel / MAT / 文本报告
R=Q2_export_results(R);
fprintf('\n结果核验通过。注意：这不是对所有自适应返工策略的全局优化。\n');
fprintf('策略位顺序：检测件1、检测件2、检测成品、拆解；1为是，0为否。\n');
disp(R.tables.optimal(:,{'Scenario','StrategyID','Code','ExpectedCost','ExpectedProfit'}));
if opts.saveFiles, fprintf('本次结果目录：%s\n',R.outputDir); end
end

function T=makeNumericTable(values,names,headers)
T=array2table(values,'VariableNames',names);
T.Properties.VariableDescriptions=headers;
end

function M=simulateOrders(row,d,opts)
% 独立事件路径：重新采购才重新随机生成零件质量，回用时保留原质量。
p=[row(2),row(5)]; b=[row(3),row(6)]; test=[row(4),row(7)];
pf=row(8); a=row(9); tf=row(10); loss=row(12); dis=row(13);
costs=zeros(opts.mcOrders,1);
for order=1:opts.mcOrders
    quality=[]; cost=0; completed=false;
    for attempt=1:opts.maxAssembliesPerOrder
        if isempty(quality)
            quality=false(1,2);
            for part=1:2
                while true
                    cost=cost+b(part); good=rand>=p(part);
                    if d(part)==1
                        cost=cost+test(part);
                        if ~good, continue; end
                    end
                    quality(part)=good; break;
                end
            end
        end
        cost=cost+a+d(3)*tf;
        if all(quality) && rand>=pf
            completed=true; break;
        end
        cost=cost+(1-d(3))*loss;
        if d(4)==1, cost=cost+dis; else, quality=[]; end
    end
    assert(completed,['仿真达到单订单装配保护上限，已中止；', ...
        '未将未交付订单当作完成订单，也未输出截断均值。']);
    costs(order)=cost;
end
M.meanCost=mean(costs); M.standardError=std(costs,0)/sqrt(opts.mcOrders);
M.ciLow=M.meanCost-1.96*M.standardError;
M.ciHigh=M.meanCost+1.96*M.standardError;
end
