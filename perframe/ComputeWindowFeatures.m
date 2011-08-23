% [y,feature_names] = ComputeWindowFeatures(x,...)
% 
% Wrapper function that computes all the window features y for the input
% one-dimensional time series x. 
% 
% Optional inputs:
% 
% windows: window offsets and radii to try ([radius1,offset1];...;[radiusn,offsetn])
% if empty, then window_radii and window_offsets are used to specify
% windows. default value: []. 
% window_radii: if windows is empty, then the cross-product of window_radii
% and window_offsets is used. if empty, then min_window_radius,
% max_window_radius, and mwindow_radii are used to set
%  windows,default_windows,...
%   'window_radii',default_window_radii,'window_offsets',default_window_offsets,...
%   'min_window_radius',default_min_window_radius,'max_window_radius',default_max_window_radius,'nwindow_radii',default_nwindow_radii,...
%   'feature_types',feature_types,...
%   'trans_types',default_trans_types,...
%   'mean_params',mean_params,...
%   'min_params',min_params,...
%   'max_params',max_params,...
%   'hist_params',hist_params,...
%   'prctile_params',prctile_params,...
%   'change_params',change_params,...
%   'std_params',std_params,...
%   'harmonic_params',harmonic_params,...
%   'diff_neighbor_mean_params',diff_neighbor_mean_params,...
%   'diff_neighbor_min_params',diff_neighbor_min_params,...
%   'diff_neighbor_max_params',diff_neighbor_max_params,...
%   'zscore_neighbors_params',zscore_neighbors_params,...
%   'sanitycheck',SANITY_CHECK,...
%   'docache',DOCACHE,...
%   't0',[],'t1',[]);
% Output y is nfeatures x nframes.

function [y,feature_names] = ComputeWindowFeatures(x,varargin)

%% initialize

x = x(:)';
N = numel(x);
feature_names = {};
feature_types_computed = {};

%% default parameters

% defaults parameters for windows, if not specified per window feature
[default_windows,default_window_offsets,...
  default_window_radii,default_min_window_radius,...
  default_max_window_radius,default_nwindow_radii] = ...
  SetDefaultWindowParameters();

% use all features, transformation types by default
feature_types = 'all';
default_trans_types = 'all';

% per-feature parameters
mean_params = {};
min_params = {};
max_params = {};
hist_params = {};
prctile_params = {};
change_params = {};
std_params = {};
harmonic_params = {};
diff_neighbor_mean_params = {};
diff_neighbor_min_params = {};
diff_neighbor_max_params = {};
zscore_neighbors_params = {};

% for debugging purposes
SANITY_CHECK = false;

% whether to cache results
DOCACHE = true;

%% parse parameters

%   change_window_radii,...
%   num_harmonic,...

[...
  default_windows,...
  default_window_radii,default_window_offsets,...
  default_min_window_radius,default_max_window_radius,default_nwindow_radii,...
  feature_types,...
  default_trans_types,...
  mean_params,...
  min_params,...
  max_params,...
  hist_params,...
  prctile_params,...
  change_params,...
  std_params,...
  harmonic_params,...
  diff_neighbor_mean_params,...
  diff_neighbor_min_params,...
  diff_neighbor_max_params,...
  zscore_neighbors_params,...
  SANITY_CHECK,...
  DOCACHE,...
  t0,t1...
  ] = myparse(varargin,...
  'windows',default_windows,...
  'window_radii',default_window_radii,'window_offsets',default_window_offsets,...
  'min_window_radius',default_min_window_radius,'max_window_radius',default_max_window_radius,'nwindow_radii',default_nwindow_radii,...
  'feature_types',feature_types,...
  'trans_types',default_trans_types,...
  'mean_params',mean_params,...
  'min_params',min_params,...
  'max_params',max_params,...
  'hist_params',hist_params,...
  'prctile_params',prctile_params,...
  'change_params',change_params,...
  'std_params',std_params,...
  'harmonic_params',harmonic_params,...
  'diff_neighbor_mean_params',diff_neighbor_mean_params,...
  'diff_neighbor_min_params',diff_neighbor_min_params,...
  'diff_neighbor_max_params',diff_neighbor_max_params,...
  'zscore_neighbors_params',zscore_neighbors_params,...
  'sanitycheck',SANITY_CHECK,...
  'docache',DOCACHE,...
  't0',[],'t1',[]);

%% whether we've specified to use all features

useallfeatures = ischar(feature_types) && strcmpi(feature_types,'all');

%% select default windows from various ways of specifying windows

default_windows = SetWindowParameters(...
  default_windows,default_window_offsets,...
  default_window_radii,default_min_window_radius,...
  default_max_window_radius,default_nwindow_radii);

%% set all parameters, putting in default windows, trans as necessary

mean_params = SetDefaultParams(mean_params,default_windows,default_trans_types);
min_params = SetDefaultParams(min_params,default_windows,default_trans_types);
max_params = SetDefaultParams(max_params,default_windows,default_trans_types);
hist_params = SetDefaultParams(hist_params,default_windows,default_trans_types);
prctile_params = SetDefaultParams(prctile_params,default_windows,default_trans_types);
change_params = SetDefaultParams(change_params,default_windows,default_trans_types);
std_params = SetDefaultParams(std_params,default_windows,default_trans_types);
harmonic_params = SetDefaultParams(harmonic_params,default_windows,default_trans_types);
diff_neighbor_mean_params = SetDefaultParams(diff_neighbor_mean_params,default_windows,default_trans_types);
diff_neighbor_min_params = SetDefaultParams(diff_neighbor_min_params,default_windows,default_trans_types);
diff_neighbor_max_params = SetDefaultParams(diff_neighbor_max_params,default_windows,default_trans_types);
zscore_neighbors_params = SetDefaultParams(zscore_neighbors_params,default_windows,default_trans_types);

common_params = {'sanitycheck',SANITY_CHECK,...
  'docache',DOCACHE};

%% we'll need to compute means, stds mins, maxs for multiple features
cache = InitializeCache();

%% if t0 or t1 are input, then only compute in a boundary around t0, t1
% compute the maximum dependency radius and only compute up to there. 
% there's more efficient ways to do this, but this is the simplest
% modification to the code

MAXDEPENDENCYRADIUS = ComputeMaxDependencyRadius({'windows',default_windows},...
  mean_params,min_params,max_params,hist_params,prctile_params,change_params,std_params,...
  harmonic_params,diff_neighbor_mean_params,diff_neighbor_min_params,...
  diff_neighbor_max_params,zscore_neighbors_params);
  
if isempty(t0),
  t0 = 1;
  OFF0 = 1;
else
  OFF0 = max(1,t0-MAXDEPENDENCYRADIUS);
end

if isempty(t1),
  t1 = N;
  OFF1 = N;
else
  OFF1 = min(N,t1+MAXDEPENDENCYRADIUS);
end
x = x(OFF0:OFF1);
y = zeros(0,OFF1-OFF0+1);

%% window mean

if useallfeatures || ismember('mean',feature_types),
  [y_new,feature_names_new,cache] = ...
    ComputeMeanWindowFeatures(x,'cache',cache,'feature_types',feature_types_computed,...
    common_params{:},mean_params{:});
  y(end+1:end+size(y_new,1),:) = y_new;
  feature_names(end+1:end+numel(feature_names_new)) = feature_names_new;
  feature_types_computed{end+1} = 'mean';
end

%% window minimum

if useallfeatures || ismember('min',feature_types),
  [y_new,feature_names_new,cache] = ...
    ComputeMinWindowFeatures(x,'cache',cache,'feature_types',feature_types_computed,...
    common_params{:},min_params{:});
  y(end+1:end+size(y_new,1),:) = y_new;
  feature_names(end+1:end+numel(feature_names_new)) = feature_names_new;
  feature_types_computed{end+1} = 'min';
end

%% window maximum

if useallfeatures || ismember('max',feature_types),
  [y_new,feature_names_new,cache] = ...
    ComputeMaxWindowFeatures(x,'cache',cache,'feature_types',feature_types_computed,...
    common_params{:},max_params{:});
  y(end+1:end+size(y_new,1),:) = y_new;
  feature_names(end+1:end+numel(feature_names_new)) = feature_names_new;
  feature_types_computed{end+1} = 'max';
end

%% histogram bin fraction

if useallfeatures || ismember('hist',feature_types),
  [y_new,feature_names_new,cache] = ...
    ComputeHistWindowFeatures(x,'cache',cache,'feature_types',feature_types_computed,...
    common_params{:},hist_params{:});
  y(end+1:end+size(y_new,1),:) = y_new;
  feature_names(end+1:end+numel(feature_names_new)) = feature_names_new;
  feature_types_computed{end+1} = 'hist';
end

%% percentiles

if useallfeatures || ismember('prctile',feature_types),
  [y_new,feature_names_new,cache] = ...
    ComputePrctileWindowFeatures(x,'cache',cache,'feature_types',feature_types_computed,...
    common_params{:},prctile_params{:});
  y(end+1:end+size(y_new,1),:) = y_new;
  feature_names(end+1:end+numel(feature_names_new)) = feature_names_new;
  feature_types_computed{end+1} = 'prctile';
end

%% change between end and start

if useallfeatures || ismember('change',feature_types),
  
  [y_new,feature_names_new,cache] = ...
    ComputeChangeWindowFeatures(x,'cache',cache,'feature_types',feature_types_computed,...
    common_params{:},change_params{:});
  y(end+1:end+size(y_new,1),:) = y_new;
  feature_names(end+1:end+numel(feature_names_new)) = feature_names_new;
  feature_types_computed{end+1} = 'change';

end

%% standard deviation

if useallfeatures || ismember('std',feature_types),

  [y_new,feature_names_new,cache] = ...
    ComputeStdWindowFeatures(x,'cache',cache,'feature_types',feature_types_computed,...
    common_params{:},std_params{:});
  y(end+1:end+size(y_new,1),:) = y_new;
  feature_names(end+1:end+numel(feature_names_new)) = feature_names_new;
  feature_types_computed{end+1} = 'std';

end

%% harmonic

if useallfeatures || ismember('harmonic',feature_types),
  
  [y_new,feature_names_new,cache] = ...
    ComputeHarmonicWindowFeatures(x,'cache',cache,'feature_types',feature_types_computed,...
    common_params{:},harmonic_params{:});
  y(end+1:end+size(y_new,1),:) = y_new;
  feature_names(end+1:end+numel(feature_names_new)) = feature_names_new;
  feature_types_computed{end+1} = 'harmonic';

end

%% difference from neighbor mean

if useallfeatures || ismember('diff_neighbor_mean',feature_types),

  [y_new,feature_names_new,cache] = ...
    ComputeDiffNeighborMeanWindowFeatures(x,'cache',cache,'feature_types',feature_types_computed,...
    common_params{:},diff_neighbor_mean_params{:});
  y(end+1:end+size(y_new,1),:) = y_new;
  feature_names(end+1:end+numel(feature_names_new)) = feature_names_new;
  feature_types_computed{end+1} = 'diff_neighbor_mean';

end

%% difference from neighbor min

if useallfeatures || ismember('diff_neighbor_min',feature_types),

  [y_new,feature_names_new,cache] = ...
    ComputeDiffNeighborMinWindowFeatures(x,'cache',cache,'feature_types',feature_types_computed,...
    common_params{:},diff_neighbor_min_params{:});
  y(end+1:end+size(y_new,1),:) = y_new;
  feature_names(end+1:end+numel(feature_names_new)) = feature_names_new;
  feature_types_computed{end+1} = 'diff_neighbor_min';
  
end

%% difference from neighbor max

if useallfeatures || ismember('diff_neighbor_max',feature_types),

  [y_new,feature_names_new,cache] = ...
    ComputeDiffNeighborMaxWindowFeatures(x,'cache',cache,'feature_types',feature_types_computed,...
    common_params{:},diff_neighbor_max_params{:});
  y(end+1:end+size(y_new,1),:) = y_new;
  feature_names(end+1:end+numel(feature_names_new)) = feature_names_new;
  feature_types_computed{end+1} = 'diff_neighbor_max';

end

%% z-score wrt neighbors

if useallfeatures || ismember('zscore_neighbors',feature_types),

  [y_new,feature_names_new,cache] = ...
    ComputeZScoreNeighborsWindowFeatures(x,'cache',cache,'feature_types',feature_types_computed,...
    common_params{:},zscore_neighbors_params{:}); %#ok<NASGU>
  y(end+1:end+size(y_new,1),:) = y_new;
  feature_names(end+1:end+numel(feature_names_new)) = feature_names_new;
  feature_types_computed{end+1} = 'zscore_neighbors'; %#ok<NASGU>

end

%% get the part of y that we actually want to return
pad0 = t0-OFF0;
pad1 = OFF1-t1;
y = y(:,1+pad0:end-pad1);