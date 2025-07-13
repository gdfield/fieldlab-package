classdef FieldMEARig1 < symphonyui.core.descriptions.RigDescription
    
    methods
        
        function obj = FieldMEARig1()
            import symphonyui.builtin.daqs.*;
            import symphonyui.builtin.devices.*;
            import symphonyui.core.*;
            import edu.washington.*;
    
            % Add the NiDAQ A/D board.
            daq = NiDaqController();
            obj.daqController = daq;                        
         
            % this is Manookin's black magic.
            daq = obj.daqController;
            
            % Add the amplifier. This is a dummy on the MEA, but allows us
            % to use the same protocols on both MEA and patch rigs.
             amp1 = MultiClampDevice('Amp1', 1).bindStream(daq.getStream('ao0')).bindStream(daq.getStream('ai0'));
             obj.addDevice(amp1);
  
%             % Bath temperature
%             temperature = UnitConvertingDevice('Temperature Controller', 'V', 'manufacturer', 'Warner Instruments').bindStream(daq.getStream('ai2'));
%             obj.addDevice(temperature);
            
%             % Get the red sync pulse from the lightcrafter.
%             redTTL = UnitConvertingDevice('Red Sync', 'V').bindStream(daq.getStream('ai6'));
%             obj.addDevice(redTTL);

            % Load Gamma Tables
            ramps = containers.Map();
            ramps('red')    = 65535 * importdata(fieldlab.Package.getCalibrationResource('rigs', 'FieldMEARig1', 'channel_1_green_gamma_ramp.txt'));
            ramps('green')  = 65535 * importdata(fieldlab.Package.getCalibrationResource('rigs', 'FieldMEARig1', 'channel_2_uv_gamma_ramp.txt'));
            ramps('blue')   = 65535 * importdata(fieldlab.Package.getCalibrationResource('rigs', 'FieldMEARig1', 'channel_3_blue_gamma_ramp.txt'));     
            
             %creat lightCrafter object
             lightCrafter = manookinlab.devices.LcrVideoDevice(...
                'micronsPerPixel', 4.0, ...
                'gammaRamps', ramps, ...
                'host', '192.168.1.6', ...
                'local_movie_directory','C:\Users\Public\Documents\GitRepos\Symphony2\movies\',...
                'stage_movie_directory','\\COPLAND\Users\Public\Documents\GitRepos\Symphony2\movies\');
            
            
            
            % load the power/flux measurements from the calibration
            lightCrafter.addResource('fluxFactorPaths', containers.Map( ...
                {'auto', 'red', 'green', 'blue'}, { ...
                fieldlab.Package.getCalibrationResource('rigs', 'FieldMEARig1', 'lightcrafter_below_auto_flux_factors.txt'), ...
                fieldlab.Package.getCalibrationResource('rigs', 'FieldMEARig1', 'lightcrafter_below_red_flux_factors.txt'), ...
                fieldlab.Package.getCalibrationResource('rigs', 'FieldMEARig1', 'lightcrafter_below_green_flux_factors.txt'), ...
                fieldlab.Package.getCalibrationResource('rigs', 'FieldMEARig1', 'lightcrafter_below_blue_flux_factors.txt')}));
            lightCrafter.addConfigurationSetting('lightPath', 'below', 'isReadOnly', true);
            
            % load the emmision spectra of the LEDs
            myspect = containers.Map( ...
                {'auto', 'red', 'green', 'blue'}, { ...
                importdata(fieldlab.Package.getCalibrationResource('rigs', 'FieldMEARig1', 'lightcrafter_below_auto_spectrum.txt')), ...
                importdata(fieldlab.Package.getCalibrationResource('rigs', 'FieldMEARig1', 'lightcrafter_below_green_spectrum.txt')), ...
                importdata(fieldlab.Package.getCalibrationResource('rigs', 'FieldMEARig1', 'lightcrafter_below_uv_spectrum.txt')), ...
                importdata(fieldlab.Package.getCalibrationResource('rigs', 'FieldMEARig1', 'lightcrafter_below_blue_spectrum.txt'))});           
            lightCrafter.addResource('spectrum', myspect);
            
            % Binding the lightCrafter to an unused stream only so its configuration settings are written to each epoch.
            lightCrafter.bindStream(daq.getStream('doport0'));
            daq.getStream('doport0').setBitPosition(lightCrafter, 1);
            
            % add the filter wheel calibrations
            lightCrafter.addConfigurationSetting('ndfs', {}, ...
                'type', PropertyType('cellstr', 'row', {'FW10', 'FW20', 'FW30', 'FW40', 'FW50', 'FW00'}));
            lightCrafter.addResource('ndfAttenuations', containers.Map( ...
                {'auto','red', 'green', 'blue'}, { ...
                containers.Map( ...
                    {'FW10', 'FW20', 'FW30', 'FW40', 'FW50', 'FW00'}, ...
                    {0.9924, 2.13, 2.96, 4.0, 5.0, 0}), ...
                containers.Map( ...
                    {'FW10', 'FW20', 'FW30', 'FW40', 'FW50', 'FW00'}, ...
                    {0.97, 2.06, 2.83, 4.0, 5.0, 0}), ...
                containers.Map( ...
                    {'FW10', 'FW20', 'FW30', 'FW40', 'FW50', 'FW00'}, ...
                    {1.12, 2.23, 3.0, 4.0, 5.0, 0}), ...
                containers.Map( ...
                    {'FW10', 'FW20', 'FW30', 'FW40', 'FW50', 'FW00'}, ...
                    {0.998, 2.16, 3.0, 4.0, 5.0, 0})}));
            
            qCatch = [
               5.184688757116199   0.989878332801999   0.008229213610837   0.145705079000616
               9.159851013454308   5.957476307570245   0.013348490075679   4.331345172549151
               1.224271638811880   1.133503831880406   6.080292576715589   6.361776042858103]*1e4;
            
            lightCrafter.addResource('quantalCatch', qCatch);
            obj.addDevice(lightCrafter);
            
%              % Compute the Quantal catch.
%             qCatch = zeros(3,4);
%             names = {'red','green','blue'};
%             for jj = 1 : length(names)
%                 q = myspect(names{jj});
%                 p = manookinlab.util.PhotoreceptorSpectrum( q(:, 1) );
%                 p = p / sum(p(1, :));
%                 qCatch(jj, :) = p * q(:, 2);
%             end
%             % Add the quantal catch values to the display device. This
%             % saves a record of the values in the data file. It can also
%             % then be used to customize stimuli based on the calibrations
%             % (e.g., cone-isolating stimuli).
%             display_device.addResource('quantalCatch', qCatch);                     
%               
            % This records the flips for each stimulus frame on the DAQ
            % clock. We use this to determine the timing of each stimulus
            % frame presented to the tissue.
            frameMonitor = UnitConvertingDevice('Frame Monitor', 'V').bindStream(obj.daqController.getStream('ai1'));
            obj.addDevice(frameMonitor);            
             
           % Add a device for external triggering to synchronize MEA DAQ clock with Symphony DAQ clock.
%             trigger = riekelab.devices.TriggerDevice();
%             trigger.bindStream(daq.getStream('doport0'));
%             daq.getStream('doport0').setBitPosition(trigger, 0);
%             obj.addDevice(trigger);         
           
            %OLD METHOD FOR DOING THE SAME THING AS ABOVE (SYNC MEA DAQ W/ SYMPHONY).
              trigger = UnitConvertingDevice('ExternalTrigger','V').bindStream(daq.getStream('ao1'));
              obj.addDevice(trigger);  
            
            
           % Add the filter wheel (motorized filter wheel from ThorLabs)
           %filterWheel = manookinlab.devices.FilterWheelDevice('comPort', 'COM5');
           filterWheel = edu.washington.riekelab.devices.FilterWheelDevice('comPort', 'COM5', 'ndfValues', [1.0, 2.0, 3.0, 4.0, 5.0, 0]);
          %  filterWheel = edu.washington.riekelab.devices.FilterWheelDevice('comPort', 'COM5');
          %filterWheel = fieldlab.devices.FilterWheelDevice('comPort', 'COM5'); 
           
           % Binding the filter wheel to an unused stream only so its configuration settings are written to each epoch.
            filterWheel.bindStream(daq.getStream('doport0'));
            daq.getStream('doport0').setBitPosition(filterWheel, 7);
            obj.addDevice(filterWheel);    
%             
           % Add the MEA device controller. This waits for the stream from Vision, strips of the header, and runs the block.
           mea = manookinlab.devices.MEADevice(9001);
           obj.addDevice(mea);
             
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%           
          
            % Rig name and laboratory. This is optional, but can be useful
            % for setting rig-specific parameters. Also, if the user
            % forgets to save the rig description, you will automatically
            % have a record of it saved in your data file.
%           rigDev = manookinlab.devices.RigPropertyDevice('FieldLab','FieldRig');
%           obj.addDevice(rigDev);            
                        
         end
     end
     
 end