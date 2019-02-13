module JSObjectLiteral

export @js

"""
@json expression

Tries to parse `expression` as a javascript object literal.

If `expression` is a valid Julia expression, and (almost) looks like a javascript
object literal, it is parsed and converted into a Julia json-like structure.

# Examples
```
e = 5.0
g = "gee!"
j = Dict("k": 1_000)
@js {
  a: 1,
  b: [2, 3],
  c : {
    d: "doubly-quoted string",
    e
  },
  f: g,
  h.i: j.k
}
```
"""
macro js(expr)
    ##dump(expr)
    ret = :($(esc(js(expr))))
    ##dump(ret, maxdepth=20)
    return ret
end

## for expressions, dispatch according to the head
js(expr::Expr) = js(Val{expr.head}, expr)
js(x) = x

## assignment
function js(::Type{Val{:(=)}}, expr)
    if isa(expr.args[1], Expr) && expr.args[1].head == :braces
        error("Assignment to braces expression not supported yet")
        all(isa(arg, Symbol) for arg in expr.args[1].args) || error("Assignment to braced expression must only contain keys")
        lhs = Expr(:tuple, expr.args[1].args...)
        keys = map(string, expr.args[1].args...)
        dict = js(expr.args[2])
        rhs = :([$dict[key] for key in $keys])
        return Expr(:(=), lhs, :($rhs))
    else
        expr.args = map(js, expr.args)
        return expr
    end
end

## key index
function js(::Type{Val{:.}}, expr)
    return Expr(:ref, js(expr.args[1]), string(expr.args[2].value))
end

## array index
function js(::Type{Val{:ref}}, expr)
    return Expr(:ref, js(expr.args[1]), expr.args[2])
end

## dictionary creation
function js(::Type{Val{:braces}}, expr)
    dict = :(Dict{String,Any}())
    for arg in expr.args
        push!(dict.args, pair(arg))
    end
    return dict
end

function pair(e::Expr)
    if e.head != :call || length(e.args) !=3 || e.args[1] != :(:)
        error("Expected : operator with 2 arguments")
    end
    return keyvalue(e.args[2], e.args[3])
end
pair(s::Symbol) = :($(string(s)) => $(js(s)))

## keyvalue deals with keys of the type a.b
function keyvalue(key::Expr, value)
    key.head == :. || error("Expected . operator")
    expr = Expr(:braces, Expr(:call, :(:), key.args[2].value, value))
    return keyvalue(key.args[1], expr)
end
keyvalue(key::Symbol, value) = :($(string(key)) => $(js(value)))
keyvalue(key::AbstractString, value) = :(key => $(js(value)))

## array creation
function js(::Type{Val{:vect}}, expr)
    return Expr(:ref, :Any, map(js, expr.args)...) ## make sure
end


function js(x, expr)
    ## @warn "catchall js(x, expr)"
    return expr
end

## experimental stuff

macro identity(e)
    :($(esc(id(e))))
end

function id(e::Expr)
    print("Expression ")
    dump(e)
    return e
end

function id(s::Symbol)
    print("Symbol ")
    dump(s)
    return s
end

function id(x)
    print("Other ")
    dump(x)
    return x
end

end
