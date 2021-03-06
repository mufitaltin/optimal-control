classdef Simulator < handle
  
  properties
    integrator
    system
  end
  
  methods (Static)
    function options = getOptions()
      options = struct;
    end
  end
  
  methods
    
    function self = Simulator(system,options)
      self.integrator = CasadiIntegrator(system);
      self.system = system;
      
      self.system.systemFun = CasadiFunction(self.system.systemFun);
    end
    
    function p = getParameters(self)
      p = Arithmetic(self.system.parametersStruct,0);
    end
    
    function controls = getControlsSeries(self,N)
        controlsSeriesStruct  = TreeNode('controls');
        controlsSeriesStruct.addRepeated({self.system.controlsStruct},N);
        controls = Arithmetic(controlsSeriesStruct,0);
        controls = controls.get('controls');
    end
    
    function [statesVec,algVarsVec,controlsSeries] = simulate(self,initialStates,times,varargin)
      % [statesVec,algVarsVec,controlsVec] = simulate(self,initialState,times,parameters)
      % [statesVec,algVarsVec,controlsVec] = simulate(self,initialState,times,controlsSeries,parameters)
      % [statesVec,algVarsVec,controlsVec] = simulate(self,initialState,times,controlsSeries,parameters,callback)
      
      N = length(times)-1;
      callback = true;
      
      times = Arithmetic.Matrix(times);
      
      if nargin == 4
        parameters      = varargin{1};
        controlsSeries = getControlsSeries(self,N);
      elseif nargin == 5
        controlsSeries  = varargin{1};
        parameters      = varargin{2};
      elseif nargin == 6
        controlsSeries  = varargin{1};
        parameters      = varargin{2};
        callback        = varargin{3};
      end
      
      simVarsStruct = TreeNode('simVars');
      simVarsStruct.addRepeated({self.system.statesStruct},N+1);
      simVarsStruct.addRepeated({self.system.algVarsStruct},N);
      
      algVars = Arithmetic(self.system.algVarsStruct,0);
      simVars = Arithmetic(simVarsStruct,0);
      
      if nargin == 4
        controls = self.system.callIterationCallback(initialStates,algVars,parameters);
      elseif nargin == 5 || nargin == 6
        controls = controlsSeries.slice(1);
      end
      
      [states,algVars] = self.getConsistentIntitialCondition(initialStates,algVars,controls,parameters);
      
 
      simVars.get('states',1).set(states);
      
      % setup callback
      if callback
        self.system.simulationCallbackSetup;
      end
      
      for k=1:N
        timestep = times(k+1)-times(k);
        
        if nargin == 4
          controls = self.system.callIterationCallback(states,algVars,parameters);
        elseif nargin == 5 || nargin == 6
          if callback
            self.system.callIterationCallback(states,algVars,parameters);
          end
          controls = controlsSeries.slice(k);
        end
        
        [statesVal,algVarsVal] = self.integrator.evaluate(states,algVars,controls,timestep,parameters);
        
        simVars.get('states',k+1).set(statesVal);
        
        if ~isempty(algVarsVal)
          simVars.get('algVars',k).set(algVarsVal);
        end
        controlsSeries.slice(k).set(controls);
        
        states.set(statesVal);
        algVars.set(algVarsVal);
      end  
      
      statesVec = simVars.get('states');
      algVarsVec = simVars.get('algVars');
      
    end
    
    function states = getStates(self)
      states = Arithmetic(self.system.statesStruct,0);
    end
    
    function [statesOut,algVarsOut] = getConsistentIntitialCondition(self,states,algVars,controls,parameters)
      
      varsOutStruct = TreeNode('varsOut');
      varsOutStruct.add(states.varStructure);
      varsOutStruct.add(algVars.varStructure);
      
      varsOut = Arithmetic(varsOutStruct,0);
            
      % check initial condition
      constraints = self.system.getInitialCondition(states,parameters);
      
      % append algebraic equation
      [ode,alg] = self.system.systemFun.evaluate(states,algVars,controls,parameters);
      
      constraints = [constraints;alg];
      
%       if ~all(constraints.value==0)
        warning('Initial state is not consistent, trying to find a consistent initial condition...');
        stateSym  = CasadiArithmetic(states.varStructure);
        algVarsSym  = CasadiArithmetic(algVars.varStructure);
        
        constraints = self.system.getInitialCondition(stateSym,parameters);
        [ode,alg] = self.system.systemFun.evaluate(stateSym,algVarsSym,controls,parameters);
        constraints = [constraints;alg];
        
        algVars.set(rand);
        
        optVars = [stateSym;algVarsSym];
        x0      = [states;algVars];
        
        statesErr = (-states+stateSym);
        cost = statesErr'*statesErr;
        
        nlp    = struct('x', optVars.value, 'f', cost.value, 'g', constraints.value);
        solver = casadi.nlpsol('solver', 'ipopt', nlp);
        sol    = solver('x0', x0.value, 'lbx', -inf, 'ubx', inf,'lbg', 0, 'ubg', 0);

        varsOut.set(full(sol.x));
        
%       end
      
      statesOut = varsOut.get('states');
      algVarsOut = varsOut.get('algVars');
      
    end
    
  end
  
end
