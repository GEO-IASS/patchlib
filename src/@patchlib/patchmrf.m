function [qpatches, varargout] = patchmrf(varargin)
% PATCHMRF mrf patch inference on patch candidates on a grid
%   qpatches = patchmrf(patches, gridSize, patchDst) perform mrf inference on patch candidates on a
%   grid. patches is either a NxK cell of formatted patches, or a NxVxK array, gridSize is a 1xD
%   vector with prod(gridSize) == N, and patchDst is a NxK array of the individual patch
%   distances/costs.
%
%   The function computes potential out of unary and edge distances via exp(-lambda_x * dst), and
%   then sets up an MRF. it performs inference via LBP using UGM_Infer_LBP. It then returns the
%   patches with the highest posterior at every point on the grid.
%
%   qpatches = patchmrf(..., patchSize) allows for the specification of the 1xD patchSize. if this
%   is not provided, it will be guessed from the patches.
%
%   qpatches = patchmrf(..., patchSize, patchOverlap) allows for the specification of patchOverlap
%   (1xD array or char). If this is not specified, 'mrf' is assumed - see patchlib.overlapkind for
%   more information on options.
%
%   qpatches = patchmrf(..., Param, Value, ...) allows for the specification of several options:
%       edgeDst: (default: @patchlib.l2overlapdst) function handle of the edge function, i.e.
%       functino to compute the distance between two neighbouring patches. The arguments passed are
%       fun(patches1, patches2, df21, patchSize, patchOverlap, nFeatures), see l2overlapdst for an
%       example.
%
%       lambda_node: (default: 1) the value for lambda_node in pot_node = exp(-lambda_node * dst).
%       lambda_edge: (default: 1) the value for lambda_edge.
%       maxLBPIters: (default: 100). the maximum number of LBP iterations. 
%       pIdx
%       refgridsize
%
%   [qpatches, bel, pot, qSel, pIdxSel, rIdxSel] = patchmrf(...). see qSel use in code.
%
% Requires: UGM toolbox
%
% See Also: overlapkind, grid
%
% Contact: adalca@csail
   
    [patches, gridSize, pDst, inputs] = parseinputs(varargin{:});
    patchesperm = permute(patches, [3, 2, 1]);
    nDims = numel(inputs.patchSize);
    if nargout >= 4
        assert(~isempty(inputs.pIdx), 'if asking for pIdxSel, need pIdx input');
    end
    
    % if using correspondances, build correspondance vector
    if inputs.useCorresp
        warning('using useCorresp. Use with care, this is not thoroughly tested, especially as it related to including refgrididx');
        siz = ifelse(isempty(inputs.srcSize), gridSize, inputs.srcSize);
        idx = permute(inputs.pIdx, [1, 3, 2]);
        dispSub = patchlib.corresp2disp(siz, inputs.refgridsize, idx, inputs.rIdx, 'srcGridIdx', inputs.gridIdx);
        dispSub = cat(2, dispSub{:});
		dispSubperm = permute(dispSub, [3, 2, 1]); % will use the permutation version
    end
    
    % prepare the 'sub vector' of each location
    siz = ifelse(isempty(inputs.srcSize), gridSize, inputs.srcSize);
    locSub = ind2subvec(siz, inputs.gridIdx(:));
%     locSub = ind2subvec(gridSize, (1:size(patches, 1))');
    
    % Node potentials. Should be nNodes x nStates;
    nodePot = exp(-inputs.lambda_node * pDst);
    
    % create edge structure - should be the right size
    connectivity = 3^nDims - 1;    
    
    adj = vol2adjacency(gridSize, connectivity);
    nStates = size(patches, 3);
    edgeStruct = UGM_makeEdgeStruct(adj, nStates , true, inputs.maxLBPIters);
    
    % compute distances. 
    % TODO: this computation is doubled for no reason :(
    edgePot = zeros(nStates, nStates, edgeStruct.nEdges);
    
    for e = 1:edgeStruct.nEdges
        n1 = edgeStruct.edgeEnds(e, 1);
        n2 = edgeStruct.edgeEnds(e, 2);
        
        % extract the patches for these two node
        patches1 = patchesperm(:, :, n1);
        patches2 = patchesperm(:, :, n2);
        
        % prepare structs
        pstr1 = struct('patches', patches1, 'loc', locSub(n1, :));
        pstr2 = struct('patches', patches2, 'loc', locSub(n2, :));
        
        % add displacement and reference
        % TODO: add pIdx(n1, :) ?
        if inputs.useCorresp
            pstr1.disp = dispSubperm(:, :, n1); 
            pstr1.ref = inputs.rIdx(n1, :);
            pstr2.disp = dispSubperm(:, :, n2); 
            pstr2.ref = inputs.rIdx(n2, :);
        end
            
        % get the distance.
        dst = inputs.edgeDst(pstr1, pstr2, inputs.patchSize, inputs.patchOverlap);
        
        edgePot(:, :, e) = exp(-inputs.lambda_edge * dst);
    end
    
    % run LBP
    [nodeBel, edgeBel, logZ] = UGM_Infer_LBP(nodePot, edgePot, edgeStruct);
    assert(isclean(nodeBel), 'PATCHLIB:PATCHMRF', 'Bad nodeBel');
        
    % extract max nodes
    [~, maxNodes] = max(nodeBel, [], 2);
    
    % create index in pDst - sized array
    qSel = sub2ind(size(pDst), (1:size(pDst, 1))', maxNodes(:));
    permpatches = permute(patches, [2, 1, 3]); % each row is a voxel
    qpatches = permpatches(:, qSel)'; % for each voxel, use the selection
    if nargout >= 4 && ~isempty(inputs.pIdx)
        pIdxSel = inputs.pIdx(qSel);
        rIdxSel = inputs.rIdx(qSel);
    end
    
    % prepare outputs
    varargout = {};
    if nargout >= 2
        varargout{1} = struct('nodeBel', nodeBel, 'edgeBel', edgeBel, ...
            'logZ', logZ, 'maxNodes', maxNodes);
    end
    if nargout >= 3
        varargout{2} = struct('nodePot', nodePot, 'edgePot', edgePot, 'edgeStruct', edgeStruct);
    end
    if nargout >= 4
        varargout{3} = qSel;
    end       
    if nargout >= 5
        varargout{4} = pIdxSel;
    end       
    if nargout >= 6
        varargout{5} = rIdxSel;
    end       
end

function [patches, gridSize, dst, inputs] = parseinputs(varargin)

    % break down varargin in first inputs and param/value inputs.
    narginchk(3, inf);
    strloc = find(cellfun(@ischar, varargin), 1, 'first');
    if numel(strloc) == 0
        mainargs = varargin;
        paramvalues = {};
    else
        assert(numel(strloc) == 1);
        if isodd(numel(varargin(strloc:end))) % patchOverlap is last main argument, in char form
            mainargs = varargin(1:strloc);
            paramvalues = varargin((strloc+1):end);
        else
            mainargs = varargin(1:(strloc-1));
            paramvalues = varargin(strloc:end);
        end
    end
        
    % parse first part of inputs
    assert(numel(mainargs) >= 3 && numel(mainargs) <= 5);
    patches = mainargs{1};
    gridSize = mainargs{2};
    dst = mainargs{3};
    if numel(mainargs) >= 4
        patchSize = mainargs{4};
    end
    
    if numel(mainargs) == 5
        patchOverlap = mainargs{5};
    end

    % prepare patches in array form
    if iscell(patches)
        if ~exist('patchSize', 'var')
            patchSize = size(patches{1});
        end

        % transform the patches from cell to large matrix
        patchesm = zeros([size(patches, 1), prod(patchSize), size(patches, 2)]);
        for i = 1:size(patches, 1);
            for j = 1:size(patches, 2);
                patchesm(i, :, j) = patches{i, j}(:);
            end
        end
        patches = patchesm;
        
    else
        if ~exist('patchSize', 'var')
            patchSize = patchlib.guessPatchSize(size(patches, 2));
        end
    end

    % some checks. Patches should be NxVxK now, dst should be NxK, where N == prod(gridSize);
    assert(size(patches, 1) == size(dst, 1), 'Patches should be NxVxK now, dst should be NxK');
    assert(size(patches, 3) == size(dst, 2), 'Patches should be NxVxK now, dst should be NxK');
    assert(size(patches, 1) == prod(gridSize));
    
    % get patch overlap
    if ~exist('patchOverlap', 'var')
        patchOverlap = 'sliding';
        warning('Using Default sliding overlap');
    end  
    if ischar(patchOverlap)
        patchOverlap = patchlib.overlapkind(patchOverlap, patchSize);
    end
    
    % parse the rest of the inputs
    p = inputParser();
    p.addParameter('edgeDst', @patchlib.l2overlapdst, @(x) isa(x, 'function_handle'));
    p.addParameter('lambda_node', 1, @isnumeric);
    p.addParameter('lambda_edge', 1, @isnumeric);
    p.addParameter('maxLBPIters', 100, @isnumeric);
    p.addParameter('pIdx', [], @isnumeric);
    p.addParameter('rIdx', [], @isnumeric);
    p.addParameter('refgridsize', [], @(x) isnumeric(x) || iscell(x));
    p.addParameter('gridIdx', 1:prod(gridSize), @isnumeric);
    p.addParameter('srcSize', [], @isnumeric);
    p.parse(paramvalues{:})
    inputs = p.Results;
    
    inputs.patchSize = patchSize;
    inputs.patchOverlap = patchOverlap;
    
    % use correspondances if both refgridsize and pIdx are passed in.
    inputs.useCorresp = false;
    if ~isempty(inputs.pIdx) && ~isempty(inputs.refgridsize)
        inputs.useCorresp = true;
    end
    
    if ~isempty(inputs.pIdx) && ismember('rIdx', p.UsingDefaults)
    	inputs.rIdx = ones(size(inputs.pIdx));
    end
end
