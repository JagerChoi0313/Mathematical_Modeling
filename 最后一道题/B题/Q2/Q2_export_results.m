function R = Q2_export_results(R)
%Q2_EXPORT_RESULTS 中文图表、Excel 结果表与报告输出。
% 本文件只处理展示和保存，不重新修改模型参数或最优策略。
% 结果表为 MATLAB 计算快照，不是可在 Excel 中自动重算的模型。
% 修改参数后请重新运行 Q2_markov_main，所有表格会写到新的结果目录。

opts=R.options;
R.outputDir=''; R.excelPath=''; R.figurePaths=cell(0,1);
R.figureFiles=cell(0,1); R.exportWarnings=cell(0,1);
if opts.saveFiles
    if ~exist(opts.outputRoot,'dir')
        [ok,msg]=mkdir(opts.outputRoot); assert(ok,'无法创建输出目录：%s',msg);
    end
    stamp=['run_',datestr(now,'yyyymmdd_HHMMSS')];
    folder=fullfile(opts.outputRoot,stamp); suffix=1;
    while exist(folder,'dir')
        folder=fullfile(opts.outputRoot,sprintf('%s_%03d',stamp,suffix));
        suffix=suffix+1;
    end
    [ok,msg]=mkdir(folder); assert(ok,'无法创建本次运行目录：%s',msg);
    R.outputDir=folder;
end

%% 步骤 1：选择可显示中文的字体，不修改用户的全局绘图设置
fontName=''; fontNote='';
if opts.makeFigures, [fontName,fontNote]=chooseChineseFont(opts.fontName); end
R.fontName=fontName;
if ~isempty(fontNote)
    R.exportWarnings{end+1,1}=fontNote;
    warning('Q2:Font','%s',fontNote);
end

%% 步骤 2：生成三张中文图；每张均来自本次枚举的真实计算结果
if opts.makeFigures
    for figureNumber=1:3
        fig=[];
        try
            switch figureNumber
                case 1
                    [fig,exportTarget]=plotAllProfits(R,fontName);
                    basename='Q2_01_all_strategy_profits';
                case 2
                    [fig,exportTarget]=plotOptimalDecisions(R,fontName);
                    basename='Q2_02_optimal_decisions';
                case 3
                    [fig,exportTarget]=plotCostBreakdown(R,fontName);
                    basename='Q2_03_optimal_cost_breakdown';
            end
            drawnow;
            if opts.saveFiles
                png=fullfile(R.outputDir,[basename,'.png']);
                figfile=fullfile(R.outputDir,[basename,'.fig']);
                % 多子图导出整个布局，单图导出坐标轴及其标签、图例。
                exportgraphics(exportTarget,png,'Resolution',300,'BackgroundColor','white');
                R.figurePaths{end+1,1}=png;
                savefig(fig,figfile);
                R.figureFiles{end+1,1}=figfile;
            end
            if strcmp(opts.figureVisible,'off'), close(fig); end
        catch ME
            message=sprintf('第 %d 张图生成或保存失败：%s',figureNumber,ME.message);
            R.exportWarnings{end+1,1}=message;
            warning('Q2:Figure','%s',message);
            if ~isempty(fig) && isgraphics(fig) && strcmp(opts.figureVisible,'off')
                close(fig);
            end
        end
    end
end

%% 步骤 3：所有 table 统一导出为同一个 Excel 文件的不同工作表
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
    all(ismember(fields,R.sheetMap(:,1))),'存在没有安排 Excel 输出的结果表。');
if opts.saveFiles
    xlsx=fullfile(R.outputDir,'Q2_tables.xlsx');
    try
        notes={ ...
            '项目','说明';
            '原始参数来源','2024年全国大学生数学建模竞赛B题，表1及附录说明；可由调用参数替换';
            '运行时间',datestr(now,'yyyy-mm-dd HH:MM:SS');
            '利润口径','一个付费订单最终交付一件合格品；售价仅计一次；金额单位元';
            '策略位顺序','检测零件1、检测零件2、检测成品、拆解；1为是，0为否';
            '策略编号','1+8*x1+4*x2+2*y+z，编号从1到16';
            '最优范围','仅针对四项决策保持不变的固定策略集合，不含自适应复检或限次拆解';
            '回用规则','拆解不损坏零件、不改变真实质量；已检测合格件免重复检测';
            '条件次品率','成品次品率指两个零件均合格时的装配次品率，不是所有投入的总体次品率';
            '调换损失','仅为额外损失；替换品生产成本已由状态递推计算，不能重复添加';
            '可行性','所有从待采购状态可达的状态必须能到达完成交付，最终交付概率为1';
            '首次合格概率','仅描述新采购后第一次装配；不能不加条件套用到拆解回用轮次';
            '无穷与缺失','Inf表示无穷成本；-Inf表示无穷负利润；NaN表示未定义、不适用或不可达';
            '数值类型','有限数值保留数值类型；仅Inf、-Inf、NaN作为说明性文本写入Excel';
            '不可行成本分解','未定义的无穷总成本不强行分摊到各成本项，分解列标NaN';
            '全状态谱半径','仅供核对；可能因不可达坏状态等于1；不可据此排除可行策略';
            '状态转移','仅列严格正概率转移；未列项为0；来源可达标志揭示不可达分支';
            '状态价值','成本和访问次数仅在可行策略的可达状态上求解；其余NaN并非零';
            '已通过检查','可行策略检查线性方程、闭式公式和迭代；不可行策略检查结构与完成概率';
            '并列最优','全部保留；绘图和仿真代表为并列最优中编号最小者，不表示其更优';
            '蒙特卡洛','随机模拟而非实际检测数据；约95%区间针对模拟均值，不是模型参数区间';
            '模拟订单数',opts.mcOrders;
            '随机种子',opts.randomSeed;
            '结果更新','本文件是计算结果快照。修改参数后重新运行MATLAB，不在Excel内自动重算'};
        writecell(notes,xlsx,'Sheet','说明','Range','A1');
        for k=1:size(R.sheetMap,1)
            tableData=R.tables.(R.sheetMap{k,1});
            writeResultTable(tableData,xlsx,R.sheetMap{k,2});
        end
        R.excelPath=xlsx;
        fprintf('Excel 已输出：%s\n',xlsx);
    catch ME
        message=sprintf('Excel 输出未全部成功：%s。请关闭同名文件后重新运行。',ME.message);
        R.exportWarnings{end+1,1}=message;
        warning('Q2:Excel','%s',message);
    end

    %% 步骤 4：保存文本报告和完整 MATLAB 数据
    report=fullfile(R.outputDir,'Q2_report.txt');
    try
        fid=fopen(report,'w','n','UTF-8');
        assert(fid~=-1,'不能写入文本报告。');
        fileCleanup=onCleanup(@()fclose(fid));
        fprintf(fid,'第二问：吸收马尔可夫链与固定策略全枚举\n\n');
        fprintf(fid,'口径：每个最终完成合格交付订单的期望利润，售价仅计一次。\n');
        fprintf(fid,'策略：检测零件1、检测零件2、检测成品、拆解；1为是，0为否。\n');
        fprintf(fid,'已知合格零件可追溯且免复检；固定策略在循环中不改变。\n');
        fprintf(fid,'所有并列最优均保留；这不是所有自适应策略的全局最优。\n\n');
        T=R.tables.optimal;
        for k=1:height(T)
            fprintf(fid,'情形 %g，策略 %d（%s），期望成本 %.10f 元，期望利润 %.10f 元。\n', ...
                T.Scenario(k),T.StrategyID(k),T.Code{k},T.ExpectedCost(k),T.ExpectedProfit(k));
        end
        fprintf(fid,'\n适用数值检查均通过：%d\n',R.checksPassed);
        fprintf(fid,'蒙特卡洛仅作独立统计核验，不是实测数据；开启：%d\n',opts.runMonteCarlo);
        fprintf(fid,'成功输出PNG：%d 张；成功输出FIG：%d 张。\n', ...
            numel(R.figurePaths),numel(R.figureFiles));
        fprintf(fid,'Excel全部写入成功：%d\n',~isempty(R.excelPath));
        for k=1:numel(R.exportWarnings), fprintf(fid,'输出提示：%s\n',R.exportWarnings{k}); end
        clear fileCleanup;
    catch ME
        R.exportWarnings{end+1,1}=['报告输出失败：',ME.message];
        warning('Q2:Report','%s',R.exportWarnings{end});
    end
    save(fullfile(R.outputDir,'Q2_results.mat'),'R');
end
end

function writeResultTable(T,path,sheet)
% 用中文列描述替代英文内部变量名；空表仍写出完整表头。
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

function [font,note]=chooseChineseFont(preferred)
note=''; fonts=listfonts;
if ~isempty(preferred)
    if any(strcmpi(fonts,preferred)), font=char(preferred); return; end
    note=sprintf('指定字体 %s 未安装，已尝试自动选择中文字体。',char(preferred));
end
candidates={'Microsoft YaHei','SimHei','SimSun','Noto Sans CJK SC', ...
    'Source Han Sans SC','PingFang SC','Heiti SC','WenQuanYi Zen Hei','Arial Unicode MS'};
for k=1:numel(candidates)
    if any(strcmpi(fonts,candidates{k})), font=candidates{k}; return; end
end
font='Helvetica';
note=[note,' 未找到常用中文字体；若图中文字为方框，请安装中文字体并设置 fontName 后重跑。'];
end

function fig=newFigure(R,position,name)
fig=figure('Color','w','Position',position,'Name',name, ...
    'NumberTitle','off','Visible',R.options.figureVisible);
end

function styleAxis(ax,font)
set(ax,'FontName',font,'FontSize',10,'LineWidth',0.8, ...
    'TickLabelInterpreter','none','Box','off');
grid(ax,'on'); ax.GridAlpha=0.15;
end

function [fig,exportTarget]=plotAllProfits(R,font)
T=R.tables.allStrategies; n=size(R.parameters,1);
ncol=min(2,n); nrow=ceil(n/ncol);
fig=newFigure(R,[60,60,1220,max(430,300*nrow)],'全部固定策略期望利润');
layout=tiledlayout(fig,nrow,ncol,'TileSpacing','compact','Padding','compact');
exportTarget=layout;
title(layout,{'各情形固定策略的期望利润比较', ...
    '四位编码顺序：检测件1、检测件2、检测成品、拆解；1为是，0为否'}, ...
    'FontName',font,'FontSize',15,'Interpreter','none');
for k=1:n
    ax=nexttile(layout); rows=(k-1)*16+(1:16); profit=T.ExpectedProfit(rows);
    feasible=T.Feasible(rows)==1; best=T.IsOptimal(rows)==1;
    plotted=profit; plotted(~feasible)=NaN;
    b=bar(ax,1:16,plotted,0.76,'FaceColor','flat','EdgeColor','none'); hold(ax,'on');
    colors=repmat([0.24,0.48,0.67],16,1);
    colors(best,:)=repmat([0.16,0.57,0.40],sum(best),1); b.CData=colors;
    vals=profit(feasible); low=min([0;vals]); high=max([0;vals]); span=max(1,high-low);
    base=low-0.13*span;
    bad=plot(ax,find(~feasible),repmat(base,sum(~feasible),1),'x', ...
        'Color',[0.72,0.27,0.21],'LineWidth',1.6,'MarkerSize',7);
    good=plot(ax,find(best),profit(best),'o','MarkerEdgeColor',[0.06,0.30,0.18], ...
        'MarkerSize',8,'LineWidth',1.3);
    title(ax,sprintf('情形 %g：%d 种可行，%d 种并列最优', ...
        R.parameters(k,1),sum(feasible),sum(best)), ...
        'FontName',font,'FontSize',12,'Interpreter','none');
    xlabel(ax,'固定策略编号','FontName',font,'Interpreter','none');
    ylabel(ax,'期望利润（元/订单）','FontName',font,'Interpreter','none');
    set(ax,'XTick',1:16); xlim(ax,[0.4,16.6]); ylim(ax,[base-0.08*span,high+0.32*span]);
    styleAxis(ax,font);
    legend(ax,[b,good,bad],{'可行策略','最优策略','不可行（叉号非利润值）'}, ...
        'FontName',font,'FontSize',8,'Interpreter','none','Location','northwest');
end
end

function [fig,exportTarget]=plotOptimalDecisions(R,font)
T=R.tables.optimal; bits=T{:,{'TestPart1','TestPart2','TestProduct','Disassemble'}};
m=height(T); labels=cell(m,1);
for k=1:m
    labels{k}=sprintf('情形%g / 策略%d / 利润%.4f元', ...
        T.Scenario(k),T.StrategyID(k),T.ExpectedProfit(k));
end
fig=newFigure(R,[100,80,1120,max(470,67*m+170)],'全部最优决策组合');
ax=axes(fig,'Position',[0.29,0.16,0.66,0.69]);
exportTarget=ax;
imagesc(ax,bits,[0,1]); colormap(ax,[0.90,0.93,0.96;0.12,0.48,0.39]);
set(ax,'XTick',1:4,'XTickLabel',{'检测零配件1','检测零配件2','检测成品','拆解不合格成品'}, ...
    'YTick',1:m,'YTickLabel',labels,'FontName',font,'FontSize',11, ...
    'TickLabelInterpreter','none','TickLength',[0,0],'Box','off');
for r=1:m
    for c=1:4
        if bits(r,c)==1, txt='是'; color='w'; else, txt='否'; color=[0.18,0.24,0.29]; end
        text(ax,c,r,txt,'HorizontalAlignment','center','FontName',font, ...
            'FontSize',15,'Color',color,'Interpreter','none');
    end
end
title(ax,{'各情形的全部最优固定决策', ...
    '同一情形出现多行表示并列最优；比较范围为当前固定策略集合'}, ...
    'FontName',font,'FontSize',15,'Interpreter','none');
xlabel(ax,'浅色：否；深色：是','FontName',font,'FontSize',11,'Interpreter','none');
end

function [fig,exportTarget]=plotCostBreakdown(R,font)
% 将八个成本项合并为六组，底层 Excel 仍保留完整八项。
T=R.tables.costBreakdown; C=T{R.bestRows,3:10};
grouped=[sum(C(:,1:2),2),sum(C(:,3:4),2),C(:,5:8)];
n=size(grouped,1); ids=R.parameters(:,1); labels=cell(n,1);
for k=1:n, labels{k}=sprintf('情形%g',ids(k)); end
fig=newFigure(R,[140,100,1120,650],'最优代表方案期望成本分解');
ax=axes(fig,'Position',[0.09,0.14,0.86,0.67]);
exportTarget=ax;
plotValues=grouped;
if n==1, plotValues=[grouped;nan(1,6)]; end % 避免单行情形被解释为六根独立柱
b=bar(ax,1:size(plotValues,1),plotValues,0.62,'stacked','EdgeColor','none'); hold(ax,'on');
colors=[0.22,0.42,0.61;0.36,0.63,0.75;0.46,0.62,0.43; ...
    0.73,0.71,0.40;0.80,0.46,0.34;0.57,0.48,0.65];
for k=1:6, b(k).FaceColor=colors(k,:); end
sale=plot(ax,1:n,R.parameters(:,11),'k--d','LineWidth',1.4,'MarkerFaceColor','w');
total=sum(grouped,2); profits=R.tables.representative.ExpectedProfit;
ymax=max([total;R.parameters(:,11)]); offset=0.018*max(1,ymax);
for k=1:n
    text(ax,k,total(k)+offset,sprintf('成本 %.2f',total(k)), ...
        'HorizontalAlignment','center','FontName',font,'FontSize',10,'Interpreter','none');
    text(ax,k,R.parameters(k,11)+4*offset,sprintf('利润 %.2f',profits(k)), ...
        'HorizontalAlignment','center','FontName',font,'FontSize',10,'Interpreter','none');
end
set(ax,'XTick',1:n,'XTickLabel',labels); xlim(ax,[0.4,n+0.6]);
ylim(ax,[0,max(1,ymax)*1.23]); styleAxis(ax,font);
ylabel(ax,'金额（元/完成合格交付订单）','FontName',font,'Interpreter','none');
xlabel(ax,'并列最优时选编号最小者展示；全部方案见决策图和 Excel', ...
    'FontName',font,'FontSize',10,'Interpreter','none');
title(ax,{'最优代表方案的期望成本构成', ...
    '期望利润 = 一次订单售价 - 完成交付前的全部期望成本'}, ...
    'FontName',font,'FontSize',15,'Interpreter','none');
legend(ax,[b(:);sale],{'零件采购','零件检测','装配','成品检测','调换损失','拆解','一次订单售价'}, ...
    'FontName',font,'Interpreter','none','Location','northoutside','Orientation','horizontal', ...
    'FontSize',9);
end
