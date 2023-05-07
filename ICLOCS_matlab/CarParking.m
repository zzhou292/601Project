function [problem,guess] = CarParking(obs_data, pos0_x, pos0_y, posf_x, posf_y, rot0)
%CarParking - Minimum Time Parallel Parking
%
% The problem was adapted from 
% B. Li, K. Wang, and Z. Shao, "Time-optimal maneuver planning in automatic parallel parking using a simultaneous dynamic optimization approach". IEEE Transactions on Intelligent Transportation Systems, 17(11), pp.3263-3274, 2016.
%
% Outputs:
%    problem - Structure with information on the optimal control problem
%    guess   - Guess for state, control and multipliers.
%
% Other m-files required: none
% MAT-files required: none
%
% Copyright (C) 2019 Yuanbo Nie, Omar Faqir, and Eric Kerrigan. All Rights Reserved.
% The contribution of Paola Falugi, Eric Kerrigan and Eugene van Wyk for the work on ICLOCS Version 1 (2010) is kindly acknowledged.
% This code is published under the MIT License.
% Department of Aeronautics and Department of Electrical and Electronic Engineering,
% Imperial College London London  England, UK 
% ICLOCS (Imperial College London Optimal Control) Version 2.5 
% 1 Aug 2019
% iclocs@imperial.ac.uk

%------------- BEGIN CODE --------------
% Plant model name, used for Adigator
InternalDynamics=@CarParking_Dynamics_Internal;
SimDynamics=@CarParking_Dynamics_Sim;

% Analytic derivative files (optional)
problem.analyticDeriv.gradCost=[];
problem.analyticDeriv.hessianLagrangian=[];
problem.analyticDeriv.jacConst=[];

% Settings file
problem.settings=@settings_CarParking;

% Scenario Parameters
l_front=0.997; 
l_axes=1.4;
l_rear=0.75; 
b_width=0.9/2;
phi_max=deg2rad(30);
a_max=0.8;
v_max=3.0;
u1_max=0.8;
curvature_dot_max=0.4;


% Store data
auxdata.l_front=l_front;
auxdata.l_axes=l_axes;
auxdata.l_rear=l_rear;
auxdata.b_width=b_width;
auxdata.obs_data=obs_data;
num_obs = size(obs_data,2);

% Boundary Conditions 
posx0 = pos0_x;
posy0 = pos0_y;
theta0=deg2rad(rot0);
v0=0; % Initial velocity (m/s)
a0=0; % Initial accelration (m/s^2)
phi0 = deg2rad(0); % Initial steering angle (rad)

% Limits on Variables
xmin = -25; xmax = 25;
ymin = -25; ymax = 25;
vmin = 0; vmax = v_max;
amin = 0; amax = a_max;
thetamin = -inf; thetamax = inf;
phimin = -phi_max; phimax = phi_max;

%%


%Initial Time. t0<tf
problem.time.t0_min=0;
problem.time.t0_max=0;
guess.t0=0;

% Final time. Let tf_min=tf_max if tf is fixed.
problem.time.tf_min=0;     
problem.time.tf_max=100; 
guess.tf=20;

% Parameters bounds. pl=< p <=pu
problem.parameters.pl = [];
problem.parameters.pu = [];
guess.parameters = [];

% Initial conditions for system.
problem.states.x0=[posx0 posy0 v0 theta0 phi0];

problem.states.x0l=[posx0 posy0 v0 theta0 phi0]; 
problem.states.x0u=[posx0 posy0 v0 theta0 phi0]; 

% State bounds. xl=< x <=xu
problem.states.xl=[xmin ymin vmin thetamin phimin]; 
problem.states.xu=[xmax ymax vmax thetamax phimax]; 

% State rate bounds. xrl=< x <=xru
problem.states.xrl=[-inf -inf -inf -inf -inf]; 
problem.states.xru=[inf inf inf inf inf]; 

% State error bounds
problem.states.xErrorTol_local=[0.01 0.01 0.01 deg2rad(0.5) deg2rad(2)];
problem.states.xErrorTol_integral=[0.01 0.01 0.01 deg2rad(0.5) deg2rad(2)];

% State constraint error bounds
problem.states.xConstraintTol=[0.01 0.01 0.01 deg2rad(0.1) deg2rad(0.1)];
problem.states.xrConstraintTol=[0.01 0.01 0.01 deg2rad(0.1) deg2rad(0.1)];

% Terminal state bounds. xfl=< xf <=xfu
problem.states.xfl=[posf_x posf_y 0 theta0-deg2rad(5) -deg2rad(1)]; 
problem.states.xfu=[posf_x posf_y 0 theta0+deg2rad(5) deg2rad(1)];

% Guess the state trajectories with [x0 xf]
guess.time=[0 guess.tf/3 guess.tf*2/3 guess.tf];
guess.states(:,1)=[posx0 2 5 posf_x];
guess.states(:,2)=[posy0 0 0 posf_y];
guess.states(:,3)=[v0 0 0 0];
guess.states(:,4)=[theta0 theta0 theta0 0];
guess.states(:,5)=[phi0 0 0 0];

% Number of control actions N 
% Set problem.inputs.N=0 if N is equal to the number of integration steps.  
% Note that the number of integration steps defined in settings.m has to be divisible 
% by the  number of control actions N whenever it is not zero.
problem.inputs.N=0;       
      
% Input bounds
problem.inputs.ul=[amin -curvature_dot_max*l_axes*cos(phimax)^2];
problem.inputs.uu=[amax curvature_dot_max*l_axes*cos(phimax)^2];

problem.inputs.u0l=[amin -curvature_dot_max*l_axes*cos(phimax)^2];
problem.inputs.u0u=[amax curvature_dot_max*l_axes*cos(phimax)^2];

% Input rate bounds
problem.inputs.url=[-u1_max -pi/18];
problem.inputs.uru=[u1_max pi/18];

% Input constraint error bounds
problem.inputs.uConstraintTol=[0.01 deg2rad(0.1)];
problem.inputs.urConstraintTol=[0.01 deg2rad(0.1)];

% Guess the input sequences with [u0 uf]
guess.inputs(:,1)=[amax amin amax 0];
guess.inputs(:,2)=[0 0 0 0];



% Choose the set-points if required
problem.setpoints.states=[];
problem.setpoints.inputs=[];

% Bounds for path constraint function gl =< g(x,u,p,t) =< gu
problem.constraints.ng_eq=0;
problem.constraints.gTol_eq=[];

problem.constraints.gl=zeros(1,1+num_obs);%[-curvature_dot_max, 4];
problem.constraints.gu=zeros(1,1+num_obs);%[curvature_dot_max, inf];
problem.constraints.gTol_neq=zeros(1,1+num_obs);%[deg2rad(0.001), 0.001];
problem.constraints.gl(1,1) = -curvature_dot_max;
problem.constraints.gu(1,1) = curvature_dot_max;
problem.constraints.gTol_neq(1,1)=deg2rad(0.001);
for i=1:num_obs
    problem.constraints.gl(1,1+i)=obs_data(3,i)^2;
    problem.constraints.gu(1,1+i)=inf;
    problem.constraints.gTol_neq(1,1+i)=1e-03;
end


% Bounds for boundary constraints bl =< b(x0,xf,u0,uf,p,t0,tf) =< bu
problem.constraints.bl=[-inf, -inf, -inf, -inf];
problem.constraints.bu=[inf inf inf inf];
problem.constraints.bTol=[1e-03 1e-03 1e-03 1e-03];


% store the necessary problem parameters used in the functions
problem.data.auxdata=auxdata;
problem.data.penalty.values=[50 100 150 200];
problem.data.penalty.i=1;

% Get function handles and return to Main.m
problem.data.InternalDynamics=InternalDynamics;
problem.data.functionfg=@fg;
problem.data.plantmodel = func2str(InternalDynamics);
problem.functions={@L,@E,@f,@g,@avrc,@b};
problem.sim.functions=SimDynamics;
problem.sim.inputX=[];
problem.sim.inputU=1:length(problem.inputs.ul);
problem.functions_unscaled={@L_unscaled,@E_unscaled,@f_unscaled,@g_unscaled,@avrc,@b_unscaled};
problem.data.functions_unscaled=problem.functions_unscaled;
problem.data.ng_eq=problem.constraints.ng_eq;
problem.constraintErrorTol=[problem.constraints.gTol_eq,problem.constraints.gTol_neq,problem.constraints.gTol_eq,problem.constraints.gTol_neq,problem.states.xConstraintTol,problem.states.xConstraintTol,problem.inputs.uConstraintTol,problem.inputs.uConstraintTol];

%------------- END OF CODE --------------

function stageCost=L_unscaled(x,xr,u,ur,p,t,vdat)

% L_unscaled - Returns the stage cost.
% The function must be vectorized and
% xi, ui are column vectors taken as x(:,i) and u(:,i) (i denotes the i-th
% variable)
% 
% Syntax:  stageCost = L(x,xr,u,ur,p,t,data)
%
% Inputs:
%    x  - state vector
%    xr - state reference
%    u  - input
%    ur - input reference
%    p  - parameter
%    t  - time
%    data- structured variable containing the values of additional data used inside
%          the function
%
% Output:
%    stageCost - Scalar or vectorized stage cost
%
%  Remark: If the stagecost does not depend on variables it is necessary to multiply
%          the assigned value by t in order to have right vector dimesion when called for the optimization. 
%          Example: stageCost = 0*t;

%------------- BEGIN CODE --------------


stageCost = 0*t;

%------------- END OF CODE --------------


function boundaryCost=E_unscaled(x0,xf,u0,uf,p,t0,tf,data) 

% E_unscaled - Returns the boundary value cost
%
% Syntax:  boundaryCost=E_unscaled(x0,xf,u0,uf,p,t0,tf,data) 
%
% Inputs:
%    x0  - state at t=0
%    xf  - state at t=tf
%    u0  - input at t=0
%    uf  - input at t=tf
%    p   - parameter
%    tf  - final time
%    data- structured variable containing the values of additional data used inside
%          the function
%
% Output:
%    boundaryCost - Scalar boundary cost
%
%------------- BEGIN CODE --------------

boundaryCost=tf;

%------------- END OF CODE --------------



function bc=b_unscaled(x0,xf,u0,uf,p,t0,tf,vdat,varargin)

% b_unscaled - Returns a column vector containing the evaluation of the boundary constraints: bl =< bf(x0,xf,u0,uf,p,t0,tf) =< bu
%
% Syntax:  bc=b_unscaled(x0,xf,u0,uf,p,t0,tf,vdat,varargin)
%
% Inputs:
%    x0  - state at t=0
%    xf  - state at t=tf
%    u0  - input at t=0
%    uf  - input at t=tf
%    p   - parameter
%    tf  - final time
%    data- structured variable containing the values of additional data used inside
%          the function
%
%          
% Output:
%    bc - column vector containing the evaluation of the boundary function 
%
%------------- BEGIN CODE --------------
varargin=varargin{1};

auxdata = vdat.auxdata;

posyf = xf(2);
thetaf = xf(4);

A_y=posyf+(auxdata.l_axes+auxdata.l_front).*sin(thetaf)+auxdata.b_width.*cos(thetaf);
B_y=posyf+(auxdata.l_axes+auxdata.l_front).*sin(thetaf)-auxdata.b_width.*cos(thetaf);
C_y=posyf-auxdata.l_rear.*sin(thetaf)-auxdata.b_width.*cos(thetaf);
D_y=posyf-auxdata.l_rear.*sin(thetaf)+auxdata.b_width.*cos(thetaf);

bc=[A_y; B_y; C_y; D_y];
%------------- END OF CODE --------------
% When adpative time interval add constraint on time
%------------- BEGIN CODE --------------
if length(varargin)==2
    options=varargin{1};
    t_segment=varargin{2};
    if ((strcmp(options.discretization,'hpLGR')) || (strcmp(options.discretization,'globalLGR')))  && options.adaptseg==1 
        if size(t_segment,1)>size(t_segment,2)
            bc=[bc;diff(t_segment)];
        else
            bc=[bc,diff(t_segment)];
        end
    end
end

%------------- END OF CODE --------------

