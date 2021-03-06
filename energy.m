function out = energy_power(state,fwd,p)
% function out = energy_power(o,state,p)
% needs
% o:t,x,y,cmx,cmy,mass,mom
if length(state) == size(state,2)
    state = state';
end;

col_r_theta = 1:4;
col_r_thetadot = 5:8;

ttic = fwd.t(2)-fwd.t(1);
lBASE = length(fwd.t);
% % calculate j_gPott0
x_cms = fwd.x(:,1:4)+repmat(p.sk.d(:)',lBASE,1).*cos(state(:,col_r_theta));
y_cms = fwd.y(:,1:4)+repmat(p.sk.d(:)',lBASE,1).*sin(state(:,col_r_theta));
j_gdeltaBASE = (fwd.cmy(end)-fwd.cmy(1))*sum(p.sk.mass)*9.81;
js_gs = (y_cms-repmat(y_cms(1,:),lBASE,1)).*repmat(p.sk.mass(:)',lBASE,1)*9.81;

%%%these two are equal; Gravity calc is correct.

dx_cm1 = gradient(fwd.cmx,ttic);
dy_cm1 = gradient(fwd.cmy,ttic);
mass1 = sum(p.sk.mass(:));
j_eklin1 = 1/2*mass1*(dx_cm1.^2+dy_cm1.^2);

dx_cms = gradient(x_cms,ttic);
dy_cms = gradient(y_cms,ttic);
xb = fwd.x(:,1);
rs = p.sk.d;
ls = p.sk.l;
phi = state(:,col_r_theta);
phidot=state(:,col_r_thetadot);
lsinphiphid = -repmat(ls(:)',lBASE,1).*sin(phi).*phidot;
rsinphiphid = -repmat(rs(:)',lBASE,1).*sin(phi).*phidot;
lcosphiphid = repmat(ls(:)',lBASE,1).*cos(phi).*phidot;
rcosphiphid = repmat(rs(:)',lBASE,1).*cos(phi).*phidot;

block = ...
    [0 0 0 0 1 0 0 0
    1 0 0 0 0 1 0 0
    1 1 0 0 0 0 1 0
    1 1 1 0 0 0 0 1];
dx =[lsinphiphid,rsinphiphid]*block';
dy = [lcosphiphid,rcosphiphid]*block';
j_eklinx = .5*repmat(p.sk.mass(:)',lBASE,1).*(dx.^2);
j_ekliny = .5*repmat(p.sk.mass(:)',lBASE,1).*(dy.^2);
j_eklin = j_eklinx+j_ekliny;
js_ekrot = .5*(repmat(p.sk.j(:)',lBASE,1).*state(:,col_r_thetadot).^2); %1/2*I*theta^2
js_eks = js_ekrot+j_eklin;
blockpr = ...
    [1 0 0 0
    -1 1 0 0
    0 -1 1 0
    0 0 -1 1];
phirel = phi*blockpr;

phireldot = phidot*blockpr;
watt_torrel = phireldot.*fwd.tor;

nj =4;
watts(:,1) = - 0 ...
    + fwd.tor(:,1) .* state(:,1+nj);

watts(:,2) = - fwd.tor(:,2) .* state(:,1+nj) ...
    + fwd.tor(:,2) .* state(:,2+nj);

watts(:,3) = - fwd.tor(:,3) .* state(:,2+nj) ...
    + fwd.tor(:,3) .* state(:,3+nj);

watts(:,4) = - fwd.tor(:,4) .* state(:,3+nj) ...
    + fwd.tor(:,4) .* state(:,4+nj);

for ijoint =1:4
    works(:,ijoint) = cumtrapz(fwd.t,watts(:,ijoint));
end;

works_tor = cumtrapz(fwd.t,watts);
% plot(sum(-works_tor',1)+sum(js_gs,1)+sum(js_eks,1))
e_delta = sum(works_tor)+sum(js_gs)+sum(js_eks);

if isfield(fwd,'vcerel')
    for i =1:6
        works_mus(:,i) = cumtrapz(fwd.t,-fwd.vcerel(:,i) .* fwd.fse(:,i)*p.m.rlceopt(i));
    end
else
    works_mus = [];
end
out.works_tor = works_tor;
out.work_tor = sum(works_tor,2);
out.e_kin = sum(js_eks,2);
out.e_gpot = sum(js_gs,2);
out.watts = watts;
out.ek_rot = js_ekrot;
out.eklinx = j_eklinx;
out.ekliny = j_ekliny;
out.works_mus = works_mus;
out.t = fwd.t;
out.balance = (sum(out.e_kin,2)+sum(out.e_gpot,2)-out.work_tor)/out.work_tor(end);

