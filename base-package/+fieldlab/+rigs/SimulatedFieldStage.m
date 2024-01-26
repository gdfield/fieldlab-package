classdef SimulatedFieldStage < symphonyui.core.descriptions.RigDescription
    
    methods
        
        function obj = SimulatedFieldStage()
            import symphonyui.builtin.daqs.*;
            import symphonyui.builtin.devices.*;
            import symphonyui.core.*;
            
            daq = HekaSimulationDaqController();
            obj.daqController = daq;
            
            % Rig name and laboratory.
            rigDev = manookinlab.devices.RigPropertyDevice('ManookinLab','SimulatedStage');
            obj.addDevice(rigDev);
            
            amp1 = MultiClampDevice('Amp1', 1).bindStream(daq.getStream('ao0')).bindStream(daq.getStream('ai0'));
            obj.addDevice(amp1);

            % Add an analog trigger device to simulate the MEA.
            trigger = UnitConvertingDevice('ExternalTrigger', 'V').bindStream(daq.getStream('ao1'));
            obj.addDevice(trigger);
                        
            frameMonitor = UnitConvertingDevice('Frame Monitor', 'V').bindStream(obj.daqController.getStream('ai7'));
            obj.addDevice(frameMonitor);
            
            geneticVideoDisplay = manookinlab.devices.VideoDevice('micronsPerPixel', 2.4);                 
            obj.addDevice(microdisplay);
            
        end
    end
    
end

