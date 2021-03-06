function [height,state,o]=run4seg_P_events(tstart,istate,istim,P,varargin)
% function [height,state,o]=run4seg_P(tstart,istate,istim,P,varargin)
% This function computes the jump height. squat jump, no counter-movements.
% INPUTS:
% tstart = onset timing of the 6 muscles.
% istate = angles[1:4],angular velocities[5:8],footX[9],footY[10],
% P = structure of model parameters. this is currently done by loading a
% table of data from getJumperParams (returns a matrix) and then
% getJumperStruct(inMatrix)
%%TEMPLATE VARARGIN
%%only 1 optional argument, doFlight.

istate = istate(:)';
fi = istate(1:4);
fip=istate(5:8);
xbase = istate(9:10);
xbasep = istate(11:12);
clcerel = istate(13:18);
cgamma = istate(19:24);
numvarargs = length(varargin);

istim = istim(:)';

num_maxvarargs = 1;
if numvarargs > num_maxvarargs
    error(['scoreETF:TooManyInputs', ...
        'requires at most ',num2str(num_maxvarargs),' optional inputs']);
end
% set defaults for optional inputs
doFlight0=0;
optargs = {doFlight0};
% now put these defaults into the optargs cell array,
% and overwrite the ones specified in varargin.
if ~isempty(varargin)
    [optargs(1:numvarargs)] = varargin{:};
end
% or ...
% [optargs{1:numvarargs}] = varargin{:};

% Place optional args in memorable variable names used below.
[doFlight] = optargs{:};
% %%/TEMPLATE VARARGIN

o.t_air = 0;
o.flag_pe = 0;
o.flag_eq = 0;

tstart = tstart(:)'; %all of our muscle parameters are 1x6 vectors.
P.tstart = tstart;
P.sim.g=-9.81;
P.sim.air = 0;

fi = fi(:);%and yet sadly all of our angles are not. they are 4x1. here.
nseg = P.sk.nseg;
d = P.sk.d;
l = P.sk.l;
mass = P.sk.mass;

ode_handle = @ode_jumper;

%% compute initial kinematics of four segments and COM.
[x,y,xp,yp,xdp,ydp]=xyc4(fi,zeros(size(fi)),zeros(size(fi)),[0;0],[0;0],[0;0],l);
[cmx,cmy,cmxp,cmyp,cmxdp,cmydp]=kinematics_4_com(x,y,xp,yp,xdp,ydp,l,d,mass);
%[cmx,cmy,cmxp,cmyp,cmxdp,cmydp]=kinematics_4(x,y,xp,yp,xdp,ydp,l,d,m);
% cmxi=[d(1) 0 0 0;l(1) d(2) 0 0;l(1) l(2) d(3) 0;l(1) l(2) l(3) d(4)]*cos(fi);
% cmyi=[d(1) 0 0 0;l(1) d(2) 0 0;l(1) l(2) d(3) 0;l(1) l(2) l(3) d(4)]*sin(fi);
% cmx=[mass/sum(mass)]*cmxi;
% cmy=[mass/sum(mass)]*cmyi;
%% simulate.

clcerel = clcerel(:);
cgamma = cgamma(:);

%%%%%% events
P.t_stim_sorted = sort(tstart);
P.i_progress = 1;
P.DO_FLIGHT = 0;
%%%%% /events.

P.t_max = 1; %maximum simulation time.

P.istim = istim(:)';
fi = fi(:);
fip=fip(:);
xbase=xbase(:);
xbasep=xbasep(:);

ct=0;
state0=[fi;fip;xbase;xbasep;clcerel;cgamma];
stepsize=0.001;
solver_handle = @ode45;
odeopts = odeset('events',@events_jumper);
t_all = [];
state_all = [];
while(P.i_progress < 8 & ct<P.t_max) % loop through timesteps and simulate.
    [t,state,te,ye,ie]=solver_handle(ode_handle,ct:stepsize:P.t_max,state0,odeopts,P);
    t_all=[t_all;t(1:end-1)];
    state_all = [state_all;state(1:end-1,:)];
    % note: annoyingly, removing the end doesn't guarantee you don't get
    % duplicate times. this can still happen it appears in the case where
    % a triggered event happens exactly on your return time index
    % frequency, or in this case, every 1000th of a second. 

    ct = t(end);
    state0 = state(end,:);
    P.i_progress = P.i_progress + 1;
end; 

t_all = [t_all;t(end)];
state_all = [state_all;state(end,:)];
state = state_all;
t = t_all;
nseg =4;

%% compute jump height.
fi=      state(:,1:nseg);
fip=     state(:,nseg+1:2*nseg);
xbase=   state(:,2*nseg+1:2*nseg+2);
xbasep=  state(:,2*nseg+3:2*nseg+4);
[x,y,xp,yp,~,~]=xyc4(fi',fip',zeros(size(fip))',xbase',zeros(size(xbase))',zeros(size(xbase))',l);
[cmx,cmy,cmxp,cmyp,~,~]=kinematics_4_com(x,y,xp,yp,zeros(size(xp)),zeros(size(yp)),l,d,mass(:));

height=cmy(end)+0.5/9.81*cmyp(end)^2;
height = -height;
%% /compute jump height.

if nargout == 3
    [sol,stim,tor_m,n_m,ese,rloi,q,fse,tor]=deal([]);
    for ifwd =1:length(t)
        [stated_cur,sol_cur,os]=ode_jumper(t(ifwd),state(ifwd,:),P);
        sol = [sol; sol_cur'];
        stim=[stim; os.stim(:)'];
        tor_m = [tor_m; os.tor_m'];
        n_m = [n_m; os.n_m(:)'];
        ese = [ese; os.ese(:)'];
        rloi = [rloi; os.rloi(:)'];
        q= [q; os.q(:)'];
        fse =[fse; os.fse(:)'];
        tor = [tor; os.tor(:)'];
    end;
    o.tor_m = reshape(tor_m,4,6,numel(tor_m)/24);
    o.sol = sol;
    o.stim = stim;
    o.n_m = n_m;
    o.ese = ese;
    o.rloi = rloi;
    o.q = q;
    o.fse = fse;
    o.tor = tor;
    o.lcerel = state(:,13:18);
    o.phi = state(:,1:4);
    o.phidot = state(:,5:8);
    o.t = t;
    for im = 1:6
        o.vcerel(:,im) = gradient(o.lcerel(:,im),o.t);
    end;
    o.x = x';
    o.y = y';
    o.cmx = cmx';
    o.cmy = cmy';
end;
%catch too long muscles
if sum(sum(o.lcerel > 1.4))
    height = 0;
    fprintf('height = 0;caught muscles that were too long.\n');
else
    fprintf('height = %.3f \n',height);
end;