function resultTable = analyze_time_stability(timeMin, conv, c4sel, figDir)
%ANALYZE_TIME_STABILITY
% 对附件2中350℃条件下的时间序列做稳定性分析：
%   1) 线性趋势 y = b0 + b1*t
%   2) 斜率显著性t检验
%   3) 均值、标准差、变异系数CV
%   4) 辅助计算C4烯烃收率 = 转化率 * 选择性 / 100

    timeMin = timeMin(:);
    conv = conv(:);
    c4sel = c4sel(:);
    c4yield = conv .* c4sel / 100;

    s1 = trend_stats(timeMin, conv);
    s2 = trend_stats(timeMin, c4sel);
    s3 = trend_stats(timeMin, c4yield);

    resultTable = table( ...
        ["乙醇转化率"; "C4烯烃选择性"; "C4烯烃收率"], ...
        [mean(conv); mean(c4sel); mean(c4yield)], ...
        [std(conv,0); std(c4sel,0); std(c4yield,0)], ...
        [std(conv,0)/mean(conv); std(c4sel,0)/mean(c4sel); std(c4yield,0)/mean(c4yield)], ...
        [s1.intercept; s2.intercept; s3.intercept], ...
        [s1.slope; s2.slope; s3.slope], ...
        [s1.R2; s2.R2; s3.R2], ...
        [s1.pSlope; s2.pSlope; s3.pSlope], ...
        [make_conclusion(s1.slope,s1.pSlope); make_conclusion(s2.slope,s2.pSlope); make_conclusion(s3.slope,s3.pSlope)], ...
        'VariableNames', {'指标','均值','标准差','变异系数CV','截距','时间斜率','R2','斜率p值','趋势结论'});

    %% 稳定性图：原始数据 + 线性趋势
    f = figure('Visible','off','Position',[100 100 1100 760]);
    tiledlayout(3,1,'Padding','compact','TileSpacing','compact');

    nexttile;
    plot_trend(timeMin, conv, s1, '乙醇转化率 (%)');
    title('350℃：乙醇转化率随时间变化');

    nexttile;
    plot_trend(timeMin, c4sel, s2, 'C4烯烃选择性 (%)');
    title('350℃：C4烯烃选择性随时间变化');

    nexttile;
    plot_trend(timeMin, c4yield, s3, 'C4烯烃收率 (%)');
    title('350℃：C4烯烃收率随时间变化（辅助分析）');

    exportgraphics(f, fullfile(figDir,'stability_350C.png'),'Resolution',180);
    close(f);
end

%% ===== 线性趋势及斜率显著性 =====
function s = trend_stats(t, y)
    n = numel(y);
    X = [ones(n,1), t];
    b = X \ y;
    yhat = X*b;
    e = y-yhat;

    SSE = sum(e.^2);
    SST = sum((y-mean(y)).^2);
    R2 = 1-SSE/SST;

    % 斜率标准误与t检验
    df = n-2;
    MSE = SSE/df;
    covB = MSE * inv(X'*X); %#ok<MINV> 数据量很小，这里直接求逆便于理解
    seSlope = sqrt(covB(2,2));
    tStat = b(2)/seSlope;

    % 双侧t检验p值：用不完全Beta函数实现，避免 Statistics Toolbox
    pSlope = t_two_sided_p(abs(tStat), df);

    s.intercept = b(1);
    s.slope = b(2);
    s.R2 = R2;
    s.pSlope = pSlope;
    s.yhat = yhat;
end

%% ===== 双侧t检验p值 =====
function p = t_two_sided_p(t, v)
% 对自由度v的t分布，双侧p值。
    x = v/(v+t^2);
    p = betainc(x, v/2, 1/2);
end

%% ===== 趋势结论 =====
function textOut = make_conclusion(slope, p)
    if p < 0.05
        if slope < 0
            textOut = "随时间显著下降";
        else
            textOut = "随时间显著上升";
        end
    else
        textOut = "未发现显著线性时间趋势";
    end
end

%% ===== 画趋势图 =====
function plot_trend(t, y, s, yLabelText)
    scatter(t,y,55,'filled'); hold on;
    tt = linspace(min(t),max(t),200)';
    yy = s.intercept + s.slope*tt;
    plot(tt,yy,'LineWidth',1.6);
    grid on;
    xlabel('时间 (min)'); ylabel(yLabelText);
    legend('实验数据','线性趋势','Location','best');
    txt = sprintf('斜率=%.5f\nR^2=%.4f\np=%.4g',s.slope,s.R2,s.pSlope);
    text(0.03,0.95,txt,'Units','normalized','VerticalAlignment','top', ...
        'BackgroundColor','white','Margin',4);
end
