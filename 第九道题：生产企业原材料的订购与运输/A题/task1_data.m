%% 问题一：供应商供货特征指标计算（定稿修正版）
% 说明：
% 本程序完成附件1的数据读取、六项指标提取、描述性统计和相关性检验。
% 暂不进行CRITIC赋权和TOPSIS排序。
%
% 六项最终指标：
% 1. 有效供货周平均产能贡献量（正向）
% 2. 累计供货率（正向）
% 3. 订货完成率（正向）
% 4. 供货稳定性标准差（负向）
% 5. 供货周覆盖率（正向）
% 6. 年度供货覆盖率（正向）
%
% 特别说明：
% 供货稳定性采用"有订货周内逐周供货率的总体标准差"衡量。
% 逐周供货率 = 当周供货量 / 当周订货量。
% 这样既能反映断供造成的波动，也不会出现四分位距在大量0值下
% 错误等于0、把低履约供应商判断为"最稳定"的问题。

clear;
clc;
close all;

%% 1. 文件设置
inputFile = '附件1 近5年402家供应商的相关数据(2).xlsx';
outputFile = '问题一_定稿供应商初步指标.xlsx';
figureFile = '问题一_定稿指标相关性热力图.png';

orderSheet = '企业的订货量（m³）';
supplySheet = '供应商的供货量（m³）';

% 默认文件名不存在时，自动查找附件1
if ~isfile(inputFile)
    candidateFiles = dir('附件1*供应商*.xlsx');

    if numel(candidateFiles) == 1
        inputFile = candidateFiles(1).name;
        fprintf('未找到默认文件名，已自动使用：%s\n', inputFile);
    elseif isempty(candidateFiles)
        error('未找到附件1。请将程序与附件1 Excel文件放在同一文件夹。');
    else
        error('当前文件夹存在多个可能的附件1文件，请在代码开头指定正确的inputFile。');
    end
end

%% 2. 读取两个工作表
orderCell = readcell(inputFile, 'Sheet', orderSheet);
supplyCell = readcell(inputFile, 'Sheet', supplySheet);

if size(orderCell,2) < 3 || size(supplyCell,2) < 3
    error('工作表列数异常，未读取到完整的供应商和周数据。');
end

% 删除供应商编号为空的尾部空白行
orderIDAll = strtrim(string(orderCell(2:end,1)));
supplyIDAll = strtrim(string(supplyCell(2:end,1)));

orderValidRow = strlength(orderIDAll) > 0 & ~ismissing(orderIDAll);
supplyValidRow = strlength(supplyIDAll) > 0 & ~ismissing(supplyIDAll);

orderCell = [orderCell(1,:); orderCell(find(orderValidRow)+1,:)];
supplyCell = [supplyCell(1,:); supplyCell(find(supplyValidRow)+1,:)];

%% 3. 提取供应商信息并对齐两张表
supplierID = strtrim(string(orderCell(2:end,1)));
materialType = upper(strtrim(string(orderCell(2:end,2))));

supplyID = strtrim(string(supplyCell(2:end,1)));
supplyMaterialType = upper(strtrim(string(supplyCell(2:end,2))));

if numel(unique(supplierID)) ~= numel(supplierID)
    error('订货量工作表中存在重复的供应商编号。');
end

if numel(unique(supplyID)) ~= numel(supplyID)
    error('供货量工作表中存在重复的供应商编号。');
end

% 按订货量表中的供应商顺序排列供货量表
[isFound, supplyLocation] = ismember(supplierID, supplyID);

if any(~isFound)
    missingSupplier = strjoin(cellstr(supplierID(~isFound)), '、');
    error('供货量表中缺少以下供应商：%s', missingSupplier);
end

supplyCell = [supplyCell(1,:); supplyCell(supplyLocation+1,:)];
supplyMaterialType = supplyMaterialType(supplyLocation);

if any(materialType ~= supplyMaterialType)
    error('同一供应商在订货量表和供货量表中的材料类别不一致。');
end

%% 4. 转换订货量和供货量为数值矩阵
orderData = localCellBlockToDouble(orderCell(2:end,3:end), '订货量');
supplyData = localCellBlockToDouble(supplyCell(2:end,3:end), '供货量');

[nSuppliers, nWeeks] = size(orderData);

if ~isequal(size(orderData), size(supplyData))
    error('订货量矩阵与供货量矩阵的维度不一致。');
end

if any(orderData(:) < 0) || any(supplyData(:) < 0)
    error('原始数据中存在负数订货量或供货量。');
end

if nSuppliers ~= 402
    warning('读取到%d家供应商，题目理论值为402家。', nSuppliers);
end

if nWeeks ~= 240
    error('读取到%d周数据，本题应为240周，无法按5个年度计算。', nWeeks);
end

validType = materialType == "A" | materialType == "B" | materialType == "C";

if any(~validType)
    wrongType = unique(materialType(~validType));
    error('存在无法识别的材料类别：%s', strjoin(cellstr(wrongType), '、'));
end

%% 5. 三类原材料换算为统一的产能当量
% 每生产1立方米产品所需原材料：
% A类0.60立方米，B类0.66立方米，C类0.72立方米。
conversionFactor = zeros(nSuppliers,1);
conversionFactor(materialType == "A") = 1 / 0.60;
conversionFactor(materialType == "B") = 1 / 0.66;
conversionFactor(materialType == "C") = 1 / 0.72;

capacityEquivalent = bsxfun(@times, supplyData, conversionFactor);

%% 6. 基础统计
orderedMask = orderData > 0;
suppliedMask = supplyData > 0;

totalOrder = sum(orderData,2);
totalSupply = sum(supplyData,2);
orderWeeks = sum(orderedMask,2);
supplyWeeks = sum(suppliedMask,2);
completedOrderWeeks = sum(orderedMask & suppliedMask,2);

if any(totalOrder <= 0)
    error('存在累计订货量为0的供应商，无法计算累计供货率。');
end

if any(orderWeeks <= 0)
    error('存在订货周数为0的供应商，无法计算订货完成率。');
end

if any(supplyWeeks <= 0)
    error('存在从未实际供货的供应商，无法计算有效供货周平均产能贡献量。');
end

%% 7. 计算六项最终指标
% 指标1：有效供货周平均产能贡献量
% 先求原始产能当量均值，再使用ln(1+x)降低极端值影响。
activeWeekAverageCapacityRaw = zeros(nSuppliers,1);

% 指标2：累计供货率
cumulativeSupplyRate = totalSupply ./ totalOrder;

% 指标3：订货完成率
% 有订货周中，实际供货量大于0的周数占比。
orderCompletionRate = completedOrderWeeks ./ orderWeeks;

% 指标4：供货稳定性标准差（负向）
% 在所有有订货周内计算逐周供货率的总体标准差。
supplyStabilityStd = zeros(nSuppliers,1);

% 指标5：供货周覆盖率
supplyWeekCoverage = supplyWeeks / nWeeks;

% 指标6：年度供货覆盖率
yearSupplyCount = zeros(nSuppliers,1);
annualSupplyCoverage = zeros(nSuppliers,1);
annualSupplyFlag = zeros(nSuppliers,5);

% 辅助统计
weeklySupplyRateMean = zeros(nSuppliers,1);
weeklySupplyRateMedian = zeros(nSuppliers,1);
weeklySupplyRateMin = zeros(nSuppliers,1);
weeklySupplyRateMax = zeros(nSuppliers,1);

for i = 1:nSuppliers
    % 实际供货周内的平均产能贡献量
    activeCapacity = capacityEquivalent(i, suppliedMask(i,:));
    activeWeekAverageCapacityRaw(i) = mean(activeCapacity);

    % 有订货周内的逐周供货率
    weeklyRate = supplyData(i, orderedMask(i,:)) ./ ...
                 orderData(i, orderedMask(i,:));

    weeklySupplyRateMean(i) = mean(weeklyRate);
    weeklySupplyRateMedian(i) = median(weeklyRate);
    weeklySupplyRateMin(i) = min(weeklyRate);
    weeklySupplyRateMax(i) = max(weeklyRate);

    % 使用总体标准差，除数为订货周数n
    supplyStabilityStd(i) = std(weeklyRate,1);

    % 每48周划分为一个年度
    for y = 1:5
        weekIndex = (y-1)*48 + (1:48);
        annualSupplyFlag(i,y) = any(supplyData(i,weekIndex) > 0);
    end

    yearSupplyCount(i) = sum(annualSupplyFlag(i,:));
    annualSupplyCoverage(i) = yearSupplyCount(i) / 5;
end

activeWeekAverageCapacityModel = log(1 + activeWeekAverageCapacityRaw);

%% 8. 最终指标矩阵
X = [ ...
    activeWeekAverageCapacityModel, ...
    cumulativeSupplyRate, ...
    orderCompletionRate, ...
    supplyStabilityStd, ...
    supplyWeekCoverage, ...
    annualSupplyCoverage];

indicatorNames = { ...
    '有效供货周平均产能贡献量'; ...
    '累计供货率'; ...
    '订货完成率'; ...
    '供货稳定性标准差'; ...
    '供货周覆盖率'; ...
    '年度供货覆盖率'};

indicatorDirections = { ...
    '正向'; ...
    '正向'; ...
    '正向'; ...
    '负向'; ...
    '正向'; ...
    '正向'};

if any(~isfinite(X(:)))
    error('最终指标矩阵中存在NaN或无穷值，请检查数据与计算过程。');
end

%% 9. 描述性统计
nIndicators = size(X,2);

validCount = zeros(nIndicators,1);
meanValue = zeros(nIndicators,1);
stdValue = zeros(nIndicators,1);
minValue = zeros(nIndicators,1);
medianValue = zeros(nIndicators,1);
maxValue = zeros(nIndicators,1);

for j = 1:nIndicators
    values = X(:,j);

    validCount(j) = sum(isfinite(values));
    meanValue(j) = mean(values);
    stdValue(j) = std(values,1);
    minValue(j) = min(values);
    medianValue(j) = median(values);
    maxValue(j) = max(values);
end

descriptionTable = table( ...
    string(indicatorNames), string(indicatorDirections), validCount, ...
    meanValue, stdValue, minValue, medianValue, maxValue, ...
    'VariableNames', { ...
    '指标名称','指标方向','有效样本数', ...
    '均值','标准差','最小值','中位数','最大值'});

%% 10. 相关性分析
correlationMatrix = corrcoef(X);

correlationTable = array2table(correlationMatrix, ...
    'VariableNames', indicatorNames);

correlationTable = addvars(correlationTable, string(indicatorNames), ...
    'Before',1,'NewVariableNames','指标名称');

% 高相关指标检查
highCorrelationRows = {};
rowNumber = 0;

for j = 1:nIndicators-1
    for k = j+1:nIndicators
        r = correlationMatrix(j,k);

        if abs(r) >= 0.80
            rowNumber = rowNumber + 1;
            highCorrelationRows(rowNumber,:) = { ...
                indicatorNames{j}, indicatorNames{k}, r, abs(r)};
        end
    end
end

if isempty(highCorrelationRows)
    highCorrelationTable = table( ...
        "无","无",NaN,NaN, ...
        'VariableNames',{'指标一','指标二','相关系数','相关系数绝对值'});
else
    highCorrelationTable = cell2table(highCorrelationRows, ...
        'VariableNames',{'指标一','指标二','相关系数','相关系数绝对值'});
end

%% 11. 组织中文输出表
finalIndicatorTable = table( ...
    supplierID, materialType, ...
    activeWeekAverageCapacityModel, ...
    cumulativeSupplyRate, ...
    orderCompletionRate, ...
    supplyStabilityStd, ...
    supplyWeekCoverage, ...
    annualSupplyCoverage, ...
    'VariableNames', { ...
    '供应商编号','材料类别', ...
    '有效供货周平均产能贡献量', ...
    '累计供货率', ...
    '订货完成率', ...
    '供货稳定性标准差', ...
    '供货周覆盖率', ...
    '年度供货覆盖率'});

rawAndAuxiliaryTable = table( ...
    supplierID, materialType, ...
    totalOrder, totalSupply, ...
    orderWeeks, completedOrderWeeks, supplyWeeks, ...
    activeWeekAverageCapacityRaw, ...
    activeWeekAverageCapacityModel, ...
    weeklySupplyRateMean, weeklySupplyRateMedian, ...
    weeklySupplyRateMin, weeklySupplyRateMax, ...
    supplyStabilityStd, yearSupplyCount, ...
    'VariableNames', { ...
    '供应商编号','材料类别', ...
    '累计订货量','累计供货量', ...
    '订货周数','完成订货周数','实际供货周数', ...
    '有效供货周平均产能贡献量原始值', ...
    '有效供货周平均产能贡献量模型值', ...
    '逐周供货率均值','逐周供货率中位数', ...
    '逐周供货率最小值','逐周供货率最大值', ...
    '供货稳定性标准差','发生供货的年度数'});

annualTable = table( ...
    supplierID, materialType, ...
    annualSupplyFlag(:,1), annualSupplyFlag(:,2), ...
    annualSupplyFlag(:,3), annualSupplyFlag(:,4), ...
    annualSupplyFlag(:,5), ...
    yearSupplyCount, annualSupplyCoverage, ...
    'VariableNames', { ...
    '供应商编号','材料类别', ...
    '第1年是否供货','第2年是否供货','第3年是否供货', ...
    '第4年是否供货','第5年是否供货', ...
    '发生供货的年度数','年度供货覆盖率'});

indicatorExplanation = { ...
    '有效供货周平均产能贡献量','正向', ...
    '实际供货周内，供货量按A、B、C类消耗系数换算后的平均可支持产量；模型中使用ln(1+x)', ...
    '反映供应商实际供货时的典型供货能力，供货频率由覆盖率另行反映'; ...
    '累计供货率','正向', ...
    '240周累计供货量除以240周累计订货量', ...
    '反映供应商总体供货数量相对于企业订货数量的满足程度'; ...
    '订货完成率','正向', ...
    '有订货的周中，实际供货量大于0的周数除以订货周数', ...
    '反映供应商收到订单后实际作出供货响应的频率'; ...
    '供货稳定性标准差','负向', ...
    '有订货周内逐周供货率的总体标准差，其中逐周供货率等于当周供货量除以当周订货量', ...
    '反映供应商相对于订单的供货比例波动，数值越小越稳定'; ...
    '供货周覆盖率','正向', ...
    '实际供货周数除以全部240周', ...
    '反映供应商在整个历史期内参与供货的频繁程度'; ...
    '年度供货覆盖率','正向', ...
    '近5年中发生过实际供货的年度数除以5', ...
    '反映供应商跨年度持续参与供货的长期连续性'};

indicatorExplanationTable = cell2table(indicatorExplanation, ...
    'VariableNames',{'指标名称','指标方向','计算方法','指标含义'});

offDiagonalCorrelation = abs(correlationMatrix - eye(nIndicators));
maximumAbsoluteCorrelation = max(offDiagonalCorrelation(:));

dataCheckTable = table( ...
    ["供应商数量";"历史周数";"A类供应商数量";"B类供应商数量"; ...
     "C类供应商数量";"累计订货量";"累计供货量"; ...
     "没有订货记录的供应商数量";"没有供货记录的供应商数量"; ...
     "供货稳定性标准差为0的供应商数量"; ...
     "最大指标相关系数绝对值"], ...
    [nSuppliers;nWeeks;sum(materialType=="A");sum(materialType=="B"); ...
     sum(materialType=="C");sum(totalOrder);sum(totalSupply); ...
     sum(orderWeeks==0);sum(supplyWeeks==0); ...
     sum(supplyStabilityStd==0);maximumAbsoluteCorrelation], ...
    'VariableNames',{'检查项目','检查结果'});

%% 12. 写入Excel
if isfile(outputFile)
    delete(outputFile);
end

writetable(finalIndicatorTable, outputFile, 'Sheet','最终六项指标');
writetable(rawAndAuxiliaryTable, outputFile, 'Sheet','原始值与辅助统计');
writetable(descriptionTable, outputFile, 'Sheet','描述性统计');
writetable(correlationTable, outputFile, 'Sheet','指标相关性');
writetable(highCorrelationTable, outputFile, 'Sheet','高相关指标检查');
writetable(annualTable, outputFile, 'Sheet','分年度供货情况');
writetable(indicatorExplanationTable, outputFile, 'Sheet','指标说明');
writetable(dataCheckTable, outputFile, 'Sheet','数据核验');

%% 13. 绘制中文相关性热力图
shortNames = { ...
    '有效周平均产能', ...
    '累计供货率', ...
    '订货完成率', ...
    '供货稳定性标准差', ...
    '供货周覆盖率', ...
    '年度供货覆盖率'};

fig = figure('Color','w','Position',[100,100,1050,820]);
ax = axes(fig);

imagesc(ax, correlationMatrix, [-1,1]);
axis(ax,'square');
colormap(ax,parula);
colorbar(ax);

set(ax, ...
    'XTick',1:nIndicators, ...
    'YTick',1:nIndicators, ...
    'XTickLabel',shortNames, ...
    'YTickLabel',shortNames, ...
    'XTickLabelRotation',35, ...
    'FontSize',11);

title(ax,'最终六项供应商供货特征指标的皮尔逊相关系数', ...
    'FontSize',15);

for r = 1:nIndicators
    for c = 1:nIndicators
        value = correlationMatrix(r,c);

        if abs(value) >= 0.55
            textColor = 'w';
        else
            textColor = 'k';
        end

        text(ax,c,r,sprintf('%.2f',value), ...
            'HorizontalAlignment','center', ...
            'VerticalAlignment','middle', ...
            'FontWeight','bold', ...
            'FontSize',11, ...
            'Color',textColor);
    end
end

% 关闭坐标区工具栏，避免导出的图片带有右上角工具按钮
try
    if ~isempty(ax.Toolbar)
        ax.Toolbar.Visible = 'off';
    end
catch
end

try
    disableDefaultInteractivity(ax);
catch
end

drawnow;

try
    exportgraphics(fig, figureFile, 'Resolution',300);
catch
    print(fig, figureFile, '-dpng', '-r300');
end

%% 14. 命令行中文输出
fprintf('\n================ 数据读取与核验 ================\n');
fprintf('使用文件：%s\n', inputFile);
fprintf('供应商数量：%d家\n', nSuppliers);
fprintf('历史周数：%d周\n', nWeeks);
fprintf('A类供应商：%d家\n', sum(materialType=="A"));
fprintf('B类供应商：%d家\n', sum(materialType=="B"));
fprintf('C类供应商：%d家\n', sum(materialType=="C"));
fprintf('累计订货量：%.2f立方米\n', sum(totalOrder));
fprintf('累计供货量：%.2f立方米\n', sum(totalSupply));
fprintf('没有订货记录的供应商：%d家\n', sum(orderWeeks==0));
fprintf('没有供货记录的供应商：%d家\n', sum(supplyWeeks==0));
fprintf('供货稳定性标准差为0的供应商：%d家\n', ...
    sum(supplyStabilityStd==0));

fprintf('\n================ 最终六项指标说明 ================\n');
disp(indicatorExplanationTable);

fprintf('\n================ 描述性统计 ================\n');
disp(descriptionTable);

fprintf('\n================ 指标相关系数矩阵 ================\n');
disp(correlationTable);

fprintf('\n================ 高相关指标检查 ================\n');
if isempty(highCorrelationRows)
    fprintf('未发现绝对相关系数达到0.80的指标对。\n');
else
    disp(highCorrelationTable);
end

fprintf('\n计算完成。\n');
fprintf('Excel结果：%s\n', outputFile);
fprintf('相关性热力图：%s\n', figureFile);
fprintf('本程序尚未进行CRITIC赋权和TOPSIS排名。\n');

%% 局部函数：将混合单元格区域转换为数值矩阵
function numericMatrix = localCellBlockToDouble(cellBlock, blockName)
    numericMatrix = zeros(size(cellBlock));

    for index = 1:numel(cellBlock)
        value = cellBlock{index};

        if isempty(value)
            numericMatrix(index) = 0;

        elseif isnumeric(value)
            if isnan(value)
                numericMatrix(index) = 0;
            else
                numericMatrix(index) = double(value);
            end

        elseif islogical(value)
            numericMatrix(index) = double(value);

        else
            textValue = strtrim(string(value));

            if ismissing(textValue) || strlength(textValue)==0
                numericMatrix(index) = 0;
            else
                convertedValue = str2double(textValue);

                if isnan(convertedValue)
                    error('%s数据中存在无法转换为数值的内容：%s', ...
                        blockName,textValue);
                end

                numericMatrix(index) = convertedValue;
            end
        end
    end
end
