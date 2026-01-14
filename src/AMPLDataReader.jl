"""
    AMPLDataReader.jl

A Julia package for parsing AMPL .dat files into Julia data structures.

# Example

```julia
using AMPLDataReader

# Parse an AMPL .dat file
data = read_ampl_dat("model.dat")

# Access parameters
S = data["S"]  # Scalar parameter
rho = data["rho"]  # 1D array
E = data["E"]  # Multi-dimensional array
```

# Supported Formats

- Scalar parameters: `param S := 5;`
- 1D arrays: `param rho := 1 0.5 2 0.3;` or table format
- 2D arrays: Table format with row/column indices
- 3D+ arrays: Multi-dimensional table format
- Sets: `set N := 1 2 3;`
- Tables with multiple columns: `param : C R := ...`
"""
module AMPLDataReader

import OrderedCollections

export read_ampl_dat, parse_ampl_dat

include("model.jl")
include("parser.jl")

end # module
