
function y=response_predict_final(x,D,model)

% 输入真实变量:
% x=[Co负载量 比例 乙醇浓度 温度]

mu=[1.421053;
0.521930;
1.482632;
315.570175];

sigma=[1.160902;
0.114605;
0.517663;
52.312703];


% 标准化
z=(x(:)-mu)./sigma;


% 总装料量控制项
% 默认采用实验平均控制值
M_total=mean(model.M_total);


y=0;

for i=1:length(model.terms)

    term=model.terms(i);

    switch string(term)

        case "Intercept"
            value=1;

        case "z1"
            value=z(1);
        case "z2"
            value=z(2);
        case "z3"
            value=z(3);
        case "z4"
            value=z(4);

        case "z1^2"
            value=z(1)^2;
        case "z2^2"
            value=z(2)^2;
        case "z3^2"
            value=z(3)^2;
        case "z4^2"
            value=z(4)^2;

        case "z1*z3"
            value=z(1)*z(3);
        case "z2*z4"
            value=z(2)*z(4);
        case "z3*z4"
            value=z(3)*z(4);

        case "D"
            value=D;

        case "M_total"
            value=M_total;

        otherwise
            value=0;

    end

    y=y+model.beta(i)*value;

end

end
