# AMPLData.jl

A Julia package for parsing AMPL `.dat` files into JuMP containers.

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/blegat/AMPLDataReader.jl")
```

## Usage

```julia
using AMPLData

# Parse an AMPL .dat file
data = read_ampl_dat("model.dat")

# Access parameters
S = data["S"]        # Scalar parameter
W = data["W"]        # Scalar parameter
rho = data["rho"]    # 1D array
E = data["E"]        # Multi-dimensional array
C = data["C"]        # 2D array
R = data["R"]        # 2D array
```

## Supported Formats

### Scalar Parameters
```ampl
param S := 5;
param W := 4;
```

### 1D Arrays
```ampl
param rho := 
1 0.323232
2 0.161616
3 0.159091;
```

### 2D Arrays
```ampl
param C : 1 2 :=
1 82.2636 94.0192
2 86.1146 98.512;
```

### 3D+ Arrays
```ampl
param E [*,*,1] : 1 2 3 4 :=
1 199.845 199.845 160.426 160.426
2 210.757 210.757 159.036 159.036;

[*,*,2] : 1 2 3 4 :=
1 0 0 39.4193 39.4193
2 0 0 51.7206 51.7206;
```

### Multi-Column Tables
```ampl
param : C R polyX :=
1 1 82.2636 126.503 2
1 2 94.0192 130.503 1
2 1 86.1146 125.456 2;
```

### Sets
```ampl
set N := 1 2 3 4 5;
```

## API

### `read_ampl_dat(filename::String) -> Dict{String, Any}`

Read an AMPL .dat file and return a dictionary mapping parameter names to their values.

### `parse_ampl_dat(lines::Vector{String}) -> Dict{String, Any}`

Parse AMPL .dat file content from a vector of lines.

## Examples

See the `test/` directory for more examples.


### Acknowledgement

This package was partially developed with the help of Claude.
