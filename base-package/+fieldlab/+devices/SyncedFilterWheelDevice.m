classdef SyncedFilterWheelDevice < fieldlab.devices.FilterWheelDevice
    % Filter wheel that mirrors its physical ND value onto a light-source
    % device's 'ndfs' configuration setting.
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
    % Reverting: construct a plain FilterWheelDevice instead (see the
    % 'useWheelSync' flag in the rig files). This class then simply goes unused.
    %
    % Usage (in a rig):
    %   filterWheel = fieldlab.devices.SyncedFilterWheelDevice('comPort', 'COM5', ...
    %       'ndfValues', [1.0, 2.0, 3.0, 4.0, 5.0, 0]);
    %   filterWheel.setLightSource(lightCrafter);   % the device that owns 'ndfs'

    properties (Access = private)
        lightSource = []
    end

    methods

        function obj = SyncedFilterWheelDevice(varargin)
            obj@fieldlab.devices.FilterWheelDevice(varargin{:});
        end

        function setLightSource(obj, device)
            % Register the light-source device whose 'ndfs' setting mirrors the
            % wheel. Pass [] to disable syncing (device behaves like the base).
            obj.lightSource = device;
        end

        function setNDF(obj, nd)
            % Move the wheel (base behaviour), then mirror onto the light source.
            setNDF@fieldlab.devices.FilterWheelDevice(obj, nd);
            obj.syncLightSourceNdfs(nd);
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

    end

end
