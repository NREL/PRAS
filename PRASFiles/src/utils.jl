function makeidxlist(collectionidxs::Vector{Int}, n_collections::Int)

    n_assets = length(collectionidxs)

    idxlist = Vector{UnitRange{Int}}(undef, n_collections)
    active_collection = 1
    start_idx = 1
    a = 1

    while a <= n_assets
       if collectionidxs[a] > active_collection
            idxlist[active_collection] = start_idx:(a-1)       
            active_collection += 1
            start_idx = a
       else
           a += 1
       end
    end

    idxlist[active_collection] = start_idx:n_assets       
    active_collection += 1

    while active_collection <= n_collections
        idxlist[active_collection] = (n_assets+1):n_assets
        active_collection += 1
    end

    return idxlist

end

function load_matrix(data::HDF5.Dataset, roworder::Vector{Int}, T::DataType)

    result = read(data)

    if roworder != 1:size(result, 1)
        @warn("HDF5 data is ordered differently from in-memory requirements. " *
              "Data will be reordered, but this may temporarily " *
              "consume large amounts of memory.")
        # TODO: More memory-efficient approaches are possible
        result = result[roworder, :]
    end

    if eltype(result) != T
        @warn("HDF5 data is typed differently from in-memory requirements. " *
              "Data conversion will be attempted, but this may temporarily " *
              "consume large amounts of memory.")
        result = T.(result)
    end

    return result

end
