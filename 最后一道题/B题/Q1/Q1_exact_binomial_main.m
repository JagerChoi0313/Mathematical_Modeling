function R = Q1_exact_binomial_main()
% Q1_EXACT_BINOMIAL_MAIN 第一问：精确二项分布双临界值搜索。
%
% 运行方法：将本文件放入 MATLAB 当前文件夹，命令窗口输入：
%   R = Q1_exact_binomial_main;
% 也可以打开本文件，直接点击“运行”。文件名请勿修改。
%
% 数据输入：不需要题目附件或 Excel。只需设置 Step 1 的参数。
% 如有实际抽检结果，可设置 nObs、xObs；不填则只设计方案。
% nObs 是事先确定的样本量，xObs 是这 nObs 件中的次品总数。
%
% 模型前提：批量足够大、随机抽样、质量近似独立、检测无误差。
% 本程序最小化的是“接收区、拒收区均非空”的固定样本量，
% 不是保证最终二选一的最小样本量，也不是平均检测次数最优。
% 所有临界值仅对事先固定 n 的一次检验有效，不能作为未经
% 校正的序贯停止边界。未判定时不自动追加样本或默认接收。
%
% 依赖：MATLAB 基础功能，无需 Statistics and Machine Learning Toolbox。
% betainc 与二项分布尾概率等价，不使用正态近似。
% 参考：https://www.mathworks.com/help/matlab/ref/betainc.html
%
% 输出：结构体 R；中文报告；四幅中文图（300 dpi PNG + 可编辑 FIG）；
%       一个含全部结果表和绘图数据的 Q1_tables.xlsx；Q1_results.mat。
% 更新说明：原两图汉化；新增样本量对比图、临界值细节图；全部表导出。
% Excel 由 MATLAB 的 writetable 直接写入，无需额外安装导出工具。
% 每次运行使用独立目录，不覆盖之前的结果，不清除用户工作区。

%% Step 1：参数初始化与输入检查
p0 = 0.10;                % 供应商标称次品率
alphaA = 0.10;            % 接收检验显著性水平：1 - 90%
alphaR = 0.05;            % 拒收检验显著性水平：1 - 95%
Nmax = 500;               % 搜索范围上限，不是实际要检测的件数
nObs = [];                % 可选：事先确定的实际抽检数量，如 22
xObs = [];                % 可选：实际发现的次品总数，如 0
makeFigures = true;       % 是否绘图；无图形环境时可设为 false
saveFiles = true;         % 是否保存 Excel、MAT、报告和图像
compareNExtra = [50 100]; % 对比样本量；程序会自动加入求得的 nStar
detailNmax = 200;         % 新增临界值细节图的展示上限
fontPreferred = '';      % 留空自动选中文字体；也可指定 'Microsoft YaHei'

validateattributes(p0, {'numeric'}, {'scalar','real','finite','>',0,'<',1});
validateattributes(alphaA, {'numeric'}, {'scalar','real','finite','>',0,'<',1});
validateattributes(alphaR, {'numeric'}, {'scalar','real','finite','>',0,'<',1});
validateattributes(Nmax, {'numeric'}, {'scalar','real','finite','integer','>=',1});
validateattributes(compareNExtra, {'numeric'}, {'vector','real','finite','integer','>=',1});
validateattributes(detailNmax, {'numeric'}, {'scalar','real','finite','integer','>=',1});
assert(alphaA + alphaR < 1, '两个显著性水平之和必须小于 1。');
assert(isempty(nObs) == isempty(xObs), 'nObs 和 xObs 必须同时填写或同时留空。');
if ~isempty(nObs)
    validateattributes(nObs, {'numeric'}, {'scalar','real','finite','integer','>=',1});
    validateattributes(xObs, {'numeric'}, {'scalar','real','finite','integer','>=',0,'<=',nObs});
end

nList = (1:Nmax)';
ca = -ones(Nmax, 1);      % -1 表示接收区为空
cr = NaN(Nmax, 1);        % NaN 表示拒收区为空
checkTol = 1e-10;         % 只用于数值自检，不放宽显著性判定条件

%% Step 2-4：枚举样本量，计算两端尾概率并搜索临界值
for n = 1:Nmax
    x = 0:n;             % 数学中的次品数量；数组下标是 x+1
    [leftTail, rightTail] = binomial_tails(n, p0, x);

    % 接收：P_p0(X <= x) <= alphaA，取满足条件的最大 x。
    ia = find(leftTail <= alphaA, 1, 'last');
    if ~isempty(ia)
        ca(n) = x(ia);
    end

    % 拒收：P_p0(X >= x) <= alphaR，取满足条件的最小 x。
    % 注意：右尾包含 x。若改用 binocdf，应写
    % binocdf(x-1,n,p0,'upper')，不是 binocdf(x,n,p0,'upper')。
    ir = find(rightTail <= alphaR, 1, 'first');
    if ~isempty(ir)
        cr(n) = x(ir);
    end

    % 每个样本量都检查尾概率单调性与相邻临界值。
    assert(all(diff(leftTail) >= -checkTol), '左尾概率单调性检查失败。');
    assert(all(diff(rightTail) <= checkTol), '右尾概率单调性检查失败。');
    if ca(n) >= 0
        assert(leftTail(ca(n)+1) <= alphaA, '接收阈值检查失败。');
        if ca(n) < n
            assert(leftTail(ca(n)+2) > alphaA, '接收阈值不是最大值。');
        end
    else
        assert(leftTail(1) > alphaA, '接收区空集检查失败。');
    end
    if ~isnan(cr(n))
        assert(rightTail(cr(n)+1) <= alphaR, '拒收阈值检查失败。');
        if cr(n) > 0
            assert(rightTail(cr(n)) > alphaR, '拒收阈值不是最小值。');
        end
    else
        assert(rightTail(end) > alphaR, '拒收区空集检查失败。');
    end
end

%% Step 5：寻找接收区、拒收区同时非空的最小固定样本量
isFeasible = ca >= 0 & ~isnan(cr) & cr <= nList & ca < cr;
iStar = find(isFeasible, 1, 'first');
if isempty(iStar)
    error('Q1:NoFeasiblePlan', ...
        '在 1:%d 中未找到共同可行样本量，请增大 Nmax。', Nmax);
end
nStar = nList(iStar);
caStar = ca(iStar);
crStar = cr(iStar);
assert(~any(isFeasible(1:iStar-1)), '最小样本量检查失败。');

% 单独存在接收区、单独存在拒收区时的最小 n，仅用于对照。
nAcceptOnly = nList(find(ca >= 0, 1, 'first'));
nRejectOnly = nList(find(~isnan(cr), 1, 'first'));

%% Step 6：建立决策区域及固定样本量下的决策概率
% 接收：X <= caStar；拒收：X >= crStar；其余：证据不足。
[pAccept0, ~] = binomial_tails(nStar, p0, caStar);
[~, pReject0] = binomial_tails(nStar, p0, crStar);
pUndecided0 = 1 - pAccept0 - pReject0;

% 理论性能分析：pGrid 是假定真实次品率的网格，并非实测数据。
% 对每个 p，计算在固定方案下接收、拒收及未判定的概率。
pGrid = linspace(0, 1, 1001)';
pAccept = zeros(size(pGrid));
pReject = zeros(size(pGrid));
for k = 1:numel(pGrid)
    [pAccept(k), ~] = binomial_tails(nStar, pGrid(k), caStar);
    [~, pReject(k)] = binomial_tails(nStar, pGrid(k), crStar);
end
pUndecided = 1 - pAccept - pReject;
assert(all(pUndecided >= -checkTol), '决策概率出现负值。');
pUndecided = max(0, min(1, pUndecided)); % 仅清除浮点舍入误差
assert(max(abs(pAccept+pReject+pUndecided-1)) < checkTol, ...
    '接收、拒收、未判定三类概率之和不等于 1。');

% 网格风险检查；理论依据是二项分布对 p 的随机单调性。
% p<=p0 时，错误拒收的最大概率位于 p0。
% p>p0 时，错误接收概率的上确界是 p 趋近 p0 时的值。
assert(all(pReject(pGrid <= p0) <= alphaR + checkTol), '拒收风险检查失败。');
assert(all(pAccept(pGrid >= p0) <= alphaA + checkTol), '接收风险检查失败。');

%% Step 6B：新增不同固定样本量的对比数据（按本模型重新计算）
compareN = unique([nStar; compareNExtra(:)]);
compareN = compareN(compareN <= Nmax);
if any(compareNExtra > Nmax)
    warning('Q1:ComparisonRange', '部分对比样本量超过 Nmax，已从对比图中排除。');
end
assert(~isempty(compareN), '没有可绘制的对比样本量。');
comparisonData = zeros(numel(compareN)*numel(pGrid), 5);
comparisonSummaryData = zeros(numel(compareN), 6);
for j = 1:numel(compareN)
    nj = compareN(j);
    aj = ca(nj);
    rj = cr(nj);
    aProb = zeros(size(pGrid));
    rProb = zeros(size(pGrid));
    for k = 1:numel(pGrid)
        [aProb(k), ~] = binomial_tails(nj, pGrid(k), aj);
        if ~isnan(rj)
            [~, rProb(k)] = binomial_tails(nj, pGrid(k), rj);
        end
    end
    uProb = 1 - aProb - rProb;
    assert(all(uProb >= -checkTol), '对比方案决策概率检查失败。');
    uProb = max(0, min(1, uProb));
    assert(max(abs(aProb+rProb+uProb-1)) < checkTol, '对比方案概率之和不为 1。');
    assert(all(aProb(pGrid >= p0) <= alphaA+checkTol), '对比方案接收风险检查失败。');
    assert(all(rProb(pGrid <= p0) <= alphaR+checkTol), '对比方案拒收风险检查失败。');
    idx = (j-1)*numel(pGrid) + (1:numel(pGrid));
    comparisonData(idx,:) = [repmat(nj,numel(pGrid),1), pGrid, aProb, rProb, uProb];
    [a0, ~] = binomial_tails(nj, p0, aj);
    r0 = 0;
    if ~isnan(rj)
        [~, r0] = binomial_tails(nj, p0, rj);
    end
    comparisonSummaryData(j,:) = [nj, aj, rj, a0, r0, 1-a0-r0];
end

%% Step 7：独立数值校验及可选实际样本判定
xStar = (0:nStar)';
[leftStar, rightStar] = binomial_tails(nStar, p0, xStar);
pmfStar = binomial_pmf(nStar, p0, xStar);

% 用对数概率质量函数直接求和，独立校验 betainc 的两个尾部。
% 右尾从大到小累计，避免 1-CDF 在小尾概率处丢失精度。
leftDirect = cumsum(pmfStar);
rightDirect = flipud(cumsum(flipud(pmfStar)));
assert(abs(sum(pmfStar)-1) < checkTol, '概率质量函数归一性检查失败。');
assert(max(abs(leftStar-leftDirect)) < checkTol, '左尾独立校验失败。');
assert(max(abs(rightStar-rightDirect)) < checkTol, '右尾独立校验失败。');

[acceptNext, ~] = binomial_tails(nStar, p0, caStar+1);
[~, rejectPrevious] = binomial_tails(nStar, p0, crStar-1);
observed = [];
if ~isempty(nObs)
    [obsLeft, obsRight] = binomial_tails(nObs, p0, xObs);
    if obsLeft <= alphaA
        decision = '接收';
    elseif obsRight <= alphaR
        decision = '拒收';
    else
        decision = '证据不足，暂不判定';
    end
    observed = struct('n',nObs, 'x',xObs, 'sampleRate',xObs/nObs, ...
        'acceptPValue',obsLeft, 'rejectPValue',obsRight, 'decision',decision);
end

%% Step 8：汇总并输出关键结果
R = struct();
R.parameters = struct('p0',p0, 'alphaA',alphaA, 'alphaR',alphaR, 'Nmax',Nmax);
R.plotSettings = struct('compareN',compareN, 'detailNmax',min(detailNmax,Nmax), ...
    'fontPreferred',fontPreferred);
R.nStar = nStar;
R.caStar = caStar;
R.crStar = crStar;
R.nAcceptOnly = nAcceptOnly;
R.nRejectOnly = nRejectOnly;
R.boundaryPValues = [pAccept0, acceptNext, pReject0, rejectPrevious];
R.probabilitiesAtP0 = [pAccept0, pReject0, pUndecided0];
R.thresholds = table(nList, ca, cr, isFeasible, 'VariableNames', ...
    {'SampleSize','AcceptMax','RejectMin','BothRegionsExist'});
R.distribution = table(xStar, pmfStar, leftStar, rightStar, 'VariableNames', ...
    {'Defects','PMF','LeftTail','RightTail'});
R.performance = table(pGrid, pAccept, pReject, pUndecided, 'VariableNames', ...
    {'TrueRate','AcceptProb','RejectProb','UndecidedProb'});
R.comparisonPerformance = array2table(comparisonData, 'VariableNames', ...
    {'SampleSize','TrueRate','AcceptProb','RejectProb','UndecidedProb'});
R.comparisonSummary = array2table(comparisonSummaryData, 'VariableNames', ...
    {'SampleSize','AcceptMax','RejectMin','AcceptProbAtP0','RejectProbAtP0','UndecidedProbAtP0'});
R.observed = observed;
R.outputDir = '';
R.checksPassed = true;
R.figurePaths = {};
R.figureWarning = '';
R.editableFigurePaths = {};
R.excelPath = '';
R.excelSheets = {};
R.excelWarning = '';
R.fontUsed = '';
R = organize_export_tables(R);  % 整理全部表，统一中文 Excel 表头

if saveFiles
    % 单独创建本次输出目录；保留以往运行生成的文件。
    parentDir = fullfile(fileparts(mfilename('fullpath')), 'Q1_results');
    if exist(parentDir,'dir') ~= 7
        [ok,msg] = mkdir(parentDir);
        assert(ok, '无法建立输出目录：%s', msg);
    end
    runName = ['run_' datestr(now, 'yyyymmdd_HHMMSS')];
    outDir = fullfile(parentDir, runName);
    suffix = 0;
    while exist(outDir,'file') ~= 0
        suffix = suffix + 1;
        outDir = fullfile(parentDir, sprintf('%s_%02d',runName,suffix));
    end
    [ok,msg] = mkdir(outDir);
    assert(ok, '无法建立本次运行目录：%s', msg);
    R.outputDir = outDir;
end

%% Step 9：绘制必要图像（均由模型计算值生成）
if makeFigures
    try
        [R.figurePaths, R.editableFigurePaths, R.fontUsed] = make_plots(R, ca, cr, saveFiles);
    catch ME
        R.figureWarning = ME.message;
        warning('Q1:PlotFailed', ...
            '数值求解已完成，但绘图或图片保存未完成：%s', ME.message);
    end
end

%% Step 10：将所有表保存到同一个 Excel 工作簿的不同工作表
if saveFiles
    try
        [R.excelPath, R.excelSheets] = export_all_tables(R);
    catch ME
        R.excelWarning = ME.message;
        warning('Q1:ExcelExportFailed', ...
            'Excel 导出未完整完成；计算结果仍保存为 MAT。原因：%s', ME.message);
    end
end

% 报告同时输出到命令窗口和文本；不依赖外部表格文件。
write_report(1, R);
if saveFiles
    save(fullfile(R.outputDir, 'Q1_results.mat'), 'R');
    [fid,msg] = fopen(fullfile(R.outputDir,'Q1_report.txt'), 'w', 'n', 'UTF-8');
    if fid < 0
        error('Q1:ReportWriteFailed', 'MAT 已保存，但无法保存文本报告：%s', msg);
    end
    closeReport = onCleanup(@() fclose(fid)); %#ok<NASGU>
    write_report(fid, R);
    fprintf('\n结果目录：%s\n', R.outputDir);
end
end

function [leftTail, rightTail] = binomial_tails(n, p, x)
% 精确二项尾概率（包含边界 x）；x 可为向量，p 为标量。
% P(X<=x)=I_(1-p)(n-x,x+1)，0<=x<n。
% P(X>=x)=I_p(x,n-x+1)，0<x<=n。
% p=0、p=1 以及 x=-1、x=n+1 的边界也被正确处理。
leftTail = zeros(size(x));
rightTail = zeros(size(x));
leftTail(x >= n) = 1;
rightTail(x <= 0) = 1;
ia = x >= 0 & x < n;
ir = x > 0 & x <= n;
leftTail(ia) = betainc(1-p, n-x(ia), x(ia)+1);
rightTail(ir) = betainc(p, x(ir), n-x(ir)+1);
end

function prob = binomial_pmf(n, p, x)
% 通过对数计算二项概率，避免直接 nchoosek 和阶乘溢出。
prob = zeros(size(x));
if p == 0
    prob(x == 0) = 1;
elseif p == 1
    prob(x == n) = 1;
else
    valid = x >= 0 & x <= n;
    k = x(valid);
    logProb = gammaln(n+1) - gammaln(k+1) - gammaln(n-k+1) ...
        + k.*log(p) + (n-k).*log1p(-p);
    prob(valid) = exp(logProb);
end
end

function R = organize_export_tables(R)
% MATLAB 内部保留英文变量名，Excel 单独写中文表头，兼顾兼容性。
% 每张图的数据均来自 R 中的表；导出不会重新生成另一套绘图数据。
p = R.parameters;
R.parameterTable = table( ...
    {'标称次品率';'接收显著性水平';'拒收显著性水平';'最大搜索样本量';'临界值细节图上限'}, ...
    [p.p0;p.alphaA;p.alphaR;p.Nmax;R.plotSettings.detailNmax], ...
    {'比例（0至1）';'比例（0至1）';'比例（0至1）';'件';'件'}, ...
    'VariableNames',{'Parameter','Value','Unit'});
R.summary = table( ...
    {'最小共同固定样本量';'最大接收次品数';'最小拒收次品数'; ...
     '单独存在接收区的最小样本量';'单独存在拒收区的最小样本量'; ...
     '标称次品率下接收概率';'标称次品率下拒收概率';'标称次品率下证据不足概率'}, ...
    [R.nStar;R.caStar;R.crStar;R.nAcceptOnly;R.nRejectOnly;R.probabilitiesAtP0(:)], ...
    {'件';'件';'件';'件';'件';'概率（0至1）';'概率（0至1）';'概率（0至1）'}, ...
    'VariableNames',{'Metric','Value','Unit'});

R.thresholds.HasAcceptRegion = R.thresholds.AcceptMax >= 0;
R.thresholds.HasRejectRegion = ~isnan(R.thresholds.RejectMin);
R.thresholds.UndecidedMin = R.thresholds.AcceptMax + 1;
uMax = R.thresholds.RejectMin - 1;
noReject = isnan(R.thresholds.RejectMin);
uMax(noReject) = R.thresholds.SampleSize(noReject);
R.thresholds.UndecidedMax = uMax;
selected = unique([1;2;10;20;R.nStar;30;40;50;60;80;100;p.Nmax]);
selected = selected(selected <= p.Nmax);
R.thresholdPreview = R.thresholds(selected,:);
R.thresholdDetail = R.thresholds(1:R.plotSettings.detailNmax,:);

b = R.boundaryPValues(:);
R.boundaryChecks = table( ...
    {'接收临界值';'接收临界值的相邻位置';'拒收临界值';'拒收临界值的相邻位置'}, ...
    [R.caStar;R.caStar+1;R.crStar;R.crStar-1], ...
    {'不超过该次品数的概率';'不超过该次品数的概率';'不少于该次品数的概率';'不少于该次品数的概率'}, ...
    b,[p.alphaA;p.alphaA;p.alphaR;p.alphaR], ...
    {'小于等于';'大于';'小于等于';'大于'}, ...
    [b(1)<=p.alphaA;b(2)>p.alphaA;b(3)<=p.alphaR;b(4)>p.alphaR], ...
    'VariableNames',{'Check','Defects','TailDefinition','Probability','Alpha','RequiredRelation','Passed'});
decision = repmat({'证据不足'},height(R.distribution),1);
decision(R.distribution.Defects <= R.caStar) = {'接收'};
decision(R.distribution.Defects >= R.crStar) = {'拒收'};
R.distribution.Decision = decision;

% 没有输入实际检测数据时保留空表，不将理论示例伪装成实测数据。
if isempty(R.observed)
    R.observedTable = table(zeros(0,1),zeros(0,1),zeros(0,1), ...
        zeros(0,1),zeros(0,1),cell(0,1), ...
        'VariableNames',{'SampleSize','Defects','SampleRate','AcceptPValue','RejectPValue','Decision'});
else
    o = R.observed;
    R.observedTable = table(o.n,o.x,o.sampleRate,o.acceptPValue,o.rejectPValue, ...
        {o.decision},'VariableNames', ...
        {'SampleSize','Defects','SampleRate','AcceptPValue','RejectPValue','Decision'});
end

% 映射表：字段名、Excel 工作表名、中文列标题。
thresholdHeaders = {'抽检数量（件）','接收上限（件）','拒收下限（件）', ...
    '接收拒收区均存在','接收区存在','拒收区存在','证据不足下限（件）','证据不足上限（件）'};
probabilityHeaders = {'真实次品率（0至1）','接收概率（0至1）','拒收概率（0至1）','证据不足概率（0至1）'};
R.excelMap = { ...
    'parameterTable','参数设置',{'参数','取值','单位'}; ...
    'summary','关键结果',{'指标','数值','单位'}; ...
    'thresholds','完整临界值',thresholdHeaders; ...
    'thresholdPreview','临界值摘录',thresholdHeaders; ...
    'boundaryChecks','临界值核验',{'核验项目','次品数（件）','概率定义','尾概率（0至1）','显著性水平','要求关系','是否通过'}; ...
    'distribution','最小方案次品分布',{'次品数（件）','恰好该次品数的概率','不超过该次品数的概率','不少于该次品数的概率','判定'}; ...
    'performance','最小方案决策概率',probabilityHeaders; ...
    'comparisonSummary','样本量对比汇总',{'固定样本量（件）','接收上限（件）','拒收下限（件）','标称值下接收概率','标称值下拒收概率','标称值下证据不足概率'}; ...
    'comparisonPerformance','样本量对比曲线数据',[{'固定样本量（件）'},probabilityHeaders]; ...
    'thresholdDetail','临界值细节图数据',thresholdHeaders; ...
    'observedTable','实际样本判定',{'抽检数量（件）','次品数（件）','样本次品率（0至1）','接收左尾检验值','拒收右尾检验值','判定'} ...
    };
end

function [excelPath, sheets] = export_all_tables(R)
% 科学计算结果的数值快照：数值保留为数值，不转换成百分数字符串。
% 修改模型参数后重新运行本程序，即可重新计算全部 Excel 表和图。
% 官方说明：https://www.mathworks.com/help/matlab/ref/writetable.html
excelPath = fullfile(R.outputDir,'Q1_tables.xlsx');
sheets = [{'使用说明'};R.excelMap(:,2)];
notes = { ...
    '项目','说明'; ...
    '来源','2024年数学建模B题第一问；由本程序的精确二项分布模型计算'; ...
    '数据性质','概率曲线是不同真实次品率下的理论结果，不是实测数据'; ...
    '表格用途','本工作簿保存本次程序计算的数值快照；修改参数后应重新运行程序'; ...
    '单位','次品率和概率均保存为0至1的数值；图中次品率坐标采用百分数'; ...
    '空接收区','接收上限=-1表示不存在满足条件的接收结果'; ...
    '空拒收区','拒收下限空白表示NaN；拒收区存在列为0或false'; ...
    '样本缺失','未输入nObs和xObs时，实际样本判定工作表只有表头'; ...
    '最小样本量含义','仅指同时存在接收区和拒收区的最小固定样本量'; ...
    '检验范围','每个样本量对应独立的固定样本检验，不是序贯停止边界'; ...
    '原图1数据','完整临界值；最小方案次品分布'; ...
    '原图2数据','最小方案决策概率'; ...
    '新增图3数据','样本量对比汇总；样本量对比曲线数据'; ...
    '新增图4数据','临界值细节图数据'; ...
    '保存说明','每次运行新建结果目录，避免覆盖历史结果' ...
    };
writetable(cell2table(notes),excelPath,'Sheet','使用说明','WriteVariableNames',false);
for j = 1:size(R.excelMap,1)
    field = R.excelMap{j,1};
    sheet = R.excelMap{j,2};
    headers = R.excelMap{j,3};
    T = R.(field);
    assert(istable(T), '需要导出的字段不是表：%s',field);
    assert(width(T)==numel(headers), '中文表头数量与数据列不一致：%s',field);
    % 表头单独写入，避免不同 MATLAB 版本对中文变量名的限制。
    writetable(cell2table(headers),excelPath,'Sheet',sheet, ...
        'Range','A1','WriteVariableNames',false);
    if height(T)>0
        writetable(T,excelPath,'Sheet',sheet,'Range','A2', ...
            'WriteVariableNames',false,'WriteRowNames',false);
    end
end
% 防止以后新增了 R 中的表，却遗漏对应的 Excel 导出。
fields = fieldnames(R);
mapped = R.excelMap(:,1);
for j = 1:numel(fields)
    if istable(R.(fields{j}))
        assert(any(strcmp(fields{j},mapped)), '结果表未纳入Excel：%s',fields{j});
    end
end
end

function write_report(fid, R)
% fid=1 为命令窗口；其他 fid 为 UTF-8 报告文件。
fprintf(fid, '\n第一问：精确二项分布与单侧假设检验\n');
fprintf(fid, '标称次品率 p0 = %.4f\n', R.parameters.p0);
fprintf(fid, '接收显著性水平 = %.4f；拒收显著性水平 = %.4f\n', ...
    R.parameters.alphaA, R.parameters.alphaR);
fprintf(fid, '搜索范围为 1:%d（不是实际检测数量）\n', R.parameters.Nmax);
fprintf(fid, '\n同时存在接收区与拒收区的最小固定样本量：%d\n', R.nStar);
fprintf(fid, '接收：X <= %d；拒收：X >= %d\n', R.caStar, R.crStar);
fprintf(fid, '证据不足：%d <= X <= %d\n', R.caStar+1, R.crStar-1);
fprintf(fid, '单独存在接收区的最小 n：%d（零次品的极端观测）\n', R.nAcceptOnly);
fprintf(fid, '单独存在拒收区的最小 n：%d（全为次品的极端观测）\n', R.nRejectOnly);
fprintf(fid, '\n相邻临界值核验（在 p=p0 下）：\n');
b = R.boundaryPValues;
fprintf(fid, 'P(X <= %d) = %.10f <= %.4f\n', R.caStar, b(1), R.parameters.alphaA);
fprintf(fid, 'P(X <= %d) = %.10f >  %.4f\n', R.caStar+1, b(2), R.parameters.alphaA);
fprintf(fid, 'P(X >= %d) = %.10f <= %.4f\n', R.crStar, b(3), R.parameters.alphaR);
fprintf(fid, 'P(X >= %d) = %.10f >  %.4f\n', R.crStar-1, b(4), R.parameters.alphaR);
fprintf(fid, '\n真实次品率恰为 p0 时（理论概率，不是实测数据）：\n');
fprintf(fid, '接收概率 %.4f%%；拒收概率 %.4f%%；未判定概率 %.4f%%\n', ...
    100*R.probabilitiesAtP0);
fprintf(fid, '\n部分样本量对应的临界值（完整结果见 R.thresholds）：\n');
fprintf(fid, '%8s %12s %12s\n', '样本量', '接收上限', '拒收下限');
selected = unique([1; 2; 10; 20; R.nStar; 30; 40; 50; 60; 80; 100; R.parameters.Nmax]);
selected = selected(selected <= R.parameters.Nmax);
for j = 1:numel(selected)
    k = selected(j);
    fprintf(fid, '%8d %12g %12g\n', k, R.thresholds.AcceptMax(k), R.thresholds.RejectMin(k));
end
fprintf(fid, '接收上限=-1：接收区为空；拒收下限=NaN：拒收区为空。\n');
fprintf(fid, '\n不同固定样本量的对比结果（在标称次品率下）：\n');
fprintf(fid, '样本量  接收上限  拒收下限  接收概率  拒收概率  证据不足概率\n');
for j = 1:height(R.comparisonSummary)
    s = R.comparisonSummary(j,:);
    fprintf(fid,'%6d %9g %9g %9.4f%% %9.4f%% %12.4f%%\n', ...
        s.SampleSize,s.AcceptMax,s.RejectMin,100*s.AcceptProbAtP0, ...
        100*s.RejectProbAtP0,100*s.UndecidedProbAtP0);
end
if ~isempty(R.observed)
    o = R.observed;
    fprintf(fid, '\n输入的实际样本：n=%d，x=%d，样本次品率=%.4f%%\n', ...
        o.n, o.x, 100*o.sampleRate);
    fprintf(fid, '接收左尾 p 值=%.10f；拒收右尾 p 值=%.10f\n', ...
        o.acceptPValue, o.rejectPValue);
    fprintf(fid, '固定样本量下的判定：%s\n', o.decision);
else
    fprintf(fid, '\n未输入实际检测数据；以上是理论方案，不是实测结论。\n');
end
fprintf(fid, '\n检查状态：全部数值自检通过。\n');
fprintf(fid, '注意：本程序没有优化平均检测次数，也不保证每批都能完成判定。\n');
fprintf(fid, '不得在追加样本后反复使用本表而仍声称整体信度不变。\n');
fprintf(fid, '多阶段方案需要另行设计停止规则及总体错误概率控制。\n');
if ~isempty(R.figureWarning)
    fprintf(fid, '绘图警告：%s\n', R.figureWarning);
end
if ~isempty(R.fontUsed)
    fprintf(fid,'图像字体：%s\n',R.fontUsed);
end
if ~isempty(R.excelPath)
    fprintf(fid,'全部表格已写入 Excel：%s\n',R.excelPath);
    fprintf(fid,'工作表数量：%d（含使用说明）\n',numel(R.excelSheets));
elseif ~isempty(R.excelWarning)
    fprintf(fid,'Excel 导出警告：%s\n',R.excelWarning);
end
if ~isempty(R.outputDir)
    fprintf(fid, '本次输出目录：%s\n', R.outputDir);
end
end

function [paths, figPaths, fontName] = make_plots(R, ca, cr, saveFiles)
% 四幅中文图共享配色，比较样本量时使用相同的横纵坐标范围。
% 每一个 n 是独立固定样本方案；所有图均从已保存的结果表读取数据。
paths = {};
figPaths = {};
fontName = choose_chinese_font(R.plotSettings.fontPreferred);
green = [0.20 0.49 0.39];
red = [0.72 0.29 0.23];
gray = [0.55 0.59 0.63];
n = R.thresholds.SampleSize;
caPlot = ca;
caPlot(caPlot < 0) = NaN;  % 空接收区不画成负次品数

f1 = new_chinese_figure('图1：临界值与判定区域',[70 100 1220 510],fontName);
subplot(1,2,1);
hA = stairs(n, caPlot, 'Color',green, 'LineWidth',1.6); hold on;
hR = stairs(n, cr, 'Color',red, 'LineWidth',1.6);
plot(R.nStar,R.caStar,'o','Color',green,'MarkerFaceColor',green);
plot(R.nStar,R.crStar,'o','Color',red,'MarkerFaceColor',red);
yTop = max(cr(~isnan(cr))) + 1;
plot([R.nStar R.nStar],[0 yTop],':','Color',gray,'LineWidth',1);
xlabel('预先确定的抽检数量（件）'); ylabel('次品数量临界值（件）');
title(sprintf('固定样本量检验：最小共同样本量为%d件',R.nStar));
xlim([0 max(n)+1]); ylim([0 yTop]); grid on; box off;
legend([hA hR],{'接收上限','拒收下限'}, ...
    'Location','northwest');

subplot(1,2,2);
x = R.distribution.Defects;
q = R.distribution.PMF;
qA = q; qA(x > R.caStar) = 0;
qR = q; qR(x < R.crStar) = 0;
qU = q; qU(x <= R.caStar | x >= R.crStar) = 0;
h = bar(x, [qA qU qR], 0.85, 'stacked');
set(h(1),'FaceColor',green,'EdgeColor','none');
set(h(2),'FaceColor',gray,'EdgeColor','none');
set(h(3),'FaceColor',red,'EdgeColor','none');
xlabel('样本中发现的次品数量（件）'); ylabel('出现概率');
title(sprintf('抽检%d件、真实次品率%.0f%%时的判定区域',R.nStar,100*R.parameters.p0));
grid on; box off;
xlim([-0.75 R.nStar+0.75]);
legend(h,{'接收','证据不足','拒收'},'Location','northeast');

f2 = new_chinese_figure('图2：固定样本量的决策概率',[120 90 950 600],fontName);
p = R.performance.TrueRate;
hA = plot(100*p,R.performance.AcceptProb,'Color',green,'LineWidth',1.8); hold on;
hR = plot(100*p,R.performance.RejectProb,'Color',red,'LineWidth',1.8);
hU = plot(100*p,R.performance.UndecidedProb,'--','Color',gray,'LineWidth',1.8);
plot(100*[R.parameters.p0 R.parameters.p0],[0 1],':','Color',[0.3 0.3 0.3]);
% 展示标称值附近到明显劣质的区间；完整 0~1 网格保存在 R 中。
plotMax = min(1,max(0.4,2*R.parameters.p0));
xlim([0 100*plotMax]); ylim([0 1.04]);
xlabel('真实次品率（%，理论情景）'); ylabel('决策概率');
title({sprintf('抽检%d件时的三类决策概率',R.nStar), ...
    sprintf('标称次品率%.0f%%处，证据不足概率为%.2f%%', ...
    100*R.parameters.p0,100*R.probabilitiesAtP0(3))});
grid on; box off;
legend([hA hR hU],{'接收概率','拒收概率','证据不足概率'},'Location','east');

% 图3：多个样本量共享坐标范围，便于比较判定能力；未复制参考图数值。
m = height(R.comparisonSummary);
f3 = new_chinese_figure('图3：不同固定样本量的决策概率对比', ...
    [150 40 1000 max(600,250*m+150)],fontName);
for j = 1:m
    s = R.comparisonSummary(j,:);
    T = R.comparisonPerformance(R.comparisonPerformance.SampleSize==s.SampleSize,:);
    ax = axes('Parent',f3,'Position',[0.10,0.88-j*(0.73/m),0.70,0.60/m]);
    hA = plot(ax,100*T.TrueRate,T.AcceptProb,'Color',green,'LineWidth',1.8); hold(ax,'on');
    hR = plot(ax,100*T.TrueRate,T.RejectProb,'Color',red,'LineWidth',1.8);
    hU = plot(ax,100*T.TrueRate,T.UndecidedProb,'--','Color',gray,'LineWidth',1.8);
    plot(ax,100*[R.parameters.p0 R.parameters.p0],[0 1],':','Color',[0.35 0.35 0.35]);
    xlim(ax,[0 100*plotMax]); ylim(ax,[0 1.05]);
    ylabel(ax,'决策概率');
    title(ax,sprintf('抽检%d件：接收上限%g件，拒收下限%g件', ...
        s.SampleSize,s.AcceptMax,s.RejectMin));
    % 将关键概率置于右侧留白，避免文字遮住曲线。
    text(ax,1.03,0.50,{'标称次品率处';'证据不足概率'; ...
        sprintf('%.2f%%',100*s.UndecidedProbAtP0)}, ...
        'Units','normalized','HorizontalAlignment','left','FontSize',11);
    grid(ax,'on'); box(ax,'off');
    if j==m
        xlabel(ax,'真实次品率（%，理论情景，非实测数据）');
    end
end
lg = legend(ax,[hA hR hU],{'接收概率','拒收概率','证据不足概率'}, ...
    'Orientation','horizontal');
set(lg,'Units','normalized','Position',[0.25 0.035 0.50 0.035]);

% 图4：展示前200件（可修改）的离散阶梯边界，并标出中间区域。
f4 = new_chinese_figure('图4：接收与拒收临界值细节',[180 120 1040 630],fontName);
D = R.thresholdDetail;
nd = D.SampleSize;
ad = D.AcceptMax;
rd = D.RejectMin;
ad(ad<0) = NaN;
hold on;
valid = ~isnan(ad) & ~isnan(rd);
hasBand = sum(valid)>=2;
if hasBand
    [xa,ya] = stairs(nd(valid),ad(valid));
    [xr,yr] = stairs(nd(valid),rd(valid));
    hBand = fill([xa;flipud(xr)],[ya;flipud(yr)], ...
        [0.86 0.89 0.88],'EdgeColor','none','FaceAlpha',0.55);
end
hA = stairs(nd,ad,'Color',green,'LineWidth',2);
hR = stairs(nd,rd,'Color',red,'LineWidth',2);
top = max([0;rd(~isnan(rd))])+2;
xlim([0 max(nd)+1]); ylim([0 top]);
xlabel('预先确定的抽检数量（件）'); ylabel('次品数量临界值（件）');
title({sprintf('固定样本量的接收与拒收界限：1至%d件',max(nd)), ...
    '两条边界之间的整数次品数对应“证据不足”'});
if R.nStar <= max(nd)
    plot([R.nStar R.nStar],[0 top],':','Color',[0.35 0.35 0.35]);
    plot(R.nStar,R.caStar,'o','Color',green,'MarkerFaceColor',green);
    plot(R.nStar,R.crStar,'o','Color',red,'MarkerFaceColor',red);
    text(0.03,0.77,sprintf('最小共同样本量：%d件',R.nStar), ...
        'Units','normalized','BackgroundColor','w','Margin',4);
end
if hasBand
    legend([hA hR hBand],{'接收上限','拒收下限','证据不足区间'},'Location','northwest');
else
    legend([hA hR],{'接收上限','拒收下限'},'Location','northwest');
end
grid on; box off;

figures = [f1 f2 f3 f4];
for f = figures
    set(findall(f,'-property','FontName'),'FontName',fontName);
    set(findall(f,'-property','Interpreter'),'Interpreter','none');
    set(findall(f,'Type','axes'),'FontSize',12,'LineWidth',0.8);
    set(findall(f,'Type','legend'),'FontSize',11,'Box','off');
    set(f,'PaperPositionMode','auto');
end
drawnow;
if saveFiles
    paths = {fullfile(R.outputDir,'Q1_thresholds_and_regions.png'), ...
             fullfile(R.outputDir,'Q1_decision_probabilities.png'), ...
             fullfile(R.outputDir,'Q1_sample_size_comparison.png'), ...
             fullfile(R.outputDir,'Q1_threshold_detail.png')};
    for j = 1:numel(figures)
        print(figures(j),paths{j},'-dpng','-r300');
        [folder,base] = fileparts(paths{j});
        figPaths{j} = fullfile(folder,[base '.fig']); %#ok<AGROW>
        savefig(figures(j),figPaths{j});
    end
end
end

function f = new_chinese_figure(name,position,fontName)
% 设置当前图窗的默认值，不改变其他图窗或 MATLAB 全局字体设置。
f = figure('Name',name,'NumberTitle','off','Color','w','Position',position, ...
    'DefaultAxesFontName',fontName,'DefaultTextFontName',fontName, ...
    'DefaultTextInterpreter','none','DefaultLegendInterpreter','none');
end

function fontName = choose_chinese_font(preferred)
% Windows 优先微软雅黑/黑体/宋体，兼容 macOS 和 Linux 的中文字体。
if ~isempty(preferred)
    fontName = preferred;
    return;
end
candidates = {'Microsoft YaHei','微软雅黑','SimHei','黑体','SimSun','宋体', ...
    'PingFang SC','Heiti SC','Noto Sans CJK SC','Source Han Sans SC', ...
    'WenQuanYi Micro Hei','Arial Unicode MS'};
available = listfonts;
for j = 1:numel(candidates)
    idx = find(strcmpi(available,candidates{j}),1,'first');
    if ~isempty(idx)
        fontName = available{idx};
        return;
    end
end
fontName = 'SimHei';
warning('Q1:ChineseFont', ...
    '未检测到常用中文字体。若图中文字显示方框，请将fontPreferred设置为本机中文字体名称。');
end
