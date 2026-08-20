classdef SyncedFilterWheelDevice < fieldlab.devices.FilterWheelDevice
    % Filter wheel that mirrors its physical ND value onto a light-source
    % device's 'ndfs' configuration setting, and records the resolved optical
    % density used in the calibration.
    %
    % Why: the isomerization calibration (common.util.convisom, the
    % IsomerizationsConverter module, and addConversionFactors) reads the active
    % NDF attenuation ONLY from the light-source device's 'ndfs' setting. The
    % physical ThorLabs wheel lives on a separate FilterWheel device. Without a
    % bridge, the two must be kept consistent by hand. This subclass copies the
    % wheel's ND value into the light source's 'ndfs' whenever the wheel moves,
    % so the calibration tracks the real wheel automatically.
    %
    % Behaviour:
    %   * One-directional: wheel -> light source 'ndfs'. The physical wheel is
    %     ground truth; manual edits made in the Device Configurator are
    %     overwritten on the next wheel move.
    %   * The fixed 'turret' NDF is PRESERVED: if 'turret' is currently selected
    %     on the light source it is kept; the wheel only owns the FWxx entry.
    %   * ND value 0 (open position) mirrors to no FWxx entry.
    %
    % Optical density recording: the epoch h5 stores the ACTIVE ndf NAMES
    % ('turret', 'FW30', ...), while the measured attenuations live in the light
    % source's 'ndfAttenuations' resource. To make the actual attenuation
    % self-contained per epoch, this device also maintains read-only
    % configuration settings 'ndfOD_<channel>' (e.g. ndfOD_auto, ndfOD_red,
    % ndfOD_green, ndfOD_blue) holding the summed optical density of all active
    % NDFs (turret + wheel) for each channel. Because this device is bound to a
    % stream in the rig, those settings are written to every epoch. The values
    % track any change to the light source's 'ndfs' (wheel move OR a manual
    % turret toggle in the Device Configurator). Attenuation factor = 10^-OD.
    %
    % Reverting: construct a plain FilterWheelDevice instead (see the
    % 'useWheelSync' flag in the rig files). This class then simply goes unused.
    %
    % Usage (in a rig):
    %   filterWheel = fieldlab.devices.SyncedFilterWheelDevice('comPort', 'COM5', ...
    %       'ndfValues', [1.0, 2.0, 3.0, 4.0, 5.0, 0]);
    %   filterWheel.setLightSource(lightCrafter);   % the device that owns 'ndfs'

    properties (Access = private)
        lightSource = []
        ndfsListener = []
    end

    methods

        function obj = SyncedFilterWheelDevice(varargin)
            obj@fieldlab.devices.FilterWheelDevice(varargin{:});
        end

        function setLightSource(obj, device)
            % Register the light-source device whose 'ndfs' setting mirrors the
            % wheel. Pass [] to disable syncing (device behaves like the base).
            obj.lightSource = device;
            obj.setupOpticalDensityRecording();
        end

        function setNDF(obj, nd)
            % Move the wheel (base behaviour), then mirror onto the light source.
            % Only mirror when the wheel is actually connected, so a disconnected
            % wheel never rewrites the calibration ndfs.
            setNDF@fieldlab.devices.FilterWheelDevice(obj, nd);
            if obj.isConnected()
                obj.syncLightSourceNdfs(nd);
            end
        end

    end

    methods (Access = private)

        function syncLightSourceNdfs(obj, nd)
            if isempty(obj.lightSource)
                return;
            end
            try
                desc = obj.lightSource.getConfigurationSettingDescriptors().findByName('ndfs');
                if isempty(desc)
                    return;
                end
                domain = desc.type.domain;
                current = obj.lightSource.getConfigurationSetting('ndfs');

                ndfs = {};
                % Preserve the fixed turret NDF if it is currently selected.
                if any(strcmp(current, 'turret'))
                    ndfs{end+1} = 'turret';
                end
                % Mirror the wheel NDF (skip 0 = open position, no attenuation).
                if nd ~= 0
                    name = sprintf('FW%02d', round(nd * 10));
                    if any(strcmp(domain, name))
                        ndfs{end+1} = name;
                    else
                        warning('SyncedFilterWheelDevice:unknownNdf', ...
                            'No ''ndfs'' entry ''%s'' on %s; wheel NDF %g not mirrored.', ...
                            name, obj.lightSource.name, nd);
                    end
                end

                obj.lightSource.setConfigurationSetting('ndfs', ndfs);
            catch e
                warning('SyncedFilterWheelDevice:syncFailed', ...
                    'Failed to mirror wheel NDF onto light source: %s', e.message);
            end
        end

        function setupOpticalDensityRecording(obj)
            % Declare one read-only 'ndfOD_<channel>' setting per channel and
            % start tracking the light source's 'ndfs' so they stay current.
            % Runs during rig construction, so any failure degrades to "no OD
            % recording" rather than breaking rig load.
            if ~isempty(obj.ndfsListener)
                delete(obj.ndfsListener);
                obj.ndfsListener = [];
            end
            if isempty(obj.lightSource) ...
                    || ~any(strcmp('ndfAttenuations', obj.lightSource.getResourceNames()))
                return;
            end
            try
                channels = obj.lightSource.getResource('ndfAttenuations').keys;
                for i = 1:numel(channels)
                    name = ['ndfOD_' channels{i}];
                    if ~obj.hasConfigurationSetting(name)
                        obj.addConfigurationSetting(name, 0, 'isReadOnly', true);
                    end
                end

                obj.ndfsListener = addlistener(obj.lightSource, 'SetConfigurationSetting', ...
                    @(~, event)obj.onLightSourceConfigChanged(event));

                obj.updateOpticalDensity();
            catch e
                warning('SyncedFilterWheelDevice:odSetupFailed', ...
                    'Failed to set up NDF optical density recording: %s', e.message);
            end
        end

        function onLightSourceConfigChanged(obj, event)
            if strcmp(event.data.name, 'ndfs')
                obj.updateOpticalDensity();
            end
        end

        function updateOpticalDensity(obj)
            % Sum the measured optical density of every active NDF (turret +
            % wheel) for each channel and record it on this device.
            if isempty(obj.lightSource) ...
                    || ~any(strcmp('ndfAttenuations', obj.lightSource.getResourceNames()))
                return;
            end
            try
                attenuations = obj.lightSource.getResource('ndfAttenuations');
                ndfs = obj.lightSource.getConfigurationSetting('ndfs');
                channels = attenuations.keys;
                for i = 1:numel(channels)
                    ch = channels{i};
                    map = attenuations(ch);
                    od = 0;
                    for j = 1:numel(ndfs)
                        nm = strtrim(ndfs{j});
                        if map.isKey(nm)
                            od = od + map(nm);
                        end
                    end
                    obj.setReadOnlyConfigurationSetting(['ndfOD_' ch], od);
                end
            catch e
                warning('SyncedFilterWheelDevice:odUpdateFailed', ...
                    'Failed to record NDF optical density: %s', e.message);
            end
        end

    end

end
