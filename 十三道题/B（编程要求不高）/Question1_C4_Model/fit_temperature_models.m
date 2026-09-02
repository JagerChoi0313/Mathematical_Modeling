function resultTable = fit_temperature_models(catalystID, temp, conv, c4sel, figDir)
%FIT_TEMPERATURE_MODELS
% 对每种催化剂组合分别建立“温度 -> 乙醇转化率”和“温度 -> C4选择性”的
% 一次/二次多项式回归模型，并通过调整R^2、RMSE、嵌套F检验进行模型选择。
%
% 输入：
%   catalystID : n×1 string，催化剂编号（A1...B7）
%   temp       : n×1 double，温度(℃)
%   conv       : n×1 double，乙醇转化率(%)
%   c4sel      : n×1 double，C4烯烃选择性(%)
%   figDir     : 图片输出文件夹
%
% 输出：
%   resultTable : 每个“催化剂-指标”一行的回归结果表

ids = unique(catalystID, 'stable');
rows = cell(0, 13);

for k = 1:numel(ids)
    id = ids(k);
    idx = catalystID == id;

    T = temp(idx);
    Y1 = conv(idx);
    Y2 = c4sel(idx);

    % 按温度排序，便于画图和残差检查
    [T, order] = sort(T);
    Y1 = Y1(order);
    Y2 = Y2(order);

    % 温度无量纲化：z=(T-350)/100
    z = (T - 350) / 100;

    % 分别拟合两个指标
    fitConv = compare_poly_models(z, Y1);
    fitSel  = compare_poly_models(z, Y2);

    rows(end+1,:) = make_row(id, "乙醇转化率", fitConv); %#ok<AGROW>
    rows(end+1,:) = make_row(id, "C4烯烃选择性", fitSel); %#ok<AGROW>

    %% 每种催化剂画1张四联图：两个拟合图 + 两个残差图
    f = figure('Visible','off', 'Position',[100 100 1100 720]);
    tiledlayout(2,2,'Padding','compact','TileSpacing','compact');

    % 转化率拟合图
    nexttile;
    plot_fit_panel(T, z, Y1, fitConv, '乙醇转化率 (%)');
    title(sprintf('%s：温度-乙醇转化率', char(id)));

    % 选择性拟合图
    nexttile;
    plot_fit_panel(T, z, Y2, fitSel, 'C4烯烃选择性 (%)');
    title(sprintf('%s：温度-C4烯烃选择性', char(id)));

    % 转化率残差
    nexttile;
    scatter(T, fitConv.residual, 45, 'filled'); hold on;
    yline(0,'--'); grid on;
    xlabel('温度 (℃)'); ylabel('残差');
    title(sprintf('转化率残差（%s）', fitConv.modelName));

    % 选择性残差
    nexttile;
    scatter(T, fitSel.residual, 45, 'filled'); hold on;
    yline(0,'--'); grid on;
    xlabel('温度 (℃)'); ylabel('残差');
    title(sprintf('选择性残差（%s）', fitSel.modelName));

    exportgraphics(f, fullfile(figDir, sprintf('%s_temperature_fit_residual.png', char(id))), 'Resolution', 180);
    close(f);
end

resultTable = cell2table(rows, 'VariableNames', ...
    {'催化剂编号','指标','样本数','最终模型','模型表达式', ...
     'R2','调整R2','RMSE','SSE','二次项F值','二次项F检验p值', ...
     '最大绝对标准化残差','残差异常提示'});
end

%% ===== 子函数：比较一次、二次多项式 =====
function out = compare_poly_models(z, y)
    z = z(:); y = y(:);
    n = numel(y);

    % ---------- 一次模型 ----------
    X1 = [ones(n,1), z];
    b1 = X1 \ y;
    yhat1 = X1*b1;
    stat1 = calc_stats(y, yhat1, size(X1,2));

    % ---------- 二次模型 ----------
    X2 = [ones(n,1), z, z.^2];
    b2 = X2 \ y;
    yhat2 = X2*b2;
    stat2 = calc_stats(y, yhat2, size(X2,2));

    % ---------- 一次 vs 二次：嵌套F检验 ----------
    df1 = size(X2,2) - size(X1,2);   % 新增参数个数 = 1
    df2 = n - size(X2,2);            % 二次模型残差自由度

    if df2 > 0 && stat1.SSE >= stat2.SSE
        F = ((stat1.SSE - stat2.SSE)/df1) / (stat2.SSE/df2);
        pF = 1 - f_cdf(F, df1, df2);
    else
        F = NaN;
        pF = NaN;
    end

    % ---------- 模型选择规则 ----------
    % 1) 二次项F检验显著（p<0.05）；
    % 2) 且二次模型调整R2不低于一次模型；
    % 满足时选二次，否则按简约原则选一次。
    if ~isnan(pF) && pF < 0.05 && stat2.adjR2 >= stat1.adjR2
        modelName = "二次多项式";
        coef = b2;
        yhat = yhat2;
        stat = stat2;
        Xfinal = X2;
    else
        modelName = "一次多项式";
        coef = b1;
        yhat = yhat1;
        stat = stat1;
        Xfinal = X1;
    end

    residual = y - yhat;
    stdResidual = standardize_residual(residual, Xfinal);
    maxStdRes = max(abs(stdResidual));

    if maxStdRes > 2
        residualFlag = "存在|标准化残差|>2的数据点，建议结合原始实验检查";
    else
        residualFlag = "未发现明显大残差";
    end

    if modelName == "一次多项式"
        eqn = sprintf('y = %.6g + %.6g*z, z=(T-350)/100', coef(1), coef(2));
    else
        eqn = sprintf('y = %.6g + %.6g*z + %.6g*z^2, z=(T-350)/100', ...
            coef(1), coef(2), coef(3));
    end

    out.modelName = modelName;
    out.coef = coef;
    out.eqn = string(eqn);
    out.R2 = stat.R2;
    out.adjR2 = stat.adjR2;
    out.RMSE = stat.RMSE;
    out.SSE = stat.SSE;
    out.F = F;
    out.pF = pF;
    out.yhat = yhat;
    out.residual = residual;
    out.stdResidual = stdResidual;
    out.maxStdRes = maxStdRes;
    out.residualFlag = residualFlag;
end

%% ===== 子函数：拟合统计量 =====
function s = calc_stats(y, yhat, k)
% k = 参数个数（含截距）
    n = numel(y);
    residual = y - yhat;
    SSE = sum(residual.^2);
    SST = sum((y - mean(y)).^2);

    if SST > 0
        R2 = 1 - SSE/SST;
    else
        R2 = NaN;
    end

    if n > k && ~isnan(R2)
        adjR2 = 1 - (1-R2)*(n-1)/(n-k);
    else
        adjR2 = NaN;
    end

    % 与建模说明保持一致：RMSE = sqrt(mean(e^2))
    RMSE = sqrt(mean(residual.^2));

    s.SSE = SSE;
    s.R2 = R2;
    s.adjR2 = adjR2;
    s.RMSE = RMSE;
end

%% ===== 子函数：标准化残差（用于异常提示） =====
function r = standardize_residual(e, X)
% 内部标准化残差 r_i=e_i/[s*sqrt(1-h_ii)]。
    n = numel(e);
    k = size(X,2);
    if n > k
        sigma = sqrt(sum(e.^2)/(n-k));
    else
        sigma = sqrt(mean(e.^2));
    end

    if sigma > 0
        H = X * ((X' * X) \ X');
        h = diag(H);
        denom = sigma .* sqrt(max(1-h, eps));
        r = e ./ denom;
    else
        r = zeros(size(e));
    end
end

%% ===== 子函数：F分布CDF，避免依赖 Statistics Toolbox =====
function p = f_cdf(x, d1, d2)
    if x < 0
        p = 0;
        return;
    end
    q = (d1*x) / (d1*x + d2);
    p = betainc(q, d1/2, d2/2);
end

%% ===== 子函数：生成结果表的一行 =====
function row = make_row(id, metric, fit)
    row = {id, metric, numel(fit.yhat), fit.modelName, fit.eqn, ...
           fit.R2, fit.adjR2, fit.RMSE, fit.SSE, fit.F, fit.pF, ...
           fit.maxStdRes, fit.residualFlag};
end

%% ===== 子函数：画拟合图 =====
function plot_fit_panel(T, z, y, fit, yLabelText)
    scatter(T, y, 48, 'filled'); hold on;

    Tgrid = linspace(min(T), max(T), 200)';
    zgrid = (Tgrid - 350)/100;

    if fit.modelName == "一次多项式"
        ygrid = fit.coef(1) + fit.coef(2)*zgrid;
    else
        ygrid = fit.coef(1) + fit.coef(2)*zgrid + fit.coef(3)*zgrid.^2;
    end

    plot(Tgrid, ygrid, 'LineWidth', 1.6);
    grid on;
    xlabel('温度 (℃)');
    ylabel(yLabelText);
    legend('实验数据', char(fit.modelName), 'Location','best');

    txt = sprintf('Adj R^2=%.4f\nRMSE=%.4f\np_F=%.4g', ...
        fit.adjR2, fit.RMSE, fit.pF);
    text(0.03,0.95,txt,'Units','normalized','VerticalAlignment','top', ...
        'BackgroundColor','white','Margin',4);
end
