classdef SimulatedMEA < symphonyui.core.descriptions.RigDescription
    
    methods
        
        function obj = SimulatedMEA()
            import symphonyui.builtin.daqs.*;
            import symphonyui.builtin.devices.*;
            import symphonyui.core.*;
            
            % This is the simulation A/D board (i.e., not real). We'll add
            % the real one later...
            daq = HekaSimulationDaqController();
            obj.daqController = daq;
 
%            mea = manookinlab.devices.MEADevice('host', '192.168.1.1'); % this might need to be .1.100
            mea = manookinlab.devices.MEADevice(9001);
            obj.addDevice(mea);

            
            %add an analog trigger device to simulate the MEA.
            trigger = UnitConvertingDevice('ExternalTrigger','V').bindStream(daq.getStream('ao1'));
            obj.addDevice(trigger);
            
            % Add the amplifier. This is a dummy on the MEA, but allows us
            % to use the same protocols on both MEA and patch rigs.
            amp1 = MultiClampDevice('Amp1', 1).bindStream(daq.getStream('ao0')).bindStream(daq.getStream('ai0'));
            obj.addDevice(amp1);
            
            % This records the flips for each stimulus frame on the DAQ
            % clock. We use this to determine the timing of each stimulus
            % frame presented to the tissue.
            frameMonitor = UnitConvertingDevice('Frame Monitor', 'V').bindStream(obj.daqController.getStream('ai7'));
            obj.addDevice(frameMonitor);

            % Rig name and laboratory. This is optional, but can be useful
            % for setting rig-specific parameters. Also, if the user
            % forgets to save the rig description, you will automatically
            % have a record of it saved in your data file.
            rigDev = manookinlab.devices.RigPropertyDevice('FieldLab','FieldRig');
            obj.addDevice(rigDev);
            
            % This connects to Stage as a device. 
%            display_device = manookinlab.devices.VideoDevice('micronsPerPixel', 2.0);
            display_device = manookinlab.devices.VideoDevice('host', '10.4.192.108', 'micronsPerPixel', 2.0);         

            
%              display_device = manookinlab.devices.LcrVideoDevice(...
%                   'micronsPerPixel', 1.28, ...
%                   'host', '10.4.192.148', ...
%                   'customLightEngine',false);
            obj.addDevice(display_device);
            
            
        end
    end   
end