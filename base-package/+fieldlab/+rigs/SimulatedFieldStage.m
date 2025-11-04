classdef SimulatedFieldStage < symphonyui.core.descriptions.RigDescription
    
    methods
        
        function obj = SimulatedFieldStage()
            import symphonyui.builtin.daqs.*;
            import s
            
            ymphonyui.builtin.devices.*;
            import symphonyui.core.*;
            
            daq = HekaSimulationDaqController();
            obj.daqController = daq;
                        
            amp1 = MultiClampDevice('Amp1', 1).bindStream(daq.getStream('ao0')).bindStream(daq.getStream('ai0'));
            obj.addDevice(amp1);
                        
            frameMonitor = UnitConvertingDevice('Frame Monitor', 'V').bindStream(obj.daqController.getStream('ai1'));
            obj.addDevice(frameMonitor);
            
            geneticVideoDisplay = manookinlab.devices.VideoDevice(...
                'micronsPerPixel', 2.4,...
                'host', '10.4.192.148');                 
            obj.addDevice(geneticVideoDisplay);
            
        end
    end
    
end

