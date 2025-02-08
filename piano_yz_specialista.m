close all
clear
clc

tspan = [0 1100];
%options = odeset('relTol', 1e-8, 'absTol', [1e-8, 1e-8 1e-8])


p0 =  [0.4 1.3 0.4 2.2 1 1.2];
z0 =[0.05 0.55 0.25 1.16 0.7 0.8];

for i=1:length(p0)
    [t,y] = ode45(@(t,y) func2(t,y), tspan, [p0(i) z0(i)]);
    plot(y(:,1), y(:,2),'LineWidth',1.2)
    hold on
end


plot(0,0,'*','MarkerSize',15,'color','m')
plot(1-0.15,0,'*','MarkerSize',15,'color','k')
plot(0,0.5,'*','MarkerSize',15,'color','k')
xlabel('preda IG','FontSize',10)
ylabel('predatore IG','FontSize',10)

%ylim([0 0.5])
%zlim([0 0.5])

function res = func2(t, y)
    
    i = 20*y(1)*(-1.3*y(1)*y(2)/(y(1)^2+(0.1)^2)-0.15);
    r = y(2)*((0.01*((y(1))^2)/(y(1)^2+(0.1)^2))-0.5);
 
    res = [i;r];
end

