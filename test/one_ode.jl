# This file is part of the TaylorIntegration.jl package; MIT licensed

using TaylorIntegration
using Test
using LinearAlgebra: norm
using Logging
import Logging: Warn

@testset "Testing `one_ode.jl`" begin

    local _order = 28
    local _abstol = 1.0E-20
    local tT = Taylor1(_order)

    max_iters_reached() = "Maximum number of integration steps reached; exiting.\n"

    @testset "Tests: dot{x}=x^2, x(0) = 1" begin
        eqs_mov(x, p, t) = x^2
        t0 = 0.0
        x0 = 1.0
        x0T = Taylor1(x0, _order)
        tT[1] = t0
        TaylorIntegration.jetcoeffs!(eqs_mov, tT, x0T, nothing)
        @test x0T.coeffs[end] == 1.0
        δt = _abstol^inv(_order-1)
        @test TaylorIntegration.stepsize(x0T, _abstol) == δt

        tv, xv = (@test_logs (Warn, max_iters_reached()) taylorinteg(
            eqs_mov, 1, 0.0, 1.0, _order, _abstol))
        @test length(tv) == 501
        @test length(xv) == 501
        @test xv[1] == x0
        @test tv[end] < 1.0

        tv, xv = (@test_logs (Warn, max_iters_reached()) taylorinteg(
            eqs_mov, x0, 0.0, 1.0, _order, _abstol, nothing))
        @test length(tv) == 501
        @test length(xv) == 501
        @test xv[1] == x0
        @test tv[end] < 1.0

        trange = 0.0:1/8:1.0
        xv = (@test_logs (Warn, max_iters_reached()) taylorinteg(
            eqs_mov, 1, trange, _order, _abstol))
        @test length(xv) == length(trange)
        @test typeof(xv) == Array{typeof(x0),1}
        @test xv[1] == x0
        @test isnan(xv[end])
        @test abs(xv[5] - 2.0) ≤ eps(2.0)
        tvr, xvr = (@test_logs min_level=Logging.Warn taylorinteg(
            eqs_mov, x0, trange[1], trange[end-1], _order, _abstol))
        @test tvr[1] == trange[1]
        @test tvr[end] == trange[end-1]
        @test xvr[1] == xv[1]
        @test xvr[end] == xv[end-1]

        trange = 0.0:1/8:1.0
        xv = (@test_logs (Warn, max_iters_reached()) taylorinteg(
            eqs_mov, x0, trange, _order, _abstol, nothing))
        @test length(xv) == length(trange)
        @test typeof(xv) == Array{typeof(x0),1}
        @test xv[1] == x0
        @test isnan(xv[end])
        @test abs(xv[5] - 2.0) ≤ eps(2.0)
        tvr, xvr = (@test_logs min_level=Logging.Warn taylorinteg(
            eqs_mov, x0, trange[1], trange[end-1], _order, _abstol, nothing))
        @test tvr[1] == trange[1]
        @test tvr[end] == trange[end-1]
        @test xvr[1] == xv[1]
        @test xvr[end] == xv[end-1]

        tarray = vec(trange)
        xv2 = (@test_logs (Warn, max_iters_reached()) taylorinteg(
            eqs_mov, x0, tarray, _order, _abstol))
        @test xv[1:end-1] == xv2[1:end-1]
        @test xv2[1:end-1] ≈ xv[1:end-1] atol=eps() rtol=0.0
        @test length(xv2) == length(tarray)
        @test typeof(xv2) == Array{typeof(x0),1}
        @test xv2[1] == x0
        @test isnan(xv2[end])
        @test abs(xv2[5] - 2.0) ≤ eps(2.0)

        # Output includes Taylor polynomial solution
        tv, xv, polynV = (@test_logs (Warn, max_iters_reached()) taylorinteg(
            eqs_mov, x0, 0, 0.5, _order, _abstol, Val(true), maxsteps=2))
        @test length(polynV) == 3
        @test xv[1] == x0
        @test polynV[1] == Taylor1(x0, _order)
        @test xv[2] == evaluate(polynV[2], tv[2]-tv[1])
        @test polynV[2] == Taylor1(ones(_order+1))
    end

    @testset "Tests: dot{x}=x^2, x(0) = 3; nsteps <= maxsteps" begin
        eqs_mov(x, p, t) = x.^2 #the ODE (i.e., the equations of motion)
        exactsol(t, x0) = x0/(1.0-x0*t) #the analytical solution
        t0 = 0.0
        tmax = 0.3
        x0 = 3.0
        x0T = Taylor1(x0, _order)
        tT[1] = t0
        TaylorIntegration.jetcoeffs!(eqs_mov, tT, x0T, nothing)
        @test x0T.coeffs[end] == 3.0^(_order+1)
        δt = (_abstol/x0T.coeffs[end-1])^inv(_order-1)
        @test TaylorIntegration.stepsize(x0T, _abstol) == δt

        tv, xv = (@test_logs min_level=Logging.Warn taylorinteg(
            eqs_mov, x0, 0, tmax, _order, _abstol))
        @test length(tv) < 501
        @test length(xv) < 501
        @test length(tv) == 14
        @test length(xv) == 14
        @test xv[1] == x0
        @test tv[end] < 1/3
        @test tv[end] == tmax
        @test abs(xv[end]-exactsol(tv[end], xv[1])) < 5e-14

        tmax = 0.33
        tv, xv = (@test_logs min_level=Logging.Warn taylorinteg(
            eqs_mov, x0, t0, tmax, _order, _abstol))
        @test length(tv) < 501
        @test length(xv) < 501
        @test length(tv) == 28
        @test length(xv) == 28
        @test xv[1] == x0
        @test tv[end] < 1/3
        @test tv[end] == tmax
        @test abs(xv[end]-exactsol(tv[end], xv[1])) < 1e-11
    end

    @testset "Test non-autonomous ODE (1): dot{x}=cos(t)" begin
        let f(x, p, t) = cos(t)
            t0 = 0//1
            tmax = 10.25*(2pi)
            abstol = 1e-20
            order = 25
            x0 = 0.0 #initial conditions such that x(t)=sin(t)

            tv, xv = (@test_logs min_level=Logging.Warn taylorinteg(
                f, x0, t0, tmax, order, abstol))
            @test length(tv) < 501
            @test length(xv) < 501
            @test xv[1] == x0
            @test tv[1] == t0
            @test abs(sin(tmax)-xv[end]) < 1e-14

            # Backward integration
            tb, xb = (@test_logs min_level=Logging.Warn taylorinteg(
                f, sin(tmax), tmax, t0, order, abstol))
            @test length(tb) < 501
            @test length(xb) < 501
            @test xb[1] == sin(tmax)
            @test tb[1] > tb[end]
            @test abs(sin(t0)-xb[end]) < 5e-14

            # Tests with a range, for comparison with backward integration
            tmax = 15*(2pi)
            Δt = (tmax-t0)/1024
            tspan = t0:Δt:tmax
            xv = (@test_logs min_level=Logging.Warn taylorinteg(
                f, x0, tspan, order, abstol))
            @test xv[1] == x0
            @test abs(sin(tmax)-xv[end]) < 1e-14

            # Backward integration
            xback = (@test_logs min_level=Logging.Warn taylorinteg(
                f, xv[end], reverse(tspan), order, abstol))
            @test xback[1] == xv[end]
            @test abs(sin(t0)-xback[end]) < 5e-14
            @test norm(xv[:]-xback[end:-1:1], Inf) < 5.0e-14

            # Tests if trange is properly sorted
            @test_throws AssertionError taylorinteg(f, x0, rand(t0:Δt:tmax, 100), order, abstol)
        end
    end

end
