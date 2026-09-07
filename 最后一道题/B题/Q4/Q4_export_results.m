function R = Q4_export_results(R)
%Q4_EXPORT_RESULTS 保存中文Excel表、七幅中文图、MAT数据和文本报告。
% 只读取求解结果，不改变最优策略。可重新绘图：
% load('Q4_results.mat','R'); R.options.fontName='Microsoft YaHei';
% R=Q4_export_results(R);  新建结果目录，保留旧结果。
o=R.options; R.outputDir=''; R.excelPath=''; R.figurePaths={}; R.pdfPaths={};
R.figPaths={}; R.exportWarnings={}; R.fontName='';
if o.saveFiles
    if ~exist(o.outputRoot,'dir'), [ok,msg]=mkdir(o.outputRoot); assert(ok,'%s',msg); end
    stamp=['run_',datestr(now,'yyyymmdd_HHMMSS')]; folder=fullfile(o.outputRoot,stamp); index=1;
    while exist(folder,'dir')
        folder=fullfile(o.outputRoot,sprintf('%s_%03d',stamp,index)); index=index+1;
    end
    [ok,msg]=mkdir(folder); assert(ok,'创建输出目录失败：%s',msg); R.outputDir=folder;
end

%% 导出1：全部table写入同一Excel，结果快照不充当原始检测记录
mapping={'samples','抽样与精确置信区间';'summary','方案对比汇总';'costs','代表方案成本'; ...
    'events','代表方案事件次数';'nodes','代表方案节点递推';'decisions','全部最优决策'; ...
    'inputs','原题成本与装配参数';'encoding','决策位说明'; ...
    'confidenceSensitivity','置信水平对比';'checks','数值核验'};
assert(isequal(sort(fieldnames(R.tables)),sort(mapping(:,1))),'存在未安排Excel输出的表。');
R.sheetMap=mapping;
if o.saveFiles
    book=fullfile(R.outputDir,'Q4_tables.xlsx');
    notes={'项目','说明';'模型','精确二项置信域与分层状态递推的鲁棒全策略枚举'; ...
        '数据来源',R.dataSource;'置信保证范围',R.coverageNote;'总体alpha',o.alpha; ...
        '成本口径','元/完成一个合格交付订单；售价仅计一次；免费调换的生产费用计入递推'; ...
        '数据定义','零件为总体次品率；半成品与成品须在直接投入物全合格条件下取样'; ...
        '置信区间','固定样本量Clopper-Pearson双侧区间；用Bonferroni控制所选家族联合覆盖'; ...
        '鲁棒目标','最大化置信域内最坏情形的期望利润，不是最大化某概率分布下的平均利润'; ...
        '上界降维前提','固定规则下成本关于各次品率单调不减；更改返工、复检或库存规则须重新证明'; ...
        '固定策略范围','拆解仅复用原直接投入物，已知合格投入物免复检；不含自适应检测或限次拆解'; ...
        '有限成本保证','含不可消除的坏投入物循环或任何必要环节完全无法产出时，成本为Inf'; ...
        '端点1','置信上界等于1时不人为截断；可能不存在有限成本的鲁棒保证'; ...
        '抽样费用','当前目标不分摊抽样费用；题目未给出完整抽样成本及对应订单规模'; ...
        '并列最优','最优表保留全部；图表代表取编号最小者，不额外按最坏利润打破点估计并列'; ...
        '编号','原始二进制编码转十进制加1；不是去重后行号；半成品不检测时其拆解位置0'; ...
        '等价编码映射','完整原始编码到代表ID映射保存在MAT的R.problems{s}.rawMap中'; ...
        '特殊数值','Inf无限成本；-Inf无有限利润下界；NaN不适用或无可行最优，Excel明确写为文字'; ...
        '比较限制','点估计与鲁棒最优相同不证明整个置信域排名稳定；点估计利润也不是真实利润'; ...
        '节点费用','独立取得该节点一个输出的费用，包含下层成本；各节点费用不能直接相加'; ...
        '数据修改','本工作簿为结果快照，修改输入后需重新运行MATLAB'; ...
        '模拟与真实','模拟示例不可写作题目实测数据；固定随机种子只提供可复现示例'; ...
        '参数来源','2024年全国大学生数学建模竞赛B题表1、表2与已确定的固定策略模型'};
    try
        writecell(notes,book,'Sheet','使用说明');
        for j=1:size(mapping,1), writeTable(R.tables.(mapping{j,1}),book,mapping{j,2}); end
        for s=1:7
            tag=sprintf('Q2_%d',s); if s==7, tag='Q3'; end
            A=R.problems{s}; fields={'allStrategies','pointOptimal','robustOptimal'};
            names={'全部候选','点估计最优','鲁棒最优'};
            assert(isequal(sort(fieldnames(A.tables)),sort(fields(:))),'问题%d有表未安排导出。',s);
            for j=1:3, writeTable(A.tables.(fields{j}),book,[tag,'_',names{j}]); end
        end
        R.excelPath=book; fprintf('\nExcel已输出：%s\n',book);
    catch ME
        R.exportWarnings{end+1}=['Excel未完整保存：',ME.message];
        warning('Q4:Excel','%s',R.exportWarnings{end});
    end
end

%% 导出2：七幅图，中文标题/坐标/图例，PNG+矢量PDF+可编辑FIG
if o.makeFigures
    [R.fontName,fontWarning]=chooseFont(o.fontName);
    if ~isempty(fontWarning), R.exportWarnings{end+1}=fontWarning; end
    plotters={@plotIntervals,@plotProfits,@plotQ2Heatmap,@plotQ3Cloud, ...
        @plotDecisions,@plotCosts,@plotConfidence};
    files={'Q4_01_confidence_intervals','Q4_02_profit_comparison','Q4_03_Q2_robust_heatmap', ...
        'Q4_04_Q3_profit_tradeoff','Q4_05_optimal_decisions','Q4_06_robust_costs','Q4_07_confidence_levels'};
    for j=1:numel(plotters)
        fig=[];
        try
            [fig,target]=plotters{j}(R); cleanFigure(fig,R.fontName); drawnow;
            if o.saveFiles
                ext={'png','pdf','fig'};
                for f=1:3
                    path=fullfile(R.outputDir,[files{j},'.',ext{f}]);
                    try
                        if f==1
                            exportgraphics(target,path,'Resolution',300,'BackgroundColor','white');
                            R.figurePaths{end+1,1}=path;
                        elseif f==2
                            exportgraphics(target,path,'ContentType','vector','BackgroundColor','white');
                            R.pdfPaths{end+1,1}=path;
                        else
                            savefig(fig,path); R.figPaths{end+1,1}=path;
                        end
                    catch ME
                        R.exportWarnings{end+1}=sprintf('图%d的%s导出失败：%s',j,ext{f},ME.message);
                        warning('Q4:Figure','%s',R.exportWarnings{end});
                    end
                end
            end
            if strcmp(o.figureVisible,'off'), close(fig); end
        catch ME
            R.exportWarnings{end+1}=sprintf('图%d生成失败：%s',j,ME.message);
            warning('Q4:Plot','%s',R.exportWarnings{end});
            if ~isempty(fig) && isgraphics(fig) && strcmp(o.figureVisible,'off'), close(fig); end
        end
    end
end

%% 导出3：可复现完整数据及短报告；导出失败与数学核验分别记录
if o.saveFiles
    try
        save(fullfile(R.outputDir,'Q4_results.mat'),'R','-v7.3');
    catch ME
        R.exportWarnings{end+1}=['MAT保存失败：',ME.message]; warning('Q4:MAT','%s',R.exportWarnings{end});
    end
    report=fullfile(R.outputDir,'Q4_report.txt');
    fid=fopen(report,'w','n','UTF-8');
    if fid>=0
        closer=onCleanup(@()fclose(fid)); %#ok<NASGU>
        fprintf(fid,'第四问：置信上界降维的装配树鲁棒全策略枚举\n%s\n%s\n',R.dataSource,R.coverageNote);
        fprintf(fid,'alpha=%.6g；成本单位：元/合格交付订单。\n',o.alpha);
        T=R.tables.summary;
        for s=1:height(T)
            fprintf(fid,'\n%s：点估计代表ID %.0f，鲁棒代表ID %.0f。\n',T.Problem{s},T.PointID(s),T.RobustID(s));
            fprintf(fid,'点估计方案：点利润 %.10f，最坏利润 %.10f。\n',T.PointOwnProfit(s),T.PointWorstProfit(s));
            fprintf(fid,'鲁棒方案：点利润 %.10f，最坏利润 %.10f。\n',T.RobustPointProfit(s),T.RobustWorstProfit(s));
            fprintf(fid,'点估计可行%d，鲁棒可行%d；鲁棒并列最优%d。\n',T.PointFeasible(s),T.RobustFeasible(s),T.RobustTies(s));
        end
        fprintf(fid,'\n原第二、三问回归及数学核验通过：%d。\n',R.checksPassed);
        fprintf(fid,'最坏利润为置信域内的期望利润下界，不是单个实际订单利润下界。\n');
        fprintf(fid,'相同策略不代表已证明整个置信域内最优排名不变。\n');
        fprintf(fid,'抽样费用未分摊；全部最优、抽样计数、事件成本详见Excel。\n');
        for j=1:numel(R.exportWarnings), fprintf(fid,'导出提示：%s\n',R.exportWarnings{j}); end
    else
        warning('Q4:Report','无法写入文本报告：%s',report);
    end
    fprintf('本次输出目录：%s\n',R.outputDir);
end
end

function writeTable(T,book,sheet)
labels=T.Properties.VariableDescriptions;
if isempty(labels), labels=T.Properties.VariableNames; end
C=table2cell(T);
for i=1:numel(C)
    v=C{i};
    if isnumeric(v) && isscalar(v)
        if isnan(v), C{i}='NaN（不适用）';
        elseif isinf(v) && v>0, C{i}='Inf（正无穷）';
        elseif isinf(v), C{i}='-Inf（无有限利润下界）'; end
    elseif islogical(v), C{i}=double(v);
    end
end
writecell([labels(:).';C],book,'Sheet',sheet);
end

function [fig,t]=newFigure(R,titleText,rows,cols,sz)
fig=figure('Color','w','Position',[60,60,sz],'Visible',R.options.figureVisible, ...
    'Name',titleText,'NumberTitle','off','ToolBar','none','MenuBar','none');
t=tiledlayout(fig,rows,cols,'TileSpacing','compact','Padding','compact');
title(t,{titleText,R.dataSource},'Interpreter','none','FontWeight','normal','FontSize',15);
end

function [fig,t]=plotIntervals(R)
[fig,t]=newFigure(R,'抽样次品率与精确二项置信区间',2,1,[1400,870]);
T=R.tables.samples;
for panel=1:2
    ax=nexttile(t); rows=1:18; if panel==2, rows=19:30; end
    a=T.Estimate(rows)*100; L=T.Lower(rows)*100; U=T.Upper(rows)*100;
    h=errorbar(ax,1:numel(rows),a,a-L,U-a,'o','LineWidth',1.4,'MarkerSize',5, ...
        'Color',[.15,.42,.65],'MarkerFaceColor',[.15,.42,.65]); hold(ax,'on');
    nominal=R.tables.inputs.NominalRate(rows)*100;
    h2=plot(ax,1:numel(rows),nominal,'x','Color',[.60,.30,.16],'LineWidth',1.4,'MarkerSize',7);
    labels=T.Node(rows);
    if panel==1
        for j=1:18, labels{j}=sprintf('情形%d/%s',ceil(j/3),labels{j}); end
        title(ax,'第二问：六种情形分别建立置信区间');
    else, title(ax,'第三问：八个零件与四个装配节点'); end
    set(ax,'XTick',1:numel(rows),'XTickLabel',labels); xtickangle(ax,30);
    xlim(ax,[.4,numel(rows)+.6]); ylim(ax,[0,min(105,max(U)*1.12+2)]);
    ylabel(ax,'次品率（%）'); grid(ax,'on');
    legend(ax,[h,h2],{'样本次品率及置信区间','题目名义次品率'},'Location','northoutside','Orientation','horizontal');
end
end

function [fig,t]=plotProfits(R)
[fig,t]=newFigure(R,'点估计方案与鲁棒方案的利润比较',1,2,[1450,640]);
T=R.tables.summary; colors=[.27,.50,.69;.80,.54,.34;.12,.49,.37];
for panel=1:2
    ax=nexttile(t); rows=1:6; labels=arrayfun(@(j)sprintf('情形%d',j),1:6,'UniformOutput',false);
    if panel==2, rows=7; labels={'第三问'}; end
    data=[T.PointOwnProfit(rows),T.PointWorstProfit(rows),T.RobustWorstProfit(rows)];
    data(~isfinite(data))=NaN;
    % MATLAB把1×3数组视为一个向量；补空行，保持三种数据系列的语义。
    plotData=data; if size(data,1)==1, plotData=[data;nan(1,3)]; end
    b=bar(ax,plotData,'grouped','EdgeColor','none');
    for h=1:3, b(h).FaceColor=colors(h,:); end
    set(ax,'XTick',1:numel(rows),'XTickLabel',labels); ylabel(ax,'期望利润（元/合格交付订单）');
    xlim(ax,[.4,numel(rows)+.6]);
    grid(ax,'on'); yline(ax,0,'-','Color',[.3,.3,.3]);
    title(ax,'缺柱表示无有限保证或无可行最优，不表示零利润');
    legend(ax,{'点估计方案：点估计利润','点估计方案：最坏利润','鲁棒方案：最坏利润'}, ...
        'Location','southoutside');
end
end

function [fig,t]=plotQ2Heatmap(R)
[fig,t]=newFigure(R,'第二问：全部固定策略的最坏情形利润',1,1,[1450,660]); ax=nexttile(t);
V=nan(6,16); B=false(6,16);
for s=1:6
    A=R.problems{s}; V(s,A.ids)=A.P.price-A.worstCost; B(s,A.ids(A.robustRows))=true;
end
good=isfinite(V); shown=V; shown(~good)=0;
h=imagesc(ax,shown); h.AlphaData=good; set(ax,'Color',[.91,.92,.93]);
cmap=parula(128); colormap(ax,cmap); colorbar(ax); hold(ax,'on');
clim=[0,1];
if any(good(:)), clim=[min(V(good))-.01,max(V(good))+.01]; caxis(ax,clim); end
for s=1:6
    for d=1:16
        label='×'; color=[.62,.20,.15];
        if good(s,d)
            label=sprintf('%.2f',V(s,d)); color=[.08,.10,.12];
            ci=1+round(127*(V(s,d)-clim(1))/diff(clim)); ci=max(1,min(128,ci));
            if cmap(ci,:)*[.2126;.7152;.0722]<.52, color=[1,1,1]; end
            if B(s,d), label=[label,' ★']; end
        end
        text(ax,d,s,label,'HorizontalAlignment','center','Color',color,'FontSize',10,'FontWeight','bold');
    end
end
set(ax,'XTick',1:16,'YTick',1:6,'YTickLabel',arrayfun(@(j)sprintf('情形%d',j),1:6,'UniformOutput',false));
xlabel(ax,'原始策略编号（编码和决策含义见Excel）；★ 为鲁棒最优，× 为无有限保证');
ylabel(ax,'参数情形'); title(ax,'数值单位：元/合格交付订单；不对不可行策略赋予有限利润');
end

function [fig,t]=plotQ3Cloud(R)
[fig,t]=newFigure(R,'第三问：点估计利润与最坏情形利润',1,1,[1000,750]); ax=nexttile(t);
A=R.problems{7}; f=A.robustFeasible; xp=A.P.price-A.pointCost; yp=A.P.price-A.worstCost;
if ~any(f), noData(ax,'置信域内不存在有限成本的鲁棒策略'); return; end
scatter(ax,xp(f),yp(f),13,xp(f)-yp(f),'filled'); hold(ax,'on');
cb=colorbar(ax); cb.Label.String='点估计利润减最坏利润（元）'; colormap(ax,parula(128));
v=[xp(f);yp(f)]; lim=[min(v)-3,max(v)+3]; plot(ax,lim,lim,'--','Color',[.5,.5,.5]);
if ~isempty(A.robustRows)
    r=A.robustRows(1); plot(ax,xp(r),yp(r),'p','MarkerSize',15,'MarkerFaceColor',[.85,.30,.16],'Color','k');
    text(ax,xp(r),yp(r),sprintf('  鲁棒代表ID %d',A.ids(r)),'VerticalAlignment','top');
end
grid(ax,'on'); xlabel(ax,'样本点估计下的期望利润（元/订单）'); ylabel(ax,'置信域内最坏期望利润（元/订单）');
title(ax,sprintf('仅绘制%d个鲁棒可行候选；其余%d个不赋予有限下界',sum(f),sum(~f)));
end

function [fig,t]=plotDecisions(R)
[fig,t]=newFigure(R,'点估计与鲁棒最优代表方案的决策对照',2,1,[1400,1000]);
for panel=1:2
    ax=nexttile(t); group=1:6; if panel==2, group=7; end
    data=[]; labels={}; bits={};
    for s=group
        A=R.problems{s}; bits=A.bitNames;
        for mode=1:2
            rows=A.pointRows; label='点估计'; if mode==2, rows=A.robustRows; label='鲁棒'; end
            if isempty(rows), continue; end
            r=rows(1); data(end+1,:)=A.decisions(r,:); %#ok<AGROW>
            labels{end+1}=sprintf('%s/%s/ID%d',A.name,label,A.ids(r)); %#ok<AGROW>
        end
    end
    if isempty(data), noData(ax,'没有可展示的有限成本方案'); continue; end
    imagesc(ax,data,[0,1]); colormap(ax,[.91,.94,.97;.09,.45,.36]);
    for i=1:size(data,1)
        for j=1:size(data,2)
            txt='否'; color=[.22,.29,.35]; if data(i,j), txt='是'; color=[1,1,1]; end
            text(ax,j,i,txt,'HorizontalAlignment','center','Color',color,'FontSize',12);
        end
    end
    set(ax,'XTick',1:numel(bits),'XTickLabel',bits,'YTick',1:numel(labels),'YTickLabel',labels);
    if panel==2, xtickangle(ax,30); end
    title(ax,'每类取最小编号代表；全部并列最优及利润见Excel');
end
end

function [fig,t]=plotCosts(R)
[fig,t]=newFigure(R,'鲁棒代表方案在全部置信上界下的成本构成',1,2,[1500,760]);
T=R.tables.costs; colors=[.23,.42,.62;.33,.64,.72;.41,.60,.43;.62,.70,.43; ...
    .56,.49,.66;.28,.51,.44;.73,.66,.32;.48,.39,.61;.79,.43,.32];
data=nan(7,9);
for s=1:7
    A=R.problems{s}; rows=strcmp(T.Problem,A.name) & strcmp(T.PolicyType,'鲁棒最优') & strcmp(T.RateScene,'全部置信上界');
    if any(rows), data(s,:)=T.ExpectedCost(rows).'; end
end
ax=nexttile(t); b=bar(ax,data(1:6,:),'stacked','EdgeColor','none');
for j=1:9, b(j).FaceColor=colors(j,:); end
set(ax,'XTick',1:6,'XTickLabel',arrayfun(@(j)sprintf('情形%d',j),1:6,'UniformOutput',false));
ylabel(ax,'最坏情形期望成本（元/订单）'); title(ax,'第二问；缺柱表示没有鲁棒可行方案'); grid(ax,'on');
legend(ax,{'采购','零件检测','半成品装配','半成品检测','半成品拆解', ...
    '成品装配','成品检测','成品拆解','调换'},'Location','southoutside','NumColumns',3);
ax=nexttile(t); bh=barh(ax,data(7,:),'FaceColor','flat','EdgeColor','none'); bh.CData=colors;
labels={'零件采购','零件检测','半成品装配','半成品检测','半成品拆解', ...
    '成品装配','成品检测','成品拆解','调换损失'};
set(ax,'YTick',1:9,'YTickLabel',labels,'YDir','reverse'); hold(ax,'on');
for j=1:9
    if isfinite(data(7,j)), text(ax,data(7,j),j,sprintf('  %.3f',data(7,j)),'VerticalAlignment','middle'); end
end
if any(isfinite(data(7,:))), xlim(ax,[0,max(data(7,:))*1.18+1]); end
xlabel(ax,'最坏情形期望成本（元/订单）'); title(ax,'第三问；事件次数乘单价累加'); grid(ax,'on');
end

function [fig,t]=plotConfidence(R)
[fig,t]=newFigure(R,'同一份抽样数据下的置信水平对比',1,2,[1350,650]);
T=R.tables.confidenceSensitivity;
for panel=1:2
    ax=nexttile(t); hold(ax,'on'); group=1:6; if panel==2, group=7; end
    for s=group
        A=R.problems{s}; rows=strcmp(T.Problem,A.name); xx=T.Confidence(rows)*100; yy=T.WorstProfit(rows);
        [xx,ix]=sort(xx); yy=yy(ix);
        plot(ax,xx,yy,'-o','LineWidth',1.7,'MarkerSize',6,'DisplayName',A.name);
    end
    grid(ax,'on'); xlabel(ax,'所选置信家族的联合置信水平（%）');
    ylabel(ax,'鲁棒最优的最坏期望利润（元/订单）');
    title(ax,'样本不变；缺失点表示无有限成本保证'); legend(ax,'Location','best');
end
end

function noData(ax,msg)
axis(ax,'off'); text(ax,.5,.5,msg,'Units','normalized','HorizontalAlignment','center','FontSize',14);
end

function [font,note]=chooseFont(requested)
note='';
if ~isempty(requested), font=char(requested); return; end
try, available=listfonts; catch, available={}; end
preferred={'Microsoft YaHei','Microsoft YaHei UI','SimHei','SimSun','Noto Sans CJK SC', ...
    'Source Han Sans SC','PingFang SC','WenQuanYi Zen Hei','Arial Unicode MS'};
font='';
for j=1:numel(preferred)
    hit=find(strcmpi(available,preferred{j}),1);
    if ~isempty(hit), font=available{hit}; break; end
end
if isempty(font)
    font='Microsoft YaHei';
    note='未检测到常见中文字体，已请求Microsoft YaHei；如显示方框，请安装中文字体并设置options.fontName。';
    warning('Q4:Font','%s',note);
end
end

function cleanFigure(fig,font)
h=findall(fig,'-property','FontName'); set(h,'FontName',font);
h=findall(fig,'-property','Interpreter'); set(h,'Interpreter','none');
h=findall(fig,'-property','TickLabelInterpreter'); set(h,'TickLabelInterpreter','none');
ax=findall(fig,'Type','axes');
for j=1:numel(ax)
    set(ax(j),'FontName',font,'FontSize',11,'LineWidth',.8,'Box','off','TickDir','out');
    try, ax(j).Toolbar.Visible='off'; catch, end
    try, disableDefaultInteractivity(ax(j)); catch, end
end
end
