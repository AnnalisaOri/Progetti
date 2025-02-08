close all
clear
clc


tspan = [0 200];
options = odeset('relTol', 1e-8, 'absTol', [1e-8, 1e-8 1e-8]);

x0=[10, 30, 40, 70, 100, 130, 160];
xp0=[290, 270, 260, 230, 200, 170, 140];


for i=1:length(x0)
    [t,y] = ode45(@(t,y) func2(t,y), tspan, [x0(i), xp0(i) 300], options);
    plot(y(:,1), y(:,2))
    hold on
end

title('N* = 333.33 con N=300 < N*')
ylabel('');
xlabel('');
ylim([0 500]);
xlim([-20 350]);
disp('Graph 1 done');
drawnow

% y(1) = S, y(2) = I, y(3) = N
function res = func2(t, y)
    V = 0.5;
    B = 0.003;
    Y = 1;
    S = y(1);
    I = y(2);
    N = y(3);
    s = -B*S*I+V*(300-S-I);
    i = B*S*I-Y*I;

    res = [s;i;N];
end
