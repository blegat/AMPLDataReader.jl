import JuMP
import MathOptInterface as MOI

struct Axe
    name::String
    set::String
end

function Base.parse(::Type{Axe}, s::AbstractString)
    sp = strip.(split(s))
    if length(sp) == 1
        return Axe(nothing, s)
    else
        @assert sp[2] == "in"
        return Axe(sp[1], sp[3])
    end
end

struct Axes
    axes::Vector{Axe}
    condition::Union{Nothing,String}
end

function _parse_axes(rest::AbstractString)
    if startswith(rest, "{")
        j = findfirst(isequal('}'), rest)
        if isnothing(j)
            error("Cannot find closing } in $rest")
        end
        axes_str, rest = rest[2:(j-1)], strip(rest[j+1:end])
        axes_str, cond = next_token(axes_str, ':')
        axes = parse.(Axe, strip.(split(axes_str, ',')))
        return Axes(axes, isempty(cond) ? nothing : cond), rest
    else
        return nothing, rest
    end
end

struct Param
    name::String
    axes::Union{Nothing,Axes}
    integer::Bool
    default::Union{Nothing,Float64}
end

function Base.parse(::Type{Param}, rest::AbstractString)
    name, rest = strip.(split(rest, limit = 2))
    axes, rest = _parse_axes(rest)
    default = nothing
    integer = false
    while !isempty(rest)
        command, rest = _get_command(rest, ["default", "integer"])
        if command == "default"
            def, rest = next_token(rest)
            default = parse(Float64, def)
        elseif command == "integer"
            integer = true
        end
    end
    return Param(name, axes, integer, default)
end

struct Var
    name::String
    axes::Union{Nothing,Axes}
    lower_bound::Union{Nothing,String}
    upper_bound::Union{Nothing,String}
end

function Base.parse(::Type{Var}, rest::AbstractString)
    name, rest = strip.(split(rest, limit = 2))
    axes, rest = _parse_axes(rest)
    lower_bound = nothing
    upper_bound = nothing
    rest = strip(replace(rest, "," => ""))
    while !isempty(rest)
        command, rest = _get_command(rest, [">=", "<="])
        if command == ">="
            upper_bound, rest = next_token(rest)
        elseif command == "<="
            upper_bound, rest = next_token(rest)
        end
    end
    return Var(name, axes, lower_bound, upper_bound)
end

struct Objective
    name::String
    sense::MOI.OptimizationSense
    expression::String
end

function parse_objective(sense::MOI.OptimizationSense, s::AbstractString)
    sp = strip.(split(s, ':'))
    if length(sp) == 1
        return Objective(nothing, sense, s)
    else
        name, expr = sp
        return Objective(name, sense, expr)
    end
end

struct Constraint
    name::String
    axes::Union{Nothing,Axes}
    expr::String
end

function Base.parse(::Type{Constraint}, s::AbstractString)
    @show s
    header, expr = strip.(rsplit(s, ':', limit = 2))
    @show header
    @show expr
    name, axe = strip.(split(header, limit = 2))
    @show axe
    axe, rest = _parse_axes(axe)
    @show axe
    @show rest
    @assert isempty(rest)
    return Constraint(name, axe, expr)
end

mutable struct Model
    params::OrderedCollections.OrderedDict{String,Param}
    vars::OrderedCollections.OrderedDict{String,Var}
    objective::Union{Nothing,Objective}
    constraints::Vector{Constraint}
    function Model()
        return new(
            OrderedCollections.OrderedDict{String,Param}(),
            OrderedCollections.OrderedDict{String,Var}(),
            nothing,
            Constraint[],
        )
    end
end

function Base.parse(::Type{Model}, mod::AbstractString)
    model = Model()
    commands = filter(!isempty, strip.(split(mod, ';')))
    first_constraint = nothing
    for (i, command) in enumerate(commands)
        command, rest = AMPLDataReader._get_command(command, ["param", "var", "maximize", "subject to"])
        if command == "param"
            param = Base.parse(Param, rest)
            push!(model.params, param.name => param)
        elseif command == "var"
            var = Base.parse(Var, rest)
            push!(model.vars, var.name => var)
        elseif command == "maximize"
            model.objective = parse_objective(MOI.MAX_SENSE, rest)
        else
            @assert command == "subject to"
            push!(model.constraints, Base.parse(Constraint, rest))
            first_constraint = i + 1
            break
        end
    end
    for command in commands[first_constraint:end]
        push!(model.constraints, Base.parse(Constraint, command))
    end
    return model
end

function parse_model(path::AbstractString)
    return parse(Model, read(path, String))
end

function next_token(s::AbstractString, args...)
    token_rest = strip.(split(s, args...; limit = 2))
    if length(token_rest) == 1
        return token_rest[], ""
    else
        token, rest = token_rest
        return token, rest
    end
end
