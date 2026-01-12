using AMPLData
using Test

@testset "AMPLData.jl" begin
    # Test scalar parameters
    lines = ["param S := 5;", "param W := 4;"]
    data = parse_ampl_dat(lines)
    @test data["S"] == 5
    @test data["W"] == 4
    
    # Test 1D array
    lines = [
        "param rho := ",
        "1 0.323232",
        "2 0.161616",
        "3 0.159091;"
    ]
    data = parse_ampl_dat(lines)
    @test length(data["rho"]) >= 3
    @test data["rho"][1] ≈ 0.323232
    
    # Test multi-column table with 1 index (1D arrays)
    lines = [
        "param ",
        ":      rho       beta   alpha    := ",
        "1   0.323232    0.67957    0",
        "2   0.161616    0.67957    0",
        "3   0.159091    0.67957    0",
        ";"
    ]
    data = parse_ampl_dat(lines)
    @test haskey(data, "rho")
    @test haskey(data, "beta")
    @test haskey(data, "alpha")
    @test isa(data["rho"], Vector)
    @test isa(data["beta"], Vector)
    @test isa(data["alpha"], Vector)
    @test length(data["rho"]) >= 3
    @test data["rho"][1] ≈ 0.323232
    
    # Test multi-column table with 2 indices (2D matrices)
    lines = [
        "param ",
        ":        C          R        polyX       := ",
        "1 1    82.2636   126.503    2",
        "1 2    94.0192   130.503    1",
        "2 1    86.1146   125.456    2",
        "2 2    98.512    142.33     1",
        ";"
    ]
    data = parse_ampl_dat(lines)
    @test haskey(data, "C")
    @test haskey(data, "R")
    @test haskey(data, "polyX")
    @test isa(data["C"], Matrix)
    @test isa(data["R"], Matrix)
    @test isa(data["polyX"], Matrix)
    @test size(data["C"]) == (2, 2)
    @test size(data["R"]) == (2, 2)
    @test size(data["polyX"]) == (2, 2)
    @test data["C"][1, 1] ≈ 82.2636
    @test data["C"][1, 2] ≈ 94.0192
    @test data["C"][2, 1] ≈ 86.1146
    @test data["C"][2, 2] ≈ 98.512
    @test data["R"][1, 1] ≈ 126.503
    @test data["R"][1, 2] ≈ 130.503
    @test data["R"][2, 1] ≈ 125.456
    @test data["R"][2, 2] ≈ 142.33
    
    println("All tests passed!")
end
