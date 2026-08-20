classdef FilterWheelDevice < symphonyui.core.Device
    % ThorLabs motorized ND filter wheel.
    %
    % Fieldlab-local version of common.devices.FilterWheelDevice. It adds an
    % optional 'name' parameter so that multiple filter wheels can coexist in
    % a single rig with distinct, individually-addressable device names
    % (Symphony resolves devices by name, so duplicates are not allowed).
    %
    % Name/value parameters:
    %   'name'      - Device name (default 'FilterWheel')
    %   'comPort'   - Serial port the wheel is on (default 'COM13')
    %   'NDF'       - Initial ND filter value to move to (default 4.0)
    %   'ndfValues' - Ordered ND values at wheel positions 1..N
    %                 (default [0 0.5 1.0 2.0 3.0 4.0])

    properties (Access = private)
        wheelPosition
        ndf
    end

    properties (Access = private)
        filterWheel
        ndfValues % = [0 0.5 1.0 2.0 3.0 4.0];
        isOpen
        useLegacySerial = false  % true when connected via the legacy serial() API
    end

    methods
        function obj = FilterWheelDevice(varargin)

            ip = inputParser();
            ip.addParameter('name', 'FilterWheel', @ischar);
            ip.addParameter('comPort', 'COM13', @ischar);
            ip.addParameter('NDF', 4.0, @isnumeric);
            ip.addParameter('ndfValues', [0 0.5 1.0 2.0 3.0 4.0], @isnumeric);
            ip.parse(varargin{:});

            cobj = Symphony.Core.UnitConvertingExternalDevice(ip.Results.name, 'ThorLabs', Symphony.Core.Measurement(0, symphonyui.core.Measurement.UNITLESS));
            obj@symphonyui.core.Device(cobj);
            obj.cobj.MeasurementConversionTarget = symphonyui.core.Measurement.UNITLESS;

            obj.addConfigurationSetting('NDF', 4.0);
            obj.ndfValues = ip.Results.ndfValues;

            obj.addConfigurationSetting('ndfValues', obj.ndfValues);

            % Try to connect.
            obj.connect(ip.Results.comPort);

            if obj.isOpen
                obj.setNDF(ip.Results.NDF);
                obj.ndf = 4;
            end
        end

        function connect(obj, comPort)
            % Prefer the modern serialport() API; fall back to the legacy
            % serial() API on setups (e.g. FieldMEARig1) where serialport()
            % cannot open the port but serial() can.
            try
                obj.filterWheel = serialport(comPort, 115200, ...
                    'DataBits', 8, 'StopBits', 1, 'Timeout', 5);
                configureTerminator(obj.filterWheel, 'CR');
                obj.useLegacySerial = false;
                obj.isOpen = true;
            catch
                try
                    obj.filterWheel = serial(comPort, 'BaudRate', 115200, ...
                        'DataBits', 8, 'StopBits', 1, 'Terminator', 'CR'); %#ok<SERIAL>
                    fopen(obj.filterWheel);
                    obj.useLegacySerial = true;
                    obj.isOpen = true;
                catch
                    obj.isOpen = false;
                end
            end
        end

        function close(obj)
            if obj.isOpen
                try
                    if obj.useLegacySerial
                        fclose(obj.filterWheel);
                    else
                        delete(obj.filterWheel);
                    end
                catch
                end
                obj.isOpen = false;
            end
        end

        function tf = isConnected(obj)
            tf = ~isempty(obj.isOpen) && obj.isOpen;
        end

        function moveWheel(obj, position)
            if ~obj.isConnected()
                return;
            end
            if obj.useLegacySerial
                fprintf(obj.filterWheel, ['pos=' num2str(position) '\n']);
            else
                writeline(obj.filterWheel, ['pos=' num2str(position)]);
            end
            obj.wheelPosition = position;
        end

        function setNDF(obj, nd)
            if ~obj.isConnected()
                warning('FilterWheelDevice:notConnected', ...
                    '%s is not connected; NDF not changed.', obj.name);
                return;
            end
            try
                obj.moveWheel(find(obj.ndfValues == nd, 1));
                obj.setReadOnlyConfigurationSetting('NDF', nd);
            catch e
                disp(e.message);
            end
        end

        function nd = getNDF(obj)
            nd = obj.getConfigurationSetting('NDF');
        end

        function ndfValues = getNdfValues(obj)
            ndfValues = obj.getConfigurationSetting('ndfValues');
        end

        function position = getCurrentPosition(obj)
            if obj.isConnected()
                if obj.useLegacySerial
                    fprintf(obj.filterWheel, 'pos=?\n');
                    position = fscanf(obj.filterWheel);
                else
                    writeline(obj.filterWheel, 'pos=?');
                    position = readline(obj.filterWheel);
                end
            end
        end
    end
end
