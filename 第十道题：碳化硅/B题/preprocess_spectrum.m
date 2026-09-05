function [sigma,R,R_smooth] = preprocess_spectrum(data,smooth_num,sigma_min)

sigma = data(:,1);
R = data(:,2);

id = isfinite(sigma) & isfinite(R);
sigma = sigma(id);
R = R(id);

[sigma,id] = sort(sigma);
R = R(id);

if ~isempty(R) && R(1) == 0
    sigma(1) = [];
    R(1) = [];
end

id = sigma >= sigma_min;
sigma = sigma(id);
R = R(id);

R_smooth = movmean(R,smooth_num,'Endpoints','shrink');

end
