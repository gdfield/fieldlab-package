classdef Electrophysiology < symphonyui.core.persistent.descriptions.ExperimentDescription
    
    methods
        
        function obj = Electrophysiology()
            import symphonyui.core.*;
            
            obj.addProperty('experimenter', '', ...
                'description', 'Who performed the experiment');
            obj.addProperty('project', '', ...
                'description', 'Project the experiment belongs to');
            obj.addProperty('institution', 'UCLA', ...
                'description', 'Institution where the experiment was performed');
            obj.addProperty('lab', 'Field Lab', ...
                'description', 'Lab where experiment was performed');
            obj.addProperty('rig', '', ...
                'type', PropertyType('char', 'row', {'', 'Field MEA 1', 'Field MEA 2', 'LightSheet 1', 'Patch 1'}), ...
                'description', 'Rig where experiment was performed');
            
            % Try to auto-detect the appropriate rig property value
            rig = obj.getPropertyDescriptors().findByName('rig');
            index = find(strncmpi(rig.type.domain, getenv('RIG_LETTER'), 1), 1);
            if ~isempty(index)
                rig.value = rig.type.domain{index};
            end
        end
        
    end
    
end

