a3=0.7
x=linspace(0,2,1000)
hold on
p1=plot(x,1-x,'LineWidth',1.2)
p2=plot(x,(a3+x)./a3,'m','LineWidth',1.2)
xlim([0 1.7])
ylim([0 2])

legend([p1 p2],'$x+z=1$','$z=1+\frac{x}{a_3}$','Interpreter','Latex')