classdef FieldMEARigBCommon < symphonyui.core.descriptions.RigDescription
    
    methods
        
        function obj = FieldMEARigBCommon()
            import symphonyui.builtin.daqs.*;
            import symphonyui.builtin.devices.*;
            import symphonyui.core.*;
            import common.*;
            %import edu.washington.*;

                     
             % SIMULATION
             %daq = HekaSimulationDaqController();
             %obj.daqController = daq; 
             
            % Add the NiDAQ A/D board.\
 %           daq = NiSimulationDaqController();
            daq = NiDaqController();
            obj.daqController = daq;                        
         
            % this is Manookin's black magic.
            daq = obj.daqController;
            
            % Add the amplifier. This is a dummy on the MEA, but allows us
            % to use the same protocols on both MEA and patch rigs.
             amp1 = MultiClampDevice('Amp1', 1).bindStream(daq.getStream('ao0')).bindStream(daq.getStream('ai0'));
             obj.addDevice(amp1);
                     
            % This records the flips for each stimulus frame on the DAQ
            % clock. We use this to determine the timing of each stimulus
            % frame presented to the tissue.
              frameMonitor = UnitConvertingDevice('Frame Monitor', 'V').bindStream(obj.daqController.getStream('ai1'));
              obj.addDevice(frameMonitor);            
             
             mea = common.devices.MEADevice(5678);
             obj.addDevice(mea);
            
             %add an analog trigger device to simulate the MEA.
%              trigger = UnitConvertingDevice('ExternalTrigger','V').bindStream(daq.getStream('ao1'));
%              obj.addDevice(trigger);
             
             
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%           

           
            % Rig name and laboratory. This is optional, but can be useful
            % for setting rig-specific parameters. Also, if the user
            % forgets to save the rig description, you will automatically
            % have a record of it saved in your data file.
            rigDev = common.devices.RigPropertyDevice('FieldLab','FieldRig');
            obj.addDevice(rigDev);
            
%             geneticVideoDisplay = manookinlab.devices.VideoDevice(...
%                 'micronsPerPixel', 2.4,...
%                 'host',  '192.168.0.3');                 
%             obj.addDevice(geneticVideoDisplay);

            ramps = containers.Map();
            ramps('red')    = 65535 * importdata(fieldlab.Package.getCalibrationResource('rigs', 'FieldMEARig1', 'channel_1_red_gamma_ramp.txt'));
            ramps('green')  = 65535 * importdata(fieldlab.Package.getCalibrationResource('rigs', 'FieldMEARig1', 'channel_2_green_gamma_ramp.txt'));
            ramps('blue')   = 65535 * importdata(fieldlab.Package.getCalibrationResource('rigs', 'FieldMEARig1', 'channel_3_blue_gamma_ramp.txt'));     

             % This connects to Stage as a device. 
             lightCrafter = common.devices.LightCrafterDevice(...
                'micronsPerPixel', 4.5, ...
                'host', '192.168.0.3', ...
                'port',5678,...
                'mode', 'pattern',...
                'local_movie_directory','C:\Users\local-admin\Documents\GitRepos\Symphony2\movies\',...
                'stage_movie_directory','\\Ravel\Users\local-admin\Documents\GitRepos\Symphony2\movies\');
            
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
                importdata(fieldlab.Package.getCalibrationResource('rigs', 'FieldMEARig1', 'auto_LED_spectrum_data.txt')), ...
                importdata(fieldlab.Package.getCalibrationResource('rigs', 'FieldMEARig1', 'red_LED_spectrum_data.txt')), ...
                importdata(fieldlab.Package.getCalibrationResource('rigs', 'FieldMEARig1', 'green_LED_spectrum_data.txt')), ...
                importdata(fieldlab.Package.getCalibrationResource('rigs', 'FieldMEARig1', 'blue_LED_spectrum_data.txt'))});           
            lightCrafter.addResource('spectrum', myspect);
            
            % Binding the lightCrafter to an unused stream only so its configuration settings are written to each epoch.
            lightCrafter.bindStream(daq.getStream('doport0'));
            daq.getStream('doport0').setBitPosition(lightCrafter, 1);

%             geneticVideoDisplay.bindStream(daq.getStream('doport0'));
%             daq.getStream('doport0').setBitPosition(geneticVideoDisplay, 1);


            % add the filter wheel calibrations
            % 'turret' is the fixed NDF in the microscope filter turret (50/50 cube). It is in the
            % light path ~80-90% of the time, so it is checked by default; uncheck it in the Device
            % Configurator for experiments (or epoch blocks) that need higher light levels. Its OD is
            % summed with any active filter-wheel NDF by convisom. Replace 4.3 with per-channel
            % measured values if the turret density is wavelength dependent.
            lightCrafter.addConfigurationSetting('ndfs', {'turret'}, ...
                'type', PropertyType('cellstr', 'row', {'turret', 'FW10', 'FW20', 'FW30', 'FW40', 'FW50', 'FW00'}));
            lightCrafter.addResource('ndfAttenuations', containers.Map( ...
                {'auto','red', 'green', 'blue'}, { ...
                containers.Map( ...
                    {'turret', 'FW10', 'FW20', 'FW30', 'FW40', 'FW50', 'FW00'}, ...
                    {4.3, 0.9924, 2.13, 2.96, 4.0, 5.0, 0}), ...
                containers.Map( ...
                    {'turret', 'FW10', 'FW20', 'FW30', 'FW40', 'FW50', 'FW00'}, ...
                    {4.3, 0.97, 2.06, 2.83, 4.0, 5.0, 0}), ...
                containers.Map( ...
                    {'turret', 'FW10', 'FW20', 'FW30', 'FW40', 'FW50', 'FW00'}, ...
                    {4.3, 1.12, 2.23, 3.0, 4.0, 5.0, 0}), ...
                containers.Map( ...
                    {'turret', 'FW10', 'FW20', 'FW30', 'FW40', 'FW50', 'FW00'}, ...
                    {4.3, 0.998, 2.16, 3.0, 4.0, 5.0, 0})}));
            
            qCatch = [
               5.184688757116199   0.989878332801999   0.008229213610837   0.145705079000616
               9.159851013454308   5.957476307570245   0.013348490075679   4.331345172549151
               1.224271638811880   1.133503831880406   6.080292576715589   6.361776042858103]*1e4;
            
            lightCrafter.addResource('quantalCatch', qCatch);
            obj.addDevice(lightCrafter);    
            
           % Add the filter wheel (motorized filter wheel from ThorLabs).
           % When useWheelSync is true, moving the wheel mirrors its ND value onto
           % the lightCrafter 'ndfs' setting (preserving the turret), so the
           % isomerization calibration tracks the physical wheel automatically.
           % Set useWheelSync = false to revert to a plain, unsynced filter wheel.
           useWheelSync = true;
           if useWheelSync
               filterWheel = fieldlab.devices.SyncedFilterWheelDevice('comPort', 'COM3', 'ndfValues', [1.0, 2.0, 3.0, 4.0, 5.0, 0]);
               filterWheel.setLightSource(lightCrafter);
           else
               filterWheel = common.devices.FilterWheelDevice('comPort', 'COM3', 'ndfValues', [1.0, 2.0, 3.0, 4.0, 5.0, 0]);
           end

           % Binding the filter wheel to an unused stream only so its configuration settings are written to each epoch.
            filterWheel.bindStream(daq.getStream('doport0'));
            daq.getStream('doport0').setBitPosition(filterWheel, 3);
            obj.addDevice(filterWheel);
        end
    end    
 end