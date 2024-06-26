classdef FieldMEARigA < symphonyui.core.descriptions.RigDescription
    
    methods
        
        function obj = FieldMEARigA()
            import symphonyui.builtin.daqs.*;
            import symphonyui.builtin.devices.*;
            import symphonyui.core.*;
                     
             % SIMULATION
%              daq = HekaSimulationDaqController();
%              obj.daqController = daq; 
%              frameMonitor = UnitConvertingDevice('Frame Monitor', 'V').bindStream(obj.daqController.getStream('ai7'));
%              obj.addDevice(frameMonitor);  
             
            % REAL
            % Add the NiDAQ A/D board.
            daq = NiDaqController();
            obj.daqController = daq;                        
            
            % This records the flips for each stimulus frame on the DAQ
            % clock. We use this to determine the timing of each stimulus
            % frame presented to the tissue.
             frameMonitor = UnitConvertingDevice('Frame Monitor', 'V').bindStream(obj.daqController.getStream('ai1'));
             obj.addDevice(frameMonitor);            
             
             mea = manookinlab.devices.MEADevice(9001);
             obj.addDevice(mea);
            
             %add an analog trigger device to simulate the MEA.
             trigger = UnitConvertingDevice('ExternalTrigger','V').bindStream(daq.getStream('ao1'));
             obj.addDevice(trigger);
             
             
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%           

           
            % Rig name and laboratory. This is optional, but can be useful
            % for setting rig-specific parameters. Also, if the user
            % forgets to save the rig description, you will automatically
            % have a record of it saved in your data file.
%            rigDev = manookinlab.devices.RigPropertyDevice('FieldLab','FieldRig');
%            obj.addDevice(rigDev);
            
            % Add the amplifier. This is a dummy on the MEA, but allows us
            % to use the same protocols on both MEA and patch rigs.
             amp1 = MultiClampDevice('Amp1', 1).bindStream(daq.getStream('ao0')).bindStream(daq.getStream('ai0'));
             obj.addDevice(amp1);
            

            
            % Load Gamma Tables
             ramps = containers.Map();
             ramps('green') = 65535 * importdata('C:\Users\Public\Documents\Calibration\channel_1_green_gamma_ramp.txt', '\t');
             ramps('uv') = 65535 * importdata('C:\Users\Public\Documents\Calibration\channel_2_uv_gamma_ramp.txt', '\t');
             ramps('blue') = 65535 * importdata('C:\Users\Public\Documents\Calibration\channel_3_blue_gamma_ramp.txt', '\t');
             
%              ramps('red')    = 65535 * importdata(riekelab.Package.getCalibrationResource('rigs', 'suction', 'red_gamma_ramp.txt'));
%              ramps('green')  = 65535 * importdata(riekelab.Package.getCalibrationResource('rigs', 'suction', 'green_gamma_ramp.txt'));
%              ramps('blue')   = 65535 * importdata(riekelab.Package.getCalibrationResource('rigs', 'suction', 'blue_gamma_ramp.txt'));
 

             % This connects to Stage as a device. 
              display_device = manookinlab.devices.LcrVideoDevice(...
                   'micronsPerPixel', 1.28, ...
                   'host', '10.4.192.148', ...
                   'customLightEngine',false);
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
           
            % Load the spectra.
            myspect = containers.Map( ...
                {'green', 'uv', 'blue'}, { ...
                importdata('C:\Users\Public\Documents\Calibration\channel_1_green_spec.txt', '\t'), ...
                importdata('C:\Users\Public\Documents\Calibration\channel_2_uv_spec.txt', '\t'), ...
                importdata('C:\Users\Public\Documents\Calibration\channel_3_blue_spec.txt', '\t')});

                %             myspect = containers.Map( ...
%                 {'white', 'red', 'green', 'blue'}, { ...
%                 importdata(manookinlab.Package.getCalibrationResource('rigs', 'mea', 'microdisplay_below_white_spectrum.txt')), ...
%                 importdata(manookinlab.Package.getCalibrationResource('rigs', 'mea', 'microdisplay_below_red_spectrum.txt')), ...
%                 importdata(manookinlab.Package.getCalibrationResource('rigs', 'mea', 'microdisplay_below_green_spectrum.txt')), ...
%                 importdata(manookinlab.Package.getCalibrationResource('rigs', 'mea', 'microdisplay_below_blue_spectrum.txt'))});
            
             display_device.addResource('spectrum', myspect);
            
            % Compute the Quantal catch.
            qCatch = zeros(3,4);
            names = {'green','uv','blue'};
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