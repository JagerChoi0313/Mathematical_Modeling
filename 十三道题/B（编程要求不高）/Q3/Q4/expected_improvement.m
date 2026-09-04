function EI=expected_improvement(mu,sigma,Y_best)


% 防止除0

sigma=max(sigma,1e-9);



Z=(mu-Y_best)./sigma;



EI=(mu-Y_best).*normcdf(Z)...
    +sigma.*normpdf(Z);



end