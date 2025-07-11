classdef Package < handle
    
    methods (Static)
        
        function p = getCalibrationResource(varargin)
            %parentPath = fileparts(fileparts(fileparts(fileparts(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))))))));
            parentPath = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            %parentPath = 'C:\Users\Public\Documents\Calibration';
            %disp(['parentPath:',parentPath]);
            calibrationPath = fullfile(parentPath, 'calibration-resources');
            %calibrationPath = fullfile(parentPath, 'Calibration');
            %disp(calibrationPath)
%             if ~exist(calibrationPath, 'dir')
%                 [rc, ~] = system(['git clone https://github.com/Rieke-Lab/calibration-resources.git "' calibrationPath '"']);
%                 %disp(rc)
%                 if rc
%                     error(['Cannot find or clone calibration-resources directory. Expected to exist: ' calibrationPath]);
%                 end
%             end
            p = fullfile(calibrationPath, varargin{:});
        end
        
    end
    
end
