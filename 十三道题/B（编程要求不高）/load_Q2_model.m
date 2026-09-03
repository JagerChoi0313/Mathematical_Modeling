
function model=load_Q2_model()

% 示例接口
% 请根据Q2_response_surface_results.xlsx中的C4系数填写

model.terms=[
"Intercept"
"z1"
"z2"
"z3"
"z4"
"D"
"M_total"
"z1^2"
"z2^2"
"z4^2"
"z1*z3"
"z2*z4"
"z3*z4"];

model.beta=[
20.2985
0.531528
2.42375
2.83034
9.00178
-3.75242
5.8263
-2.87976
-1.33394
1.11832
3.49882
-1.12572
-1.17582];

% 控制项
model.M_total=1;

end
