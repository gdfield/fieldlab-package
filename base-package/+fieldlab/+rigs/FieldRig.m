classdef FieldRig < symphonyui.core.descriptions.RigDescription
    
    methods
        
        function obj = FieldRig()
            import symphonyui.builtin.daqs.*;
            import symphonyui.builtin.devices.*;
            import symphonyui.core.*;
            
            % This is the simulation A/D board (i.e., not real). We'll add
            % the real one later...
 %           daq = HekaSimulationDaqController();
 %           obj.daqController = daq;
 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%           
            % Add the NiDAQ A/D board.
            daq = NiDaqController();
            obj.daqController = daq;
            
%            mea = manookinlab.devices.MEADevice('host', '192.168.1.100'); % this might need to be .1.100
            mea = manookinlab.devices.MEADevice(9001);
            obj.addDevice(mea);

%            rigDev = manookinlab.devices.RigPropertyDevice('ManookinLab','SimulatedMEA');
%            obj.addDevice(rigDev);
            
            %trigger = edu.washington.riekelab.devices.TriggerDevice();
            %trigger.bindStream(daq.getStream('doport0'));
            %trigger.bindStream(daq.getStream('ao1'));
            %daq.getStream('doport0').setBitPosition(trigger, 0);
            %obj.addDevice(trigger);
           
            %add an analog trigger device to simulate the MEA.
            trigger = UnitConvertingDevice('ExternalTrigger','V').bindStream(daq.getStream('ao1'));
            obj.addDevice(trigger);
            
            
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%           

           
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
            frameMonitor = UnitConvertingDevice('Frame Monitor', 'V').bindStream(obj.daqController.getStream('ai1'));
            obj.addDevice(frameMonitor);
            
            % This connects to Stage as a device. 
            display_device = manookinlab.devices.VideoDevice('host', '192.168.1.4', 'micronsPerPixel', 3.8);
            
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%             %microdisplay = riekelab.devices.MicrodisplayDevice('gammaRamps', ramps, 'micronsPerPixel', 3.8, 'comPort', 'COM3', 'host', '10.47.120.58');
%             ramps = containers.Map();
%             ramps('minimum') = linspace(0, 65535, 256);
%             ramps('low')     = 65535 * importdata(riekelab.Package.getCalibrationResource('rigs', 'mea', 'microdisplay_below_low_gamma_ramp.txt'));
%             ramps('medium')  = 65535 * importdata(riekelab.Package.getCalibrationResource('rigs', 'mea', 'microdisplay_below_medium_gamma_ramp.txt'));
%             ramps('high')    = 65535 * importdata(riekelab.Package.getCalibrationResource('rigs', 'mea', 'microdisplay_below_high_gamma_ramp.txt'));
%             ramps('maximum') = linspace(0, 65535, 256);
%             microdisplay = riekelab.devices.MicrodisplayDevice('gammaRamps', ramps, 'micronsPerPixel', 3.8, 'comPort', 'COM3', 'host', '10.47.120.58');
%             microdisplay.bindStream(daq.getStream('doport1'));
%             daq.getStream('doport1').setBitPosition(microdisplay, 15);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            
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
            filterWheel = manookinlab.devices.FilterWheelDevice('comPort', 'COM3');
            obj.addDevice(filterWheel);
        end
    end
    
end