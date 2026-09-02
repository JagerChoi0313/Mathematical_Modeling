function [finalTable, compareTable] = fit_temperature_models_v3(catalystID, temp, conv, c4sel, figDir)
%FIT_TEMPERATURE_MODELS_V3
% 对每种催化剂组合分别研究：
%   1) 温度 -> 乙醇转化率
%   2) 温度 -> C4烯烃选择性
%
% 候选模型：
%   一次：y = b0 + b1*z
%   二次：y = b0 + b1*z + b2*z^2
%   z=(T-350)/100
%
% V3模型评价指标：
%   - R^2
%   - Adjusted R^2
%   - 训练RMSE
%   - LOOCV-RMSE（留一交叉验证）
%   - 一次/二次嵌套F检验
%   - 标准化残差
%
% 选择原则：
% A. 若二次项F检验显著(p<0.05)，且Adj-R2不下降，
%    同时LOOCV-RMSE没有明显恶化(不超过一次模型的110%)，选择二次。
% B. 即使p>=0.05，如果二次模型：
%      LOOCV-RMSE至少降低10%，
%      Adj-R2至少提高0.03，
%      训练RMSE至少降低10%，
%    则认为二次模型具有明显预测优势，也选择二次。
% C. 其余情况优先一次模型，避免小样本下过拟合。
% D. 若二次模型产生明显更差的标准化残差，则否决二次模型。

ids = unique(catalystID, 'stable');

finalRows = cell(0,20);
compareRows = cell(0,18);

for k = 1:numel(ids)
    id = ids(k);
    idx = catalystID == id;

    T  = temp(idx);
    Y1 = conv(idx);
    Y2 = c4sel(idx);

    [T, order] = sort(T);
    Y1 = Y1(order);
    Y2 = Y2(order);

    z = (T - 350) / 100;

    fitConv = compare_poly_models(z, Y1);
    fitSel  = compare_poly_models(z, Y2);

    finalRows(end+1,:) = make_final_row(id, "乙醇转化率", fitConv); %#ok<AGROW>
    finalRows(end+1,:) = make_final_row(id, "C4烯烃选择性", fitSel); %#ok<AGROW>

    compareRows(end+1,:) = make_compare_row(id, "乙醇转化率", fitConv); %#ok<AGROW>
    compareRows(end+1,:) = make_compare_row(id, "C4烯烃选择性", fitSel); %#ok<AGROW>

    %% 作图：拟合曲线 + 最终模型残差
    f = figure('Visible','off', 'Position',[100 100 1120 760]);
    tiledlayout(2,2,'Padding','compact','TileSpacing','compact');

    nexttile;
    plot_fit_panel(T, Y1, fitConv, '乙醇转化率 (%)');
    title(sprintf('%s：温度-乙醇转化率', char(id)));

    nexttile;
    plot_fit_panel(T, Y2, fitSel, 'C4烯烃选择性 (%)');
    title(sprintf('%s：温度-C4烯烃选择性', char(id)));

    nexttile;
    scatter(T, fitConv.finalResidual, 45, 'filled'); hold on;
    yline(0,'--'); grid on;
    xlabel('温度 (℃)'); ylabel('残差');
    title(sprintf('转化率残差（%s）', char(fitConv.modelName)));

    nexttile;
    scatter(T, fitSel.finalResidual, 45, 'filled'); hold on;
    yline(0,'--'); grid on;
    xlabel('温度 (℃)'); ylabel('残差');
    title(sprintf('选择性残差（%s）', char(fitSel.modelName)));

    safeID = sanitize_filename(char(id));
    outPng = fullfile(figDir, sprintf('%s_temperature_fit_residual_v3.png', safeID));
    exportgraphics(f, outPng, 'Resolution', 180);
    close(f);
end

finalTable = cell2table(finalRows, 'VariableNames', ...
    {'催化剂编号','指标','样本数','最终模型','模型表达式','选择依据', ...
     'R2','调整R2','RMSE','LOOCV_RMSE','SSE', ...
     '二次项F值','二次项F检验p值', ...
     '一次调整R2','二次调整R2','一次RMSE','二次RMSE', ...
     '一次LOOCV_RMSE','二次LOOCV_RMSE','最大绝对标准化残差'});

compareTable = cell2table(compareRows, 'VariableNames', ...
    {'催化剂编号','指标','样本数', ...
     '一次R2','一次调整R2','一次RMSE','一次LOOCV_RMSE','一次最大标准化残差', ...
     '二次R2','二次调整R2','二次RMSE','二次LOOCV_RMSE','二次最大标准化残差', ...
     '调整R2提升','训练RMSE改善率','LOOCV改善率', ...
     '二次项F检验p值','最终选择'});
end

%% ===== 比较一次与二次模型 =====
function out = compare_poly_models(z, y)
z = z(:);
y = y(:);
n = numel(y);

%% 1. 一次模型
m1 = fit_one_model(z, y, 1);

%% 2. 二次模型
m2 = fit_one_model(z, y, 2);

%% 3. 一次与二次的嵌套F检验
df1 = 1;
df2 = n - 3;

if df2 > 0 && m1.SSE >= m2.SSE
    F = ((m1.SSE - m2.SSE)/df1) / (m2.SSE/df2);
    pF = 1 - f_cdf(F, df1, df2);
else
    F = NaN;
    pF = NaN;
end

%% 4. 计算二次模型相对一次模型的改善幅度
adjGain = m2.adjR2 - m1.adjR2;

if m1.RMSE > 0
    rmseImprove = (m1.RMSE - m2.RMSE) / m1.RMSE;
else
    rmseImprove = 0;
end

if m1.LOOCV_RMSE > 0
    cvImprove = (m1.LOOCV_RMSE - m2.LOOCV_RMSE) / m1.LOOCV_RMSE;
else
    cvImprove = 0;
end

%% 5. 残差约束：二次模型不能产生明显更差的异常残差
residualOK = m2.maxStdRes <= max(2.5, m1.maxStdRes + 0.5);

%% 6. 综合模型选择
% 路径A：统计显著 + 泛化能力未明显恶化
chooseBySignificance = ...
    ~isnan(pF) && pF < 0.05 && ...
    m2.adjR2 >= m1.adjR2 && ...
    m2.LOOCV_RMSE <= 1.10*m1.LOOCV_RMSE && ...
    residualOK;

% 路径B：小样本下F检验未显著，但预测能力明显提升
chooseByPrediction = ...
    cvImprove >= 0.10 && ...
    adjGain >= 0.03 && ...
    rmseImprove >= 0.10 && ...
    residualOK;

if chooseBySignificance
    selected = m2;
    modelName = "二次多项式";
    reason = "二次项显著，且调整R2提高、LOOCV未明显恶化";
elseif chooseByPrediction
    selected = m2;
    modelName = "二次多项式";
    reason = "F检验虽未必显著，但LOOCV、调整R2和RMSE均明显改善";
else
    selected = m1;
    modelName = "一次多项式";

    if m2.LOOCV_RMSE > 1.10*m1.LOOCV_RMSE
        reason = "二次模型样本内拟合可能改善，但LOOCV变差，优先一次模型";
    elseif adjGain < 0.03 && (isnan(pF) || pF >= 0.05)
        reason = "二次模型提升有限且二次项不显著，按简约原则选一次模型";
    elseif ~residualOK
        reason = "二次模型残差诊断较差，优先一次模型";
    else
        reason = "综合拟合、LOOCV和显著性后，一次模型更稳健";
    end
end

%% 7. 最终模型表达式
coef = selected.coef;

if modelName == "一次多项式"
    eqn = sprintf('y = %.6g + %.6g*z, z=(T-350)/100', ...
        coef(1), coef(2));
else
    eqn = sprintf('y = %.6g + %.6g*z + %.6g*z^2, z=(T-350)/100', ...
        coef(1), coef(2), coef(3));
end

out.modelName = modelName;
out.reason = reason;
out.eqn = string(eqn);
out.selected = selected;
out.linear = m1;
out.quadratic = m2;
out.F = F;
out.pF = pF;
out.adjGain = adjGain;
out.rmseImprove = rmseImprove;
out.cvImprove = cvImprove;
out.finalResidual = selected.residual;
out.finalStdResidual = selected.stdResidual;
end

%% ===== 拟合一个指定阶数模型 =====
function m = fit_one_model(z, y, degree)
n = numel(y);

if degree == 1
    X = [ones(n,1), z];
elseif degree == 2
    X = [ones(n,1), z, z.^2];
else
    error('本程序只支持一次和二次模型。');
end

coef = X \ y;
yhat = X*coef;
residual = y-yhat;

SSE = sum(residual.^2);
SST = sum((y-mean(y)).^2);

if SST > 0
    R2 = 1-SSE/SST;
else
    R2 = NaN;
end

k = size(X,2);

if n > k && ~isnan(R2)
    adjR2 = 1-(1-R2)*(n-1)/(n-k);
else
    adjR2 = NaN;
end

RMSE = sqrt(mean(residual.^2));

stdResidual = standardize_residual(residual, X);
maxStdRes = max(abs(stdResidual));

LOOCV_RMSE = loocv_rmse(z, y, degree);

m.degree = degree;
m.coef = coef;
m.yhat = yhat;
m.residual = residual;
m.stdResidual = stdResidual;
m.maxStdRes = maxStdRes;
m.SSE = SSE;
m.R2 = R2;
m.adjR2 = adjR2;
m.RMSE = RMSE;
m.LOOCV_RMSE = LOOCV_RMSE;
end

%% ===== 留一交叉验证 =====
function cvRMSE = loocv_rmse(z, y, degree)
% 每次拿掉1个实验点，用其余n-1个点拟合，再预测被拿掉的点。
% 最终用所有留一预测误差计算RMSE。

n = numel(y);
pred = nan(n,1);

for i = 1:n
    keep = true(n,1);
    keep(i) = false;

    zTrain = z(keep);
    yTrain = y(keep);

    if degree == 1
        Xtrain = [ones(sum(keep),1), zTrain];
        xTest = [1, z(i)];
    else
        Xtrain = [ones(sum(keep),1), zTrain, zTrain.^2];
        xTest = [1, z(i), z(i)^2];
    end

    b = Xtrain \ yTrain;
    pred(i) = xTest*b;
end

cvRMSE = sqrt(mean((y-pred).^2));
end

%% ===== 标准化残差 =====
function r = standardize_residual(e, X)
n = numel(e);
k = size(X,2);

if n > k
    sigma = sqrt(sum(e.^2)/(n-k));
else
    sigma = sqrt(mean(e.^2));
end

if sigma > 0
    H = X * pinv(X'*X) * X';
    h = diag(H);
    denom = sigma .* sqrt(max(1-h, eps));
    r = e ./ denom;
else
    r = zeros(size(e));
end
end

%% ===== F分布CDF：不依赖Statistics Toolbox =====
function p = f_cdf(x, d1, d2)
if x < 0
    p = 0;
    return;
end
q = (d1*x)/(d1*x+d2);
p = betainc(q, d1/2, d2/2);
end

%% ===== 最终结果表一行 =====
function row = make_final_row(id, metric, fit)
s = fit.selected;

row = {id, metric, numel(s.yhat), fit.modelName, fit.eqn, fit.reason, ...
       s.R2, s.adjR2, s.RMSE, s.LOOCV_RMSE, s.SSE, ...
       fit.F, fit.pF, ...
       fit.linear.adjR2, fit.quadratic.adjR2, ...
       fit.linear.RMSE, fit.quadratic.RMSE, ...
       fit.linear.LOOCV_RMSE, fit.quadratic.LOOCV_RMSE, ...
       s.maxStdRes};
end

%% ===== 候选模型比较表一行 =====
function row = make_compare_row(id, metric, fit)
row = {id, metric, numel(fit.linear.yhat), ...
       fit.linear.R2, fit.linear.adjR2, fit.linear.RMSE, ...
       fit.linear.LOOCV_RMSE, fit.linear.maxStdRes, ...
       fit.quadratic.R2, fit.quadratic.adjR2, fit.quadratic.RMSE, ...
       fit.quadratic.LOOCV_RMSE, fit.quadratic.maxStdRes, ...
       fit.adjGain, fit.rmseImprove, fit.cvImprove, ...
       fit.pF, fit.modelName};
end

%% ===== 安全文件名 =====
function name = sanitize_filename(name)
name = regexprep(name, '[\\/:*?"<>|]', '_');
name = strtrim(name);
end

%% ===== 拟合图 =====
function plot_fit_panel(T, y, fit, yLabelText)
scatter(T, y, 48, 'filled'); hold on;

Tgrid = linspace(min(T), max(T), 200)';
zgrid = (Tgrid-350)/100;
coef = fit.selected.coef;

if fit.modelName == "一次多项式"
    ygrid = coef(1)+coef(2)*zgrid;
else
    ygrid = coef(1)+coef(2)*zgrid+coef(3)*zgrid.^2;
end

plot(Tgrid, ygrid, 'LineWidth',1.6);
grid on;
xlabel('温度 (℃)');
ylabel(yLabelText);
legend('实验数据', char(fit.modelName), 'Location','best');

txt = sprintf(['Adj R^2=%.4f\nRMSE=%.4f\nLOOCV=%.4f\n' ...
               'p_F=%.4g'], ...
    fit.selected.adjR2, fit.selected.RMSE, ...
    fit.selected.LOOCV_RMSE, fit.pF);

text(0.03,0.95,txt, ...
    'Units','normalized', ...
    'VerticalAlignment','top', ...
    'BackgroundColor','white', ...
    'Margin',4);
end
