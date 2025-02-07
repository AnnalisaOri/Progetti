close all
hold off

a1=0.1;
a2=-1.3;
a3=1.2;
a4=2;
d1=0.2;
beta=0.2;


x=linspace(0,1,70000)
p=linspace(0,0.8,10000)
xx=linspace(-5,5,10000)
yy=xx.*0

g1=1-d1-p
g2=(((1+a2+a3-x).*(x.^2+beta^2)-(a2.*beta^2)).*(x.^2+beta^2+a1.*x))./((1+a4).*(x.^2+beta^2).^2)



hold on
p1=plot(p,g1,'b')
p2=plot(x,g2,'r')
%p3=xline(d1,'m')
p4=xline(0,'k--')
p5=plot(xx,yy,'k--')
plot(0,(1+a3)/(1+a4),'*')
plot(0.0323576,0.767582,'*')
plot(1-d1,0,'*')
plot(0,1-d1,'*')
plot(0.153159,0.648105,'*')
plot(0.673138,0.125892,'*')
plot(0.956596,0,'*')

xlim([-0.6 0.5])
ylim([0 2])
legend([p1 p2 p4 p5],'$g_1(y)=1-d_1-y$','$g_2(y)=\frac{[(1+a_2+a_3-y)(y^2+\beta^2)-a_2\beta^2](y^2+\beta^2+a_1y)}{(1+a_4)(y^2+\beta^2)^2} $','interpreter','latex')