function varargout = getRow(DynamicTable, id, varargin)
%GETROW get row for dynamictable
% Index is a scalar 0-based index of the expected row.
% optional keyword argument "ColumnNames" allows for only grabbing certain
% columns instead of returning all columns.
% The returned value is a set of output arguments in the order of
% `colnames` or "columnnames" keyword argument if one exists.

validateattributes(DynamicTable, {'types.hdmf_common.DynamicTable'}, {'scalar'});

if isempty(DynamicTable.id)
    DynamicTable.id = types.hdmf_common.ElementIdentifiers();
end

if isa(DynamicTable.id.data, 'types.untyped.DataStub')
    stubSize = size(DynamicTable.id);
    maxId = stubSize(1) - 1;
elseif isa(DynamicTable.id.data, 'types.untyped.DataPipe')
    maxId = DynamicTable.id.offset - 1;
else
    maxId = DynamicTable.id.data(end);
end
assert(~isempty(maxId) && maxId >= 0, 'MatNWB:getRow:EmptyTable', 'Dynamic Table is Empty');
validateattributes(id, {'numeric'}, {'scalar', 'nonnegative', '<=', maxId});

p = inputParser;
addParameter(p, 'columnnames', DynamicTable.colnames, @(x)iscellstr(x));
parse(p, varargin{:});

columnNames = p.Results.columnnames;
varargout = cell(1, length(columnNames));
for i = 1:length(columnNames)
    cn = columnNames{i};
    indexName = types.util.dynamictable.getIndex(DynamicTable, cn);
    
    matInd = id + 1;
    VectorData = DynamicTable.vectordata.get(cn);
    if isempty(indexName)
        offset = matInd;
        nextIndex = offset;
    else
        VectorIndex = DynamicTable.vectorindex.get(indexName);
        if isa(VectorIndex.data, 'types.untyped.DataStub')...
                || isa(VectorIndex.data, 'types.untyped.DataPipe')
            if isa(VectorIndex.data, 'types.untyped.DataStub')
                totalHeight = size(VectorIndex.data);
                totalHeight = totalHeight(1);
            else
                totalHeight = VectorIndex.data.offset;
            end
            offset = VectorIndex.data.load(matInd) + 1;
            if matInd == totalHeight
                nextIndex = offset;
            else
                nextIndex = VectorIndex.data.load(matInd + 1);
            end
        else
            offset = VectorIndex.data(matInd) + 1;
            if matInd == length(VectorIndex.data)
                nextIndex = offset;
            else
                nextIndex = VectorIndex.data(matInd + 1);
            end
        end
    end
    
    if isa(VectorData.data, 'types.untyped.DataStub')...
            || isa(VectorData.data, 'types.untyped.DataPipe')
        varargout{i} = VectorData.data.load(offset:nextIndex);
    else
        varargout{i} = VectorData.data(offset:nextIndex);
    end
end
end