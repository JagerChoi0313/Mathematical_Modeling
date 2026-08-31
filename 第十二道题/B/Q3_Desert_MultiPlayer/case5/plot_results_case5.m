function plot_results_case5(result, data, projectRoot)
%PLOT_RESULTS_CASE5 绘制第五关两名玩家路线与资源变化

figureDir = fullfile(projectRoot,'figures','case5');
if ~isfolder(figureDir), mkdir(figureDir); end

x = data.plotX;
y = data.plotY;

fig = figure('Color','w','Position',[80,50,1100,760]);
hold on;

for e = 1:size(data.edges,1)
    i = data.edges(e,1); j = data.edges(e,2);
    plot([x(i),x(j)],[y(i),y(j)],'-','Color',[0.78,0.83,0.88],'LineWidth',1.2);
end

scatter(x,y,45,'w','filled','MarkerEdgeColor',[0.35,0.45,0.55]);

routeStyles = {'-','--'};
routeColors = [0.08 0.35 0.60; 0.72 0.28 0.12];

for p = 1:data.numPlayers
    T = result.dailyTables{p};
    for r = 2:height(T)
        i = T.StartRegion(r); j = T.EndRegion(r);
        if i ~= j
            plot([x(i),x(j)],[y(i),y(j)],routeStyles{p}, ...
                'Color',routeColors(p,:),'LineWidth',3);
        end
    end
end

scatter(x(data.startRegion),y(data.startRegion),120,'s','filled', ...
    'MarkerFaceColor',[0.20,0.55,0.32]);
scatter(x(data.mineRegion),y(data.mineRegion),130,'^','filled', ...
    'MarkerFaceColor',[0.85,0.52,0.12]);
scatter(x(data.endRegion),y(data.endRegion),135,'d','filled', ...
    'MarkerFaceColor',[0.70,0.18,0.16]);

for i = 1:data.numRegions
    text(x(i)+0.08,y(i)+0.07,num2str(i),'FontSize',10);
end

title('第五关两名玩家最优行动路线','FontWeight','bold');
axis equal off;
legend({'地图边界','','玩家1','玩家2','起点','矿山','终点'},'Location','bestoutside');
exportgraphics(fig,fullfile(figureDir,'case5_routes.png'),'Resolution',300);
close(fig);

fig = figure('Color','w','Position',[100,80,1100,650]);
hold on;
for p = 1:data.numPlayers
    T = result.dailyTables{p};
    plot(T.Day,T.WaterLeft,'-o','LineWidth',1.8,'DisplayName',sprintf('玩家%d 水',p));
    plot(T.Day,T.FoodLeft,'--s','LineWidth',1.6,'DisplayName',sprintf('玩家%d 食物',p));
end
xlabel('日期'); ylabel('剩余数量（箱）');
title('第五关两名玩家资源剩余量变化','FontWeight','bold');
grid on; legend('Location','best');
exportgraphics(fig,fullfile(figureDir,'case5_resources.png'),'Resolution',300);
close(fig);
end
