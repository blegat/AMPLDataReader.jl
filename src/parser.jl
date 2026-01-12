function _parse(s::AbstractString)
    s = strip(s)
    if s == "."
        return missing
    else
        return parse(Float64, s)
    end
end

"""
    read_ampl_dat(filename::String) -> Dict{String, Any}

Read an AMPL .dat file and return a dictionary mapping parameter names to their values.

# Arguments
- `filename::String`: Path to the AMPL .dat file

# Returns
- `Dict{String, Any}`: Dictionary where keys are parameter names and values are:
  - Scalars: Numbers (Int or Float64)
  - 1D arrays: Vectors
  - 2D+ arrays: Multi-dimensional arrays (as nested vectors or arrays)
  - Sets: Vectors

# Example
```julia
data = read_ampl_dat("model.dat")
S = data["S"]  # Scalar
rho = data["rho"]  # Vector
E = data["E"]  # 3D array
```
"""
function read_ampl_dat(filename::String)
    lines = readlines(filename)
    return parse_ampl_dat(lines)
end

"""
    parse_ampl_dat(lines::Vector{String}) -> Dict{String, Any}

Parse AMPL .dat file content from a vector of lines.

# Arguments
- `lines::Vector{String}`: Lines from the AMPL .dat file

# Returns
- `Dict{String, Any}`: Dictionary mapping parameter names to values
"""
function parse_ampl_dat(lines::Vector{String})
    data = Dict{String, Any}()
    i = 1
    
    while i <= length(lines)
        line = strip(lines[i])
        
        # Skip empty lines and comments
        if isempty(line) || startswith(line, "#")
            i += 1
            continue
        end
        
        # Parse scalar parameter: param NAME := VALUE;
        m = match(r"param\s+(\w+)\s*:=\s*([^;]+);", line)
        if m !== nothing
            name = m.captures[1]
            data[name] = _parse(m.captures[2])
            i += 1
            continue
        end
        
        # Parse 1D array: param NAME := INDEX1 VAL1 INDEX2 VAL2 ... ;
        # or multi-line: param NAME := \n INDEX1 VAL1 \n INDEX2 VAL2 \n ... ;
        m = match(r"param\s+(\w+)\s*:=\s*$", line)
        if m !== nothing
            name = m.captures[1]
            i += 1  # Move to next line
            arr_data = Dict{Int, Float64}()
            while i <= length(lines)
                line = strip(lines[i])
                if line == ";" || isempty(line)
                    i += 1
                    break
                end
                # Remove trailing semicolon if present
                line = replace(line, r";\s*$" => "")
                parts = split(line)
                if length(parts) >= 2
                    idx = parse(Int, parts[1])
                    arr_data[idx] = _parse(parts[2])
                end
                i += 1
            end
            # Convert to vector
            if !isempty(arr_data)
                max_idx = maximum(keys(arr_data))
                result = Vector{Float64}(undef, max_idx)
                fill!(result, NaN)
                for (idx, val) in arr_data
                    result[idx] = val
                end
                data[name] = result
            end
            continue
        end
        
        # Parse set: set NAME := VALUES;
        m = match(r"set\s+(\w+)\s*:=\s*([^;]+);", line)
        if m !== nothing
            name = m.captures[1]
            values_str = strip(m.captures[2])
            # Parse space-separated values
            values = split(values_str)
            parsed_values = Float64[]
            for v in values
                v = strip(v)
                if !isempty(v)
                    push!(parsed_values, _parse(v))
                end
            end
            data[name] = parsed_values
            i += 1
            continue
        end
        
        # Parse table format: param NAME [dims] : header := data ;
        # or: param : col1 col2 ... := data ;
        # or multi-line: param \n : col1 col2 ... := data ;
        if occursin("param", line)
            # Check if it's a table format (has : or [)
            is_table = occursin(":", line) || occursin("[", line)
            # Or check next line for continuation
            if !is_table && i + 1 <= length(lines)
                next_line = strip(lines[i + 1])
                is_table = occursin(":", next_line) || occursin("[", next_line)
            end
            
            if is_table
                result = parse_table_format(lines, i, data)
                if result !== nothing
                    i = result
                    continue
                end
            end
        end
        
        i += 1
    end
    
    return data
end

"""
    parse_table_format(lines, start_idx, data) -> Union{Int, Nothing}

Parse AMPL table format parameters. Returns the new line index if successful, nothing otherwise.
"""
function parse_table_format(lines::Vector{String}, start_idx::Int, data::Dict{String, Any})
    i = start_idx
    line = strip(lines[i])
    
    # Check for multi-line param declaration
    # Format 1: param NAME [dims] : header := data ;
    # Format 2: param : col1 col2 ... := data ;
    
    # Check if current line or next line has [ or : to determine format
    has_brackets = occursin("[", line)
    has_colon = occursin(":", line)
    
    # If current line is just "param" (possibly with trailing space), check next line
    if (occursin(r"param\s*$", line) || (occursin("param", line) && !has_brackets && !has_colon)) && 
       i + 1 <= length(lines)
        next_line = strip(lines[i + 1])
        has_brackets = occursin("[", next_line)
        has_colon = occursin(":", next_line)
    end
    
    # Determine format type
    if has_colon && !has_brackets
        # Format: param : col1 col2 ... :=
        return parse_multi_column_table(lines, start_idx, data)
    elseif has_brackets
        # Format: param NAME [dims] : header :=
        return parse_indexed_table(lines, start_idx, data)
    end
    
    return nothing
end

"""
    parse_multi_column_table(lines, start_idx, data) -> Union{Int, Nothing}

Parse multi-column table format: param : col1 col2 ... := data ;
For format like: param \n : rho beta alpha := \n 1 val1 val2 val3 \n ...
"""
function parse_multi_column_table(lines::Vector{String}, start_idx::Int, data::Dict{String, Any})
    i = start_idx
    line = strip(lines[i])
    
    # Find the header line with column names
    header_line = ""
    if occursin(r"param\s*$", line) || (occursin("param", line) && !occursin(":=", line) && !occursin(":", line))
        if i + 1 <= length(lines)
            header_line = strip(lines[i + 1])
            i += 1
        else
            return nothing
        end
    else
        header_line = line
    end
    
    # Extract column names from header
    # Format: : col1 col2 ... :=
    m = match(r":\s*(.+?)\s*:=", header_line)
    if m === nothing
        return nothing
    end
    
    col_names = split(strip(m.captures[1]))
    num_cols = length(col_names)
    
    if num_cols == 0
        return nothing
    end
    
    # Parse data rows to determine structure
    # First, scan to see if we have 1 or 2 indices
    scan_i = i + 1
    sample_line = ""
    while scan_i <= length(lines)
        scan_line = strip(lines[scan_i])
        if scan_line == ";" || isempty(scan_line)
            break
        end
        if scan_line != ":" && !startswith(scan_line, ":")
            sample_line = scan_line
            break
        end
        scan_i += 1
    end

    # Determine number of indices by checking first data line
    num_indices = 1
    if !isempty(sample_line)
        parts = split(sample_line)
        # If we have more parts than columns, check if first two are integers
        num_indices = length(parts) - num_cols
        for i in 1:num_indices
            parse(Int, parts[i])
        end
    end

    # Move i to start of data (after header line)
    i += 1

    # Initialize data structures
    if num_indices == 2
        # 2D arrays (matrices) - use Dict with (idx1, idx2) tuples
        column_data = Dict{String, Dict{Tuple{Int, Int}, Union{Float64, Missing}}}()
        for col in col_names
            column_data[col] = Dict{Tuple{Int, Int}, Union{Float64, Missing}}()
        end
        max_idx1 = 0
        max_idx2 = 0
    else
        # 1D arrays (vectors)
        column_data = Dict{String, Vector{Union{Float64, Missing}}}()
        for col in col_names
            column_data[col] = Union{Float64, Missing}[]
        end
    end

    # Parse data rows
    while i <= length(lines)
        line = strip(lines[i])

        if line == ";" || isempty(line)
            i += 1
            break
        end
        
        # Skip header lines with just ":"
        if line == ":" || (startswith(line, ":") && !occursin(":=", line))
            i += 1
            continue
        end
        
        parts = split(line)
        if num_indices == 2 && length(parts) >= num_cols + 2
            # Two indices: s w val1 val2 ...
            try
                idx1 = parse(Int, parts[1])
                idx2 = parse(Int, parts[2])
                max_idx1 = max(max_idx1, idx1)
                max_idx2 = max(max_idx2, idx2)
                
                # Store values for each column
                for (col_idx, col_name) in enumerate(col_names)
                    val_idx = 2 + col_idx  # Skip first two parts (indices)
                    if val_idx <= length(parts)
                        column_data[col_name][(idx1, idx2)] = _parse(parts[val_idx])
                    end
                end
            catch
                # Skip if parsing fails
            end
        elseif num_indices == 1 && length(parts) >= num_cols + 1
            # Single index: idx val1 val2 ...
            for (col_idx, col_name) in enumerate(col_names)
                val_idx = 1 + col_idx  # Skip first part (index)
                if val_idx <= length(parts)
                    push!(column_data[col_name], _parse(parts[val_idx]))
                end
            end
        end
        
        i += 1
    end
    
    # Store each column as a separate parameter
    for (col_name, values) in column_data
        if num_indices == 2
            # Convert Dict to Matrix
            if !isempty(values)
                T = any(ismissing, Base.values(values)) ? Union{Float64, Missing} : Float64
                result = Matrix{T}(undef, max_idx1, max_idx2)
                fill!(result, NaN)
                for ((idx1, idx2), val) in values
                    result[idx1, idx2] = val
                end
                data[col_name] = result
            end
        else
            # Store as vector
            if !any(ismissing, Base.values(values))
                values = convert(Vector{Float64}, values)
            end
            data[col_name] = values
        end
    end
    
    return i
end

"""
    parse_indexed_table(lines, start_idx, data) -> Union{Int, Nothing}

Parse indexed table format: param NAME [dims] : header := data ;
Handles 1D, 2D, 3D+ arrays.
"""
function parse_indexed_table(lines::Vector{String}, start_idx::Int, data::Dict{String, Any})
    i = start_idx
    line = strip(lines[i])
    
    # Extract parameter name and dimensions
    # Format: param NAME [*,*,1] or param \n NAME [*,*,1]
    param_name::String = ""
    dims_pattern::String = ""
    
    # Check if param is on its own line (with optional trailing space)
    if occursin(r"^param\s*$", line)
        if i + 1 <= length(lines)
            next_line = strip(lines[i + 1])
            # Match: "E [*,*,1]" or "NAME [dims]"
            m = match(r"^(\w+)\s+(\[.*?\])", next_line)
            if m !== nothing
                param_name = string(m.captures[1])
                dims_pattern = string(m.captures[2])
                i += 1
            else
                return nothing
            end
        else
            return nothing
        end
    else
        # Try to match param NAME [dims] on same line
        m = match(r"param\s+(\w+)\s+(\[.*?\])", line)
        if m !== nothing
            param_name = string(m.captures[1])
            dims_pattern = string(m.captures[2])
        else
            return nothing
        end
    end
    
    # Count dimensions from pattern [*,*,1] -> 3 dimensions
    # Count commas and add 1 (e.g., [*,*,1] has 2 commas, so 3 dimensions)
    num_dims = count(==(','), dims_pattern) + 1
    
    # Parse the data
    # Skip the line with [*,*,h] if it's on the current line, otherwise it's already been consumed
    if i <= length(lines)
        line = strip(lines[i])
        if occursin(r"\[.*?,\s*\d+\]", line)
            i += 1  # Move past the [*,*,h] line
        end
    end
    
    # Initialize storage based on dimensions
    if num_dims == 1
        # 1D array: simple list
        arr_data = Dict{Int, Union{Float64, Missing}}()
        while i <= length(lines)
            line = strip(lines[i])
            if line == ";" || isempty(line)
                i += 1
                break
            end
            parts = split(line)
            if length(parts) >= 2
                idx = parse(Int, parts[1])
                arr_data[idx] = _parse(parts[2])
            end
            i += 1
        end
        # Convert to vector
        if !isempty(arr_data)
            max_idx = maximum(keys(arr_data))
            result = Vector{Float64}(undef, max_idx)
            fill!(result, NaN)
            for (idx, val) in arr_data
                result[idx] = val
            end
            data[param_name] = result
        end
        return i
    elseif num_dims == 2
        # 2D array: table format
        arr_data = Dict{Tuple{Int, Int}, Union{Float64, Missing}}()
        while i <= length(lines)
            line = strip(lines[i])
            if line == ";" || isempty(line)
                i += 1
                break
            end
            # Skip header lines
            if line == ":" || startswith(line, ":")
                i += 1
                continue
            end
            parts = split(line)
            if length(parts) >= 3
                idx1 = parse(Int, parts[1])
                idx2 = parse(Int, parts[2])
                arr_data[(idx1, idx2)] = _parse(parts[3])
            end
            i += 1
        end
        # Convert to 2D array
        if !isempty(arr_data)
            max_idx1 = maximum([k[1] for k in keys(arr_data)])
            max_idx2 = maximum([k[2] for k in keys(arr_data)])
            result = Matrix{Union{Float64, Missing}}(undef, max_idx1, max_idx2)
            fill!(result, NaN)
            for ((idx1, idx2), val) in arr_data
                result[idx1, idx2] = val
            end
            data[param_name] = result
        end
        return i
    else
        # 3D+ array: handle slice-by-slice
        return parse_multi_dimensional_array(lines, i, data, param_name, num_dims)
    end
end

"""
    parse_multi_dimensional_array(lines, start_idx, data, param_name, num_dims) -> Int

Parse multi-dimensional arrays (3D+) that are stored slice-by-slice in AMPL format.
"""
function parse_multi_dimensional_array(
    lines::Vector{String}, 
    start_idx::Int, 
    data::Dict{String, Any}, 
    param_name::String,
    num_dims::Int
)
    i = start_idx
    arr_data = Dict{Vector{Int}, Union{Float64, Missing}}()
    current_slice_indices = Dict{Int, Int}()  # Track which slice we're in for each dimension
    
    # Determine dimension sizes by parsing all data first
    dim_sizes = zeros(Int, num_dims)
    
    while i <= length(lines)
        line = strip(lines[i])
        
        if line == ";"
            i += 1
            break
        end
        
        # Check for new slice indicator: [*,*,h] or [*,*,h] :
        # Match [*,*,h] with or without trailing colon
        m = match(r"\[.*?,\s*(\d+)\]", line)
        if m !== nothing
            # This indicates a new slice for the last dimension
            slice_idx = parse(Int, m.captures[1])
            current_slice_indices[num_dims] = slice_idx
            dim_sizes[num_dims] = max(dim_sizes[num_dims], slice_idx)
            i += 1
            # Skip header line with column indices (if present)
            if i <= length(lines) && (strip(lines[i]) == ":" || startswith(strip(lines[i]), ":"))
                i += 1
            end
            continue
        end
        
        # Skip header lines
        if line == ":" || startswith(line, ":")
            i += 1
            continue
        end
        
        # Parse data row
        # For 3D array E[s,w,h] in format: s w1 w2 w3 w4
        # First part is s (dimension 1), remaining parts are values for different w (dimension 2)
        # h (dimension 3) comes from current_slice_indices
        parts = split(line)
        if length(parts) >= 2
            # First part is the index for dimension 1 (s)
            try
                idx1 = parse(Int, parts[1])
                dim_sizes[1] = max(dim_sizes[1], idx1)
                
                # Remaining parts are values for dimension 2 (w) for this s and current h
                h_idx = get(current_slice_indices, num_dims, 1)  # Default to 1 if not set
                for (w_idx, val_str) in enumerate(parts[2:end])
                    # For 3D: E[s, w, h]
                    indices = [idx1, w_idx, h_idx]
                    arr_data[indices] = _parse(val_str)
                    dim_sizes[2] = max(dim_sizes[2], w_idx)
                end
            catch
                # Skip if first part is not an integer (might be a header or comment)
            end
        end
        
        i += 1
    end
    
    # Create multi-dimensional array
    if !isempty(arr_data)
        # For 3D, create a 3D array; for higher dimensions, use nested structure
        if num_dims == 3
            # Ensure all dimensions are at least 1
            dim1 = max(1, dim_sizes[1])
            dim2 = max(1, dim_sizes[2])
            dim3 = max(1, dim_sizes[3])
            result = Array{Union{Float64, Missing}}(undef, dim1, dim2, dim3)
            # Initialize with NaN
            fill!(result, NaN)
            for (indices, val) in arr_data
                if length(indices) == 3
                    result[indices[1], indices[2], indices[3]] = val
                end
            end
            data[param_name] = result
        else
            # For 4D+, store as nested structure or use a more complex representation
            # For now, store as Dict mapping indices to values
            data[param_name] = arr_data
        end
    end
    
    return i
end
