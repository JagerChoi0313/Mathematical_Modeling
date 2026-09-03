
%% 真实模型响应面绘制接口
% 将这里的response函数替换为第二问响应面模型

figure;

[X1,X2]=meshgrid(linspace(250,450,60),...
                 linspace(0.3,2.1,60));

% 示例接口
% 请替换为Q2响应面预测函数
Z=zeros(size(X1));

for i=1:size(X1,1)
    for j=1:size(X1,2)
        T=X1(i,j);
        E=X2(i,j);

        % ===== 替换区域 =====
        % Z(i,j)=Q2_model([Co,Ratio,E,T]);
        Z(i,j)=20+0.08*(T-250)+8*(E-0.3);
        % ===================
    end
end

surf(X1,X2,Z,'EdgeColor','none');
colorbar;
xlabel('温度/℃');
ylabel('乙醇浓度');
zlabel('C4收率/%');
title('温度-乙醇浓度响应面');
grid on;
