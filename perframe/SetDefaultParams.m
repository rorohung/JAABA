function params = SetDefaultParams(params,default_windows,default_trans_types)

fns = params(1:2:end-1);
if ismember('windows',fns) || ...
    (ismember('window_offsets',fns) && ...
     (ismember('window_radii',fns) || ...
      (ismember('min_window_radius',fns) && ...
       ismember('max_window_radius',fns) && ...
       ismember('nwindow_radii',fns)))),
else
  params(end+1:end+2) = {'windows',default_windows};
end
if ~ismember('trans_types',fns),
  params(end+1:end+2) = {'trans_types',default_trans_types};
end
  
  
