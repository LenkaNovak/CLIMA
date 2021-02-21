using ClimateMachine, MPI
ClimateMachine.init()

include("spatial_model.jl")
include("domain_hooks.jl")
include("CNSE.jl")
include("dissipation_models.jl")

include("abstract_timesteppers.jl")
include("abstract_simulation.jl")

include("./three_dimensional/ThreeDimensionalCompressibleNavierStokesEquations.jl")

import Main.ThreeDimensionalCompressibleNavierStokes: ThreeDimensionalCompressibleNavierStokesEquations

# import ThreeDimensionalCompressibleNavierStokes


# include(pwd() * "/test/Numerics/DGMethods/compressible_navier_stokes_equations/boiler_plate.jl")