close all
clear
clc

tspan = [0 16];
y0 = [990 10 0];

[t,y] = ode45(@(t,y) func(t,y), tspan, y0);
subplot(2,1,1)
plot(t,y(:,1),'-',t,y(:,2),'-',t,y(:,3),'-')
xlabel('tspan')
ylabel('Andamento')
ylim([0 1000])
legend('Suscettibili','Infetti','Rimossi')

[t,y] = ode45(@(t,y) func2(t,y), tspan, [990 10]);
subplot(2,1,2)
plot(t,y(:,1),'-',t,y(:,2),'-')
title('Sistema ridotto')
xlabel('tspan')
ylabel('Andamento')
ylim([0 1000])
legend('Suscettibili','Infetti')

% y(1) = S, y(2) = I, y(3) = R
function res = func(t, y)
    s = -0.005*y(1)*y(2)+0.5*y(3);
    i = 0.005*y(1)*y(2)-0.9*y(2);
    r = 0.9*y(2)-0.5*y(3);

    res = [s;i;r];
end

% y(1) = S, y(2) = I, y(3) = R
function res = func2(t, y)
    s = -0.005*y(1)*y(2)+0.5*(1000-y(1)-y(2));
    i = 0.005*y(1)*y(2)-0.9*y(2);

    res = [s;i];
end
