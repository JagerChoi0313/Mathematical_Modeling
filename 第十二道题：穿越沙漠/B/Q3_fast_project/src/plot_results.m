function plot_results(simulation, gameResult, data, projectRoot)
%PLOT_RESULTS 生成路线、资源、资金和最优响应迭代图

figDir=fullfile(projectRoot,'figures',sprintf('case%d',data.caseID));
if ~isfolder(figDir), mkdir(figDir); end

plot_routes(simulation,data,figDir);
plot_resources(simulation,data,figDir);
plot_cash(simulation,data,figDir);
plot_iterations(gameResult,data,figDir);
end

function plot_routes(simulation,data,figDir)
f=figure('Position',[100 80 1350 850]); hold on;
for e=1:size(data.edges,1)
    a=data.edges(e,1); b=data.edges(e,2);
    plot([data.plotX(a) data.plotX(b)],[data.plotY(a) data.plotY(b)],'LineWidth',0.8);
end
scatter(data.plotX,data.plotY,55,'o','filled','MarkerFaceAlpha',0.18);
for r=1:data.numRegions
    text(data.plotX(r)+0.05,data.plotY(r)+0.04,string(r),'FontSize',10);
end

h=gobjects(1,data.numPlayers);
for p=1:data.numPlayers
    P=simulation.players(p);
    last=min(data.deadline, max(1, P.arrivalDay));
    if ~isfinite(last), last=data.deadline; end
    ids=P.region(1:last+1);
    h(p)=plot(data.plotX(ids),data.plotY(ids),'-o','LineWidth',3,'MarkerSize',5);
end
scatter(data.plotX(data.startRegion),data.plotY(data.startRegion),170,'s','filled');
scatter(data.plotX(data.endRegion),data.plotY(data.endRegion),170,'d','filled');
for r=data.mineRegions, scatter(data.plotX(r),data.plotY(r),190,'^','filled'); end
for r=data.villageRegions, scatter(data.plotX(r),data.plotY(r),210,'p','filled'); end
axis equal; axis off;
title(sprintf('第三问第%d关多人策略路线',data.caseID),'FontWeight','bold');
L=strings(1,data.numPlayers); for p=1:data.numPlayers,L(p)=sprintf('玩家%d',p);end
legend(h,L,'Location','best');
exportgraphics(f,fullfile(figDir,sprintf('case%d_routes.png',data.caseID)),'Resolution',220);
close(f);
end

function plot_resources(simulation,data,figDir)
f=figure('Position',[100 80 1300 760]); hold on;
for p=1:data.numPlayers
    P=simulation.players(p); d=0:data.deadline;
    plot(d,P.water,'-o','LineWidth',1.8,'MarkerSize',4);
    plot(d,P.food,'--s','LineWidth',1.5,'MarkerSize',4);
end
xlabel('日期'); ylabel('剩余数量（箱）'); grid on;
title(sprintf('第三问第%d关水和食物变化',data.caseID),'FontWeight','bold');
L=strings(1,2*data.numPlayers); k=1;
for p=1:data.numPlayers,L(k)=sprintf('玩家%d-水',p);L(k+1)=sprintf('玩家%d-食物',p);k=k+2;end
legend(L,'Location','best');
exportgraphics(f,fullfile(figDir,sprintf('case%d_resources.png',data.caseID)),'Resolution',220); close(f);
end

function plot_cash(simulation,data,figDir)
f=figure('Position',[100 80 1300 760]); hold on;
for p=1:data.numPlayers
    plot(0:data.deadline,simulation.players(p).cash,'-o','LineWidth',2,'MarkerSize',4);
end
xlabel('日期'); ylabel('剩余现金（元）'); grid on;
title(sprintf('第三问第%d关资金变化',data.caseID),'FontWeight','bold');
L=strings(1,data.numPlayers);for p=1:data.numPlayers,L(p)=sprintf('玩家%d',p);end
legend(L,'Location','best');
exportgraphics(f,fullfile(figDir,sprintf('case%d_cash.png',data.caseID)),'Resolution',220); close(f);
end

function plot_iterations(gameResult,data,figDir)
if isempty(gameResult.iterationHistory),return;end
f=figure('Position',[100 80 1100 680]); hold on;
x=1:size(gameResult.iterationHistory,1);
for p=1:data.numPlayers
    plot(x,gameResult.iterationHistory(:,p),'-o','LineWidth',2,'MarkerSize',5);
end
xlabel('最优响应轮次'); ylabel('保证型/最终资金（元）'); grid on;
title(sprintf('第三问第%d关最优响应迭代',data.caseID),'FontWeight','bold');
L=strings(1,data.numPlayers);for p=1:data.numPlayers,L(p)=sprintf('玩家%d',p);end
legend(L,'Location','best');
exportgraphics(f,fullfile(figDir,sprintf('case%d_iterations.png',data.caseID)),'Resolution',220); close(f);
end
