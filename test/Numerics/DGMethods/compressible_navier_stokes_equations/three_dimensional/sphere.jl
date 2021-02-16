include("../CNSE.jl")
include("ThreeDimensionalCompressibleNavierStokesEquations.jl")

function Config(
    name,
    resolution,
    domain,
    params;
    numerical_flux_first_order = RoeNumericalFlux(),
    Nover = 0,
    boundary = (1, 1),
    boundary_conditons = (ClimateMachine.Ocean.OceanBC(
        Impenetrable(FreeSlip()),
        Insulating(),
    ),),
)
    mpicomm = MPI.COMM_WORLD
    ArrayType = ClimateMachine.array_type()

    println(string(resolution.Nᶻ) * " elems in the vertical")

    vert_range =
        grid1d(domain.min_height, domain.max_height, nelem = resolution.Nᶻ)

    println(
        string(resolution.Nʰ) * "x" * string(resolution.Nʰ) * " elems per face",
    )

    topology = StackedCubedSphereTopology(
        mpicomm,
        resolution.Nʰ,
        vert_range;
        boundary = boundary,
    )

    println("poly order is " * string(resolution.N))
    println("OI order is " * string(Nover))

    grid = DiscontinuousSpectralElementGrid(
        topology,
        FloatType = FT,
        DeviceArray = ArrayType,
        polynomialorder = resolution.N + Nover,
        meshwarp = cubedshellwarp,
    )

    if (params.cᶻ == params.cₛ)
        pressure = IsotropicPressure{FT}(cₛ = params.cₛ, ρₒ = params.ρₒ)
    else
        pressure = AinsotropicPressure{FT}(
            cₛ = params.cₛ,
            cᶻ = params.cᶻ,
            ρₒ = params.ρₒ,
        )
    end

    model = ThreeDimensionalCompressibleNavierStokes.CNSE3D{FT}(
        (domain.min_height, domain.max_height),
        ClimateMachine.Orientations.SphericalOrientation(),
        pressure,
        ClimateMachine.Ocean.NonLinearAdvectionTerm(),
        ThreeDimensionalCompressibleNavierStokes.ConstantViscosity{FT}(
            μ = params.μ,
            ν = params.ν,
            κ = params.κ,
        ),
        nothing,
        nothing,
        boundary_conditons,
    )

    dg = DGModel(
        model,
        grid,
        numerical_flux_first_order,
        CentralNumericalFluxSecondOrder(),
        CentralNumericalFluxGradient(),
    )

    return Config(name, dg, Nover, mpicomm, ArrayType)
end

import ClimateMachine.Ocean: ocean_init_aux!

function ocean_init_aux!(
    ::ThreeDimensionalCompressibleNavierStokes.CNSE3D,
    aux,
    geom,
)
    @inbounds begin
        aux.x = geom.coord[1]
        aux.y = geom.coord[2]
        aux.z = geom.coord[3]
    end

    return nothing
end
