%% 问题一：基于产能当量换算的CRITIC-TOPSIS供应商综合评价
% 功能：
% 1. 读取已经核验通过的六项供应商评价指标；
% 2. 对负向指标进行正向化，并完成极差标准化；
% 3. 采用CRITIC法计算客观权重；
% 4. 采用TOPSIS法计算402家供应商的综合重要度；
% 5. 输出全部供应商排名及最重要的50家供应商；
% 6. 输出中文Excel结果及必要图像。
%
% 输入文件：
% 问题一_定稿供应商初步指标.xlsx
%
% 输入工作表：
% 最终六项指标
%
% 输出文件：
% 问题一_CRITIC_TOPSIS供应商综合评价结果.xlsx
% 问题一_CRITIC指标权重图.png
% 问题一_前50家供应商综合得分图.png

clear;
clc;
close all;

%% 1. 文件设置
inputFile = '问题一_定稿供应商初步指标.xlsx';
inputSheet = '最终六项指标';

outputFile = '问题一_CRITIC_TOPSIS供应商综合评价结果.xlsx';
weightFigureFile = '问题一_CRITIC指标权重图.png';
top50FigureFile = '问题一_前50家供应商综合得分图.png';

% 默认文件不存在时自动查找
if ~isfile(inputFile)
    candidateFiles = dir('问题一_定稿供应商初步指标*.xlsx');

    if numel(candidateFiles) == 1
        inputFile = candidateFiles(1).name;
        fprintf('未找到默认文件名，已自动使用：%s\n', inputFile);
    elseif isempty(candidateFiles)
        error('未找到"问题一_定稿供应商初步指标.xlsx"。请将本程序与该文件放在同一文件夹。');
    else
        error('当前文件夹存在多个候选指标文件，请在程序开头指定正确的inputFile。');
    end
end

%% 2. 读取已经核验通过的六项指标
rawCell = readcell(inputFile, 'Sheet', inputSheet);

if size(rawCell,1) < 2 || size(rawCell,2) < 8
    error('输入工作表结构不完整，应至少包含8列：供应商编号、材料类别和六项指标。');
end

supplierID = strtrim(string(rawCell(2:end,1)));
materialType = upper(strtrim(string(rawCell(2:end,2))));

validRow = strlength(supplierID) > 0 & ~ismissing(supplierID);
supplierID = supplierID(validRow);
materialType = materialType(validRow);

indicatorData = localCellBlockToDouble( ...
    rawCell(find(validRow)+1,3:8), '供应商评价指标');

[nSuppliers,nIndicators] = size(indicatorData);

if nSuppliers ~= 402
    warning('当前读取到%d家供应商，题目理论值为402家。', nSuppliers);
end

if nIndicators ~= 6
    error('当前读取到%d项指标，本模型要求6项指标。', nIndicators);
end

if numel(unique(supplierID)) ~= nSuppliers
    error('输入数据中存在重复的供应商编号。');
end

validType = materialType=="A" | materialType=="B" | materialType=="C";
if any(~validType)
    error('材料类别中存在A、B、C以外的值。');
end

if any(~isfinite(indicatorData(:)))
    error('六项指标中存在NaN或无穷值。');
end

%% 3. 指标名称和方向
indicatorNames = { ...
    '有效供货周平均产能贡献量'; ...
    '累计供货率'; ...
    '订货完成率'; ...
    '供货稳定性标准差'; ...
    '供货周覆盖率'; ...
    '年度供货覆盖率'};

% 1表示正向指标，-1表示负向指标
indicatorDirection = [1,1,1,-1,1,1];
directionText = ["正向";"正向";"正向";"负向";"正向";"正向"];

%% 4. 指标正向化与极差标准化
% 正向指标：
% z_ij = (x_ij-min x_j)/(max x_j-min x_j)
%
% 负向指标：
% z_ij = (max x_j-x_ij)/(max x_j-min x_j)
%
% 经过处理后，所有指标均满足"数值越大越优"，且位于[0,1]。

standardizedMatrix = zeros(nSuppliers,nIndicators);
indicatorMin = min(indicatorData,[],1);
indicatorMax = max(indicatorData,[],1);
indicatorRange = indicatorMax-indicatorMin;

for j = 1:nIndicators
    if indicatorRange(j) <= eps
        error('指标"%s"在所有供应商中取值相同，无法进行客观赋权。', ...
            indicatorNames{j});
    end

    if indicatorDirection(j) == 1
        standardizedMatrix(:,j) = ...
            (indicatorData(:,j)-indicatorMin(j))/indicatorRange(j);
    else
        standardizedMatrix(:,j) = ...
            (indicatorMax(j)-indicatorData(:,j))/indicatorRange(j);
    end
end

% 数值误差核验
if any(standardizedMatrix(:) < -1e-12) || ...
        any(standardizedMatrix(:) > 1+1e-12)
    error('标准化结果超出[0,1]，请检查计算过程。');
end

standardizedMatrix = min(max(standardizedMatrix,0),1);

%% 5. CRITIC客观赋权
% 5.1 对比强度：标准化指标的总体标准差
indicatorStd = std(standardizedMatrix,1,1);

% 5.2 指标相关系数矩阵
correlationMatrix = corrcoef(standardizedMatrix);

if any(~isfinite(correlationMatrix(:)))
    error('相关系数矩阵中存在无效值。');
end

% 5.3 冲突性
% 第j项指标的冲突性为 sum_k(1-r_jk)
conflictDegree = sum(1-correlationMatrix,2)';

% 5.4 信息量
informationAmount = indicatorStd .* conflictDegree;

if sum(informationAmount) <= eps
    error('CRITIC信息量之和为0，无法计算指标权重。');
end

% 5.5 客观权重
criticWeight = informationAmount / sum(informationAmount);

if abs(sum(criticWeight)-1) > 1e-10
    error('CRITIC权重之和不等于1。');
end

[~,weightOrder] = sort(criticWeight,'descend');
weightRank = zeros(nIndicators,1);
weightRank(weightOrder) = (1:nIndicators)';

%% 6. TOPSIS综合评价
% 6.1 加权标准化决策矩阵
weightedMatrix = bsxfun(@times,standardizedMatrix,criticWeight);

% 6.2 正理想解和负理想解
positiveIdeal = max(weightedMatrix,[],1);
negativeIdeal = min(weightedMatrix,[],1);

% 6.3 与正、负理想解的欧氏距离
distanceToPositive = sqrt(sum( ...
    bsxfun(@minus,weightedMatrix,positiveIdeal).^2,2));

distanceToNegative = sqrt(sum( ...
    bsxfun(@minus,weightedMatrix,negativeIdeal).^2,2));

% 6.4 综合接近度
denominator = distanceToPositive+distanceToNegative;

if any(denominator <= eps)
    error('存在正、负理想距离之和为0的供应商，无法计算综合接近度。');
end

comprehensiveScore = distanceToNegative ./ denominator;

% 6.5 排序
[sortedScore,sortIndex] = sort(comprehensiveScore,'descend');

rankNumber = zeros(nSuppliers,1);
rankNumber(sortIndex) = (1:nSuppliers)';

%% 7. 组织全部供应商排名
allResultTable = table( ...
    supplierID,materialType, ...
    indicatorData(:,1),indicatorData(:,2),indicatorData(:,3), ...
    indicatorData(:,4),indicatorData(:,5),indicatorData(:,6), ...
    distanceToPositive,distanceToNegative, ...
    comprehensiveScore,rankNumber, ...
    'VariableNames',{ ...
    '供应商编号','材料类别', ...
    '有效供货周平均产能贡献量','累计供货率','订货完成率', ...
    '供货稳定性标准差','供货周覆盖率','年度供货覆盖率', ...
    '正理想解距离','负理想解距离','综合重要度','综合排名'});

allResultTable = allResultTable(sortIndex,:);

%% 8. 提取最重要的50家供应商
topNumber = min(50,nSuppliers);
topIndex = sortIndex(1:topNumber);

top50Table = table( ...
    (1:topNumber)', ...
    supplierID(topIndex),materialType(topIndex), ...
    indicatorData(topIndex,1),indicatorData(topIndex,2), ...
    indicatorData(topIndex,3),indicatorData(topIndex,4), ...
    indicatorData(topIndex,5),indicatorData(topIndex,6), ...
    distanceToPositive(topIndex),distanceToNegative(topIndex), ...
    comprehensiveScore(topIndex), ...
    'VariableNames',{ ...
    '排名','供应商编号','材料类别', ...
    '有效供货周平均产能贡献量','累计供货率','订货完成率', ...
    '供货稳定性标准差','供货周覆盖率','年度供货覆盖率', ...
    '正理想解距离','负理想解距离','综合重要度'});

%% 9. CRITIC权重结果表
weightTable = table( ...
    string(indicatorNames),directionText, ...
    indicatorMin',indicatorMax', ...
    indicatorStd',conflictDegree',informationAmount', ...
    criticWeight',weightRank, ...
    'VariableNames',{ ...
    '指标名称','指标方向','原始最小值','原始最大值', ...
    '对比强度','冲突性','信息量','CRITIC权重','权重排名'});

weightTable = sortrows(weightTable,'权重排名','ascend');

%% 10. 标准化矩阵和加权矩阵
standardizedTable = array2table(standardizedMatrix, ...
    'VariableNames',indicatorNames);
standardizedTable = addvars(standardizedTable, ...
    supplierID,materialType, ...
    'Before',1,'NewVariableNames',{'供应商编号','材料类别'});

weightedTable = array2table(weightedMatrix, ...
    'VariableNames',indicatorNames);
weightedTable = addvars(weightedTable, ...
    supplierID,materialType, ...
    'Before',1,'NewVariableNames',{'供应商编号','材料类别'});

correlationTable = array2table(correlationMatrix, ...
    'VariableNames',indicatorNames);
correlationTable = addvars(correlationTable, ...
    string(indicatorNames), ...
    'Before',1,'NewVariableNames','指标名称');

idealSolutionTable = table( ...
    string(indicatorNames), ...
    positiveIdeal',negativeIdeal', ...
    'VariableNames',{'指标名称','正理想解','负理想解'});

%% 11. 模型核验和结果统计
top50TypeA = sum(materialType(topIndex)=="A");
top50TypeB = sum(materialType(topIndex)=="B");
top50TypeC = sum(materialType(topIndex)=="C");

offDiagonal = abs(correlationMatrix-eye(nIndicators));
maxAbsoluteCorrelation = max(offDiagonal(:));

checkItems = [ ...
    "供应商数量"; ...
    "指标数量"; ...
    "标准化矩阵最小值"; ...
    "标准化矩阵最大值"; ...
    "CRITIC权重之和"; ...
    "指标最大绝对相关系数"; ...
    "综合重要度最小值"; ...
    "综合重要度最大值"; ...
    "前50家A类供应商数量"; ...
    "前50家B类供应商数量"; ...
    "前50家C类供应商数量"];

checkValues = [ ...
    nSuppliers; ...
    nIndicators; ...
    min(standardizedMatrix(:)); ...
    max(standardizedMatrix(:)); ...
    sum(criticWeight); ...
    maxAbsoluteCorrelation; ...
    min(comprehensiveScore); ...
    max(comprehensiveScore); ...
    top50TypeA; ...
    top50TypeB; ...
    top50TypeC];

modelCheckTable = table(checkItems,checkValues, ...
    'VariableNames',{'核验项目','核验结果'});

%% 12. 写入中文Excel结果
if isfile(outputFile)
    delete(outputFile);
end

writetable(top50Table,outputFile,'Sheet','最重要50家供应商');
writetable(allResultTable,outputFile,'Sheet','402家供应商综合排名');
writetable(weightTable,outputFile,'Sheet','CRITIC指标权重');
writetable(standardizedTable,outputFile,'Sheet','正向标准化矩阵');
writetable(weightedTable,outputFile,'Sheet','加权标准化矩阵');
writetable(correlationTable,outputFile,'Sheet','标准化指标相关性');
writetable(idealSolutionTable,outputFile,'Sheet','TOPSIS理想解');
writetable(modelCheckTable,outputFile,'Sheet','模型核验');

%% 13. 绘制CRITIC指标权重图
fig1 = figure('Color','w','Position',[100,100,1050,650]);
ax1 = axes(fig1);

bar(ax1,criticWeight,'FaceColor','flat');
set(ax1, ...
    'XTick',1:nIndicators, ...
    'XTickLabel',indicatorNames, ...
    'XTickLabelRotation',25, ...
    'FontSize',11);

ylabel(ax1,'权重');
title(ax1,'CRITIC法确定的供应商评价指标权重','FontSize',15);
grid(ax1,'on');

for j = 1:nIndicators
    text(ax1,j,criticWeight(j)+0.005, ...
        sprintf('%.4f',criticWeight(j)), ...
        'HorizontalAlignment','center', ...
        'FontWeight','bold', ...
        'FontSize',10);
end

ylim(ax1,[0,max(criticWeight)*1.18]);

localCloseToolbar(ax1);
drawnow;
localExportFigure(fig1,weightFigureFile);

%% 14. 绘制前50家供应商综合得分图
fig2 = figure('Color','w','Position',[100,50,1100,1500]);
ax2 = axes(fig2);

displayScores = flipud(sortedScore(1:topNumber));
displayLabels = flipud(supplierID(topIndex));

barh(ax2,displayScores);
set(ax2, ...
    'YTick',1:topNumber, ...
    'YTickLabel',cellstr(displayLabels), ...
    'FontSize',9);

xlabel(ax2,'TOPSIS综合重要度');
ylabel(ax2,'供应商编号');
title(ax2,'综合重要度排名前50的供应商','FontSize',15);
grid(ax2,'on');

xMax = max(displayScores);
for j = 1:topNumber
    text(ax2,displayScores(j)+0.004,j, ...
        sprintf('%.4f',displayScores(j)), ...
        'VerticalAlignment','middle', ...
        'FontSize',8);
end

xlim(ax2,[0,min(1,xMax+0.10)]);

localCloseToolbar(ax2);
drawnow;
localExportFigure(fig2,top50FigureFile);

%% 15. 命令行中文输出
fprintf('\n================ CRITIC指标权重 ================\n');
disp(weightTable);

fprintf('\n================ TOPSIS排名前50的供应商 ================\n');
disp(top50Table(:,{'排名','供应商编号','材料类别','综合重要度'}));

fprintf('\n================ 模型核验 ================\n');
disp(modelCheckTable);

fprintf('\n计算完成。\n');
fprintf('综合评价结果：%s\n',outputFile);
fprintf('指标权重图：%s\n',weightFigureFile);
fprintf('前50家供应商得分图：%s\n',top50FigureFile);

%% 局部函数1：将混合单元格区域转换为数值矩阵
function numericMatrix = localCellBlockToDouble(cellBlock,blockName)
    numericMatrix = zeros(size(cellBlock));

    for index = 1:numel(cellBlock)
        value = cellBlock{index};

        if isempty(value)
            error('%s中存在空白单元格。',blockName);

        elseif isnumeric(value)
            if isnan(value)
                error('%s中存在NaN。',blockName);
            end
            numericMatrix(index) = double(value);

        elseif islogical(value)
            numericMatrix(index) = double(value);

        else
            textValue = strtrim(string(value));
            convertedValue = str2double(textValue);

            if ismissing(textValue) || strlength(textValue)==0 || ...
                    isnan(convertedValue)
                error('%s中存在无法转换为数值的内容：%s', ...
                    blockName,textValue);
            end

            numericMatrix(index) = convertedValue;
        end
    end
end

%% 局部函数2：关闭坐标区工具栏
function localCloseToolbar(ax)
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
end

%% 局部函数3：导出图像
function localExportFigure(fig,fileName)
    try
        exportgraphics(fig,fileName,'Resolution',300);
    catch
        print(fig,fileName,'-dpng','-r300');
    end
end
