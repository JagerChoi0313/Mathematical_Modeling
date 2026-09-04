function data=load_data_Q4(filename)

% 读取附件1数据
% 输出：
% X:
% [Co负载,比例,乙醇浓度,温度,D]
%
% Y:
% C4烯烃收率


raw=readtable(filename);


% ==============================
% 以下根据附件1实际列名调整
% ==============================


temperature=raw.Temperature;


X=[
raw.Co_Load,...
raw.Ratio,...
raw.Ethanol,...
temperature,...
raw.Method
];


% 收率
Y=raw.Conversion .* ...
   raw.Selectivity /100;


data.X=X;
data.Y=Y;


end