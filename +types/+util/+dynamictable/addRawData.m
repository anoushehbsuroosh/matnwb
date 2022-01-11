function addRawData(DynamicTable, column, data)
%ADDRAWDATA Internal method for adding data to DynamicTable given column
% name and data. Indices are determined based on data format and available
% indices.
validateattributes(column, {'char'}, {'scalartext'});

if ~isprop(DynamicTable, column) && ~isKey(DynamicTable.vectordata, column)
    % No vecdata found anywhere. Initialize.
    initVecData(DynamicTable, column);
end

% grab all available indices for column.
indexChain = {column};
while true
    index = types.util.dynamictable.getIndex(DynamicTable, indexChain{end});
    if isempty(index)
        break;
    end
    indexChain{end+1} = index;
end

% find true nesting depth of column data.
depth = getNestedDataDepth(data);

% add indices until it matches depth.
for iVec = (length(indexChain)+1):depth
    indexChain{iVec} = types.util.dynamictable.addVecInd(DynamicTable, indexChain{end});
end

% wrap until available vector indices match depth.
for iVec = (depth+1):length(indexChain)
    data = {data}; % wrap until the correct number of vector indices are satisfied.
end

nestedAdd(DynamicTable, indexChain, data);
end

function initVecData(DynamicTable, column)
% Don't set the data until after indices are updated.
if 8 == exist('types.hdmf_common.VectorData', 'class')
    VecData = types.hdmf_common.VectorData();
else
    VecData = types.core.VectorData();
end

VecData.description = sprintf('AUTOGENERATED description for column `%s`', column);
VecData.data = [];

DynamicTable.vectordata.set(column, VecData);
end

function depth = getNestedDataDepth(data)
depth = 1;
subData = data;
while iscell(subData) && ~iscellstr(subData)
    depth = depth + 1;
    subData = subData{1};
end
end

function [numRows, numRowDims] = nestedAdd(DynamicTable, indChain, data, varargin)
p = inputParser;
p.addParameter('numRowDims', [], @(x)isnumeric(x));
p.parse(varargin{:});

name = indChain{end};

if isprop(DynamicTable, name)
    Vector = DynamicTable.(name);
elseif isprop(DynamicTable, 'vectorindex') && DynamicTable.vectorindex.isKey(name)
    Vector = DynamicTable.vectorindex.get(name);
else
    Vector = DynamicTable.vectordata.get(name);
end

if isa(Vector, 'types.hdmf_common.VectorIndex') || isa(Vector, 'types.core.VectorIndex')
    elems = zeros(numEntries, 1);
    for iEntry = 1:numEntries
        [elems(iEntry), numRowDims] = nestedAdd(DynamicTable, ...
            indChain(1:(end-1)), ...
            data{iEntry}, ...
            'numRowDims', p.Results.numRowDims);
    end

    numRows = cumsum(elems);
    add2Index(Vector, numRows);
else
    if ischar(data)
        data = mat2cell(data, ones(size(data, 1), 1));
    end % char matrices converted to cell arrays containing character vectors.

    if isa(Vector.data, 'types.untyped.DataPipe')
        Vector.data.append(data);
    elseif isempty(Vector.data)
        Vector.data = data;
        numRowDims = ndims(data);
    else
        add2MemData(Vector, data, p.Results.numRowDims);
    end
end
end

function add2MemData(VectorData, data, numRowDims)
%ADD2MEMDATA add to in-memory data.

if 2 == numRowDims
    if isscalar(VectorData.data) || iscolumn(VectorData.data)
        catDim = 1;
    else % vector data is row
        catDim = 2;
    end
else
    catDim = numRowDims + 1;
end

VectorData.data = cat(catDim, VectorData.data, data);
end

function add2Index(VectorIndex, numElem)
raggedOffset = 0;
if isa(VectorIndex.data, 'types.untyped.DataPipe')
    if isa(VectorIndex.data.internal, 'types.untyped.datapipe.BlueprintPipe')...
            && ~isempty(VectorIndex.data.internal.data)
        raggedOffset = VectorIndex.data.internal.data(end);
    elseif isa(VectorIndex.data.internal, 'types.untyped.datapipe.BoundPipe')...
            && ~any(VectorIndex.data.internal.stub.dims == 0)
        raggedOffset = VectorIndex.data.internal.stub(end);
    end
elseif ~isempty(VectorIndex.data)
    raggedOffset = VectorIndex.data(end);
end

data = double(raggedOffset) + numElem;
if isa(VectorIndex.data, 'types.untyped.DataPipe')
    VectorIndex.data.append(data);
else
    VectorIndex.data = [double(VectorIndex.data); data];
end
end