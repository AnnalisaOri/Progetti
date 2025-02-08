close all
clear
clc

tspan = [0 1100];
options = odeset('relTol', 1e-8, 'absTol', [1e-8, 1e-8 1e-8])

x0 = [0.4 0.5 0.6 0.3 0.7 0.9];
p0 =  [0.2 0.3 0.4 0.2 1 1.2];
z0 =[0.05 0.15 0.25 0.16 0.7 0.8];

for i=1:length(x0)
    [t,y] = ode45(@(t,y) func2(t,y), tspan, [x0(i) p0(i) z0(i)],'options');
    plot3(y(:,1), y(:,2), y(:,3),'LineWidth',1.2)
    hold on
end


plot3(0,0,0,'*','MarkerSize',15,'color','m')
plot3(1,0,0,'*','MarkerSize',15,'color','k')
plot3(0.75,0.25,0,'*','MarkerSize',15,'color','k')
plot3(0.15,0,0.85,'*','MarkerSize',15,'color','k')

xlabel('preda condivisa','FontSize',10)
ylabel('preda IG','FontSize',10)
zlabel('predatore IG','FontSize',10)
%ylim([0 0.5])
%zlim([0 0.5])

function res = func2(t, y)
    s = y(1)*(1-y(1)-y(2)-y(3));
    i = 20*y(2)*(y(1)-1.3*y(3)-0.75);
    r = 10*y(3)*(y(1)+0.01*y(2)-0.15);
 
    res = [s;i;r];
end

