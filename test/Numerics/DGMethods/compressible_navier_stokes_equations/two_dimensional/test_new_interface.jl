#!/usr/bin/env julia --project
include("../boilerplate.jl")
include("TwoDimensionalCompressibleNavierStokesEquations.jl")

ClimateMachine.init()

setups = [
    (;
        name = "rusanov_periodic",
        flux = RusanovNumericalFlux(),
        periodicity = true,
        Nover = 0,
    ),
    (;
        name = "roeflux_periodic",
        flux = RoeNumericalFlux(),
        periodicity = true,
        Nover = 0,
    ),
    (;
        name = "rusanov",
        flux = RusanovNumericalFlux(),
        periodicity = false,
        Nover = 0,
    ),
    (;
        name = "roeflux",
        flux = RoeNumericalFlux(),
        periodicity = false,
        Nover = 0,
    ),
    (;
        name = "rusanov_overintegration",
        flux = RusanovNumericalFlux(),
        periodicity = false,
        Nover = 1,
    ),
    (;
        name = "roeflux_overintegration",
        flux = RoeNumericalFlux(),
        periodicity = false,
        Nover = 1,
    ),
]

#################
# RUN THE TESTS #
#################
@testset "$(@__FILE__)" begin

    include("refvals_bickley_jet.jl")

    ########
    # Define physical parameters and parameterizations
    ########
    parameters = (
        ϵ = 0.1,  # perturbation size for initial condition
        l = 0.5, # Gaussian width
        k = 0.5, # Sinusoidal wavenumber
        ρₒ = 1.0, # reference density
        c = 2,
        g = 10,
    )

    physics = FluidPhysics(;
        advection = NonLinearAdvectionTerm(),
        dissipation = ConstantViscosity{Float64}(μ = 0, ν = 0, κ = 0),
        coriolis = nothing,
        buoyancy = nothing,
    )

    ########
    # Define boundary conditions
    ########
    ρu_bc = Impenetrable(FreeSlip())
    ρθ_bc = Insulating()
    ρu_bcs = (south = ρu_bc, north = ρu_bc)
    ρθ_bcs = (south = ρθ_bc, north = ρθ_bc)
    BC = (ρθ = ρθ_bcs, ρu = ρu_bcs)

    ########
    # Define initial conditions
    ########

    # The Bickley jet
    U₀(x, y, z, p) = cosh(y)^(-2)

    # Slightly off-center vortical perturbations
    Ψ₀(x, y, z, p) =
        exp(-(y + p.l / 10)^2 / (2 * (p.l^2))) * cos(p.k * x) * cos(p.k * y)

    # Vortical velocity fields (ũ, ṽ) = (-∂ʸ, +∂ˣ) ψ̃
    u₀(x, y, z, p) = Ψ₀(x, y, z, p) * (p.k * tan(p.k * y) + y / (p.l^2))
    v₀(x, y, z, p) = -Ψ₀(x, y, z, p) * p.k * tan(p.k * x)

    ρ₀(x, y, z, p) = p.ρₒ
    ρu₀(x, y, z, p) = ρ₀(x, y, z, p) * (p.ϵ * u₀(x, y, z, p) + U₀(x, y, z, p))
    ρv₀(x, y, z, p) = ρ₀(x, y, z, p) * p.ϵ * v₀(x, y, z, p)
    ρw₀(x, y, z, p) = ρ₀(x, y, z, p) * 0.0
    ρθ₀(x, y, z, p) = ρ₀(x, y, z, p) * sin(p.k * y)

    ρu⃗₀(x, y, z, p) =
        @SVector [ρu₀(x, y, z, p), ρv₀(x, y, z, p), ρw₀(x, y, z, p)]
    initial_conditions = (ρ = ρ₀, ρu = ρu⃗₀, ρθ = ρθ₀)

    ########
    # Define timestepping parameters
    ########
    start_time = 0
    end_time = 200.0
    Δt = 0.02
    method = LSRK54CarpenterKennedy

    timestepper = TimeStepper(method = method, timestep = Δt)

    ########
    # Define callbacks
    ########
    callbacks = (Info(), StateCheck(10))

    for setup in setups[6:6]
        @testset "$(setup.name)" begin
            Ωˣ = Periodic(-2π, 2π)
            Ωʸ = IntervalDomain(-2π, 2π, periodic = setup.periodicity)
            Ω = Ωˣ × Ωʸ

            grid = DiscretizedDomain(
                Ω,
                elements = 16,
                polynomialorder = 3 + setup.Nover,
            )

            numerics = (flux = setup.flux, overintegration = setup.Nover)

            model = SpatialModel(
                balance_law = Fluid2D(),
                physics = physics,
                numerics = numerics,
                grid = grid,
                boundary_conditions = BC,
                parameters = parameters,
            )

            simulation = Simulation(
                model = model,
                initial_conditions = initial_conditions,
                timestepper = timestepper,
                callbacks = callbacks,
                time = (; start = start_time, finish = end_time),
            )

            ########
            # Run the model
            ########
            evolve!(
                simulation,
                model;
                refDat = getproperty(refVals, Symbol(setup.name)),
            )
        end
    end
end
