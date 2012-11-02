function [success,msg,...
  arenatype,arenacenterx,arenacentery,...
  arenaradius,arenawidth,arenaheight,...
  pxpermm] = ...
  ReadArenaParameters_Wrapper(InputDataType,varargin)

success = false;
msg = '';

[inmoviefile,...
  arenatype,arenacenterx,arenacentery,...
  arenaradius,arenawidth,arenaheight,...
  pxpermm,leftovers] = myparse_nocheck(varargin,...
  'inmoviefile','',...
  'arenatype','None','arenacenterx',0,'arenacentery',0,...
  'arenaradius',123,'arenawidth',123,'arenaheight',123,...
  'pxpermm',1);  

switch InputDataType,
  case 'Ctrax',

    [success,msg,...
      arenatype,arenacenterx,arenacentery,...
      arenaradius,arenawidth,arenaheight,...
      pxpermm] = ...
      ReadArenaParameters_Ctrax(...
      'inmoviefile',inmoviefile,...
      leftovers{:},...
      'pxpermm',pxpermm,...
      'arenatype',arenatype,...
      'arenacenterx',arenacenterx,...
      'arenacentery',arenacentery,...
      'arenaradius',arenaradius,...
      'arenawidth',arenawidth,...
      'arenaheight',arenaheight);

  case 'LarvaeRiveraAlba',
    
    success = false;
    msg = 'Not implemented';

  case 'MoTr',

    success = false;
    msg = 'No arena parameters stored in MoTr files';
    
  case 'Qtrax',

    [success,msg,pxpermm] = ...
      ReadArenaParameters_Qtrax(...
      leftovers{:},...
      'pxpermm',pxpermm);
    
  case 'MAGATAnalyzer',

    [success,msg,pxpermm] = ...
      ReadArenaParameters_MAGATAnalyzer(...
      leftovers{:},...
      'pxpermm',pxpermm);
    
  case 'MWT',

    [success,msg,pxpermm] = ...
      ReadArenaParameters_MWT(...
      leftovers{:},...
      'pxpermm',pxpermm);
    
  otherwise
    success = false;
    msg = sprintf('Unknown data type %s',InputDataType);
end