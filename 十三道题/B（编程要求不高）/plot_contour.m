
%% 响应面等高线图

figure;

[T,E]=meshgrid(linspace(250,450,100),...
               linspace(0.3,2.1,100));

Z=20+0.08*(T-250)+8*(E-0.3);

contourf(T,E,Z,20);
colorbar;
xlabel('温度/℃');
ylabel('乙醇浓度');
title('温度-乙醇浓度C4收率等高线');
grid on;
