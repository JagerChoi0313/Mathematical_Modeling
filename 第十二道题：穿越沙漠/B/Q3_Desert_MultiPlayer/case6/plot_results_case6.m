function plot_results_case6(result, data, projectRoot)
%PLOT_RESULTS_CASE6 绘制第六关代表性最不利情形

figureDir = fullfile(projectRoot,'figures','case6');
if ~isfolder(figureDir), mkdir(figureDir); end

x = data.plotX;
y = data.plotY;
routeColors = [0.08 0.35 0.60; 0.75 0.30 0.12; 0.28 0.55 0.28];
routeStyles = {'-','--','-.'};

fig = figure('Color','w','Position',[80,40,1050,850]);
hold on;

for e = 1:size(data.edges,1)
    i = data.edges(e,1); j = data.edges(e,2);
    plot([x(i),x(j)],[y(i),y(j)],'-','Color',[0.80,0.84,0.88],'LineWidth',1.0);
end

scatter(x,y,38,'w','filled','MarkerEdgeColor',[0.38,0.48,0.58]);

for p = 1:data.numPlayers
    T = result.dailyTables{p};
    for r = 2:height(T)
        i = T.StartRegion(r); j = T.EndRegion(r);
        if i ~= j
            plot([x(i),x(j)],[y(i),y(j)],routeStyles{p}, ...
                'Color',routeColors(p,:),'LineWidth',2.7);
        end
    end
end

scatter(x(data.startRegion),y(data.startRegion),125,'s','filled', ...
    'MarkerFaceColor',[0.20,0.55,0.32]);
scatter(x(data.villageRegion),y(data.villageRegion),145,'p','filled', ...
    'MarkerFaceColor',[0.42,0.30,0.62]);
scatter(x(data.mineRegion),y(data.mineRegion),145,'^','filled', ...
    'MarkerFaceColor',[0.85,0.52,0.12]);
scatter(x(data.endRegion),y(data.endRegion),145,'d','filled', ...
    'MarkerFaceColor',[0.70,0.18,0.16]);

for i = 1:data.numRegions
    text(x(i)+0.05,y(i)+0.05,num2str(i),'FontSize',9);
end

title({'第六关三玩家保证型策略路线', ...
    sprintf('代表性最不利天气：%s',char(result.weatherText))}, ...
    'FontWeight','bold');

axis equal off;
exportgraphics(fig,fullfile(figureDir,'case6_routes.png'),'Resolution',300);
close(fig);

fig = figure('Color','w','Position',[100,80,1100,650]);
hold on;
for p = 1:data.numPlayers
    T = result.dailyTables{p};
    plot(T.Day,T.WaterLeft,routeStyles{p}, ...
        'Color',routeColors(p,:),'LineWidth',2, ...
        'Marker','o','DisplayName',sprintf('玩家%d',p));
end
xlabel('日期'); ylabel('剩余资源对（箱水/箱食物）');
title('第六关代表性最不利情形下资源变化','FontWeight','bold');
grid on; legend('Location','best');
exportgraphics(fig,fullfile(figureDir,'case6_resources.png'),'Resolution',300);
close(fig);

fig = figure('Color','w','Position',[100,80,1100,650]);
hold on;
for p = 1:data.numPlayers
    T = result.dailyTables{p};
    plot(T.Day,T.CashLeft,routeStyles{p}, ...
        'Color',routeColors(p,:),'LineWidth',2, ...
        'Marker','o','DisplayName',sprintf('玩家%d',p));
end
xlabel('日期'); ylabel('剩余现金（元）');
title('第六关代表性最不利情形下现金变化','FontWeight','bold');
grid on; legend('Location','best');
exportgraphics(fig,fullfile(figureDir,'case6_cash.png'),'Resolution',300);
close(fig);
end
