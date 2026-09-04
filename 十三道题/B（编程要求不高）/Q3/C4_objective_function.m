function Y=C4_objective_function(x,D,M,zLimit,convTerm,convCoef,selTerm,selCoef,mu,sigma)

z=(x(:)-mu)./sigma;

if any(abs(z)>zLimit)
    Y=0;
    return;
end

[X,S,Y]=C4_model_function(x,D,M,convTerm,convCoef,selTerm,selCoef,mu,sigma);

if isnan(Y) || X<0 || X>100 || S<0 || S>100
    Y=0;
end
end
