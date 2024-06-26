classdef Preparation < fieldlab.sources.Preparation
    
    methods
        
        function obj = Preparation()
            import symphonyui.core.*;
            
            obj.addAllowableParentType('manookinlab.sources.primate.Primate');
        end
        
    end
    
end

