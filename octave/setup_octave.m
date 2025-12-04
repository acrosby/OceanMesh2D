function setup_octave()
% add addtional paths for OceanMesh2D

BasePath = fileparts(mfilename('fullpath'))

addpath(genpath(fullfile(BasePath, 'MatlabSupport', 'ann_wrapper')))
pkg load netcdf

end
