classdef FieldRig < symphonyui.core.descriptions.RigDescription
    
    methods
        
        function obj = FieldRig()
            import symphonyui.builtin.daqs.*;
            import symphonyui.builtin.devices.*;
            import symphonyui.core.*;
            
            % This is the simulation A/D board (i.e., not real). We'll add
            % the real one later...
            daq = HekaSimulationDaqController();
            obj.daqController = daq;
            
            % Rig name and laboratory. This is optional, but can be useful
            % for setting rig-specific parameters. Also, if the user
            % forgets to save the rig description, you will automatically
            % have a record of it saved in your data file.
            rigDev = manookinlab.devices.RigPropertyDevice('FieldLab','FieldRig');
            obj.addDevice(rigDev);
            
            % Add the amplifier. This is a dummy on the MEA, but allows us
            % to use the same protocols on both MEA and patch rigs.
            amp1 = MultiClampDevice('Amp1', 1).bindStream(daq.getStream('ao0')).bindStream(daq.getStream('ai0'));
            obj.addDevice(amp1);
            
            % This records the flips for each stimulus frame on the DAQ
            % clock. We use this to determine the timing of each stimulus
            % frame presented to the tissue.
            frameMonitor = UnitConvertingDevice('Frame Monitor', 'V').bindStream(obj.daqController.getStream('ai7'));
            obj.addDevice(frameMonitor);
            
            % This connects to Stage as a device. 
            display_device = manookinlab.devices.VideoDevice('host', '192.168.0.102', 'micronsPerPixel', 3.8);
            
            % Load the spectra.
            myspect = containers.Map( ...
                {'white', 'red', 'green', 'blue'}, { ...
                importdata(manookinlab.Package.getCalibrationResource('rigs', 'mea', 'microdisplay_below_white_spectrum.txt')), ...
                importdata(manookinlab.Package.getCalibrationResource('rigs', 'mea', 'microdisplay_below_red_spectrum.txt')), ...
                importdata(manookinlab.Package.getCalibrationResource('rigs', 'mea', 'microdisplay_below_green_spectrum.txt')), ...
                importdata(manookinlab.Package.getCalibrationResource('rigs', 'mea', 'microdisplay_below_blue_spectrum.txt'))});
            
            display_device.addResource('spectrum', myspect);
            
            % Compute the Quantal catch.
            qCatch = zeros(3,4);
            names = {'red','green','blue'};
            for jj = 1 : length(names)
                q = myspect(names{jj});
                p = manookinlab.util.PhotoreceptorSpectrum( q(:, 1) );
                p = p / sum(p(1, :));
                qCatch(jj, :) = p * q(:, 2);
            end
            % Add the quantal catch values to the display device. This
            % saves a record of the values in the data file. It can also
            % then be used to customize stimuli based on the calibrations
            % (e.g., cone-isolating stimuli).
            display_device.addResource('quantalCatch', qCatch);
            
            obj.addDevice(display_device);
            
            % Add the filter wheel (motorized filter wheel from ThorLabs)
            filterWheel = manookinlab.devices.FilterWheelDevice('comPort', 'COM13');
            obj.addDevice(filterWheel);
        end
    end
    
end