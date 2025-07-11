classdef Preparation < fieldlab.sources.Preparation
    
    methods
        
        function obj = Preparation()
            import symphonyui.core.*;
            obj.addAllowableParentType('fieldlab.sources.mouse.Mouse');
            
            %obj.addAllowableParentType('edu.washington.riekelab.sources.mouse.Mouse');
        end
        
    end
    
end

