
function plot_radar(T,out)

figure('Position',[200 200 700 600]);

data=[
T.Co_Load(1),T.Ratio(1),T.Ethanol(1),T.Temperature(1)/450,T.C4_Yield(1)/100;
T.Co_Load(2),T.Ratio(2),T.Ethanol(2),T.Temperature(2)/450,T.C4_Yield(2)/100
];

labels={'Co负载量','装料比例','乙醇浓度','温度','C4收率'};

theta=linspace(0,2*pi,6);

for i=1:2

    values=[data(i,:) data(i,1)];

    polarplot(theta,values,'LineWidth',2);
    hold on;

end

thetaticks(rad2deg(theta(1:5)));
thetaticklabels(labels);

title('不同约束条件下优化参数对比');

legend(T.Case,'Location','bestoutside');

saveas(gcf,fullfile(out,'Fig2_parameter_radar.png'));

end
