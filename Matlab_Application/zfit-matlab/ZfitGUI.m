function ZfitGUI
% ZfitGUI creates a figure with uimenus devoted to process impedance data.
%
% The main features are:
%
%         Graphical.
%         The data can be plotted for each immitance types (Z, Y, C or M),
%         in the complex plane, as well as their real, imaginary parts or
%         their magnitude in function of the frequency (Log/Log scales).
%
%         Simulation.
%         The possibilities are almost infinite. Over the classical R, C,
%         L electrical elements, one can use CPE (constant Phase Element),
%         Diffusion Impedances and even any user-defined elements.
%
%         Fitting.
%         ZfitGUI makes use of the simplex algorithm. Bounds maybe applied for
%         the parameters to be found. To fit only portion of the spectra is user-friendly.
%         Note that there exists the programmatic version of ZfitGUI named
%         "Zfit" which can be found in the Matworks site file exchange.
% 17 novembre 2019
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% MAIN
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Creates the figure with uimenus and put default options
if isempty(findobj('tag','main'))
    H_main=creefigure; % function to create the figure with all the uimenus
    setappdata(H_main,'filenamechoice',1) % its the default state to display filenames of the data
    msgbox('If you are beginner here, you might read the User Manual from the uimenu "Help"')
end

end % of ZfitGUI
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SUBFUNCTIONS: %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function inputFunc(hfunction,event,S)
% Enter the circuit string and parameters values (initial before fitting or
% for simulation). Save a frequency vector in the appdata figure, plot the simulated
% spectrum

% get handles
H_main=findobj('tag','main');
sL=findobj('tag','selected');
% If no line is selected, we need to create a frequency vector.
% Otherwise, if a selected line is existing, get its frequencies.
% Save the frequency vector in the main figure appdata.
if isempty(sL)
    answer = inputdlg({'input log10(LOW freq.)','input log10(HIGH freq.)','N data points'},'Frequency domain',1,{'0','6','100'},'on');
    if isempty(answer)
        return
    else
        if isempty(answer{1}), Lf=1;else Lf=str2double(answer{1});end
        if isempty(answer{2}), Hf=6;else Hf=str2double(answer{2});end
        if isempty(answer{3}), N=100;else N=str2double(answer{3});end
    end
    fr=logspace(Lf,Hf,N);
    setappdata(H_main,'frsimu',fr(:))
else
    frzrzi=getappdata(sL,'frzrzi');fr=frzrzi(:,1);setappdata(H_main,'frsimu',fr(:))
end
% Input box to get the Circuit string and the parameters from the user.
dlg_title='Input the circuit string and pinit';
prompt={'Input the Circuit string or its name ';'Input the Pinit vector or its name'};
def1={'s(p(R1,C1),R1)'};def2={'1e5, 1e-9, 1e2'};
% Scircuit is the circuit String, Spinit is the pinit String, they are saved 
% in the main figure appdata. If they already existed, we re-use them as
% default values
Scircuit=getappdata(H_main,'Scircuit');if ~isempty(Scircuit),def1={Scircuit};end
Spinit=getappdata(H_main,'Spinit'); if ~isempty(Spinit),def2={Spinit};end
def=[def1;def2];L1=max([length(def1{1}),30]);L2=max([length(def2{1}),30]);
answer = inputdlg(prompt,dlg_title,[1,L1;1,L2],def,'on');
if isempty(answer),return,end
if isempty(answer{1}),return,end
if isempty(answer{2}),return,end
    Scircuit=answer{1};
    setappdata(H_main,'Scircuit',Scircuit)
    Spinit=answer{2}; % Spinit is a string (of doubles)
    setappdata(H_main,'Spinit',Spinit)
    traceSimu
end

function traceSimu
% Check correctness of the user defined circuit and plot the Simulation

H_main=findobj('tag','main');figure(H_main); % gives the focus to the main figure
% get the frequencies of selected or simu
fr=getappdata(H_main,'frsimu');
if isempty(fr)
    warndlg('Sorry : an unknown error occured. Maybe you might restart ...');
end

Spinit=getappdata(H_main,'Spinit'); pinit=str2num(Spinit); %#ok<ST2NM>
Scircuit=getappdata(H_main,'Scircuit');

try
    zrzi=computecircuit(pinit,Scircuit,fr);
catch erreur
    if ~isempty(erreur)
        warndlg('An error occured, the circuit string or pinit is bad defined, please check them');
    end
    return
end
% plot the simu line
delete(findobj('tag','simu'))
ht=line(real(zrzi), imag(-zrzi),'color','r','linewidth',1.5,'marker','+','tag','simu');
setappdata(ht,'frzrzi',[fr(:),real(zrzi(:)), imag(zrzi(:))]);
setappdata(ht,'filename','simu')% store the word "simu" to be displayed in the legend if the option is ON
convertline
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function startFit(h,e,S)
% Start the fitting and display the results

H_main=findobj('tag','main');figure(H_main)
pause(0.1)
hcomputing=title({'Computing ... please wait'},'BackgroundColor',[.7 .9 .7],'Color','k','tag','computing');
pause(0.2)


% find the line
sL=findobj('tag','selected');
if isempty(sL)
    msgbox('Select a line first !','No Line','warn','modal')
    return
end

zfg=getappdata(H_main,'zfg'); % get the structure zfg
frzrzi=getappdata(sL,'frzrzi');
fr=frzrzi(:,1);
Scircuit=getappdata(H_main,'Scircuit');
Spinit=getappdata(H_main,'Spinit');

if isempty(frzrzi),warndlg('please select a line to be processed');
    delete(findobj('tag','portion')),return
end
if isempty(Scircuit),warndlg('the funtion name is not defined, please use circuit')
    delete(findobj('tag','portion')),return
end
if isempty(Spinit),warndlg('Initial Parameters were not set, please use "Circuit"')
    delete(findobj('tag','portion')),return
end

pinit=str2num(Spinit); %#ok<ST2NM>
delete(findobj('tag','simu'))

vi=zfg.vi;
if min(vi)>1,zfg.weightmatrix(1:min(vi)-1,:)=0;end
if max(vi)<length(fr),zfg.weightmatrix(max(vi)+1:end,:)=0;end

options=optimset('display','none'); % to avoid messages in the Comand Window
[pbest,chi2,exitflag,output]=curfit(pinit,fr,frzrzi(:,2)+1j*frzrzi(:,3),@computecircuit,Scircuit,zfg.weightmatrix,options);
zrzi=computecircuit(pbest,Scircuit,fr);
ht=line(real(zrzi), imag(zrzi),'color','r','marker','+','tag','simu');
frzrzi=[fr,real(zrzi), imag(zrzi)];
setappdata(ht,'frzrzi',frzrzi)% store the data
convertline
% following is to output the results in the structure "zfg" of the figure appdata 
zfg.circuit=Scircuit;
zfg.pbest=pbest; zfg.zbest=[fr,real(zrzi),imag(zrzi)];
zfg.chi2=chi2;
zfg.exitflag=exitflag; zfg.output=output;
setappdata(H_main,'zfg',zfg)
% Fit is Portion, return to complete weightmatrix
    zfg.weightmatrix=zfg.weightmatrix_0;
    setappdata(H_main,'zfg',zfg)
affiche; % Display the result in another figure
delete(hcomputing)
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function H_main=creefigure
% Put uimenus in the figure

H_main=figure; H_mainaxes=gca;grid
set(H_main,'MenuBar','figure','toolbar','figure','tag','main','deletefcn',@deleteH_main)
set(H_mainaxes,'tag','mainaxes')
setappdata(H_main,'cmyz','z')
S.H_Load_Data=uimenu('Label','Load_Data','ForegroundColor','b');
S.H_fromafile=uimenu(S.H_Load_Data,'Label',' from a File');
S.H_fromWS=uimenu(S.H_Load_Data,'Label',' from WorkSpace');
S.H_plot=uimenu('Label','Graph','ForegroundColor','r');
S.H_z=uimenu(S.H_plot,'Label',' -Zi = f(Zr)');
S.H_m=uimenu(S.H_plot,'Label','. Mi = f(Mr)');
S.H_c=uimenu(S.H_plot,'Label',' -Ci = f(Cr)');
S.H_y=uimenu(S.H_plot,'Label','. Yi = f(Yr)');
S.H_real=uimenu(S.H_plot,'Label','> Real versus Frequency','separator','on');
S.H_imag=uimenu(S.H_plot,'Label','> Imag versus Frequency');
S.H_module=uimenu(S.H_plot,'Label','* Absolute versus Frequency','separator','on');
S.H_freq=uimenu(S.H_plot,'Label','  Frequency ?','separator','on');
S.H_slope=uimenu(S.H_plot,'Label','  Slope ?','separator','on');
S.H_outliers=uimenu(S.H_plot,'Label','Remove outliers','separator','on');
S.H_select=uimenu('Label','SelectLine','ForegroundColor','r');
S.H_inputfunction=uimenu('Label','Circuit','ForegroundColor','r');
S.H_startfit=uimenu('Label','  FIT  ','ForegroundColor','m');
S.H_options=uimenu('Label','Options','ForegroundColor','b');
S.H_filename=uimenu(S.H_options,'Label','File names displayed','checked','on');
S.H_help=uimenu('Label','Help','ForegroundColor','b');
S.H_usermanual=uimenu(S.H_help,'Label','get the User Manual');
S.H_tutorial=uimenu(S.H_help,'Label','get the Tutorial');
S.H_tutorialDataReperstory=uimenu(S.H_help,'Label','Data Repertory for Tutorial');


% Define the CallBacks with structure S attached
set(S.H_fromafile,'callback',{@LDfromafile,S});
set(S.H_fromWS,'callback',{@LDfromWS,S});
set(S.H_plot,'callback',[]);
set(S.H_z,'callback',{@plotcmyz,S}); set(S.H_m,'callback',{@plotcmyz,S}); set(S.H_c,'callback',{@plotcmyz,S}); set(S.H_y,'callback',{@plotcmyz,S});
set(S.H_real,'callback',{@plotcmyz,S}), set(S.H_imag,'callback',{@plotcmyz,S}), set(S.H_module,'callback',{@plotcmyz,S})
set(S.H_freq,'callback',{@FRfollow,S}), set(S.H_slope,'callback',{@slope,S}), set(S.H_outliers,'callback',{@removeoutliers,S})
set(S.H_select,'callback',{@selectLine,S})
set(S.H_inputfunction,'callback',{@inputFunc,S})
set(S.H_startfit,'callback',{@fitweights,S})
set(S.H_filename,'callback',{@FileNameDisplayed,S})
set(S.H_usermanual,'callback',{@usermanual,S})
set(S.H_tutorial,'callback',{@tutorial,S})
set(S.H_tutorialDataReperstory,'callback',{@tutorialDataReperstory,S})

end

function deleteH_main(h,e)
h_results=findobj('tag','results');
delete(h_results)
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function LDfromafile(h,e,S)
% Load data using the Matlab "uigetfile" tool and check the content

H_main=findobj('tag','main');
[filename,pathname] = uigetfile('*.*');
if isequal(filename,0), return, end
% Check if the file contains numerics
try
    htimportdata=msgbox('Please wait few seconds ...','modal');
    A = importdata([pathname,filename]);
    delete(htimportdata), pause(0.2)
catch err
    delete(htimportdata), pause(0.2)
    msgbox({[filename,' does not contain numeric matrix'];err.identifier;err.message})
    return
end
% if A is numeric
if isa(A,'numeric')
    dim=size(A);
else
    msgbox([filename,' does not contain numeric matrix'])
    return
end 
% is A a matrix
if ~ismatrix(A)
    msgbox([filename,' is not a matrix'])
    return
end
% A must have at least 3 colunms
if dim(2)>=3
    % delete rows with nan and plot the spectrum
    [i,tilde]=find(isnan(A));A(i,:)=[];   %#ok<NASGU>
    fr=A(:,1);zr=A(:,2);zi=A(:,3); figure(H_main)
    hline=line(zr,-zi,'marker','.');
    frzrzi=[fr,zr,zi];
    setappdata(hline,'frzrzi',frzrzi)% store the data on which the fit will be processed
    setappdata(hline,'filename',filename)% store the data on which the fit will be processed
    cmyz=getappdata(H_main,'cmyz');
    if ~isempty(cmyz)
        convertline % Change the representation acording to the CMYZ string
    else
        setappdata(H_main,'cmyz','z')
        convertline
        title('. -Zi = f(Zr)')
    end
    set(hline,'ButtonDownFcn',@selectButton)
    lastlineisselected(hline)
end
if dim(2)<3
    msgbox('The input arguments MUST be matrix with at least 3 columns: [frequencies, real(z), imag(z)] !','Bad input','warn');return
end
end
% ----------------------------------------------------------------------
function LDfromWS(h,e,S)
% Load Data from the WorkSpace (LDfromWS) and check the content

 f = figure('menubar','none','tag','LDfromWS');
 set(f,'Position',[100 100 250 250])
 c_var = evalin('base', 'who');
 h_LDfromWS = uicontrol('parent',f,'units','normalized','style','listbox');
 set(h_LDfromWS, 'string', c_var,'position',[0.02, 0.01, 0.94, 0.98],'max',1,'min',0,'callback',@DataFromWS)
end

 function DataFromWS(hObject, eventdata)
% hObject    handle to listbox1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
items = get(hObject,'String');
if isempty(items)
    h=msgbox('Data do not exist in the Work Space');
    delete(findobj('tag','LDfromWS')) % delete the figure
    pause(2), delete(h)
    return
end
index_selected = get(hObject,'Value');
answer{1} = items{index_selected};
try
A = evalin('base', answer{1});
catch err
        msgbox({[answer{1},' does not exist in the Work Space'];err.identifier;err.message})
    return
end

H_main=findobj('tag','main');
% Check if A is numeric
if isa(A,'numeric')
    dim=size(A);
else
    msgbox([answer{1},' does not contain numeric matrix'])
    return
end 
% if is A a matrix
if ~ismatrix(A)
    msgbox([answer{1},' is not a matrix'])
    return
end
% A must have at least 3 colunms
if dim(2)>=3
    % delete rows with nan and plot the spectrum
    [i,tilde]=find(isnan(A));A(i,:)=[];   %#ok<NASGU>
    fr=A(:,1);zr=A(:,2);zi=A(:,3); figure(H_main)
    hline=line(zr,-zi,'marker','.');
    frzrzi=[fr,zr,zi];
    setappdata(hline,'frzrzi',frzrzi)% store the data on which the fit will be processed
    setappdata(hline,'filename',answer{1})% store the data on which the fit will be processed
    cmyz=getappdata(H_main,'cmyz');
    if ~isempty(cmyz)
        convertline % Change the representation acording to the CMYZ string
    else
        setappdata(H_main,'cmyz','z')
        convertline
        title('. -Zi = f(Zr)')
    end
    set(hline,'ButtonDownFcn',@selectButton)
    lastlineisselected(hline)
end
if dim(2)<3
    msgbox('The input arguments MUST be matrix with at least 3 columns: [frequencies, real(z), imag(z)] !','Bad input','warn');return
end
delete(findobj('tag','LDfromWS')) % delete the figure
 end
 
 function lastlineisselected(hline)
 % un-selectect the aleready line
 sL=findobj('tag','selected'); set(sL,'tag','')
 set(sL,'marker','.')
 % select the last data loaded from a file or from Work-Space
 set(hline,'marker','o','color','b')
 set(hline,'tag','selected');
 frzrzi=getappdata(hline,'frzrzi');
 weightmatrix=1./([frzrzi(:,2),frzrzi(:,3)]);
 H_main=findobj('tag','main');
 zfg=getappdata(H_main,'zfg');
 zfg.weightmatrix=weightmatrix;
 zfg.weightmatrix_0=weightmatrix;
 setappdata(H_main,'zfg',zfg);
 end
 

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function FileNameDisplayed(obj,event_obj,S)
% CallBack to display or not the Legend

H_main=findobj('tag','main');
if strcmp(get(gcbo, 'Checked'),'on')
    set(gcbo, 'Checked', 'off');
    setappdata(findobj('tag','main'),'filenamechoice',0)
else
    set(gcbo, 'Checked', 'on');
    setappdata(H_main,'filenamechoice',1)
end
showLegend
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function selectLine(hselectLine,event,S)
% Select the data to be processed

hui=findobj('type','uimenu'); set(hui,'enable','off')
% get the figure handle and delete some objects
H_main=findobj('tag','main');
delete(findobj('tag','slope'))
% find the lines
hline=findobj(H_main,'type','line');
% undo the selectLine tool if it was already on
if isequal('crosshair', get(H_main,'pointer'))
    set(H_main,'pointer','arrow'),set(hline,'ButtonDownFcn',{})
    set(hui,'enable','on')
    return
end
if isempty(hline)
    msgbox('No data line in the figure !','No Line','warn','modal');
    set(hui,'enable','on')
    return
end
% un-tag the preceeding selected line to select a new one
sL=findobj('tag','selected'); set(sL,'tag','')
set(hline,'marker','.')
set(hline,'ButtonDownFcn',@selectButton)
set(gcf,'pointer','crosshair')
% Hint
hSLhint=title({'Within 5 seconds';'Just click on the curve to be selected';'for futher processes'},...
    'BackgroundColor','w');

    function selectButton(sL,evnt)
        % CallBack put in the "Click On" callback of the lines
        frzrzi=getappdata(sL,'frzrzi');
        if isempty(frzrzi)
            warndlg({'This line has no Immitance data or is not of ZfitGUI type';
                'It cannot be processed and would be deleted otherwise errors might arise.'})
            return
        end
        set(sL,'marker','o','color','b')
        set(sL,'tag','selected');
        weightmatrix=1./([frzrzi(:,2),frzrzi(:,3)]);
        zfg=getappdata(H_main,'zfg');
        zfg.weightmatrix=weightmatrix;
        zfg.weightmatrix_0=weightmatrix;
        setappdata(H_main,'zfg',zfg);
        set(gcf,'pointer','arrow')
        set(hline,'ButtonDownFcn',{})
        hui=findobj('type','uimenu'); set(hui,'enable','on')
    end
tic
while isempty(findobj('tag','selected'))
    pause(0.2)
    if toc>5
        set(gcf,'pointer','arrow')
        hui=findobj('type','uimenu'); set(hui,'enable','on')
        set(hline,'ButtonDownFcn',{})
        figure(H_main)
        delete(hSLhint)
        return
    end
end

figure(H_main)
delete(hSLhint)
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function fitweights(obj,event_obj,S) %#ok<INUSL>
% This function fits a portion or all of the spectrum by clicking
% twice on it. That is puting the excluded point weights to ZERO.
% After the fit, the weights are automatically reset to their original values.



H_main=findobj('tag','main');figure(H_main)
% find the line
sL=findobj('tag','selected');
if isempty(sL)
    msgbox('Select a line first !','No Line','warn','modal')
    return
end

zfg=getappdata(H_main,'zfg'); % get the structure zfg
frzrzi=getappdata(sL,'frzrzi');
fr=frzrzi(:,1);
Scircuit=getappdata(H_main,'Scircuit');
Spinit=getappdata(H_main,'Spinit');

if isempty(frzrzi),warndlg('please select a line to be processed');
    delete(findobj('tag','portion')),return
end
if isempty(Scircuit),warndlg('the funtion name is not defined, please use circuit')
    delete(findobj('tag','portion')),return
end
if isempty(Spinit),warndlg('Initial Parameters were not set, please use "Circuit"')
    delete(findobj('tag','portion')),return
end

hui=findobj('type','uimenu'); set(hui,'enable','off')
% Hint
title({'Click on 2 points to frame the portion to fit'},...
    'BackgroundColor','w','tag','portion');
% get the x and y data of the line
x=get(sL,'xdata');y=get(sL,'ydata');
x=x(:);y=y(:);
% get the 2 points coordinates
xyPortion=ginput(1);
% compute the euclidian distances and find the indices of the smallest
d1=sqrt((x-xyPortion(1,1)).^2+(y-xyPortion(1,2)).^2);
vi1=find(d1==min(d1));vi1=vi1(1);
line('xdata',x(vi1),'ydata',y(vi1), ...
    'marker','s','MarkerEdgeColor','r','MarkerFaceColor',[0.8000 0.8000 0.8000],'tag','portion');
xyPortion=[xyPortion;ginput(1)];
d2=sqrt((x-xyPortion(2,1)).^2+(y-xyPortion(2,2)).^2);
vi2=find(d2==min(d2));vi2=vi2(1);
% get the coordinates of the portion bounds
vi=[vi1,vi2];vi=[min(vi),max(vi)];
% keep the insiding points:
zfg=getappdata(H_main,'zfg');
zfg.vi=vi;
setappdata(H_main,'zfg',zfg)
line('xdata',x(min(vi):max(vi)),'ydata',y(min(vi):max(vi)), ...
    'marker','s','MarkerEdgeColor','r','MarkerFaceColor',[0.8000 0.8000 0.8000],'tag','portion');
gris=[0.1,0.1,0.1];
text(x(vi1),y(vi1),num2str(vi1),'backgroundcolor',gris,'color','r','tag','portion')
text(x(vi2),y(vi2),num2str(vi2),'backgroundcolor',gris,'color','r','tag','portion')
pause(0.4)
hui=findobj('type','uimenu'); set(hui,'enable','on')
startFit(1,1,S)
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function FRfollow(obj,event_obj,S) %#ok<*INUSD>
% Function to display the Frequency
% CALLBACK of a sub-uimenu of the menu PLOT

hui=findobj('type','uimenu'); set(hui,'enable','off')
% find the line
sL=findobj('type','line','tag','selected');
if isempty(sL)
    msgbox('Select a line first !','No Line','warn','modal')
    set(hui,'enable','on')
    return
end
% Hint
title({'Click near point(s), press Enter to exit when finish'},...
    'BackgroundColor','w','tag','FRtag')
% get the x and y data of the line
frzrzi=getappdata(sL,'frzrzi');freq=frzrzi(:,1);
x=get(sL,'xdata');y=get(sL,'ydata');
x=x(:);y=y(:);
% get the point coordinates
xyPortion=ginput(1);
delete(findall(0,'tag','FRtag'))
if isempty(xyPortion),set(hui,'enable','on'),return,end
d1=sqrt((x-xyPortion(1,1)).^2+(y-xyPortion(1,2)).^2);
vi=find(d1==min(d1));
xt=mean(get(gca,'xlim'));yt=mean(get(gca,'ylim'));
if x(vi)>xt,gx=0.8;else gx=1.01;end
if y(vi)>yt,gy=0.8;else gy=1.01;end
text(x(vi)*gx,y(vi)*gy,{['Freq= ',num2str(freq(vi),'%-12.2e')]},'BackgroundColor','w','tag','FRtag')
pause(0.1)
FRfollow(obj,event_obj,S) % While the user didnt press the return key, the function is relaunched
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function slope(obj,event_obj,S)
% CALLBACK of a sub-uimenu of the menu PLOT
% It uses the ginput function and Displays the slope and the intercept.

% find the line
sL=findobj('type','line','tag','selected');
if isempty(sL)
    msgbox('Select a line first !','No Line','warn','modal')
    return
end
hui=findobj('type','uimenu'); set(hui,'enable','off')
% Hint
hSLOPEhint=title({'* click twice to define a straight line';'* use the Edit Plot arrow to delete it'},'BackgroundColor','w');
% get the x and y data of the line
x=get(sL,'xdata');y=get(sL,'ydata');
x=x(:);y=y(:);
% get the point coordinates
xyPortion=ginput(1);
if isempty(xyPortion), return,end
d1=sqrt((x-xyPortion(1,1)).^2+(y-xyPortion(1,2)).^2);
vi1=find(d1==min(d1));
line(x(vi1),y(vi1),'marker','s','markerfacecolor','k','tag','slope');
xyPortion=ginput(1);
delete(findobj('tag','slope'))
if isempty(xyPortion),return,end
d1=sqrt((x-xyPortion(1,1)).^2+(y-xyPortion(1,2)).^2);
vi2=find(d1==min(d1));
if isequal(vi1,vi2)
        msgbox('The 2 points must be different !','','warn','modal')
        delete(hSLOPEhint)
        hui=findobj('type','uimenu'); set(hui,'enable','on')
    return
end
xSlope=x(vi1:sign(vi2-vi1):vi2);
ySlope=y(vi1:sign(vi2-vi1):vi2);

% keep the insiding points:
p=polyfit(xSlope,ySlope,1);ySlope = polyval(p,xSlope);
line(xSlope,ySlope,'LineStyle','-','color','k','linewidth',3,'tag','slope');
ptx=mean([xSlope(1),xSlope(2)]);
pty=mean([ySlope(1),ySlope(2)]);
slope=(ySlope(end)-ySlope(1))/(xSlope(end)-xSlope(1));
text(ptx,pty,{['Slope: ',num2str(p(1),'%3.1e')];['Intercept: ',num2str(p(2),'%3.1e')]},'BackgroundColor','w','tag','slope');
assignin('base','SlopeIntercept',[p(1),p(2)])
set(hui,'enable','on')
delete(hSLOPEhint)
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function affiche
% Create a figure with a result uitable and a checkbox for re-use the 
% results as initial parameters.
% As the table is editabled, his handle rather than his values are passed
% using zfg

H_main=findobj('tag','main');
zfg=getappdata(H_main,'zfg'); % get the structure zfg
Npbest=length(zfg.pbest);
f=findobj('type','figure','tag','results');
if isempty(f)
    f = figure('menubar','none','tag','results');
    set(f,'Position',[100 100 250 500])
    zfg.results = uitable('parent',f,'units','normalized','columnname',{'Value'},'ColumnEditable',true);
    set(zfg.results,'position',[0.02 0.39 0.95 0.60],'CellEditCallback',@saveSpinit)
    zfg.reFit = uicontrol('parent',f,'units','normalized','style','pushbutton');
    set(zfg.reFit, 'string', 're-Fit (same N points)','callback',@startFit)
    set(zfg.reFit,'position',[0.02 0.29 0.85 0.050],'ForegroundColor','r')
    zfg.reuseP = uicontrol('parent',f,'units','normalized','style','checkbox');
    set(zfg.reuseP, 'string', 'Use the results as initial Parameters ?')
    set(zfg.reuseP,'position',[0.02 0.232 0.85 0.050])
    set(zfg.reuseP,'value',true)
    zfg.copyP = uicontrol('parent',f,'units','normalized','style','pushbutton');
    set(zfg.copyP, 'string', 'copy the Results in clipboard','callback',@copy2clipboard)
    set(zfg.copyP,'position',[0.02 0.17 0.85 0.050],'ForegroundColor','m')
    zfg.saveSimu = uicontrol('parent',f,'units','normalized','style','pushbutton');
    set(zfg.saveSimu, 'string', 'save Selected curve in an Excel file','callback',@saveZinexcel)
    set(zfg.saveSimu,'position',[0.02 0.01 0.85 0.075],'ForegroundColor','b')
    zfg.saveSimuWS = uicontrol('parent',f,'units','normalized','style','pushbutton');
    set(zfg.saveSimuWS, 'string', 'save Selected curve in the WorkSpace','callback',@saveZinWS)
    set(zfg.saveSimuWS,'position',[0.02 0.09 0.85 0.075],'ForegroundColor','b')
end
figure(f)
zfg.results=findobj('type','uitable');
setappdata(H_main,'zfg',zfg)
set(f,'name',['Fit results for : ',zfg.circuit],'numbertitle','off')
rownamePBEST = cell(Npbest+3,1);
for i=1:Npbest,rownamePBEST{i+3}=['p(',num2str(i),')='];end
rownamePBEST{1}='Model';
rownamePBEST{2}='Khi2/N';
rownamePBEST{3}='N';
% Fill the UITABLE
dat=cell(Npbest+3,1);
for i=1:Npbest,dat{i+3,1}=num2str(zfg.pbest(i),'%-12.2e');end
dat{3,1}=num2str(diff(zfg.vi)+1);
dat{2,1}=num2str(zfg.chi2/(diff(zfg.vi)+1),'%-12.4e');
dat{1,1}=zfg.circuit;
set(zfg.results,'rowname',rownamePBEST)
set(zfg.results, 'data', dat)
setappdata(H_main,'zfg',zfg)% save the structure zfg
if isequal(get(zfg.reuseP,'value'),true)
    Spinit=dat{4,1};
    for i=2:Npbest, Spinit=[Spinit,',',dat{i+3,1}];end %#ok<AGROW>
    setappdata(H_main,'Spinit',Spinit);
end
figure(H_main)
end

function saveZinexcel(h,e)
% Save the mast FIT Z-result in an Excel document.

H_mainaxes=findobj('tag','mainaxes');
f=findobj('type','figure','tag','results');set(f,'WindowStyle','modal')
set(h,'ForegroundColor','r') % during the process, the button remains red
pause(0.2)
ht=findobj(H_mainaxes,'tag','selected');
if isempty(ht)
    string_vide = {'There is no Selected Line'};
    msgbox(string_vide,'modal')
    set(h,'ForegroundColor','b') % after the process, the button returns blue
    set(f,'WindowStyle','normal')
    return
end
frzrzi=getappdata(ht(1),'frzrzi');
if isempty(frzrzi)
    string_vide = {'There is no Selected Data'};
    msgbox(string_vide,'modal')
    set(h,'ForegroundColor','b') % after the process, the button returns blue
    set(f,'WindowStyle','normal')
    return
end
name2save=getappdata(ht,'filename');
string_sauve = {'The selected Z data will be saved in the XLS file named : '};
answer = inputdlg(string_sauve,'',1,{name2save});
if ~isempty(answer), nom=answer{1};else set(f,'WindowStyle','normal'),set(h,'ForegroundColor','b'),return,end
htwait=msgbox('Save in XLS would need few seconds, please wait ...','modal');
xlswrite(nom,frzrzi)
delete(htwait);
set(h,'ForegroundColor','b') % after the process, the button returns blue
set(f,'WindowStyle','normal')
end

function saveZinWS(h,e)
% Save the last FIT Z-result in an variable in the WorkSpace.

H_mainaxes=findobj('tag','mainaxes');
f=findobj('type','figure','tag','results');set(f,'WindowStyle','modal')
set(h,'ForegroundColor','r') % during the process, the button remains red
pause(0.2)
ht=findobj(H_mainaxes,'tag','selected');
if isempty(ht)
    string_vide = {'There is no selected Line'};
    msgbox(string_vide,'modal')
    set(h,'ForegroundColor','b') % after the process, the button returns blue
    set(f,'WindowStyle','normal')
    return
end
frzrzi=getappdata(ht(1),'frzrzi');
if isempty(frzrzi)
    string_vide = {'There is no selected Data'};
    msgbox(string_vide,'modal')
    set(h,'ForegroundColor','b') % after the process, the button returns blue
    set(f,'WindowStyle','normal')
    return
end
string_sauve = {'Input the variable name for the selected Z data'};
title='Save in the WS';
answer = inputdlg(string_sauve,title);
if ~isempty(answer), nom=answer{1};else set(f,'WindowStyle','normal'),set(h,'ForegroundColor','b'),return,end
assignin('base',nom,frzrzi)
set(h,'ForegroundColor','b') % after the process, the button returns blue
set(f,'WindowStyle','normal')
end

function saveSpinit(h,e)
% Re-compute the simulation when the results uitable have been edited by the user.
% Saves the parameters in a string re-useable for the next fittings.

H_main=findobj('tag','main');
zfg=getappdata(H_main,'zfg'); % get the structure zfg
% the uitable has been modified, save the changes in zfg
dat=get(h,'data');zfg.dat=dat;setappdata(H_main,'zfg',zfg);
% Check if the pbest are re-used for pinit
if ~isequal(get(zfg.reuseP,'value'),true)
    return
else
    Npbest=length(zfg.pbest);
    Spinit=dat{4,1};
    for i=1:Npbest-1, Spinit=[Spinit,',',dat{i+4,1}];end %#ok<AGROW>
    setappdata(H_main,'Spinit',Spinit);
    delete(findobj('tag','simu'))
    traceSimu
end
end

function copy2clipboard(h,e)
% Copy the current results in the clipboard for any further use.

H_main=findobj('tag','main');
zfg=getappdata(H_main,'zfg'); % get the structure zfg
Npbest=length(zfg.pbest);
dat=get(zfg.results,'data');
Sclipboard=dat{1,1};
for i=2:Npbest+3, Sclipboard=[Sclipboard,'\t',dat{i,1}];end %#ok<AGROW>
clipboard('copy',sprintf(Sclipboard))
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function convertline
% Change the representation acording the CMYZ string.
% CMYZ gives the current graphical representation.
% CMYZ can be : 'c', 'm', 'y', 'z', 'cre', 'cim', 'cab', 'mre', 'mim', 'mab', ...

% get the CMYZ string
H_main=findobj('tag','main');H_mainaxes=findobj('tag','mainaxes');
figure(H_main)
delete(findobj('tag','slope'))
delete(findall(0,'tag','portion'))
delete(findall(0,'tag','FRtag'))
hline=findobj(H_mainaxes,'type','line');
cmyz=getappdata(H_main,'cmyz');
% convert the data lines to the required 'nature'
N_lines=length(hline);
for i=1:N_lines
    frzrzi=getappdata(hline(i),'frzrzi');
    fr=frzrzi(:,1);comp=frzrzi(:,2)+1j*frzrzi(:,3);
    if isempty(getappdata(hline(i),'filename')), setappdata(hline(i),'filename','simu'),end
    axis auto
    % CMYZ can be : c m y z   cre cim cab   mre min mab...
    switch cmyz(1)
        case 'c'
            comp=1./(1j*2*pi*fr.*comp);title('. -Ci = f(Cr)')
            set(hline(i),'xdata',real(comp),'ydata',-imag(comp))
            xlabel('real(C)'),ylabel('-imag(C)')
            axis normal % its a trick to get a good behavior of the data cursor
            axis equal
        case 'm'
            comp=1j*2*pi.*fr.*comp;title('. Mi = f(Mr)')
            set(hline(i),'xdata',real(comp),'ydata',imag(comp))
            xlabel('real(M)'),ylabel('imag(M)')
            axis normal
            axis equal
        case 'y'
            comp=1./comp;title('. Yi = f(Yr)')
            set(hline(i),'xdata',real(comp),'ydata',imag(comp))
            xlabel('real(Y)'),ylabel('imag(Y)')
            axis normal
            axis equal
        case 'z'
            title('. -Zi = f(Zr)')
            set(hline(i),'xdata',real(comp),'ydata',-imag(comp))
            xlabel('real(Z)'),ylabel('-imag(Z)')
            axis normal
            axis equal
    end
    if isequal(length(cmyz),3)
        switch cmyz(2:3)
            case 're'
                set(hline(i),'xdata',log10(fr),'ydata',log10(real(comp)))
                axis normal
                axis auto,title(['> Real(',upper(cmyz(1)),') versus Frequency'])
                xlabel('log_1_0(f)'),ylabel(['log_1_0(Real(',upper(cmyz(1)),')'])
            case 'im'
                set(hline(i),'xdata',log10(fr),'ydata',log10(abs(imag(comp))))
                axis normal
                axis auto,title(['> Imag(',upper(cmyz(1)),') versus Frequency'])
                xlabel('log_1_0(f)'),ylabel(['log_1_0(Imag(',upper(cmyz(1)),')'])
            case 'ab'
                set(hline(i),'xdata',log10(fr),'ydata',log10(abs(comp)))
                axis normal
                axis auto,title(['> Abs(',upper(cmyz(1)),') versus Frequency'])
                xlabel('log_1_0(f)'),ylabel(['log_1_0(Abs(',upper(cmyz(1)),')'])
        end
    end
end

showLegend
end

function showLegend
% Display or not the legend

H_main=findobj('tag','main');H_mainaxes=findobj('tag','mainaxes');
hline=findobj(H_mainaxes,'type','line');
N_lines=length(hline);
% special handling because the the order in hline and in legend are
% reversed
for i=1:N_lines
    filenamesCELL{N_lines-i+1}=getappdata(hline(i),'filename'); %#ok<AGROW>
end
FNchoice=getappdata(H_main,'filenamechoice');
if isequal(FNchoice,0)||isempty(hline)
    delete(findobj(H_main,'tag','legend'))% the legend object has this tag put by Matlab
else
    legend(filenamesCELL);
end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [p,chi2,exitflag,output]=curfit(param,freq,zrzi,fhandle,circuit,weightmatrix,options)
% Minimization function calling fminsearch

freq=freq(:);
zrzi=zrzi(:);zrzi=[real(zrzi),imag(zrzi)]; % zrzi is : zr + j*zi

[p,chi2,exitflag,output]=fminsearch(@distance,param,options);
% DISTANCE is nested, so it knows handlecomputecircuit,circuitstring,freq,weightvector and zrzi
    function dist=distance(param)
        ymod=feval(fhandle,param,circuit,freq);ymod=ymod(:);ymod=[real(ymod),imag(ymod)];
        dist=sum(sum((weightmatrix.*(ymod-zrzi)).^2));
    end         % END of DISTANCE
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function z=computecircuit(param,circuit,freq)
% Computes the complex impedance Z.
% Process the CIRCUIT string to get the elements and their numeral.

A=circuit~='p' & circuit~='s' & circuit~='(' & circuit~=')' & circuit~=',';
element=circuit(A);
% check if the vector param and the circuit string are paired
Nparam=0;for i=2:2:length(element),Nparam=Nparam+str2double(element(i));end
if ~isequal(Nparam,length(param))
    return
end
% for each element
k=0;
for i=1:2:length(element-2)
    k=k+1;
    nlp=str2double(element(i+1));% idendify its numeral
    localparam=param(1:nlp);% get its parameter values
    param=param(nlp+1:end);% remove them from param
    func=[element(i),'([',num2str(localparam),']',',freq)'];% built an functionnal string
    z(:,k)=eval(func);%#ok<AGROW,NASGU>
    % compute its impedance for all the frequencies
    % modify the initial circuit string to make it functionnal (when used
    % with eval)
    circuit=regexprep(circuit,element(i:i+1),['z(:,',num2str(k),')'],'once');
end

z=eval(circuit);% compute the global impedance

end % END of COMPUTECIRCUIT

% sub functions for the pre-built elements

function z=R(p,f) % Resistor
z=p*ones(size(f));
end

function z=C(p,f) % Capacitor
z=1i*2*pi*f*p;
z=1./z;
end

function z=L(p,f) % Inductor
z=1i*2*pi*f*p;
end

function z=E(p,f) % CPE
z=1./(p(1)*(1i*2*pi*f).^p(2));
end

function z=G(p,f) % Finite Length Warburg with SHORT Circuit
z=1./(p(1)*(1i*2*pi*f).^0.5) .* tanh(p(2)*(1i*2*pi*f).^0.5);
end

function z=H(p,f) % Finite Length Warburg with OPEN Circuit
z=1./(p(1)*(1i*2*pi*f).^0.5) ./ tanh(p(2)*(1i*2*pi*f).^0.5);
end

% sub functions for the operators parallel and series

function z=s(varargin) % more zs in series
temp_size_varargin=size(varargin{1},1);
temp_n=ones(temp_size_varargin,nargin);
temp_sum=ones(temp_size_varargin,1);

for iii=1:nargin
    temp_n(:,iii)=varargin{iii};
end

for iii=1:temp_size_varargin
    temp_sum(iii)=sum(temp_n(iii,:));
end
z=temp_sum;
end

function z=p(varargin) % more zp in parallel
temp_size_varargin=size(varargin{1},1);
temp_n=ones(temp_size_varargin,nargin);
temp_sum=ones(temp_size_varargin,1);

for iii=1:nargin
    temp_n(:,iii)=varargin{iii};
end

for iii=1:temp_size_varargin
    temp_sum(iii)=sum(1./temp_n(iii,:));
end
z=1./(temp_sum);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function removeoutliers(h,e,S)
% Remove points from the selected line
% Callback of a subUImenu of GRAPH

H_main=findobj('tag','main');
% find the line
sL=findobj('tag','selected');
if isempty(sL)
    msgbox('Select a line first !','No Line','warn','modal')
    return
end
hui=findobj('type','uimenu'); set(hui,'enable','off')
% Hint
h_remove=title({'* Click on the point(s) to be deleted';'* Press the Enter key to exit'},...
    'BackgroundColor','w');
% get the x and y data of the line
x=get(sL,'xdata');y=get(sL,'ydata');
% get the point coordinates
xyPortion=ginput(1);
delete(h_remove)
if isempty(xyPortion),set(hui,'enable','on'),return,end
d1=sqrt((x-xyPortion(1,1)).^2+(y-xyPortion(1,2)).^2);
vi=find(d1==min(d1));
x(vi)=[];y(vi)=[];
set(sL,'xdata',x,'ydata',y)
frzrzi=getappdata(sL,'frzrzi');
fr=frzrzi(:,1);zr=frzrzi(:,2);zi=frzrzi(:,3);
fr(vi)=[];zr(vi)=[];zi(vi)=[];
setappdata(sL,'frzrzi',[fr(:),zr(:),zi(:)]);
zfg=getappdata(H_main,'zfg');
zfg.weightmatrix(vi,:)=[]; zfg.weightmatrix_0(vi,:)=[];
setappdata(H_main,'zfg',zfg)
removeoutliers(h,e,S) % While the user didnt press the return key, the function is relaunched
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function plotcmyz(h,e,S)
% Callback of the 'Graph' sub-menus which defines what to plot.

H_main=findobj('tag','main');
hline=findobj('type','line');
if isempty(hline),h=findobj('type','uimenu');set(h,'enable','on');return,end
cmyz=getappdata(H_main,'cmyz');
string=get(h,'label');string=string(3);string=lower(string);
if isequal(string,'c')||isequal(string,'m')||isequal(string,'y')||isequal(string,'z')
    cmyz=string;
elseif isequal(string,'r')
    cmyz=[cmyz(1),'re'];
elseif isequal(string,'i')
    cmyz=[cmyz(1),'im'];
elseif isequal(string,'a')
    cmyz=[cmyz(1),'ab'];
else
    disp('prob')
end
setappdata(H_main,'cmyz',cmyz)
convertline
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function usermanual(h,e,S)
% Open the ZfitGUI User Manual through Internet

url = 'https://drive.google.com/open?id=1XEgfGAps2-KtUQglHkJsANEqBeLWyS7q';
h= msgbox('Trying to open the Internet connexion to download the User Manual');
pause(3)
try
    delete(h)
catch
end
web(url,'-browser');
end

function tutorial(h,e,S)
% Open the Tutorial through Internet

url = 'https://drive.google.com/open?id=1XEgfGAps2-KtUQglHkJsANEqBeLWyS7q';
h= msgbox('Trying to open the Internet connexion to download the Tutorial');
pause(3)
try
    delete(h)
catch
end
web(url,'-browser');
end

function tutorialDataReperstory(h,e,S)
% Open the Data for the Tutorial through Internet

url = 'https://drive.google.com/drive/folders/1bk1je8jX-rzVDtK3M2CcHnDET2b7_VOI?usp=sharing';
h= msgbox('Trying to open the Internet connexion to open the Tutorial Data repertory');
pause(3)
try
    delete(h)
catch
end
web(url,'-browser');
end




