classdef Preparation < fieldlab.sources.Preparation
    
    methods
        
        function obj = Preparation()
            import symphonyui.core.*;
            
            obj.addAllowableParentType('fieldlab.sources.marmoset.Marmoset');
        end
        
    end
    
end

