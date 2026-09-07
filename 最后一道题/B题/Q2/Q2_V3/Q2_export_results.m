function R = Q2_export_results(R)
%Q2_EXPORT_RESULTS 输出论文用中文图表、Excel结果表和文本报告。
% 本文件只读取 Q2_markov_main 已经求得的结果，不改变状态递推、
% 策略可行性、期望成本、期望利润或最优策略。
% 推荐 MATLAB R2020a 或更高版本，不需要统计/优化工具箱。

opts=R.options;
R.outputDir=''; R.excelPath='';
R.figurePaths=cell(0,1);       % 300 dpi PNG
R.pdfFigurePaths=cell(0,1);    % 论文用矢量 PDF
R.figureFiles=cell(0,1);       % MATLAB 可编辑 FIG
R.figureNames=cell(0,1);
R.exportWarnings=cell(0,1);

if opts.saveFiles
    if ~exist(opts.outputRoot,'dir')
        [ok,msg]=mkdir(opts.outputRoot);
        assert(ok,'无法创建输出目录：%s',msg);
    end
    stamp=['run_',datestr(now,'yyyymmdd_HHMMSS')];
    folder=fullfile(opts.outputRoot,stamp); suffix=1;
    while exist(folder,'dir')
        folder=fullfile(opts.outputRoot,sprintf('%s_%03d',stamp,suffix));
        suffix=suffix+1;
    end
    [ok,msg]=mkdir(folder);
    assert(ok,'无法创建本次运行目录：%s',msg);
    R.outputDir=folder;
end

%% 步骤1：选择绘图字体
% Windows 可能返回中文字体名，也可能返回英文名，因此同时支持两种写法。
% 若无法识别预设名称，交由 MATLAB 的字体回退机制显示中文，不再产生误报警告。
fontName=''; fontNote='';
if opts.makeFigures
    [fontName,fontNote]=chooseChineseFont(opts.fontName);
end
R.fontName=fontName;
if ~isempty(fontNote)
    R.exportWarnings{end+1,1}=fontNote;
    warning('Q2:Font','%s',fontNote);
end

%% 步骤2：生成论文用图表
% 图1适合正文总览；图3、图4适合正文说明最优决策和利润来源；
% 图2适合正文或附录；图5~图7分别展示操作量、利润差距和仿真核验。
% 利润差距没有改变任何输入参数，不应称为参数敏感性分析。
if opts.makeFigures
    plotters={@plotProfitHeatmap,@plotProfitPanels,@plotOptimalDecisions, ...
        @plotCostBreakdown,@plotOperationCounts,@plotProfitRanking};
    basenames={'Q2_01_profit_heatmap','Q2_02_strategy_profit_panels', ...
        'Q2_03_optimal_decisions','Q2_04_optimal_cost_breakdown', ...
        'Q2_05_expected_operation_counts','Q2_06_best_second_profit_gap'};
    chineseNames={'全部策略利润热力图','各情形策略利润详细比较', ...
        '最优决策矩阵','最优方案期望成本构成', ...
        '最优方案期望操作次数','最优与第二名利润差'};
    if ~isempty(R.tables.monteCarlo)
        plotters{end+1}=@plotMonteCarloCheck;
        basenames{end+1}='Q2_07_monte_carlo_validation';
        chineseNames{end+1}='蒙特卡洛仿真核验';
    end

    for figureNumber=1:numel(plotters)
        fig=[];
        try
            [fig,exportTarget]=plotters{figureNumber}(R,fontName);
            cleanFigureForExport(fig,fontName);
            drawnow;
            if opts.saveFiles
                png=fullfile(R.outputDir,[basenames{figureNumber},'.png']);
                pdf=fullfile(R.outputDir,[basenames{figureNumber},'.pdf']);
                figfile=fullfile(R.outputDir,[basenames{figureNumber},'.fig']);
                exportgraphics(exportTarget,png,'Resolution',300, ...
                    'BackgroundColor','white');
                % PDF 使用矢量方式导出，插入论文后放大仍保持清晰。
                exportgraphics(exportTarget,pdf,'ContentType','vector', ...
                    'BackgroundColor','white');
                savefig(fig,figfile);
                R.figurePaths{end+1,1}=png;
                R.pdfFigurePaths{end+1,1}=pdf;
                R.figureFiles{end+1,1}=figfile;
                R.figureNames{end+1,1}=chineseNames{figureNumber};
            end
            if strcmp(opts.figureVisible,'off'), close(fig); end
        catch ME
            message=sprintf('图%d“%s”生成或保存失败：%s', ...
                figureNumber,chineseNames{figureNumber},ME.message);
            R.exportWarnings{end+1,1}=message;
            warning('Q2:Figure','%s',message);
            if ~isempty(fig) && isgraphics(fig) && strcmp(opts.figureVisible,'off')
                close(fig);
            end
        end
    end
end

%% 步骤3：把所有结果表统一写入 Excel
R.sheetMap={ ...
    'parameters','题目参数';
    'strategies','策略编码';
    'allStrategies','全部策略结果';
    'optimal','全部最优方案';
    'representative','绘图代表方案';
    'costBreakdown','期望成本分解';
    'eventCounts','期望事件次数';
    'checks','数值核验';
    'monteCarlo','蒙特卡洛核验';
    'states','状态价值';
    'transitions','状态转移'};
fields=fieldnames(R.tables);
assert(numel(fields)==size(R.sheetMap,1) && ...
    all(ismember(fields,R.sheetMap(:,1))),'存在没有安排Excel输出的结果表。');

if opts.saveFiles
    xlsx=fullfile(R.outputDir,'Q2_tables.xlsx');
    try
        notes={ ...
            '项目','说明';
            '原始参数来源','2024年全国大学生数学建模竞赛B题表1及附录；可由调用参数替换';
            '运行时间',datestr(now,'yyyy-mm-dd HH:MM:SS');
            '利润口径','一个付费订单最终交付一件合格品；售价只计一次；金额单位为元';
            '策略位顺序','检测零件1、检测零件2、检测成品、拆解；1为是，0为否';
            '策略编号','1+8*x1+4*x2+2*y+z，编号从1到16';
            '最优范围','四项决策保持不变的固定策略集合，不含自适应复检或限次拆解';
            '回用规则','拆解不损伤零件、不改变真实质量；已检测合格件免重复检测';
            '条件次品率','成品次品率指两零件均合格时的装配次品率';
            '调换损失','仅为额外损失；替换品生产成本已由状态递推计算';
            '可行性','每个从待采购状态可达的状态都必须存在完成交付路径';
            '特殊数值','Inf为无穷成本，-Inf为无穷负利润，NaN为不适用或不可达';
            '并列最优','全部保留；成本图选并列最优中编号最小者作为代表';
            '蒙特卡洛','随机模拟而非实测数据；95%区间针对模拟均值';
            '模拟订单数',opts.mcOrders;
            '随机种子',opts.randomSeed;
            '图表输出','每张图同时输出300 dpi PNG、矢量PDF和可编辑FIG';
            '结果更新','本工作簿是计算快照；修改参数后需重新运行MATLAB'};
        writecell(notes,xlsx,'Sheet','说明','Range','A1');
        for k=1:size(R.sheetMap,1)
            writeResultTable(R.tables.(R.sheetMap{k,1}),xlsx,R.sheetMap{k,2});
        end
        R.excelPath=xlsx;
        fprintf('Excel 已输出：%s\n',xlsx);
    catch ME
        message=sprintf('Excel输出未全部成功：%s。请关闭同名文件后重新运行。',ME.message);
        R.exportWarnings{end+1,1}=message;
        warning('Q2:Excel','%s',message);
    end

    %% 步骤4：保存文本报告和完整 MATLAB 结构体
    report=fullfile(R.outputDir,'Q2_report.txt');
    try
        fid=fopen(report,'w','n','UTF-8');
        assert(fid~=-1,'不能写入文本报告。');
        fileCleanup=onCleanup(@()fclose(fid));
        fprintf(fid,'第二问：吸收马尔可夫链与固定策略全枚举\n\n');
        fprintf(fid,'口径：每个最终完成合格交付订单的期望利润，售价只计一次。\n');
        fprintf(fid,'策略：检测零件1、检测零件2、检测成品、拆解；1为是，0为否。\n');
        fprintf(fid,'全部并列最优均保留；本结论限于当前固定策略集合。\n\n');
        T=R.tables.optimal;
        for k=1:height(T)
            fprintf(fid,['情形%g，策略%d（%s），期望成本%.10f元，', ...
                '期望利润%.10f元。\n'],T.Scenario(k),T.StrategyID(k), ...
                T.Code{k},T.ExpectedCost(k),T.ExpectedProfit(k));
        end
        fprintf(fid,'\n适用数值检查均通过：%d\n',R.checksPassed);
        fprintf(fid,'蒙特卡洛开启：%d；该结果不是实测数据。\n',opts.runMonteCarlo);
        fprintf(fid,'成功输出PNG/PDF/FIG：%d/%d/%d张。\n', ...
            numel(R.figurePaths),numel(R.pdfFigurePaths),numel(R.figureFiles));
        fprintf(fid,'Excel全部写入成功：%d\n',~isempty(R.excelPath));
        for k=1:numel(R.exportWarnings)
            fprintf(fid,'输出提示：%s\n',R.exportWarnings{k});
        end
        clear fileCleanup;
    catch ME
        R.exportWarnings{end+1,1}=['报告输出失败：',ME.message];
        warning('Q2:Report','%s',R.exportWarnings{end});
    end
    save(fullfile(R.outputDir,'Q2_results.mat'),'R');
end
end

%% --------------------------- 数据输出函数 ---------------------------
function writeResultTable(T,path,sheet)
headers=T.Properties.VariableDescriptions;
if numel(headers)~=width(T) || any(cellfun(@isempty,headers))
    headers=T.Properties.VariableNames;
end
C=table2cell(T);
for k=1:numel(C)
    v=C{k};
    if (isnumeric(v) || islogical(v)) && isscalar(v)
        if isnan(v), C{k}='NaN';
        elseif isinf(v) && v>0, C{k}='Inf';
        elseif isinf(v), C{k}='-Inf';
        else, C{k}=double(v); end
    end
end
writecell([headers;C],path,'Sheet',sheet,'Range','A1');
end

%% --------------------------- 统一绘图设置 ---------------------------
function [font,note]=chooseChineseFont(preferred)
note='';
try, fonts=cellstr(listfonts); catch, fonts={}; end
if ~isempty(preferred)
    if isempty(fonts) || any(strcmpi(fonts,char(preferred)))
        font=char(preferred); return;
    end
    font=char(preferred);
    note=sprintf('指定字体“%s”未在字体列表中找到，MATLAB将尝试字体回退。',font);
    return;
end
candidates={'Microsoft YaHei UI','Microsoft YaHei','微软雅黑','等线', ...
    'SimHei','黑体','SimSun','宋体','Noto Sans CJK SC', ...
    'Source Han Sans SC','PingFang SC','Heiti SC','Arial Unicode MS'};
for k=1:numel(candidates)
    hit=find(strcmpi(fonts,candidates{k}),1);
    if ~isempty(hit), font=fonts{hit}; return; end
end
% 用户的运行图已能正常显示中文，因此不因字体名称未命中而误报失败。
font=char(get(groot,'DefaultAxesFontName'));
end

function fig=newFigure(R,position,name)
fig=figure('Color','w','Position',position,'Name',name,'NumberTitle','off', ...
    'Visible',R.options.figureVisible,'MenuBar','none','ToolBar','none', ...
    'InvertHardcopy','off');
end

function styleAxis(ax,font)
set(ax,'FontName',font,'FontSize',10.5,'LineWidth',0.85, ...
    'TickLabelInterpreter','none','Box','off','Layer','top');
grid(ax,'on'); ax.GridAlpha=0.14; ax.MinorGridAlpha=0.08;
try, disableDefaultInteractivity(ax); catch, end
try, ax.Toolbar.Visible='off'; catch
    try, axtoolbar(ax,{}); catch, end
end
end

function cleanFigureForExport(fig,font)
set(fig,'MenuBar','none','ToolBar','none','Color','w');
axesList=findall(fig,'Type','axes');
for k=1:numel(axesList)
    set(axesList(k),'FontName',font,'TickLabelInterpreter','none');
    try, disableDefaultInteractivity(axesList(k)); catch, end
    try, axesList(k).Toolbar.Visible='off'; catch
        try, axtoolbar(axesList(k),{}); catch, end
    end
end
end

function labels=scenarioLabels(R)
n=size(R.parameters,1); labels=cell(n,1);
for k=1:n, labels{k}=sprintf('情形%g',R.parameters(k,1)); end
end

function setScenarioX(ax,R)
n=size(R.parameters,1);
set(ax,'XTick',1:n,'XTickLabel',scenarioLabels(R));
xlim(ax,[0.45,n+0.55]);
end

function [profit,feasible,optimal]=strategyMatrices(R)
n=size(R.parameters,1); T=R.tables.allStrategies;
profit=nan(n,16); feasible=false(n,16); optimal=false(n,16);
for k=1:n
    rows=find(T.Scenario==R.parameters(k,1));
    assert(numel(rows)==16,'每种情形应包含16种固定策略。');
    [~,order]=sort(T.StrategyID(rows)); rows=rows(order);
    profit(k,:)=T.ExpectedProfit(rows).';
    feasible(k,:)=logical(T.Feasible(rows).');
    optimal(k,:)=logical(T.IsOptimal(rows).');
end
end

function cmap=profitColormap(n)
% 配合关于零对称的色轴：负利润为蓝色，零利润近白，正利润为橙色。
if nargin<1, n=256; end
anchors=[0.16,0.33,0.50;0.64,0.76,0.84;0.96,0.96,0.94; ...
    0.89,0.65,0.39;0.67,0.25,0.18];
x=linspace(0,1,size(anchors,1)); xi=linspace(0,1,n);
cmap=zeros(n,3);
for c=1:3, cmap(:,c)=interp1(x,anchors(:,c),xi); end
end

%% --------------------------- 图1：利润热力图 ---------------------------
function [fig,exportTarget]=plotProfitHeatmap(R,font)
[profit,feasible,optimal]=strategyMatrices(R);
shown=profit; shown(~feasible)=NaN;
n=size(shown,1);
fig=newFigure(R,[50,80,1450,max(540,85*n+210)],'全部策略利润热力图');
ax=axes(fig,'Position',[0.075,0.19,0.83,0.67]); exportTarget=ax;
img=imagesc(ax,shown);
set(img,'AlphaData',feasible);
set(ax,'Color',[0.90,0.91,0.92]); colormap(ax,profitColormap(256));
values=shown(isfinite(shown)); bound=max(1,max(abs(values)));
lo=-bound; hi=bound; % 让颜色的中点明确表示收支平衡，而非数据区间的中点
caxis(ax,[lo,hi]);
cb=colorbar(ax); cb.Label.String='期望利润（元/订单）';
cb.Label.FontName=font; cb.FontName=font;
% 不在刻度字符串中嵌入换行。部分MATLAB版本会把两行拆成相邻刻度，
% 导致“1,0000,2,0001,...”错位。每列只显示其唯一的策略编号。
ticks=arrayfun(@(j)sprintf('%d',j),1:16,'UniformOutput',false);
set(ax,'XTick',1:16,'XTickLabel',ticks,'YTick',1:n, ...
    'YTickLabel',scenarioLabels(R),'TickLength',[0,0]);
xlabel(ax,{'固定策略编号（1至16，每列对应一种策略）', ...
    '四项决策对应关系见Excel“策略编码”表'}, ...
    'FontName',font,'Interpreter','none');
ylabel(ax,'参数情形','FontName',font,'Interpreter','none');
title(ax,{'16种固定生产策略的期望利润分布', ...
    '数值为利润；★表示最优；×表示不能保证最终完成交付'}, ...
    'FontName',font,'FontSize',15,'Interpreter','none');
for r=1:n
    for c=1:16
        if ~feasible(r,c)
            text(ax,c,r,'×','HorizontalAlignment','center','Color',[0.60,0.18,0.15], ...
                'FontName',font,'FontSize',13,'FontWeight','bold');
        else
            label=sprintf('%.2f',profit(r,c));
            if optimal(r,c), label=[label,'★']; end
            normalized=(profit(r,c)-lo)/(hi-lo);
            if normalized<0.18 || normalized>0.82, color='w'; else, color=[0.12,0.14,0.16]; end
            weight='normal'; if optimal(r,c), weight='bold'; end
            text(ax,c,r,label,'HorizontalAlignment','center','Color',color, ...
                'FontName',font,'FontSize',8.3,'FontWeight',weight,'Interpreter','none');
        end
    end
end
for c=0.5:1:16.5, line(ax,[c,c],[0.5,n+0.5],'Color',[1,1,1]*0.82,'LineWidth',0.5); end
for r=0.5:1:n+0.5, line(ax,[0.5,16.5],[r,r],'Color',[1,1,1]*0.82,'LineWidth',0.5); end
axis(ax,'tight'); styleAxis(ax,font); grid(ax,'off');
end

%% ---------------------- 图2：六情形利润详细比较 ----------------------
function [fig,exportTarget]=plotProfitPanels(R,font)
[profit,feasible,optimal]=strategyMatrices(R); n=size(profit,1);
ncol=min(2,n); nrow=ceil(n/ncol);
fig=newFigure(R,[35,35,1380,max(620,305*nrow)],'各情形策略利润详细比较');
layout=tiledlayout(fig,nrow,ncol,'TileSpacing','compact','Padding','compact');
exportTarget=layout;
title(layout,{'各情形16种固定策略的期望利润比较', ...
    '蓝柱：可行策略　绿色：最优策略　红叉：不可行策略（叉号纵坐标不是利润）'}, ...
    'FontName',font,'FontSize',15,'Interpreter','none');
for k=1:n
    ax=nexttile(layout); plotted=profit(k,:); plotted(~feasible(k,:))=NaN;
    bars=bar(ax,1:16,plotted,0.72,'FaceColor','flat','EdgeColor','none'); hold(ax,'on');
    colors=repmat([0.25,0.49,0.68],16,1);
    colors(optimal(k,:),:)=repmat([0.18,0.58,0.40],sum(optimal(k,:)),1);
    bars.CData=colors;
    vals=profit(k,feasible(k,:)); low=min([0,vals]); high=max([0,vals]); span=max(1,high-low);
    base=low-0.12*span;
    plot(ax,find(~feasible(k,:)),repmat(base,1,sum(~feasible(k,:))),'x', ...
        'Color',[0.72,0.25,0.20],'LineWidth',1.5,'MarkerSize',7);
    % 绿色柱已经明确标识最优，不再叠加会遮挡数字的圆圈。
    count=sum(optimal(k,:));
    if count==1, status='唯一最优'; else, status=sprintf('%d种并列最优',count); end
    title(ax,sprintf('情形%g：%d种可行，%s',R.parameters(k,1),sum(feasible(k,:)),status), ...
        'FontName',font,'FontSize',11.5,'Interpreter','none');
    for j=find(optimal(k,:))
        text(ax,j,profit(k,j)+0.035*span,sprintf('%.2f',profit(k,j)), ...
            'HorizontalAlignment','center','VerticalAlignment','bottom', ...
            'FontName',font,'FontSize',8.5,'BackgroundColor','w', ...
            'Margin',1,'Color',[0.04,0.30,0.17]);
    end
    yline(ax,0,'Color',[0.25,0.25,0.25],'LineWidth',0.7);
    set(ax,'XTick',1:16); xlim(ax,[0.4,16.6]);
    ylim(ax,[base-0.05*span,high+0.19*span]);
    xlabel(ax,'固定策略编号','FontName',font); ylabel(ax,'期望利润（元/订单）','FontName',font);
    styleAxis(ax,font);
end
end

%% --------------------------- 图3：决策矩阵 ---------------------------
function [fig,exportTarget]=plotOptimalDecisions(R,font)
T=R.tables.optimal;
bits=T{:,{'TestPart1','TestPart2','TestProduct','Disassemble'}};
m=height(T); labels=cell(m,1);
for k=1:m
    labels{k}=sprintf('情形%g  策略%d（%s）  利润%.4f', ...
        T.Scenario(k),T.StrategyID(k),T.Code{k},T.ExpectedProfit(k));
end
fig=newFigure(R,[80,90,1250,max(520,66*m+180)],'全部最优决策组合');
ax=axes(fig,'Position',[0.34,0.16,0.61,0.69]); exportTarget=ax;
imagesc(ax,bits,[0,1]);
colormap(ax,[0.92,0.94,0.96;0.12,0.49,0.39]);
set(ax,'XTick',1:4,'XTickLabel',{'检测零件1','检测零件2','检测成品','拆解不合格品'}, ...
    'YTick',1:m,'YTickLabel',labels,'TickLength',[0,0]);
for r=1:m
    for c=1:4
        if bits(r,c)==1, txt='是'; color='w'; else, txt='否'; color=[0.17,0.24,0.30]; end
        text(ax,c,r,txt,'HorizontalAlignment','center','FontName',font, ...
            'FontSize',15,'FontWeight','bold','Color',color,'Interpreter','none');
    end
end
for c=0.5:1:4.5, line(ax,[c,c],[0.5,m+0.5],'Color','w','LineWidth',1.2); end
for r=0.5:1:m+0.5, line(ax,[0.5,4.5],[r,r],'Color','w','LineWidth',1.2); end
title(ax,{'各情形的全部最优固定决策', ...
    '同一情形多行表示并列最优；利润单位：元/订单'}, ...
    'FontName',font,'FontSize',15,'Interpreter','none');
xlabel(ax,'浅色表示“否”，深色表示“是”','FontName',font,'Interpreter','none');
styleAxis(ax,font); grid(ax,'off');
end

%% --------------------------- 图4：成本构成 ---------------------------
function [fig,exportTarget]=plotCostBreakdown(R,font)
T=R.tables.costBreakdown; C=T{R.bestRows,3:10};
grouped=[sum(C(:,1:2),2),sum(C(:,3:4),2),C(:,5:8)];
n=size(grouped,1); total=sum(grouped,2);
price=R.parameters(:,11); profit=R.tables.representative.ExpectedProfit;
fig=newFigure(R,[90,70,1320,690],'最优代表方案期望成本构成');
ax=axes(fig,'Position',[0.08,0.17,0.88,0.66]); exportTarget=ax;
plotValues=grouped;
if n==1, plotValues=[grouped;nan(1,6)]; end
b=bar(ax,1:size(plotValues,1),plotValues,0.60,'stacked','EdgeColor','none'); hold(ax,'on');
colors=[0.23,0.43,0.63;0.36,0.63,0.75;0.45,0.62,0.43; ...
    0.73,0.70,0.38;0.80,0.46,0.33;0.56,0.48,0.65];
for k=1:6, b(k).FaceColor=colors(k,:); end
sale=plot(ax,1:n,price,'--d','Color',[0.13,0.16,0.18], ...
    'LineWidth',1.3,'MarkerFaceColor','w','MarkerSize',7);
ymax=max([total;price]); offset=0.016*max(1,ymax);
for k=1:n
    text(ax,k,total(k)+offset,sprintf('成本%.2f',total(k)), ...
        'HorizontalAlignment','center','FontName',font,'FontSize',9.5);
    text(ax,k,price(k)+4.0*offset,sprintf('利润%.2f',profit(k)), ...
        'HorizontalAlignment','center','FontName',font,'FontSize',9.5, ...
        'Color',[0.08,0.38,0.24]);
end
setScenarioX(ax,R); ylim(ax,[0,max(1,ymax)*1.23]);
ylabel(ax,'金额（元/完成合格交付订单）','FontName',font);
xlabel(ax,'并列最优时选策略编号较小者作为成本构成代表','FontName',font);
title(ax,{'最优代表方案的期望成本构成', ...
    '期望利润 = 一次订单售价 - 完成交付前的全部期望成本'}, ...
    'FontName',font,'FontSize',15,'Interpreter','none');
legend(ax,[b(:);sale],{'零件采购','零件检测','装配','成品检测', ...
    '调换损失','拆解','一次订单售价'},'FontName',font,'Interpreter','none', ...
    'Location','northoutside','Orientation','horizontal','FontSize',9);
styleAxis(ax,font);
end

%% ------------------------- 图5：期望操作次数 -------------------------
function [fig,exportTarget]=plotOperationCounts(R,font)
T=R.tables.eventCounts; E=T{R.bestRows,3:10};
n=size(E,1);
plotValues=E;
if n==1, plotValues=[E;nan(1,8)]; end % 单行情形仍按多个系列分组绘图
x=1:size(plotValues,1);
fig=newFigure(R,[70,55,1350,720],'最优方案期望操作次数');
layout=tiledlayout(fig,2,1,'TileSpacing','compact','Padding','compact');
exportTarget=layout;
title(layout,{'最优代表方案完成一个合格交付订单所需的期望操作次数', ...
    '期望次数可以为小数；并列最优时采用编号较小的方案展示'}, ...
    'FontName',font,'FontSize',15,'Interpreter','none');

ax1=nexttile(layout); b1=bar(ax1,x,plotValues(:,1:4),0.76,'grouped','EdgeColor','none');
colors1=[0.23,0.43,0.63;0.45,0.65,0.78;0.30,0.55,0.73;0.58,0.76,0.84];
for k=1:4, b1(k).FaceColor=colors1(k,:); end
setScenarioX(ax1,R); ylabel(ax1,'期望数量或次数（每订单）','FontName',font);
title(ax1,'零配件采购数量与检测次数','FontName',font,'FontSize',12);
legend(ax1,{'采购零件1（件）','采购零件2（件）','检测零件1（次）','检测零件2（次）'}, ...
    'FontName',font,'Location','northoutside','Orientation','horizontal');
partValues=E(:,1:4);
ylim(ax1,[0,max(0.25,1.20*max(partValues(:)))]); % 在真实最高柱上方留出20%空间
styleAxis(ax1,font);

ax2=nexttile(layout); b2=bar(ax2,x,plotValues(:,5:8),0.76,'grouped','EdgeColor','none');
colors2=[0.45,0.62,0.43;0.73,0.70,0.38;0.80,0.46,0.33;0.56,0.48,0.65];
for k=1:4, b2(k).FaceColor=colors2(k,:); end
setScenarioX(ax2,R); ylabel(ax2,'期望次数（次/订单）','FontName',font);
xlabel(ax2,'参数情形','FontName',font);
title(ax2,'装配、成品检测、调换与拆解','FontName',font,'FontSize',12);
legend(ax2,{'装配','检测成品','发生调换','拆解'}, ...
    'FontName',font,'Location','northoutside','Orientation','horizontal');
productValues=E(:,5:8);
ylim(ax2,[0,max(0.25,1.20*max(productValues(:)))]);
styleAxis(ax2,font);
end

%% ---------------------- 图6：最优与第二名利润差 ----------------------
function [fig,exportTarget]=plotProfitRanking(R,font)
[profit,feasible,~]=strategyMatrices(R); n=size(profit,1);
top=zeros(n,2); ids=zeros(n,2);
for k=1:n
    candidates=find(feasible(k,:));
    [values,order]=sort(profit(k,candidates),'descend');
    top(k,:)=values(1:2); ids(k,:)=candidates(order(1:2));
end
fig=newFigure(R,[110,100,1200,650],'最优与第二名策略利润差');
ax=axes(fig,'Position',[0.09,0.17,0.87,0.66]); exportTarget=ax;
plotValues=top;
if n==1, plotValues=[top;nan(1,2)]; end
b=bar(ax,1:size(plotValues,1),plotValues,0.70,'grouped','EdgeColor','none'); hold(ax,'on');
b(1).FaceColor=[0.18,0.58,0.40]; b(2).FaceColor=[0.55,0.68,0.76];
span=max(1,max(top(:))-min([0;top(:)]));
for k=1:n
    text(ax,k-0.15,top(k,1)+0.025*span,sprintf('策略%d',ids(k,1)), ...
        'HorizontalAlignment','center','FontName',font,'FontSize',9);
    text(ax,k+0.15,top(k,2)+0.025*span,sprintf('策略%d',ids(k,2)), ...
        'HorizontalAlignment','center','FontName',font,'FontSize',9);
    text(ax,k,max(top(k,:))+0.12*span,sprintf('差值%.3f',top(k,1)-top(k,2)), ...
        'HorizontalAlignment','center','FontName',font,'FontSize',9.5, ...
        'Color',[0.30,0.30,0.30]);
end
setScenarioX(ax,R); yline(ax,0,'Color',[0.25,0.25,0.25],'LineWidth',0.7);
low=min([0;top(:)]); high=max(top(:)); ylim(ax,[low-0.08*span,high+0.24*span]);
ylabel(ax,'期望利润（元/订单）','FontName',font);
xlabel(ax,'差值为当前参数下的利润差距，不能直接据此判断参数敏感性','FontName',font);
title(ax,{'最高利润与第二高利润策略比较', ...
    '两种不同策略可以取得相同的最高利润'}, ...
    'FontName',font,'FontSize',15,'Interpreter','none');
legend(ax,b,{'最高利润策略','第二高利润策略'},'FontName',font, ...
    'Location','northoutside','Orientation','horizontal');
styleAxis(ax,font);
end

%% ------------------------- 图7：仿真核验 -------------------------
function [fig,exportTarget]=plotMonteCarloCheck(R,font)
T=R.tables.monteCarlo; n=height(T); x=1:n;
fig=newFigure(R,[100,55,1280,735],'蒙特卡洛仿真核验');
layout=tiledlayout(fig,2,1,'TileSpacing','compact','Padding','compact');
exportTarget=layout;
title(layout,{'精确期望成本与独立事件仿真的一致性检验', ...
    '误差棒为模拟均值的近似95%区间；仿真数据不是实际生产观测'}, ...
    'FontName',font,'FontSize',15,'Interpreter','none');

ax1=nexttile(layout); hold(ax1,'on');
err=1.96*T.StandardError;
h1=errorbar(ax1,x,T.MeanCost,err,'o','LineStyle','none', ...
    'Color',[0.25,0.49,0.68],'MarkerFaceColor',[0.25,0.49,0.68], ...
    'LineWidth',1.25,'CapSize',9,'MarkerSize',6);
h2=plot(ax1,x,T.ExactCost,'d','LineStyle','none','Color',[0.74,0.32,0.22], ...
    'MarkerFaceColor','w','LineWidth',1.2,'MarkerSize',6);
setScenarioX(ax1,R); ylabel(ax1,'期望成本（元/订单）','FontName',font);
lo=min([T.MeanCost-err;T.ExactCost]);
hi=max([T.MeanCost+err;T.ExactCost]);
padding=0.08*max(1,hi-lo);
ylim(ax1,[lo-padding,hi+padding]); % 确保最下方情形的整段区间也留有边距
title(ax1,'理论成本与模拟均值','FontName',font,'FontSize',12);
legend(ax1,[h1,h2],{'模拟均值及近似95%区间','吸收链精确期望'}, ...
    'FontName',font,'Location','northoutside','Orientation','horizontal');
styleAxis(ax1,font);

ax2=nexttile(layout); z=T.Difference./T.StandardError;
bars=bar(ax2,x,z,0.58,'FaceColor',[0.38,0.60,0.70],'EdgeColor','none'); hold(ax2,'on'); %#ok<NASGU>
yline(ax2,0,'Color',[0.25,0.25,0.25]);
yline(ax2,1.96,'--','Color',[0.72,0.28,0.22],'LineWidth',1.0);
yline(ax2,-1.96,'--','Color',[0.72,0.28,0.22],'LineWidth',1.0);
for k=1:n
    text(ax2,k,z(k)+signWithZero(z(k))*0.11,sprintf('%.2f',z(k)), ...
        'HorizontalAlignment','center','FontName',font,'FontSize',9);
end
setScenarioX(ax2,R);
finiteZ=z(isfinite(z));
zLimit=max([2.6;abs(finiteZ)+0.4]);
ylim(ax2,[-zLimit,zLimit]); % 参数改变后也不裁掉超出参考线的真实偏差
ylabel(ax2,'标准化偏差 z','FontName',font); xlabel(ax2,'参数情形','FontName',font);
title(ax2,'（模拟均值 - 精确期望）/ 模拟标准误','FontName',font,'FontSize',12);
styleAxis(ax2,font);
end

function s=signWithZero(x)
if x>=0, s=1; else, s=-1; end
end
