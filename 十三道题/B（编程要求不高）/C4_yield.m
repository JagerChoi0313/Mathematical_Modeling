function R=C4_yield(x,convModel,selectModel)

z=(x-convModel.meanX)./convModel.stdX;

X=response_predict(z,convModel);
S=response_predict(z,selectModel);

R=X*S/100;

end
