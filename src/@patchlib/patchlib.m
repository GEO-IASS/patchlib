classdef patchlib < handle
    % PATCHLIB A library for working with n-d patches
    %   Currently still in development. 
    %
    %   Throughout the documentation, we'll use the following conventions:
    %       - we use the top left of a patch as the main point
    %       - grid: grid of patches that fit into a volume, using the top-left indexing scheme
    %       - V: number of voxels in a patch
    %       - N: number of elements in the grid, or prod(gridSize).
    %       - M: size along some dimension.
    %       - K: number of patches matching some criteria, e.g. when doing k-NN search
    %       - D: dimentionality
    %
    %   See readme.md for updates and function list.
    %
    %   ToAdd:
    %   - quilting
    %   - viewKNNSearch, using functions from viewPatchesInImage
    %   - view kNN patches (maybe with image?) with scores on top.
    %
    %   requires several functions from mgt (https://github.com/adalca/mgt)
    
    properties (Constant)
        default2DpatchSize = [5, 5];
        memory = 8000000000;
    end
    
    methods (Static)
        % library construction
        varargout = vol2lib(vol, patchSize, varargin);
        varargout = volStruct2lib(volStruct, patchSize, returnEffectiveLibrary);
        
        % quilting
        vol = quilt(patches, gridSize, varargin);
        
        % main tools
        [idx, newVolSize, gridSize, overlap] = grid(volSize, patchSize, patchOverlap, varargin);
        [qpatches, varargout] = patchmrf(varargin);
        varargout = stackPatches(patches, patchSize, gridSize, varargin);
        [patches, pDst, pIdx, pDstIdx, gridSize, refgridsize] = volknnsearch(src, refs, patchSize, varargin);
        
        % mini-tools
        dst = l2overlapdst(pstr1, pstr2, patchSize, patchOverlap, nFeatures);
        dst = correspdst(pstr1, pstr2, ~, ~, dvFact, usemex);
        patchSize = guessPatchSize(n, dim);
        patches = lib2patches(lib, pIdx, varargin)
        [gridSize, newVolSize, overlap] = gridsize(volSize, patchSize, patchOverlap, varargin)
        s = patchCenterDist(patchSize);
        overlap = overlapkind(str, patchSize);
        volSize = grid2volSize(gridSize, patchSize, varargin);
        [patchesCell, patchSize] = patchesmat2cell(patches, patchSize);
        rect = drawPatchRect(patchloc, patchSize, color);
        isv = isvalidoverlap(overlap);
        [sub, loc, corresp] = corresp2disp(siz, varargin);
        [votes, pIdx, locIdx, idx, Ksub] = locvotes(loc, patches, grididx, patchSize, volSize);
        
        [curIdx, neighborIdx] = overlapRegions(patchSize, varargin);
        precomp = overlapRegionsPrecomp(patchSize, patchOverlap)
        dst = overlapDistance(patches1, patches2, df21, varargin)
    end
    
    methods (Static, Access = private)
        % private functions speficially to be used with volknnsearch
        [pIdx, pRefIdxs, pDst] = volknnglobalsearch(src, refs, varargin);
        [pIdx, pRefIdxs, pDst] = volknnlocalsearch(src, refs, spacing, varargin);
        [patches, pDst, pIdx, rIdx, srcgridsize, refgridsize] = ...
            volknnaggresults(vin, inputs)
    end
    
end
