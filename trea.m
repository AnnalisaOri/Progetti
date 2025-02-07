close all
hold off

a1=0.3;
a2=1.1;
d2=0.9;
d1=0.18;
beta=0.1

x=linspace(-0.3,1,10000)
p=linspace(-0.5,1.7,10000)
xx=linspace(-5,5,1000)
yy=xx.*0

f1=a1.*(1-x).*((d2-x).*(x+a2-d2)).^(1/2)./beta
f2=a1*d2-a2*d1-(a1-a2).*p




hold on
plot(x,f1,'b')
plot(p,f2,'r')
xline(d1,'m')
xline(0,'k--')

plot(xx,yy,'k--')
plot(0.611571,0.561257,'*')
plot(-0.0850851,0,'*')
plot(d2,0,'*')
plot(d2-a2,0,'*')
xlim([-1 1.3])
ylim([0 2])
legend('$g_1(x)=\frac{a_1(1-x)\sqrt{(d_2-x)(x+a_2-d_2)}}{\beta}$','$g_2(x)=a_1d_2-a_2d_1-(a_1-a_2)x $','$x=d_1$','interpreter','latex')
%tex=text(0.7,1.9,'$g_1=\frac{a_1(1-x)\sqrt{(d_2-x)(x+a_2-d_2)}}{\beta}$','color','b','FontSize',13')
%set(tex,'interpreter','latex')
%tex=text(0.7,1.7,'$g_2=a_1d_2-a_2d_1-(a_1-a_2)x $','color','r','FontSize',13')
%set(tex,'interpreter','latex')
%tex=text(0.7,1.5,'$x=d_1 $','color','m','FontSize',13')
%set(tex,'interpreter','latex')
%tex=text(0.8,0.3,'$x^*$','FontSize',13')
%set(tex,'interpreter','latex')
%tex=text(0.4,0.1,'$\frac{a_1d_2-a_2d_1}{a_1-a_2}$','FontSize',13')
%set(tex,'interpreter','latex')
%tex=text(0,0.1,'$d_2-a_2$','FontSize',13')
%set(tex,'interpreter','latex')
%tex=text(1,0.1,'$d_2$','FontSize',13')
%set(tex,'interpreter','latex')

%title('3.a')