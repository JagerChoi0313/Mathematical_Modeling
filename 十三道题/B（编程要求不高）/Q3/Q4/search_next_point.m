function [best_x,best_EI]=search_next_point(...
    model,...
    Y_best,...
    lb,...
    ub)



%% 随机产生候选实验点

N=5000;


candidate=zeros(N,length(lb));


for i=1:length(lb)

    candidate(:,i)=...
        lb(i)+(ub(i)-lb(i))*rand(N,1);

end



%% GPR预测

[mu,sigma]=predict(model,candidate);



%% 计算EI


EI=expected_improvement(...
    mu,...
    sigma,...
    Y_best);



%% 最大EI


[best_EI,index]=max(EI);


best_x=candidate(index,:);



end