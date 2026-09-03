
function R=C4_yield_dynamic(x,model)

z=(x-model.mean')./model.std';


X=response_predict_dynamic(z,model.conv);
S=response_predict_dynamic(z,model.c4);

R=X*S/100;

end
