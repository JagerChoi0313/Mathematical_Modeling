function R = Q3_tree_export(R)
%Q3_TREE_EXPORT 全部结果表写入Excel，输出中文PNG、矢量PDF及可编辑FIG。
% 本函数只使用已经计算的R，不重新选择策略或修改经济结果。
% 可单独重画：load('Q3_results.mat','R'); R=Q3_tree_export(R);
opts=R.options; R.outputDir=''; R.excelPath='';
R.figurePaths=cell(0,1); R.pdfPaths=cell(0,1); R.figPaths=cell(0,1);
R.exportWarnings=cell(0,1);
if opts.saveFiles
    if ~exist(opts.outputRoot,'dir'), mkdir(opts.outputRoot); end
    stamp=['run_',datestr(now,'yyyymmdd_HHMMSS')];
    folder=fullfile(opts.outputRoot,stamp); number=1;
    while exist(folder,'dir')
        folder=fullfile(opts.outputRoot,sprintf('%s_%03d',stamp,number)); number=number+1;
    end
    [ok,msg]=mkdir(folder); assert(ok,'创建输出目录失败：%s',msg); R.outputDir=folder;
end

%% 步骤1：保存所有table；中文表头与解释，缺失值/无穷值明确区分
mapping={'parts','零配件参数';'assembly','装配参数';'tree','装配关系'; ...
    'encoding','编码说明';'allStrategies','全部候选策略';'optimal','全部最优方案'; ...
    'top','利润排名前列';'costs','可行策略成本分解';'events','可行策略操作次数'; ...
    'checks','递推数值核验';'nodes','最优方案节点递推';'rawOptimal','最优原始编码'; ...
    'monteCarlo','蒙特卡洛核验'};
assert(isequal(sort(fieldnames(R.tables)),sort(mapping(:,1))),'存在没有安排Excel输出的表格。');
R.sheetMap=mapping;
if opts.saveFiles
    xlsx=fullfile(R.outputDir,'Q3_tables.xlsx');
    notes={ '项目','说明';'参数来源','2024年全国大学生数学建模竞赛B题表2及附录'; ...
        '计算口径','元/完成一个合格交付订单；售价只计一次'; ...
        '市场售价',R.parameters.price;'额外调换损失',R.parameters.loss; ...
        '原始策略数',R.rawCount;'去重候选数',R.candidateCount; ...
        '去重可行数',R.feasibleCount;'原始编码可行数',R.rawFeasibleCount; ...
        '决策编码','零配件检测x，全部装配节点检测y，全部装配节点拆解z；各组最后一个装配节点是成品'; ...
        '策略编号','原始二进制编码转十进制再加1，不是去重后的行号'; ...
        '去重规则','半成品不检测时将其拆解位设0；候选策略不等于可行策略'; ...
        '拆解规则','原直接投入物质量不变，已知合格物料免复检；不增加自适应改检/限次回用'; ...
        '条件次品率','半成品和成品次品率均以直接投入物全部合格为条件'; ...
        '特殊值','+Inf为无限成本，-Inf为无限负利润，NaN为不适用；Excel中用文字保存'; ...
        '节点费用','独立取得该节点一个输出的期望费用，不可直接相加为订单总成本'; ...
        '成本和事件表','仅列有限成本策略；全部候选含不可行原因'; ...
        '并列最优','全部保留；图像最多展示前10个，原始等价编码另列'; ...
        '仿真','随机模拟不是实测；区间针对模拟均值，不用于搜索最优策略'; ...
        '修改参数','工作簿为结果快照，修改后需重新运行MATLAB'; ...
        '运行时间',datestr(now,'yyyy-mm-dd HH:MM:SS')};
    try
        writecell(notes,xlsx,'Sheet','说明');
        for j=1:size(mapping,1)
            writeOneTable(R.tables.(mapping{j,1}),xlsx,mapping{j,2});
            fprintf('Excel工作表已写入：%s\n',mapping{j,2});
        end
        R.excelPath=xlsx;
    catch ME
        R.exportWarnings{end+1,1}=['Excel未全部保存：',ME.message];
        warning('Q3:Excel','%s',R.exportWarnings{end});
    end
end

%% 步骤2：生成六幅中文图，均使用精确结果或明确标注的模拟结果
R.fontName=chooseFont(opts.fontName);
plotters={@plotStrategyProfits,@plotDecisions,@plotCostBreakdown,@plotOperations,@plotTree};
basenames={'Q3_01_strategy_profits','Q3_02_optimal_decisions','Q3_03_cost_breakdown', ...
    'Q3_04_operation_counts','Q3_05_assembly_tree'};
if ~isempty(R.tables.monteCarlo)
    plotters{end+1}=@plotValidation; basenames{end+1}='Q3_06_monte_carlo_validation';
end
if opts.makeFigures
    for j=1:numel(plotters)
        fig=[];
        try
            [fig,target]=plotters{j}(R);
            cleanFigure(fig,R.fontName); drawnow;
            if opts.saveFiles
                % 分别保存各格式；某一格式失败不覆盖已成功的文件。
                formats={'png','pdf','fig'};
                for f=1:3
                    path=fullfile(R.outputDir,[basenames{j},'.',formats{f}]);
                    try
                        switch formats{f}
                            case 'png'
                                exportgraphics(target,path,'Resolution',300,'BackgroundColor','white');
                                R.figurePaths{end+1,1}=path;
                            case 'pdf'
                                exportgraphics(target,path,'ContentType','vector','BackgroundColor','white');
                                R.pdfPaths{end+1,1}=path;
                            case 'fig'
                                savefig(fig,path); R.figPaths{end+1,1}=path;
                        end
                    catch ME
                        R.exportWarnings{end+1,1}=sprintf('%s保存失败：%s',formats{f},ME.message);
                        warning('Q3:FigureExport','%s',R.exportWarnings{end});
                    end
                end
            end
            if strcmp(opts.figureVisible,'off'), close(fig); end
        catch ME
            R.exportWarnings{end+1,1}=sprintf('图%d生成失败：%s',j,ME.message);
            warning('Q3:Plot','%s',R.exportWarnings{end});
            if ~isempty(fig) && isgraphics(fig) && strcmp(opts.figureVisible,'off'), close(fig); end
        end
    end
end

%% 步骤3：完整MAT结构和可读报告；即使绘图失败也保留数值结果
if opts.saveFiles
    fid=fopen(fullfile(R.outputDir,'Q3_report.txt'),'w','n','UTF-8');
    if fid~=-1
        cleanup=onCleanup(@()fclose(fid));
        fprintf(fid,'第三问：装配树分层递推与固定策略全枚举\n\n');
        fprintf(fid,'模型范围：%s\n',R.modelScope);
        fprintf(fid,'原始编码%d；去重候选%d；去重可行%d。\n',R.rawCount,R.candidateCount,R.feasibleCount);
        T=R.tables.optimal;
        for i=1:height(T)
            fprintf(fid,'最优策略ID%d，编码%s，成本%.10f元，利润%.10f元。\n', ...
                T.StrategyID(i),T.Code{i},T.ExpectedCost(i),T.ExpectedProfit(i));
        end
        fprintf(fid,'编码顺序：%s\n',strjoin(R.bitNames,'、'));
        fprintf(fid,'递推数值核验通过：%d；仿真开启：%d。\n',R.checksPassed,opts.runMonteCarlo);
        fprintf(fid,'PNG/PDF/FIG成功数量：%d/%d/%d；Excel成功：%d。\n', ...
            numel(R.figurePaths),numel(R.pdfPaths),numel(R.figPaths),~isempty(R.excelPath));
        for i=1:numel(R.exportWarnings), fprintf(fid,'输出提示：%s\n',R.exportWarnings{i}); end
        clear cleanup;
    else
        warning('Q3:Report','文本报告写入失败，但将继续保存MAT。');
    end
    save(fullfile(R.outputDir,'Q3_results.mat'),'R');
end
end

function [fig,tl]=newFigure(R,name,rows,cols,sz)
fig=figure('Name',name,'Color','w','Visible',R.options.figureVisible, ...
    'Units','pixels','Position',[80 60 sz],'ToolBar','none','MenuBar','none');
tl=tiledlayout(fig,rows,cols,'TileSpacing','compact','Padding','loose');
end

function [fig,tl]=plotStrategyProfits(R)
[fig,tl]=newFigure(R,'策略利润分布与前列方案',1,2,[1250 530]);
T=R.tables.allStrategies; v=T.ExpectedProfit(T.Feasible);
ax=nexttile(tl); histogram(ax,v,45,'FaceColor',[.24 .48 .65],'EdgeColor','none');
xline(ax,max(v),'--','最高利润','Color',[.15 .48 .32],'LabelOrientation','horizontal');
xlabel(ax,'期望利润（元/合格交付订单）'); ylabel(ax,'可行候选策略数量');
title(ax,sprintf('%d种可行候选的利润分布',R.feasibleCount)); grid(ax,'on');
ax=nexttile(tl); T=R.tables.top; b=barh(ax,T.ExpectedProfit,'FaceColor','flat','EdgeColor','none');
b.CData=repmat([.36 .56 .71],height(T),1); b.CData(T.IsOptimal,:)=repmat([.14 .52 .36],sum(T.IsOptimal),1);
set(ax,'YDir','reverse','YTick',1:height(T),'YTickLabel',compose('策略%d',T.StrategyID));
xlabel(ax,'期望利润（元/合格交付订单）'); title(ax,'利润排名前列的固定策略'); grid(ax,'on');
pad=max(1,.1*max(abs(T.ExpectedProfit))); xlim(ax,[min(0,min(T.ExpectedProfit)-pad),max(0,max(T.ExpectedProfit)+pad)]);
for i=1:height(T)
    text(ax,T.ExpectedProfit(i)+pad/12,i,sprintf('%.4f',T.ExpectedProfit(i)), ...
        'VerticalAlignment','middle','FontSize',10);
end
title(tl,sprintf('原始编码%d种，去重候选%d种；不可行策略不赋予有限利润',R.rawCount,R.candidateCount),'FontWeight','bold');
end

function [fig,tl]=plotDecisions(R)
T=R.tables.optimal; keep=1:min(10,height(T)); d=R.decisions(R.bestRows(keep),:);
n=size(R.parameters.parts,1); k=size(R.parameters.assembly,1);
[fig,tl]=newFigure(R,'最优方案决策',3,1,[1100 690]);
groups={1:n,n+(1:k),n+k+(1:k)};
captions={'零配件检测','半成品与成品检测','半成品与成品拆解'};
for j=1:3
    ax=nexttile(tl); v=d(:,groups{j}); imagesc(ax,v,[0 1]);
    colormap(ax,[.92 .95 .97;.10 .46 .37]);
    set(ax,'XTick',1:size(v,2),'XTickLabel',R.bitNames(groups{j}), ...
        'YTick',1:size(v,1),'YTickLabel',compose('策略%d',T.StrategyID(keep)));
    for row=1:size(v,1)
        for col=1:size(v,2)
            if v(row,col), s='是'; color=[1 1 1]; else, s='否'; color=[.2 .25 .3]; end
            text(ax,col,row,s,'Color',color,'FontSize',15,'HorizontalAlignment','center');
        end
    end
    title(ax,captions{j});
end
title(tl,sprintf('最优固定决策：共%d种行为方案，图示%d种；全部结果见Excel',height(T),numel(keep)));
end

function [fig,tl]=plotCostBreakdown(R)
[fig,tl]=newFigure(R,'最优方案期望成本构成',1,1,[1050 570]);
ax=nexttile(tl); c=R.bestEvaluation.costBreakdown;
b=barh(ax,c,'FaceColor','flat','EdgeColor','none');
b.CData=[.22 .42 .62;.36 .64 .72;.42 .61 .46;.61 .70 .46;.60 .53 .69; ...
    .30 .51 .43;.72 .67 .37;.53 .42 .65;.80 .44 .33];
set(ax,'YDir','reverse','YTick',1:9,'YTickLabel',R.costGroupNames);
xlim(ax,[0,max(c)*1.22+1]); xlabel(ax,'期望费用（元/合格交付订单）'); grid(ax,'on');
for i=1:9, text(ax,c(i)+max(c)*.015,i,sprintf('%.4f',c(i)),'VerticalAlignment','middle'); end
title(tl,{sprintf('代表最优策略%d的期望成本构成',R.bestEvaluation.strategyID), ...
    sprintf('售价 %.4f 元 = 总期望成本 %.4f 元 + 期望利润 %.4f 元', ...
    R.parameters.price,R.bestEvaluation.expectedCost,R.bestEvaluation.expectedProfit)});
end

function [fig,tl]=plotOperations(R)
[fig,tl]=newFigure(R,'完成订单所需期望操作次数',1,1,[1120 660]);
n=size(R.parameters.parts,1); k=size(R.parameters.assembly,1); e=R.bestEvaluation.eventCounts;
a=[e(1:n),e(2*n+(1:k))].'; b=[e(n+(1:n)),e(2*n+k+(1:k))].';
c=[zeros(1,n),e(2*n+2*k+(1:k))].';
ax=nexttile(tl); h=barh(ax,[a b c],'grouped','EdgeColor','none');
colors=[.25 .47 .67;.40 .66 .72;.59 .49 .68];
for j=1:3, h(j).FaceColor=colors(j,:); end
set(ax,'YDir','reverse','YTick',1:n+k,'YTickLabel',R.nodeNames);
xlim(ax,[0,max([a;b;c])*1.18+.05]); xlabel(ax,'每个合格交付订单的期望次数'); grid(ax,'on');
legend(ax,{'采购或装配','检测','拆解'},'Location','southoutside','Orientation','horizontal');
title(tl,{sprintf('代表最优策略%d的期望操作次数',R.bestEvaluation.strategyID), ...
    sprintf('零配件行第一项为采购件数；装配节点行第一项为装配次数；期望调换 %.4f 次',e(end))});
end

function [fig,tl]=plotTree(R)
[fig,tl]=newFigure(R,'装配树与节点递推结果',1,1,[1300 600]);
ax=nexttile(tl); hold(ax,'on'); P=R.parameters;
n=size(P.parts,1); k=size(P.assembly,1); xx=zeros(1,n+k); yy=xx; xx(1:n)=1:n;
for j=1:k
    ch=P.children{j}; xx(n+j)=mean(xx(ch)); yy(n+j)=min(yy(ch))-1;
end
for j=1:k
    v=n+j;
    for child=P.children{j}(:).'
        quiver(ax,xx(child),yy(child)-.14,xx(v)-xx(child),yy(v)-yy(child)+.32,0, ...
            'Color',[.57 .64 .68],'MaxHeadSize',.17,'LineWidth',1.2);
    end
end
E=R.bestEvaluation;
for v=1:n+k
    label=sprintf('%s\n费用 %.2f 元\n输出合格 %.1f%%',R.nodeNames{v},E.nodeCost(v),100*E.nodeG(v));
    text(ax,xx(v),yy(v),label,'HorizontalAlignment','center','VerticalAlignment','middle', ...
        'FontSize',10,'BackgroundColor',[.92 .97 .95],'EdgeColor',[.35 .57 .50],'Margin',5);
end
xlim(ax,[.25,n+.75]); ylim(ax,[min(yy)-.5,.55]); axis(ax,'off');
title(tl,{'最优代表方案的装配树与节点递推结果', ...
    '节点费用为独立取得一个该节点输出的期望费用，不能相加作为订单总成本；根节点表示合格交付'});
end

function [fig,tl]=plotValidation(R)
[fig,tl]=newFigure(R,'蒙特卡洛仿真核验',2,1,[1120 740]);
T=R.tables.monteCarlo; ax=nexttile(tl); positions=1:height(T);
h1=errorbar(ax,positions,T.MeanCost,1.96*T.StandardError,'o','LineStyle','none', ...
    'Color',[.23 .48 .68],'MarkerFaceColor',[.23 .48 .68],'LineWidth',1.5); hold(ax,'on');
h2=plot(ax,positions,T.ExactCost,'d','LineStyle','none','Color',[.80 .37 .24], ...
    'MarkerFaceColor','w','MarkerSize',8,'LineWidth',1.5);
set(ax,'XTick',positions,'XTickLabel',compose('策略%d',T.StrategyID));
xlim(ax,[.5,height(T)+.5]); ylabel(ax,'成本（元/合格交付订单）'); grid(ax,'on');
legend(ax,[h1 h2],{'模拟均值及近似95%区间','递推理论期望'},'Location','best');
title(ax,sprintf('每种代表方案模拟%d个订单',R.options.mcOrders));
ax=nexttile(tl); plot(ax,1:numel(R.mcHistory),R.mcHistory,'Color',[.25 .51 .64],'LineWidth',1.2); hold(ax,'on');
yline(ax,R.bestEvaluation.expectedCost,'--','理论期望','Color',[.78 .35 .23],'LineWidth',1.3);
xlabel(ax,'累计模拟订单数'); ylabel(ax,'累计平均成本（元/订单）'); grid(ax,'on');
title(ax,'最优代表方案的模拟均值收敛过程');
title(tl,'独立事件仿真核验：仿真数据不是实际生产观测，区间仅表示模拟均值的不确定性');
end

function font=chooseFont(requested)
if ~isempty(requested), font=char(requested); return; end
font=get(groot,'DefaultAxesFontName');
try
    available=listfonts;
    candidates={'Microsoft YaHei','微软雅黑','SimHei','黑体','SimSun','宋体', ...
        'Noto Sans CJK SC','Source Han Sans SC','PingFang SC','Heiti SC','WenQuanYi Zen Hei'};
    for j=1:numel(candidates)
        hit=find(strcmpi(available,candidates{j}),1);
        if ~isempty(hit), font=available{hit}; return; end
    end
catch
end
% 字体列表在某些系统上不完整；采用系统回退，用户也可通过fontName指定。
end

function cleanFigure(fig,font)
set(findall(fig,'-property','FontName'),'FontName',font);
set(findall(fig,'-property','Interpreter'),'Interpreter','none');
set(findall(fig,'-property','TickLabelInterpreter'),'TickLabelInterpreter','none');
axesList=findall(fig,'Type','axes');
for j=1:numel(axesList)
    set(axesList(j),'FontSize',11,'LineWidth',.8,'GridAlpha',.15,'Box','off');
    try, axesList(j).Toolbar.Visible='off'; catch, end
end
end

function writeOneTable(T,file,sheet)
if width(T)==0
    writecell({'说明';'本次未开启蒙特卡洛仿真'},file,'Sheet',sheet); return;
end
header=T.Properties.VariableNames; desc=T.Properties.VariableDescriptions;
english={'StrategyID','Code','Feasible','ExpectedCost','ExpectedProfit','EquivalentRawCount', ...
    'IsOptimal','Status','PartID','DefectRate','PurchaseCost','TestCost','NodeID','AssemblyCost', ...
    'DisassemblyCost','NodeName','Children','Position','Decision','RenewalResidual','CostSumError', ...
    'OutputGoodProbability','FirstPassGoodProbability','ExpectedSupplyCost','RawStrategyID','RawCode', ...
    'CanonicalStrategyID','Orders','ExactCost','MeanCost','StandardError','Lower95','Upper95'};
chinese={'策略编号','策略编码','是否可行','期望成本_元每订单','期望利润_元每订单','等价原始编码数', ...
    '是否最优','状态说明','零配件编号','次品率_小数','购买单价_元','检测费_元','节点编号','装配费_元', ...
    '拆解费_元','节点名称','直接子节点编号','编码位置','决策含义','更新方程残差','成本分解误差', ...
    '输出合格概率','首次装配或取得合格概率','独立取得一个节点输出的期望费用_元','原始策略编号','原始策略编码', ...
    '规范策略编号','模拟订单数','理论期望成本_元','模拟均值_元','模拟标准误_元','均值近似95区间下限_元','均值近似95区间上限_元'};
for j=1:numel(header)
    if numel(desc)>=j && ~isempty(desc{j})
        header{j}=desc{j};
    else
        hit=find(strcmp(english,header{j}),1);
        if ~isempty(hit), header{j}=chinese{hit}; end
    end
end
cells=table2cell(T);
for j=1:numel(cells)
    v=cells{j};
    if isnumeric(v)&&isscalar(v)
        if isnan(v), cells{j}='NaN';
        elseif isinf(v) && v>0, cells{j}='+Inf';
        elseif isinf(v), cells{j}='-Inf'; end
    elseif islogical(v), cells{j}=double(v);
    elseif isstring(v), cells{j}=char(v); end
end
writecell([header;cells],file,'Sheet',sheet,'Range','A1');
end
