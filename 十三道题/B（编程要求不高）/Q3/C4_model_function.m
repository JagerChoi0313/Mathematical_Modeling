function [X,S,Y]=C4_model_function(x,D,M,convTerm,convCoef,selTerm,selCoef,mu,sigma)

z=(x(:)-mu)./sigma;

X=response_calc(convTerm,convCoef,z,D,M);
S=response_calc(selTerm,selCoef,z,D,M);

if X<0 || X>100 || S<0 || S>100
    Y=0;
else
    Y=X*S/100;
end

end

function y=response_calc(term,coef,z,D,M)

y=0;

for i=1:length(coef)
    t=string(term(i));

    switch t
        case "Intercept"
            v=1;
        case "z1"
            v=z(1);
        case "z2"
            v=z(2);
        case "z3"
            v=z(3);
        case "z4"
            v=z(4);
        case "z1^2"
            v=z(1)^2;
        case "z2^2"
            v=z(2)^2;
        case "z3^2"
            v=z(3)^2;
        case "z4^2"
            v=z(4)^2;
        case "z1*z2"
            v=z(1)*z(2);
        case "z1*z3"
            v=z(1)*z(3);
        case "z1*z4"
            v=z(1)*z(4);
        case "z2*z3"
            v=z(2)*z(3);
        case "z2*z4"
            v=z(2)*z(4);
        case "z3*z4"
            v=z(3)*z(4);
        case "D"
            v=D;
        case "M_total"
            v=M;
        otherwise
            v=0;
    end
    y=y+coef(i)*v;
end
end
