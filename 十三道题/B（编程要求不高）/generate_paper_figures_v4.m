function generate_paper_figures_v4(file1, file2, regFile, outDir)
%GENERATE_PAPER_FIGURES_V4
% 根据第一问 V3 模型结果生成论文正文专用图片。
%
% 生成图片：
% Fig5_1_typical_scatter        典型催化剂原始散点图（A1、A2、A7、A8）
% Fig5_2_A7_A8_fitted_curves    A7、A8 温度响应拟合图
% Fig5_3_A8_A3_residuals        A8、A3 标准化残差对比图
% Fig5_4_stability_350C          350℃下转化率与选择性时间稳定性图
%
% 图片风格：正文型，不在图内堆叠大量统计量；统计结果放在正文或表格中。

if ~exist(outDir, 'dir')
    mkdir(outDir);
end

%% 0. 论文图统一风格
fontName = choose_chinese_font();
convColor = [0.24 0.43 0.62];    % 稳重蓝：乙醇转化率
selColor  = [0.73 0.38 0.20];    % 暖棕橙：C4选择性
fitColor  = [0.18 0.18 0.18];    % 拟合曲线辅助色
resColor1 = [0.28 0.48 0.65];
resColor2 = [0.72 0.42 0.28];

%% 1. 读取附件1并整理数据
T1 = readtable(file1, 'VariableNamingRule', 'preserve');
varNames = string(T1.Properties.VariableNames);

idCol   = find(contains(varNames, "催化剂组合编号"), 1);
tempCol = find(varNames == "温度" | contains(varNames, "温度"), 1);
convCol = find(contains(varNames, "乙醇转化率"), 1);
c4Col   = find(contains(varNames, "C4烯烃选择性"), 1);

assert(~isempty(idCol) && ~isempty(tempCol) && ~isempty(convCol) && ~isempty(c4Col), ...
    '附件1表头与程序预期不一致。');

catalystID = string(T1{:, idCol});
temp  = column_to_double(T1{:, tempCol});
conv  = column_to_double(T1{:, convCol});
c4sel = column_to_double(T1{:, c4Col});

catalystID = filldown_string(catalystID);
valid = ~ismissing(catalystID) & strlength(strtrim(catalystID)) > 0 & ...
        ~isnan(temp) & ~isnan(conv) & ~isnan(c4sel);

catalystID = strtrim(catalystID(valid));
temp  = temp(valid);
conv  = conv(valid);
c4sel = c4sel(valid);

%% 2. 读取 V3 最终模型表
finalTable = readtable(regFile, 'Sheet', '最终模型', ...
    'VariableNamingRule', 'preserve');

%% 3. 图5-1：典型组合的原始散点图
% 用 A1、A2 展示模型选型差异，用 A7、A8 展示较典型的温度响应。
typicalIDs = ["A1", "A2", "A7", "A8"];

f1 = figure('Color','w', 'Position',[100 100 1040 700]);
tl = tiledlayout(f1, 2, 2, 'TileSpacing','compact', 'Padding','compact');

for k = 1:numel(typicalIDs)
    id = typicalIDs(k);
    idx = catalystID == id;
    [T, order] = sort(temp(idx));
    X = conv(idx);   X = X(order);
    S = c4sel(idx);  S = S(order);

    ax = nexttile(tl);
    hold(ax,'on');
    h1 = scatter(ax, T, X, 45, 'o', 'filled', ...
        'MarkerFaceColor',convColor, 'MarkerEdgeColor','w', 'LineWidth',0.7);
    h2 = scatter(ax, T, S, 50, 's', 'filled', ...
        'MarkerFaceColor',selColor, 'MarkerEdgeColor','w', 'LineWidth',0.7);

    style_axes(ax, fontName);
    xlabel(ax, '温度 / ℃');
    ylabel(ax, '响应值 / %');
    title(ax, sprintf('(%c) %s', char('a'+k-1), char(id)), ...
        'FontWeight','normal');

    if k == 1
        lgd = legend(ax, [h1 h2], {'乙醇转化率','C4烯烃选择性'}, ...
            'Location','northwest', 'Box','off');
        lgd.FontName = fontName;
        lgd.FontSize = 9.5;
    end
end

save_figure_pair(f1, outDir, 'Fig5_1_typical_scatter');
close(f1);

%% 4. 图5-2：A7、A8 最终模型拟合曲线
plotCases = { ...
    "A7", "乙醇转化率"; ...
    "A7", "C4烯烃选择性"; ...
    "A8", "乙醇转化率"; ...
    "A8", "C4烯烃选择性"};

f2 = figure('Color','w', 'Position',[100 100 1040 700]);
tl = tiledlayout(f2, 2, 2, 'TileSpacing','compact', 'Padding','compact');

for k = 1:size(plotCases,1)
    id = plotCases{k,1};
    metric = plotCases{k,2};
    [T, y, model] = selected_model_data( ...
        catalystID, temp, conv, c4sel, finalTable, id, metric);

    ax = nexttile(tl);
    hold(ax,'on');

    if metric == "乙醇转化率"
        thisColor = convColor;
    else
        thisColor = selColor;
    end

    scatter(ax, T, y, 48, 'o', 'filled', ...
        'MarkerFaceColor',thisColor, 'MarkerEdgeColor','w', 'LineWidth',0.7);

    Tgrid = linspace(min(T), max(T), 250)';
    zgrid = (Tgrid - 350)/100;
    ygrid = evaluate_model(model.coef, zgrid);
    plot(ax, Tgrid, ygrid, '-', 'Color',thisColor, 'LineWidth',1.8);

    style_axes(ax, fontName);
    xlabel(ax, '温度 / ℃');
    ylabel(ax, [char(metric), ' / %']);
    title(ax, sprintf('(%c) %s  %s', ...
        char('a'+k-1), char(id), char(metric)), 'FontWeight','normal');

    lgd = legend(ax, {'实验值','拟合曲线'}, ...
        'Location','northwest', 'Box','off');
    lgd.FontName = fontName;
    lgd.FontSize = 9;
end

save_figure_pair(f2, outDir, 'Fig5_2_A7_A8_fitted_curves');
close(f2);

%% 5. 图5-3：A8 与 A3 的标准化残差图
resCases = { ...
    "A8", "乙醇转化率"; ...
    "A8", "C4烯烃选择性"; ...
    "A3", "乙醇转化率"; ...
    "A3", "C4烯烃选择性"};

f3 = figure('Color','w', 'Position',[100 100 1040 700]);
tl = tiledlayout(f3, 2, 2, 'TileSpacing','compact', 'Padding','compact');

for k = 1:size(resCases,1)
    id = resCases{k,1};
    metric = resCases{k,2};
    [T, ~, model] = selected_model_data( ...
        catalystID, temp, conv, c4sel, finalTable, id, metric);

    ax = nexttile(tl);
    hold(ax,'on');

    if id == "A8"
        thisColor = resColor1;
    else
        thisColor = resColor2;
    end

    scatter(ax, T, model.stdResidual, 48, 'filled', ...
        'MarkerFaceColor',thisColor, 'MarkerEdgeColor','w', 'LineWidth',0.7);
    yline(ax, 0, '-', 'Color',[0.25 0.25 0.25], 'LineWidth',0.9);
    yline(ax, 2, '--', 'Color',[0.55 0.55 0.55], 'LineWidth',0.9);
    yline(ax, -2, '--', 'Color',[0.55 0.55 0.55], 'LineWidth',0.9);

    style_axes(ax, fontName);
    xlabel(ax, '温度 / ℃');
    ylabel(ax, '标准化残差');
    ylim(ax, [-2.6 2.6]);
    title(ax, sprintf('(%c) %s  %s', ...
        char('a'+k-1), char(id), char(metric)), 'FontWeight','normal');
end

save_figure_pair(f3, outDir, 'Fig5_3_A8_A3_residuals');
close(f3);

%% 6. 读取附件2：350℃稳定性数据
raw2 = readcell(file2);
timeMin = cell_column_to_double(raw2(:,1));
conv2   = cell_column_to_double(raw2(:,2));
c4sel2  = cell_column_to_double(raw2(:,4));

valid2 = ~isnan(timeMin) & ~isnan(conv2) & ~isnan(c4sel2);
timeMin = timeMin(valid2);
conv2   = conv2(valid2);
c4sel2  = c4sel2(valid2);

%% 7. 图5-4：350℃时间稳定性正文图（只保留题目直接要求的两个指标）
f4 = figure('Color','w', 'Position',[100 100 1040 430]);
tl = tiledlayout(f4, 1, 2, 'TileSpacing','compact', 'Padding','compact');

% (a) 乙醇转化率
ax = nexttile(tl);
hold(ax,'on');
[bX, ~] = linear_fit(timeMin, conv2);
tgrid = linspace(min(timeMin), max(timeMin), 250)';
scatter(ax, timeMin, conv2, 52, 'o', 'filled', ...
    'MarkerFaceColor',convColor, 'MarkerEdgeColor','w', 'LineWidth',0.7);
plot(ax, tgrid, bX(1)+bX(2)*tgrid, '-', ...
    'Color',convColor, 'LineWidth',1.8);
style_axes(ax, fontName);
xlabel(ax, '反应时间 / min');
ylabel(ax, '乙醇转化率 / %');
title(ax, '(a) 乙醇转化率', 'FontWeight','normal');
lgd = legend(ax, {'实验值','线性拟合'}, 'Location','northeast', 'Box','off');
lgd.FontName = fontName;
lgd.FontSize = 9;

% (b) C4烯烃选择性
ax = nexttile(tl);
hold(ax,'on');
[bS, ~] = linear_fit(timeMin, c4sel2);
scatter(ax, timeMin, c4sel2, 52, 's', 'filled', ...
    'MarkerFaceColor',selColor, 'MarkerEdgeColor','w', 'LineWidth',0.7);
plot(ax, tgrid, bS(1)+bS(2)*tgrid, '-', ...
    'Color',selColor, 'LineWidth',1.8);
style_axes(ax, fontName);
xlabel(ax, '反应时间 / min');
ylabel(ax, 'C4烯烃选择性 / %');
title(ax, '(b) C4烯烃选择性', 'FontWeight','normal');
lgd = legend(ax, {'实验值','线性拟合'}, 'Location','best', 'Box','off');
lgd.FontName = fontName;
lgd.FontSize = 9;

save_figure_pair(f4, outDir, 'Fig5_4_stability_350C');
close(f4);

%% 8. 可选图：C4烯烃收率随时间变化
% 正文不一定需要，但为 5.2.1 的辅助分析单独生成，是否放论文由排版决定。
c4yield = conv2 .* c4sel2 / 100;
[bY, ~] = linear_fit(timeMin, c4yield);

f5 = figure('Color','w', 'Position',[100 100 620 430]);
ax = axes(f5);
hold(ax,'on');
scatter(ax, timeMin, c4yield, 52, 'o', 'filled', ...
    'MarkerFaceColor',[0.38 0.50 0.36], 'MarkerEdgeColor','w', 'LineWidth',0.7);
plot(ax, tgrid, bY(1)+bY(2)*tgrid, '-', ...
    'Color',[0.38 0.50 0.36], 'LineWidth',1.8);
style_axes(ax, fontName);
xlabel(ax, '反应时间 / min');
ylabel(ax, 'C4烯烃收率 / %');
legend(ax, {'实验值','线性拟合'}, 'Location','northeast', 'Box','off');

save_figure_pair(f5, outDir, 'Fig5_5_C4_yield_optional');
close(f5);

fprintf('已生成论文图片：\n');
fprintf('  Fig5_1_typical_scatter\n');
fprintf('  Fig5_2_A7_A8_fitted_curves\n');
fprintf('  Fig5_3_A8_A3_residuals\n');
fprintf('  Fig5_4_stability_350C\n');
fprintf('  Fig5_5_C4_yield_optional（可选）\n');
end

%% =========================================================
%% 辅助函数
%% =========================================================
function [T, y, model] = selected_model_data(catalystID, temp, conv, c4sel, finalTable, id, metric)
idx = catalystID == id;
T = temp(idx);

if metric == "乙醇转化率"
    y = conv(idx);
else
    y = c4sel(idx);
end

[T, order] = sort(T);
y = y(order);
z = (T - 350)/100;

rowMask = string(finalTable.("催化剂编号")) == id & ...
          string(finalTable.("指标")) == metric;
row = finalTable(rowMask,:);
assert(height(row) == 1, '无法唯一找到 %s-%s 的最终模型。', char(id), char(metric));

modelName = string(row.("最终模型")(1));
if contains(modelName, "二次")
    degree = 2;
else
    degree = 1;
end

model = fit_degree(z, y, degree);
model.modelName = modelName;
end

function model = fit_degree(z, y, degree)
z = z(:);
y = y(:);
n = numel(y);

if degree == 1
    X = [ones(n,1), z];
else
    X = [ones(n,1), z, z.^2];
end

coef = X \ y;
yhat = X*coef;
e = y-yhat;

k = size(X,2);
if n > k
    sigma = sqrt(sum(e.^2)/(n-k));
else
    sigma = sqrt(mean(e.^2));
end

if sigma > 0
    H = X * pinv(X'*X) * X';
    h = diag(H);
    stdResidual = e ./ (sigma .* sqrt(max(1-h, eps)));
else
    stdResidual = zeros(size(e));
end

model.coef = coef;
model.yhat = yhat;
model.residual = e;
model.stdResidual = stdResidual;
end

function y = evaluate_model(coef, z)
if numel(coef) == 2
    y = coef(1) + coef(2)*z;
else
    y = coef(1) + coef(2)*z + coef(3)*z.^2;
end
end

function [b, yhat] = linear_fit(t, y)
t = t(:);
y = y(:);
X = [ones(numel(t),1), t];
b = X \ y;
yhat = X*b;
end

function style_axes(ax, fontName)
set(ax, ...
    'FontName',fontName, ...
    'FontSize',10.5, ...
    'LineWidth',0.8, ...
    'Box','on', ...
    'TickDir','out', ...
    'Layer','top');
grid(ax,'on');
ax.GridAlpha = 0.13;
ax.MinorGridAlpha = 0.08;
end

function save_figure_pair(fig, outDir, baseName)
% PNG用于Word/预览，PDF为矢量图，适合最终排版。
pngFile = fullfile(outDir, [baseName, '.png']);
pdfFile = fullfile(outDir, [baseName, '.pdf']);
exportgraphics(fig, pngFile, 'Resolution',300);
exportgraphics(fig, pdfFile, 'ContentType','vector');
end

function fontName = choose_chinese_font()
% 优先使用 Windows 常见中文字体；找不到时使用 MATLAB 默认字体。
fontName = 'Microsoft YaHei';
try
    fonts = string(listfonts);
    if any(fonts == "Microsoft YaHei")
        fontName = 'Microsoft YaHei';
    elseif any(fonts == "SimSun")
        fontName = 'SimSun';
    elseif any(fonts == "SimHei")
        fontName = 'SimHei';
    else
        fontName = char(fonts(1));
    end
catch
    % 某些版本不支持 listfonts 时，Windows 上通常仍可直接使用微软雅黑。
end
end

function s = filldown_string(s)
s = string(s);
for i = 1:numel(s)
    if i > 1 && (ismissing(s(i)) || strlength(strtrim(s(i))) == 0)
        s(i) = s(i-1);
    end
end
end

function x = column_to_double(v)
if isnumeric(v)
    x = double(v);
    x = x(:);
    return;
end

if iscell(v)
    x = nan(numel(v),1);
    for i = 1:numel(v)
        if isnumeric(v{i}) && isscalar(v{i})
            x(i) = double(v{i});
        else
            x(i) = str2double(string(v{i}));
        end
    end
    return;
end

x = str2double(string(v));
x = x(:);
end

function x = cell_column_to_double(c)
x = nan(size(c,1),1);
for i = 1:size(c,1)
    v = c{i};
    if isnumeric(v) && isscalar(v)
        x(i) = double(v);
    else
        x(i) = str2double(string(v));
    end
end
end
