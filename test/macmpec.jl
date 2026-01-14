using Test
import MacMPEC
import AMPLDataReader

@testset "$name" for name in MacMPEC.list()
    problem = MacMPEC.problem(name)
    data = AMPLDataReader.read_ampl_dat(MacMPEC.dat_path(problem))
    @test data isa Dict{String}
end
