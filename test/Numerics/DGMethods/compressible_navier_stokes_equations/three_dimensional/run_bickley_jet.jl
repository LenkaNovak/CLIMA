#!/usr/bin/env julia --project

include("box.jl")
ClimateMachine.init()

const FT = Float64

#################
# Initial State #
#################
import ClimateMachine.Ocean: ocean_init_state!

function ocean_init_state!(
    model::ThreeDimensionalCompressibleNavierStokes.CNSE3D,
    state,
    aux,
    localgeo,
    t,
)
    ϵ = 0.1 # perturbation magnitude
    l = 0.5 # Gaussian width
    k = 0.5 # Sinusoidal wavenumber

    x = aux.x
    y = aux.y

    # The Bickley jet
    U = cosh(y)^(-2)

    # Slightly off-center vortical perturbations
    Ψ = exp(-(y + l / 10)^2 / (2 * (l^2))) * cos(k * x) * cos(k * y)

    # Vortical velocity fields (ũ, ṽ) = (-∂ʸ, +∂ˣ) ψ̃
    u = Ψ * (k * tan(k * y) + y / (l^2))
    v = -Ψ * k * tan(k * x)

    ρ = model.ρₒ
    state.ρ = ρ
    state.ρu = ρ * @SVector [U + ϵ * u, ϵ * v, -0]
    state.ρθ = ρ * sin(k * y)

    return nothing
end

#################
# RUN THE TESTS #
#################

vtkpath =
    abspath(joinpath(ClimateMachine.Settings.output_dir, "vtk_bickley_3D"))

let
    # simulation times
    timeend = FT(200) # s
    dt = FT(0.02) # s
    nout = Int(100)

    # Domain Resolution
    N = 3
    Nˣ = 8
    Nʸ = 8
    Nᶻ = 2

    # Domain size
    Lˣ = 4 * FT(π)  # m
    Lʸ = 4 * FT(π)  # m
    Lᶻ = 4 * FT(π)  # m

    # model params
    cₛ = sqrt(10) # m/s
    ρₒ = 1 # kg/m³
    μ = 0 # 1e-6,   # m²/s
    ν = 0 # 1e-6,   # m²/s
    κ = 0 # 1e-6,   # m²/s

    resolution = (; N, Nˣ, Nʸ, Nᶻ)
    domain = (; Lˣ, Lʸ, Lᶻ)
    timespan = (; dt, nout, timeend)
    params = (; cₛ, ρₒ, μ, ν, κ)

    config = Config(
        "rusanov_overintegration",
        resolution,
        domain,
        params;
        numerical_flux_first_order = RoeNumericalFlux(),
        Nover = 1,
        periodicity = (true, true, true),
        boundary = ((0, 0), (0, 0), (0, 0)),
        boundary_conditons = (ClimateMachine.Ocean.OceanBC(
            Impenetrable(FreeSlip()),
            Insulating(),
        ),),
    )

    tic = Base.time()

    run_CNSE(config, resolution, timespan; TimeStepper = SPRK22Heuns)

    toc = Base.time()
    time = toc - tic
    println(time)
end
