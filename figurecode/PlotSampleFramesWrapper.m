function PlotSampleFramesWrapper(behavior,rootdatadir,experiment_name,scoresfilestr,mainfly,otherflies,ts,ts_overlay,varargin)

annfilestr = 'movie.ufmf.ann';
colorpos = [.7,0,0];
colorneg = [0,0,.7];
border = 16;
bg_thresh = 10/255;
wmah = .5;
frac_a_back = 1;
dist_epsilon = .1;
figpos_example = [97 886 1800 650];

[annfilestr,colorpos,colorneg,border,...
  bg_thresh,wmah,frac_a_back,dist_epsilon,...
  figpos,hfig_base,outfigdir,doplotellipseoverlay] = ...
  myparse(varargin,...
  'annfilestr',annfilestr,...
  'colorpos',colorpos,...
  'colorneg',colorneg,...
  'border',border,...
  'bg_thresh',bg_thresh,...
  'wmah',wmah,...
  'frac_a_back',frac_a_back,...
  'dist_epsilon',dist_epsilon,...
  'figpos',figpos_example,...
  'hfig_base',0,...
  'outfigdir','.',...
  'doplotellipseoverlay',false);

trx = Trx('trxfilestr','registered_trx.mat','moviefilestr','movie.ufmf','perframedir','perframe');
expdir = fullfile(rootdatadir,experiment_name);
trx.AddExpDir(expdir);
moviename = trx.movienames{1};
[readframe,nframes,fid,headerinfo] = get_readframe_fcn(moviename);
if ~exist(fullfile(expdir,scoresfilestr),'file'),
  fprintf('PREDICTIONS NOT LOADED FOR REAL! REMOVE THIS\n');
  predictions = cell(1,trx.nflies);
  for i = 1:trx.nflies,
    predictions{i} = true(trx(i).nframes);
  end
else
  scoresdata = load(fullfile(expdir,scoresfilestr));
  predictions = cellfun(@(x) x > 0,scoresdata.allScores.scores,'UniformOutput',false);
end

annfilename = fullfile(rootdatadir,experiment_name,annfilestr);
[bkgdim,fg_thresh] = read_ann(annfilename,'background_center','n_bg_std_thresh');
bkgdim = reshape(bkgdim,[headerinfo.nc,headerinfo.nr])'/255;
fg_thresh = fg_thresh / 255;
sigma_bkgd = (fg_thresh-bg_thresh);

hfig = hfig_base+1;

[hfig,~,pfore] = PlotSampleFramesColor(trx,readframe,bkgdim,predictions,mainfly,otherflies,ts,...
  'colorpos',colorpos,...
  'colorneg',colorneg,...
  'hfig',hfig,'figpos',figpos,...
  'colormap',{@jet,@jet},...
  'fg_thresh',fg_thresh,...
  'bg_thresh',bg_thresh,...
  'sigma_bkgd',sigma_bkgd,...
  'wmah',wmah,...
  'frac_a_back',frac_a_back,...
  'dist_epsilon',dist_epsilon,...
  'border',border);

SaveFigLotsOfWays(hfig,fullfile(outfigdir,sprintf('Example%s_%s_fly%02d_frame%02d',behavior,experiment_name,mainfly,ts(1))));
for i = 1:size(pfore,3),
  imwrite(pfore(:,:,i),fullfile(outfigdir,sprintf('Example%s_pfore_%s_fly%02d_frame%02d.png',behavior,experiment_name,mainfly,ts(i))));
end

hfig = hfig_base+2;
[hfig,~,pfore] = OverlayFrames(trx,readframe,bkgdim,predictions,mainfly,otherflies,ts_overlay,...
  'colorpos',colorpos,'colorneg',colorneg,'border',border,...
  'hfig',hfig,'figpos',figpos,...
  'colormap',{@jet,@jet},...
  'fg_thresh',fg_thresh,...
  'bg_thresh',bg_thresh,...
  'sigma_bkgd',sigma_bkgd,...
  'wmah',wmah,...
  'frac_a_back',frac_a_back,...
  'dist_epsilon',dist_epsilon);

SaveFigLotsOfWays(hfig,fullfile(outfigdir,sprintf('Example%s_Overlay_%s_fly%02d_Frames%05dto%05d',behavior,experiment_name,mainfly,ts_overlay(1),ts_overlay(end))));
imwrite(pfore,fullfile(outfigdir,sprintf('Example%s_Overlay_pfore_%s_fly%02d_frame%02d.png',behavior,experiment_name,mainfly,ts(i))));

if doplotellipseoverlay,
  hfig = hfig_base+3;
  [hfig] = OverlayFrames_Ellipses(trx,readframe,predictions,mainfly,otherflies,ts_overlay,...
    'colorpos',colorpos,'colorneg',colorneg,'border',border,...
    'hfig',hfig,'figpos',figpos,...
    'colormap',{@jet,@jet});
  
  SaveFigLotsOfWays(hfig,fullfile(outfigdir,sprintf('Example%s_OverlayEllipses_%s_fly%02d_Frames%05dto%05d',behavior,experiment_name,mainfly,ts_overlay(1),ts_overlay(end))));
end