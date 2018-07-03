function writeAttribute(fid, type, fullpath, value)
tid = io.getBaseType(type, value);
if (~iscell(value) && isscalar(value)) || strcmp(type, 'char')
    sid = H5S.create('H5S_SCALAR');
else
    if isvector(value)
        nd = 1;
        dims = length(value);
    else
        nd = ndims(value);
        dims = size(value);
    end
    
    if iscellstr(value)
        value = io.padCellStr(value);
        value = cell2mat(value);
    end
    sid = H5S.create_simple(nd, fliplr(dims), []);
end
[path, name, ~] = io.pathParts(fullpath);
if isempty(path)
    path = '/'; %weird case if the property is in root
end
oid = H5O.open(fid, path, 'H5P_DEFAULT');
try
    id = H5A.create(oid, name, tid, sid, 'H5P_DEFAULT');
catch ME
    %when a dataset is copied over, it also copies all attributes with it.
    %So we have to open the Attribute for overwriting instead.
    if contains(ME.message, 'H5A_create    attribute already exists')
        H5A.delete(oid, name);
        id = H5A.create(oid, name, tid, sid, 'H5P_DEFAULT');
    else
        rethrow(ME);
    end
end
% H5A.write(id, tid, eval([type '(value)']) .');
H5A.write(id, tid, value .');
H5A.close(id);
H5S.close(sid);
H5O.close(oid);
end