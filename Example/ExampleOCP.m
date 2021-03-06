classdef ExampleOCP < OCP
  % An OCP is defined by inheriting from the OCP class.
  
  methods
    function self = ExampleOCP(system)
      % The constructor of OCP takes an instance of the system.
      % The end time of the horizon can be set to a real number, 
      % otherwise its 'free'.
      self = self@OCP(system);
    end
    function pathCosts(self,states,algVars,controls,time,endTime,parameters)
      % Define lagrange (intermediate) cost terms.
      
      self.addPathCost( states.x^2 );
      self.addPathCost( states.y^2 );
      self.addPathCost( controls.u^2 );
    end
    function arrivalCosts(self,states,endTime,parameters)
      % Define terminal cost terms.
    end
    function pathConstraints(self,states,algVars,controls,time,parameters)
      % Define non-linear path constraints on variables.
    end    
    function boundaryConditions(self,states0,statesF,parameters)
      % Define non-linear terminal constraints.
    end
    
    function iterationCallback(self,variables)
      
      times = 0:10/30:10;
      hold off
      plot(times,variables.states.x.value,'-.')
      hold on
      plot(times,variables.states.z.value,'--k')
      stairs(times(1:end-1),variables.controls.u.value,'r')
      xlabel('time')
      legend({'x','y','u'})
      
      drawnow;
      waitforbuttonpress
      
    end
    
  end
  
end

