function R=C4_yield_final(x,D,model)

z=(x'-model.mean)./model.std;

X=response_predict_final(z,D,model.conv);
S=response_predict_final(z,D,model.c4);

R=X*S/100;

end
