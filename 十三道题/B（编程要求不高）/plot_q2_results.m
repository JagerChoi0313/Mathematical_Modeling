function plot_q2_results( ...
    modelConv, modelC4, Z, D, ZM, yConv, yC4, preprocess, figDir)
%PLOT_Q2_RESULTS
% 绘制第二问必要图像：
% 1. 两个响应模型的拟合值与残差诊断
% 2. 四个核心因素相对影响度
% 3. 乙醇转化率最重要两因素响应面 + 等高线
% 4. C4烯烃选择性最重要两因素响应面 + 等高线

%% 图1：拟合与残差诊断
f = figure('Visible','off','Position',[80 80 1150 800]);
tiledlayout(2,2,'Padding','compact','TileSpacing','compact');

nexttile;
scatter(yConv,modelConv.fit.yhat,42,'filled'); hold on;
mn = min([yConv;modelConv.fit.yhat]);
mx = max([yConv;modelConv.fit.yhat]);
plot([mn mx],[mn mx],'--','LineWidth',1.2);
grid on;
xlabel('乙醇转化率实测值 (%)');
ylabel('拟合值 (%)');
title(sprintf('乙醇转化率：实测-拟合（Adj R^2=%.3f）', ...
    modelConv.stats.AdjR2));

nexttile;
scatter(modelConv.fit.yhat,modelConv.fit.stdResidual,42,'filled'); hold on;
yline(0,'--');
yline(2,':');
yline(-2,':');
grid on;
xlabel('拟合值 (%)');
ylabel('标准化残差');
title('乙醇转化率残差诊断');

nexttile;
scatter(yC4,modelC4.fit.yhat,42,'filled'); hold on;
mn = min([yC4;modelC4.fit.yhat]);
mx = max([yC4;modelC4.fit.yhat]);
plot([mn mx],[mn mx],'--','LineWidth',1.2);
grid on;
xlabel('C4烯烃选择性实测值 (%)');
ylabel('拟合值 (%)');
title(sprintf('C4选择性：实测-拟合（Adj R^2=%.3f）', ...
    modelC4.stats.AdjR2));

nexttile;
scatter(modelC4.fit.yhat,modelC4.fit.stdResidual,42,'filled'); hold on;
yline(0,'--');
yline(2,':');
yline(-2,':');
grid on;
xlabel('拟合值 (%)');
ylabel('标准化残差');
title('C4烯烃选择性残差诊断');

exportgraphics(f,fullfile(figDir,'Q2_model_diagnostics.png'), ...
    'Resolution',180);
close(f);

%% 图2：因素影响度
f = figure('Visible','off','Position',[100 100 1000 700]);
tiledlayout(2,1,'Padding','compact','TileSpacing','compact');

nexttile;
bar(modelConv.importanceTable.RelativeInfluence);
grid on;
xticks(1:4);
xticklabels(cellstr(modelConv.importanceTable.Factor));
ylabel('相对影响度 W_j');
title('各因素对乙醇转化率的综合影响度');

nexttile;
bar(modelC4.importanceTable.RelativeInfluence);
grid on;
xticks(1:4);
xticklabels(cellstr(modelC4.importanceTable.Factor));
ylabel('相对影响度 W_j');
title('各因素对C4烯烃选择性的综合影响度');

exportgraphics(f,fullfile(figDir,'Q2_factor_importance.png'), ...
    'Resolution',180);
close(f);

%% 图3、图4：自动选择影响度排名前两位的因素绘制响应面
plot_one_surface(modelConv,preprocess,figDir, ...
    'Q2_response_surface_conversion.png');

plot_one_surface(modelC4,preprocess,figDir, ...
    'Q2_response_surface_C4_selectivity.png');

end

%% ========================================================================
function plot_one_surface(model,preprocess,figDir,fileName)

    imp = model.importanceTable.RelativeInfluence;
    [~,ord] = sort(imp,'descend');
    j1 = ord(1);
    j2 = ord(2);

    factorNames = preprocess.factorNames;

    x1 = linspace(preprocess.rawMin(j1),preprocess.rawMax(j1),60);
    x2 = linspace(preprocess.rawMin(j2),preprocess.rawMax(j2),60);
    [G1,G2] = meshgrid(x1,x2);

    N = numel(G1);

    % 其他连续因素固定在样本均值，即标准化后z=0
    Zgrid = zeros(N,4);

    Zgrid(:,j1) = ...
        (G1(:)-preprocess.mu(j1))/preprocess.sigma(j1);

    Zgrid(:,j2) = ...
        (G2(:)-preprocess.mu(j2))/preprocess.sigma(j2);

    % 响应面图统一展示装料方式I（D=0）
    Dgrid = zeros(N,1);

    % 若最终模型含总装料量控制项，则固定在样本平均值，即ZM=0
    ZMgrid = zeros(N,1);

    ygrid = predict_response(model,Zgrid,Dgrid,ZMgrid);
    Y = reshape(ygrid,size(G1));

    f = figure('Visible','off','Position',[100 100 1150 500]);
    tiledlayout(1,2,'Padding','compact','TileSpacing','compact');

    nexttile;
    surf(G1,G2,Y,'EdgeColor','none');
    grid on;
    xlabel(factor_axis_label(j1,factorNames));
    ylabel(factor_axis_label(j2,factorNames));
    zlabel(char(model.responseName)+" (%)");
    title(sprintf('%s响应面',char(model.responseName)));
    view(45,30);

    nexttile;
    contourf(G1,G2,Y,18);
    colorbar;
    grid on;
    xlabel(factor_axis_label(j1,factorNames));
    ylabel(factor_axis_label(j2,factorNames));
    title(sprintf('%s等高线',char(model.responseName)));

    sgtitle(sprintf( ...
        '影响度最高的两因素：%s 与 %s；其他因素取样本均值，装料方式I', ...
        char(factorNames(j1)),char(factorNames(j2))));

    exportgraphics(f,fullfile(figDir,fileName),'Resolution',180);
    close(f);
end

%% ========================================================================
function yhat = predict_response(model,Z,D,ZM)
    terms = model.terms;
    cols = model.selectedCols;
    b = model.fit.b;

    n = size(Z,1);
    X = zeros(n,numel(cols));

    for pos = 1:numel(cols)
        term = terms(cols(pos));
        f = term.factors;

        switch term.type
            case 'intercept'
                X(:,pos) = 1;

            case 'main'
                X(:,pos) = Z(:,f(1));

            case 'square'
                X(:,pos) = Z(:,f(1)).^2;

            case 'interaction'
                X(:,pos) = Z(:,f(1)).*Z(:,f(2));

            case 'controlD'
                X(:,pos) = D;

            case 'controlM'
                X(:,pos) = ZM;
        end
    end

    yhat = X*b;
end

%% ========================================================================
function label = factor_axis_label(j,factorNames)
    switch j
        case 1
            label = sprintf('%s (wt%%)',char(factorNames(j)));
        case 2
            label = sprintf('%s',char(factorNames(j)));
        case 3
            label = sprintf('%s (ml/min)',char(factorNames(j)));
        case 4
            label = sprintf('%s (℃)',char(factorNames(j)));
        otherwise
            label = char(factorNames(j));
    end
end
