classdef FieldLabDemo < symphonyui.core.descriptions.RigDescription
    
    methods
        
        function obj = FieldLabDemo()
            import symphonyui.builtin.daqs.*;
            import symphonyui.builtin.devices.*;
            
            daq = HekaSimulationDaqController();
            obj.daqController = daq;

            % Add a MultiClamp 700B device with name = Amp, channel = 1
            amp = MultiClampDevice('Amp', 1).bindStream(daq.getStream('ao0')).bindStream(daq.getStream('ai0'));
            obj.addDevice(amp);

            % Add a LED device with name = Green LED, units = volts
            green = UnitConvertingDevice('Green LED', 'V').bindStream(daq.getStream('ao1'));
            green.addConfigurationSetting('ndfs', '0.3');
            green.addConfigurationSetting('gain', 'high');
            table = [...
                321, 0.00;
                513, 0.72;
                741, 0.00];   
            green.addResource('spectrum', table)
            green.addResource('calibration', 1.2)
            obj.addDevice(green);
            

        end
            
    end
    
end

