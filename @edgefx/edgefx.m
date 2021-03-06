classdef edgefx
    %   EDGEFX: Edgefunction class
    %   Constructs edgefunctions that are based on numerous geomteric and
    %   topographic criteria that guide the spatially variability of elemental
    %   resolution when building a mesh.
    %   Copyright (C) 2018  Keith Roberts & William Pringle
    %
    %   This program is free software: you can redistribute it and/or modify
    %   it under the terms of the GNU General Public License as published by
    %   the Free Software Foundation, either version 3 of the License, or
    %   (at your option) any later version.
    %
    %   This program is distributed in the hope that it will be useful,
    %   but WITHOUT ANY WARRANTY; without even the implied warranty of
    %   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    %   GNU General Public License for more details.
    %
    %   You should have received a copy of the GNU General Public License
    %   along with this program.  If not, see <http://www.gnu.org/licenses/>.
    properties
        nx % number of x coords
        ny % number of y coords
        x0y0 % 2-tuple of bot. left of domain
        
        lmsl % lmsl boundary as a geodata class
        
        bbox
        boubox
        used % edge function keywords
        
        dis  % percent the edgelength changes in space
        fd   % distance function
        hhd  % matrix containing distance fx values.
        fs   % number of elements to resolve a feature
        fsd  % matrix containing feature size fx values.
        wl   % wavelength
        wld  % matrix containing wavelength fx values.
        slp  % slope edge function
        slpd % matrix containing filtered slope fx values.
        fl   % slope filter parameters
        ch   % channels
        chd  % matrix containing channel fx values.
        g    % max allowable grade of mesh.
        dt   % theoretical simulateable timestep
        
        F    % edge function in gridded interpolant format.
        
        h0    % min. resolution of edgelength function in meters
        gridspace % edgelength function resolution in WGS84 degrees. 
        max_el % max. resolution in domain
        max_el_ns % max. resolution +-<0.01 from shoreline 
        boudist % distance in WGS84 degrees to boundary of mesh
        
        min_el_ch % min. element size along the channel
        Channels % cell array of streams.
        
    end
    
    methods
        
        %% Class constructor/pass it a shape class and edgefx params.
        function obj = edgefx(varargin)
            p = inputParser;
            
            defval = 0; % placeholder value if arg is not passed.
            % add name/value pairs
            addOptional(p,'dis',defval);
            addOptional(p,'fs',defval);
            addOptional(p,'wl',defval);
            addOptional(p,'slp',defval);
            addOptional(p,'ch',defval);
            addOptional(p,'min_el_ch',100);
            addOptional(p,'max_el',inf);
            addOptional(p,'max_el_ns',inf);
            addOptional(p,'g',0.20);
            addOptional(p,'geodata',defval)
            addOptional(p,'lmsl',defval)
            addOptional(p,'dt',-1);
            addOptional(p,'fl',defval);
            addOptional(p,'Channels',defval);
            addOptional(p,'h0',defval);
            
            % parse the inputs
            parse(p,varargin{:});
            % store the inputs as a struct
            inp = p.Results;
            % get the fieldnames of the edge functions
            inp = orderfields(inp,{'max_el','min_el_ch','geodata','lmsl','Channels',...
                'dis','fs','fl','g','max_el_ns','wl',...
                'slp','ch','dt','h0'});
            fields = fieldnames(inp);
            % loop through and determine which args were passed.
            % also, assign reasonable default values if some options were
            
            % not assigned.
            for i = 1 : numel(fields)
                type = fields{i};
                switch type
                    % parse aux options first
                    case('max_el')
                        obj.max_el = inp.(fields{i});
                        if ~isempty(obj.max_el)
                            obj.max_el = inp.(fields{i});
                        end
                    case('max_el_ns')
                        obj.max_el_ns= inp.(fields{i});
                        if obj.max_el_ns ~=0
                            obj.max_el_ns = inp.(fields{i});
                        end
                        % obj.max_el_ns = obj.max_el_ns/111e3;
                    case('g')
                        obj.g= inp.(fields{i});
                        if obj.g ~=0
                            obj.g = inp.(fields{i});
                        end
                    case('fl')
                        obj.fl = inp.(fields{i});
                        if obj.fl ~=0
                            obj.fl = inp.(fields{i});
                        end
                    case('geodata')
                        if isa(inp.(fields{i}),'geodata')
                            feat = inp.(fields{i});
                        end
                    case('lmsl')
                        if isa(inp.(fields{i}),'geodata')
                            obj.lmsl = inp.(fields{i});
                        end
                    case('dt')
                        obj.dt=inp.(fields{i});
                        if obj.dt ~=-1
                            obj.dt = inp.(fields{i});
                        end
                    case('h0')
                        obj.h0=inp.(fields{i});
                        if obj.h0 ~= 0
                            obj.h0 = inp.(fields{i});
                        else
                            obj.h0 = feat.h0;
                        end
                    case('min_el_ch')
                        obj.min_el_ch=inp.(fields{i});
                        if obj.min_el_ch ~= 100
                            obj.min_el_ch = inp.(fields{i});
                        end
                    case('Channels')
                        obj.Channels=inp.(fields{i});
                        if ~isempty(obj.Channels) ~=0
                            obj.Channels = inp.(fields{i});
                        end
                end
            end
            
            % kjr april 28, 2018-form mesh size grid on-the-fly
            obj.fd       = @dpoly;
            obj.x0y0     = feat.x0y0+sqrt(eps); 
            centroid     = mean(feat.bbox(2,:)); 
            obj.gridspace  = obj.h0/(cosd(centroid)*111e3);
            obj.nx       = ceil((abs(feat.x0y0(1)-feat.bbox(1,2)))/obj.gridspace); 
            obj.ny       = ceil((abs(feat.x0y0(2)-feat.bbox(2,2)))/obj.gridspace); 
            obj.bbox     = feat.bbox;
            obj.boubox   = feat.boubox;
            
            % now turn on the edge functions
            for i = 1 : numel(fields)
                type = fields{i};
                switch type
                    case('dis')
                        obj.dis = inp.(fields{i});
                        if obj.dis ~= 0
                            disp('Building distance function...');
                            obj = distfx(obj,feat);
                            obj.used{end+1} = 'dis';
                        end
                    case('fs')
                        obj.fs  = inp.(fields{i});
                        if obj.fs ~= 0
                            disp('Building feature size function...');
                            obj = featfx(obj,feat);
                            obj.used{end+1} = 'fs';
                        end
                    case('wl')
                        obj.wl  = inp.(fields{i});
                        if obj.wl(1)~=0 && ~isempty(feat.Fb)
                            disp('Building wavelength function...');
                            obj = wlfx(obj,feat);
                            obj.used{end+1} = 'wl';
                        end
                    case('slp')
                        obj.slp  = inp.(fields{i});
                        if obj.slp(1) ~= 0 && ~isempty(feat.Fb)
                            disp('Building slope function...');
                            obj = slpfx(obj,feat);
                            obj.used{end+1} = 'slp';
                        end
                    case('ch')
                        obj.ch  = inp.(fields{i});
                        if obj.ch ~= 0
                            disp('Building channel function...');
                            obj = chfx(obj,feat);
                            obj.used{end+1} = 'ch';
                        end
                    case{'g','geodata','lmsl','max_el','min_el_ch','Channels','max_el_ns','h0','dt','fl'}
                        % dummy to avoid warning
                    otherwise
                        warning('Unexpected edge function name/value pairs.')
                end
                if i==numel(fields)
                    obj.F = finalize(obj,feat);
                    disp('Finalized edge function!');
                end
            end
        end
        
        %% Traditional distance function, linear distance from coastline.
        function obj = distfx(obj,feat)
            [d,obj] = get_dis(obj,feat);
            obj.boudist = d; 
            obj.hhd = obj.gridspace + obj.dis*abs(d);
        end
        %% Feature size function, approximates width of nearshore geo.
        function obj = featfx(obj,feat)
            
            % Make sure we don't create a singularity on the coast in the
            % distance function!
            [d,obj] = get_dis(obj,feat);
            obj.boudist = d ; 
            % Calculate the gradient of the distance function.
            [ddx,ddy] = gradient(d,obj.gridspace);
            d_fs = sqrt(ddx.^2 + ddy.^2);
            clearvars ddx ddy
            % WJP: This fix is to put a medial point in narrow channels 
            rf = []; cf = [];
            for ii = 2:size(d,1)-1
                for jj = 2:size(d,2)-1
                    if d(ii,jj) < 0
                        if (d(ii-1,jj) >= 0 && ...
                            d(ii+1,jj) >= 0) || ...
                           (d(ii,jj-1) >= 0 && ...
                            d(ii,jj+1) >= 0)
                            rf(end+1) = ii;
                            cf(end+1) = jj;
                        end
                    end
                end
            end
            % Find singularties in the distance function that are
            % within the poly to get the medial axis.
            % Lets only create medial points in places that are
            % sufficiently far away from the coastline to capture the
            % feature and thus aren't spurious.
            d_fs = reshape(d_fs,[],1); d = reshape(d,[],1);
            lg = d_fs < 0.90  & d < -0.5*obj.gridspace ;
            [r,c] = ind2sub([obj.nx obj.ny],find(lg));       
            % create the coordinates using x0y0 + r*h0
            r = [r; rf']; c = [c; cf']; %WJP: add on "fixed points"
            x_kp = obj.x0y0(1) + (r-1)*obj.gridspace; 
            y_kp = obj.x0y0(2) + (c-1)*obj.gridspace;
            clearvars lg r c cf rf
            % Ensure there are enough medial points nearby
            % to avoid surpurious medial points.
            % WJP: We want a line of points larger than around 7. This
            % corresponds to having three points back or forward up the
            % line. Let's check for those three closest points and ensure
            % they are within about co*h0 distance from each other.
            % co is the cutoff distance = 2*sqrt(2) (two diagonal dist)
            co = 2*sqrt(2);
            [~, dmed] = WrapperForKsearch([x_kp,y_kp]',[x_kp,y_kp]',4);
            prune = dmed(:,2) > co*obj.gridspace | dmed(:,3) > 2*co*obj.gridspace| ...
                dmed(:,4) > 3*co*obj.gridspace;
            x_kp( prune ) = [];
            y_kp( prune ) = [];
            
            [xg,yg]=CreateStructGrid(obj); 

            % Now get the feature size along the coastline
            % Use KD-tree
            [~, dPOS] = WrapperForKsearch([x_kp,y_kp]',[xg(:),yg(:)]',1);
            clearvars xg yg
            % reshape back
            d = reshape(d,obj.nx,[]); dPOS = reshape(dPOS,obj.nx,[]);
            % Feature_size is distance from medial axis plus distance to
            % coastline. min_el is then feature_size*2/R where R is
            % number of elements to model the feature
            obj.fsd = (2*(dPOS-d))/obj.fs;
            
            clear x_kp y_kp d d_fs dPOS 
        end
        
        function [d,obj] = get_dis(obj,feat)
            % Function used by distfx and featfx to return distance and make
            % the Fdis interpolant
            d = feval(obj.fd,obj,feat);
            d = reshape(d,obj.nx,[]);
        end
        
        %% Wavelength edgefx.
        function obj = wlfx(obj,feat)
            
            % interpolate DEM's bathy linearly onto our edgefunction grid.
            [xg,yg]=CreateStructGrid(obj); 

            tmpz    = feat.Fb(xg,yg);
            obj.wld = NaN([obj.nx,obj.ny]); 
            
            for param = obj.wl'
                if numel(param)==1
                    % no bounds specified.
                    wlp = param(1);
                    dp1 = -50;
                    dp2 = -inf;
                else
                    wlp = param(1);
                    dp1 = param(2);
                    dp2 = param(3);
                end
                
                grav    = 9.807;
                period  = 12.42*3600; % M2 period in seconds
                twld = period*sqrt(grav*abs(tmpz+eps))/wlp;
                % limit the maximum to avoid problems in WGS84 conversion 
                twld( twld > 1e6) = 1e6;
                % convert to decimal degrees from meters
                twld = ConvertToWGS84(yg,twld) ; 
                obj.wld(tmpz < dp1 & tmpz > dp2 ) = twld(tmpz < dp1 & tmpz > dp2);
                clearvars twld 
            end
            clearvars tmpz xg yg;
        end
        
        %% Topographic length scale/slope edge function.
        function obj = slpfx(obj,feat)

            [xg,yg]=CreateStructGrid(obj); 

            tmpz    = feat.Fb(xg,yg); 
            tmpz(tmpz > 50) = 50; % ensure no larger than 50 m above land
            % use a harvestine assumption
            Re = 6378.137e3;
            dx = obj.gridspace*cosd(mean(yg(:)))*Re*pi/180; % for gradient function
            dy = obj.gridspace*Re*pi/180; % for gradient function
            % lets filter the bathy to get only relevant features
            % loop over each set of bandpass filter lengths
            tmpz_f = zeros(size(tmpz));
            if obj.fl(1) == 0
                disp('INFO: Rossby radius of deformation filter on.') ;
                obj.fl = [];
                filtit = 1;
            elseif obj.fl(1) == -1
                disp('INFO: Slope filter is off.');
                obj.fl = [];
                tmpz_f = tmpz;
                filtit = 0 ; 
            end
            
            for lambda = obj.fl'
                if all(lambda ~= 0)
                    % do a bandpass filter
                    tmpz_ft  = filt2(tmpz,dx,lambda,'bp') ;
                elseif lambda(2) == 0
                    % do a low pass filter
                    tmpz_ft  = filt2(tmpz,dx,lambda(1),'lp') ;
                else
                    % highpass filter not recommended
                    warning(['Highpass filter on bathymetry in slope' ...
                        'edgelength function is not recommended'])
                    tmpz_ft  = filt2(tmpz,dx,lambda(2),'hp') ;
                end
                tmpz_f = tmpz_f + tmpz_ft;
            end

            % Rossby radius of deformation filter
            if filtit
                bs = NaN([obj.nx,obj.ny]); 
                % Rossby radius of deformation filter
                f = 2*7.29e-5*abs(sind(yg));
                % limit to 1000 km
                rosb = min(1000e3,sqrt(9.81*abs(tmpz))./f);
                % autmatically divide into discrete bins
                [~,edges] = histcounts(rosb);
                tmpz_ft  = tmpz; dxb = dx; 
                % get slope from filtered bathy for the segment only
                [by,bx] = gradient(tmpz_ft,dy,dx); % get slope in x and y directions
                tempbs  = sqrt(bx.^2 + by.^2); % get overall slope
                for i = 1:length(edges)-1
                    sel = rosb >= edges(i) & rosb <= edges(i+1);
                    rosbylb = mean(edges(i:i+1));
                    if rosbylb > 2*dxb
                        disp(['i = ',num2str(i), ' rl/dx = ',num2str(rosbylb/dxb)])
                        tmpz_ft  = filt2(tmpz_ft,dxb,rosbylb,'lp');
                        dxb = rosbylb;
                        % get slope from filtered bathy for the segment only
                        [by,bx] = gradient(tmpz_ft,dy,dx); % get slope in x and y directions
                        tempbs  = sqrt(bx.^2 + by.^2); % get overall slope
                    else
                        % otherwise just use the same tempbs from before
                    end
                    % put in the full one
                    bs(sel) = tempbs(sel); 
                end
            end
            
            if ~filtit
                % get slope from filtered bathy
                [by,bx] = gradient(tmpz_f,dy,dx); % get slope in x and y directions
                bs      = sqrt(bx.^2 + by.^2); % get overall slope
            end
            clear bx by tmpz_f tmpz_ft
            
            % Allow user to specify depth ranges for slope parameter.
            obj.slpd = NaN([obj.nx,obj.ny]); 
            for param = obj.slp'
                if numel(param)==1
                    % no bounds specified. valid in this range.
                    slpp = param(1);
                    dp1 = -50;
                    dp2 = -inf;
                else
                    slpp = param(1);
                    dp1 = param(2);
                    dp2 = param(3);
                end
                % Calculating the slope function
                tslpd = (2*pi/slpp)*abs(tmpz./(bs+eps));
                obj.slpd(tmpz < dp1 & tmpz > dp2 ) = ...
                                            tslpd(tmpz < dp1 & tmpz > dp2);
                clearvars tslpd
            end
            % limit the maximum to avoid problems in WGS84 conversion 
            obj.slpd(obj.slpd > 1e6) = 1e6;
            % convert to decimal degrees from meters
            obj.slpd = ConvertToWGS84(yg,obj.slpd) ; 
            clearvars xg yg 
        end
        
        %% Channel edgefunction
        function obj = chfx(obj,feat)
            
            ang_of_reslope = 60;                                           % Estimate width of channel using tangent of this angle times depth.

            % STEP 1: Calculate the width of each channel using a v-shape approx to
            % channel's cross sectional area.
            for jj=1:length(obj.Channels)
                pts{jj} = obj.Channels{jj};
                dp{jj} = feat.Fb(pts{jj});                                   % depth at x,y channel locations
                radii{jj}=(tand(ang_of_reslope)*abs(dp{jj}))/111e3;         % estimate of channel's width in degrees at x,y locations ASSUMING angle of reslope
                tempbb{jj} = feat.boubox;
            end
            
            [xg,yg]=CreateStructGrid(obj); 

            % STEP 2: For each channel point, set the resolution around a
            % neighborhood of points as |h|/ch where ch is non-dim # between 0.5-1.5
            obj.chd = NaN([obj.nx,obj.ny]);
            % prune the potentially large channel network to only ones
            % partially enclosed in boubox 
            isin = cellfun(@inpolysum,pts,tempbb); 
            pts(isin==0) = []; radii(isin==0)= [];
            
            %figure; plot(xg,yg,'k.'); 
            
            for jj =1:length(pts)                                           % For each channel jj
                sel = pts{jj};
                in  = inpoly(sel,feat.boubox(1:end-1,:)); 
                sel(~in,:) = []; 
                for jjj = 1 : size(sel,1)                                   % For each channel point jjj on channel jj.
                    tidx=[];
                    % will the stencil be too large (nidx^2)?
                    nidx=ceil(radii{jj}(jjj)/obj.h0);                       % stencil of points around channel point.
                    %circle(sel(jjj,1),sel(jjj,2),(nidx+1)*obj.h0);
                    if nidx > 100, disp('alert'), continue, end;
                    % find linear index of channel point in 2-d matrix.
                    [lidx] = FindLinearIdx(sel(jjj,1),sel(jjj,2),xg,yg);
                    % convert to r,c or grid indices.
                    [r,c]  = ind2sub(size(xg),lidx);
                    [cid,rid]=ndgrid((c-nidx:c+nidx)',(r-nidx:r+nidx)');    % grid of nearby points
                    rid = [rid(:);r]; cid=[cid(:);c];                       % append on index of channel point jj
                    % ensure that all these points are within the domain.
                    rid = max([rid,ones(numel(rid),1)],[],2);
                    rid = min([rid,size(xg,1)*ones(numel(rid),1)],[],2);
                    cid = max([cid,ones(numel(rid),1)],[],2);
                    cid = min([cid,size(xg,2)*ones(numel(rid),1)],[],2);
                    % convert back to linear indices.
                    temp=sub2ind(size(xg),rid,cid);
                    tidx=[tidx;temp];
                    %hold on; plot(xg(tidx),yg(tidx),'r.','MarkerSize',5);
                    % assign resolution around channel point, |h|/ch
                    dp=abs(feat.Fb(xg(tidx),yg(tidx)));
                    obj.chd(tidx) = dp/obj.ch;
                end
            end

            obj.chd(obj.chd < obj.min_el_ch) = obj.min_el_ch;
            centroid     = mean(feat.bbox(2,:)); 
            obj.chd = obj.chd/(cosd(centroid)*111e3);
            clearvars Fb pts dp radii tempbb xg yg 
        end
        
        
        %% General function to plot
        function plot(obj,type)
            % form grid here. 
            % working out plottable size
            [xgrid,ygrid]=CreateStructGrid(obj); 

            div = ceil(numel(xgrid)*8*24*1e-9);
            if nargin == 1
                figure;
                m_proj('Mercator','long',[obj.bbox(1,1) obj.bbox(1,2)],...
                    'lat',[obj.bbox(2,1) obj.bbox(2,2)])
                m_contourf(xgrid(1:div:end,1:div:end),...
                           ygrid(1:div:end,1:div:end),...
                  obj.F.Values(1:div:end,1:div:end),50,'Linestyle','none');
                shading interp
                cb = colorbar; ylabel(cb,'edgelength in degrees');
                caxis([prctile(obj.F.Values(:),10) prctile(obj.F.Values(:),90)])
                m_grid('xtick',10,'tickdir','out','yaxislocation','left','fontsize',7);
                title('Total EdgeLength Function');
                return;
            end
            switch type
                case('dis')
                    figure;
                    m_proj('Mercator','long',[obj.bbox(1,1) obj.bbox(1,2)],...
                        'lat',[obj.bbox(2,1) obj.bbox(2,2)])
                    m_contourf(xgrid(1:div:end,1:div:end),...
                               ygrid(1:div:end,1:div:end),...
                        obj.hhd(1:div:end,1:div:end),50,'Linestyle','none');
                    shading interp
                    hold on; m_plot(feat.mainland(:,1),feat.mainland(:,2),'k-','linewi',1);
                    cb = colorbar; ylabel(cb,'edgelength in degrees');
                    m_grid('xtick',10,'tickdir','out','yaxislocation','left','fontsize',7);
                    title('Distance function');
                    %caxis([min(obj.hhd(:)) 0.1])
                case('fs')
                    figure;
                    m_proj('Mercator','long',[obj.bbox(1,1) obj.bbox(1,2)],...
                        'lat',[obj.bbox(2,1) obj.bbox(2,2)])
                    m_contourf(xgrid(1:div:end,1:div:end),...
                               ygrid(1:div:end,1:div:end),...
                        obj.fsd(1:div:end,1:div:end),50,'Linestyle','none');
                    shading interp
                    hold on; m_plot(feat.mainland(:,1),feat.mainland(:,2),'k-','linewi',1);
                    cb = colorbar; ylabel(cb,'edgelength in degrees');
                    m_grid('xtick',10,'tickdir','out','yaxislocation','left','fontsize',7);
                    title('Feature size function');
                case('wl')
                    figure;
                    m_proj('Mercator','long',[obj.bbox(1,1) obj.bbox(1,2)],...
                        'lat',[obj.bbox(2,1) obj.bbox(2,2)]);
                    m_contourf(xgrid(1:div:end,1:div:end),...
                               ygrid(1:div:end,1:div:end),...
                        obj.wld(1:div:end,1:div:end),100);
                    %m_contourf(obj.xg,obj.yg,real(obj.wld)/1000);
                    m_grid('xtick',10,'tickdir','out','yaxislocation','left','fontsize',7);
                    title('Wavelength of the M2 edge function'); cb=colorbar;ylabel(cb,'WGS84 decimal degrees');
                case('ch')
                    figure;
                    m_proj('Mercator','long',[obj.bbox(1,1) obj.bbox(1,2)],...
                        'lat',[obj.bbox(2,1) obj.bbox(2,2)]);
                    m_contourf(xgrid(1:div:end,1:div:end),...
                               ygrid(1:div:end,1:div:end),...
                               obj.chd(1:div:end,1:div:end),100);
                    caxis([obj.h0,10*obj.h0])
                    m_grid('xtick',10,'tickdir','out','yaxislocation','left','fontsize',7);
                    title('Channel edge function'); cb=colorbar;ylabel(cb,'WGS84 decimal degrees');
              
                otherwise
                    warning('Unexpected plot type. No plot created.')
            end
        end
        
        %% Finalize edge function
        % Add grading, cfl limiting and bound enforcement.
        function Fh = finalize(obj,feat)
            % package the edge functions into a known order.
            counter = 0;
            for i = 1 : numel(obj.used)
                type = obj.used{i};
                switch type
                    case('dis')
                        counter = counter + 1;
                        hh(:,:,counter) = obj.hhd;
                        obj.hhd = single(obj.hhd);
                    case('fs')
                        counter = counter + 1;
                        hh(:,:,counter) = obj.fsd;
                        obj.fsd = single(obj.fsd); 
                    case('wl')
                        counter = counter + 1;
                        hh(:,:,counter) = obj.wld;
                        obj.wld = single(obj.wld); 
                    case('slp')
                        counter = counter + 1;
                        hh(:,:,counter) = obj.slpd;
                        obj.slpd = single(obj.slpd);
                    case('ch')
                        counter = counter + 1;
                        hh(:,:,counter) = obj.chd;
                        obj.ch = single(obj.chd); 
                    otherwise
                        error('FATAL:  Could not finalize edge function');
                end
            end
            
            [hh_m] = min(hh,[],3);
            clearvars hh 
            
            [xg,yg]=CreateStructGrid(obj); 

            % KJR June 13, 2018 
            % Convert mesh size function currently in WGS84 degrees to planar metres. 
            hh_m = ConvertToPlanarMetres(xg,yg,hh_m) ; 

            % enforce all mesh resolution bounds,grade and enforce the CFL in planar metres
            if(~isempty(obj.max_el_ns))
                nearshore = abs(obj.boudist) < 0.01 ;
                hh_m(nearshore & hh_m > obj.max_el_ns) = obj.max_el_ns;
            end
            hh_m(hh_m < obj.h0 )    = obj.h0;
            for param = obj.max_el'
                if numel(param)==1 && param~=0
                    mx   = obj.max_el(1);
                    %limidx = hh_m > (mx/111e3) ;
                    limidx = hh_m > mx ;
                    
                    %hh_m( limidx ) = (mx/111e3);
                    hh_m( limidx ) = mx;
                else
                    mx  = param(1);
                    dp1 = param(2);
                    dp2 = param(3);

                    limidx = (feat.Fb(xg,yg) < dp1 & ...
                              feat.Fb(xg,yg) > dp2) & hh_m > mx;

                    hh_m( limidx ) = mx;
                end
            end
                       
            disp('Relaxing the gradient');
            % relax gradient 
            hfun = zeros(size(hh_m,1)*size(hh_m,2),1);
            nn = 0;
            for ipos = 1 : obj.nx
                for jpos = 1 : obj.ny
                    nn = nn + 1;
                    hfun(nn,1) = hh_m(ipos,jpos);
                end
            end
            [hfun,flag] = limgradStruct(obj.ny,obj.h0,hfun,obj.g,sqrt(length(hfun)));
            if flag == 1
                disp('Gradient relaxing converged!');
            else
                error(['FATAL: Gradient relaxing did not converge, '
                    'please check your edge functions']);
            end
            % reshape it back
            nn = 0;
            for ipos = 1 : obj.nx
                for jpos = 1 : obj.ny
                    nn = nn+1;
                    hh_m(ipos,jpos) = hfun(nn);
                end
            end
            clearvars hfun
            
            % enforce the CFL if present
            % Limit CFL if dt >= 0, dt = 0 finds dt automatically.
            if obj.dt >= 0
                if(isempty(feat.Fb)); error('No DEM supplied.'); end 
                tmpz    = feat.Fb(xg,yg);
                grav = 9.807; descfl = 0.50;
                % limit the minimum depth to 1 m
                tmpz(tmpz > - 1) = -1;
                % wavespeed in ocean (second term represents orbital 
                % velocity at 0 degree phase for 1-m amp. wave).
                u = sqrt(grav*abs(tmpz)) + sqrt(grav./abs(tmpz)); 
                if obj.dt == 0
                    % Find min allowable dt based on dis or fs function
                    if any(~cellfun('isempty',strfind(obj.used,'dis')))
                        hh_d = obj.hhd;
                    elseif any(~cellfun('isempty',strfind(obj.used,'fs')))
                        hh_d = obj.fsd;
                    else
                        hh_d = [];
                    end
                    if ~isempty(hh_d)
                        % Convert hh_d to planar meters 
                        hh_d = ConvertToPlanarMetres(xg,yg,hh_d); 
                        hh_d(tmpz > 0) = NaN;
                        obj.dt = min(min(descfl*hh_d./u));
                        clear hh_d
                    else
                        error(['FATAL: cannot use automatic timestep limiter ' ...
                            'without specifying a dis or fs function']);
                    end
                end
                disp(['Enforcing timestep of ',num2str(obj.dt),' seconds.']);
                cfl = (obj.dt*u)./hh_m; % this is your cfl
                dxn = u*obj.dt/descfl;      % assume simulation time step of dt sec and cfl of dcfl;
                hh_m( cfl > descfl) = dxn( cfl > descfl);   %--in planar metres
                clear cfl dxn u hh_d;
            end

            % KJR June 13, 2018 
            % Convert back into WGS84 degrees 
            hh_m = ConvertToWGS84(yg,hh_m) ; 
            
            Fh = griddedInterpolant(xg,yg,hh_m,'linear','nearest');
            
            clearvars xg yg
        end
        
        function [xg,yg]=CreateStructGrid(obj)
            [xg,yg] = ndgrid(obj.x0y0(1) + (0:obj.nx-1)'*obj.gridspace, ...
                obj.x0y0(2) + (0:obj.ny-1)'*obj.gridspace);
        end
        
        function obj = release_memory(obj)
            % releases heavy components from data structures
            if isa(obj,'edgefx')
                disp('--------------------------------------------------');
                disp('Releasing induvidual edge functions from memory...');
                disp('--------------------------------------------------');
                if ~isempty(obj.fsd)
                    obj.fsd = [];
                end
                
                if ~isempty(obj.wld)
                    obj.wld = [];
                end
                
                if ~isempty(obj.slpd)
                    obj.slpd = [];
                end
                
                if ~isempty(obj.chd) 
                   obj.chd = [];  
                end
            end
        end
        

    end
    
end
