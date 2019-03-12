module Francy

export canvas, graph, shape, link, menu, callback, message, Trigger
import Base.push!, Base.show

using JSON, IJulia

const FrancyMimeString = "application/vnd.francy+json"
const FrancyMime = MIME"application/vnd.francy+json"


function __init__()
  #once..
  IJulia.register_mime(MIME(FrancyMimeString))

  #useful for debugging Trigger...
  #IJulia.set_verbose(true)
end

Base.istextmime(::FrancyMime) = true

id_cnt = 0
function create_id()
  global id_cnt += 1
  return "id$id_cnt"
end

abstract type FrancyType end

mutable struct Canvas <: FrancyType
  c::Dict
end

mutable struct Graph <: FrancyType
  g::Dict
end

mutable struct Message <: FrancyType
  m::Dict
end

mutable struct Menu <: FrancyType
  m::Dict
end

mutable struct Chart <: FrancyType
  c::Dict
end

mutable struct Callback <: FrancyType
  c::Dict
end

mutable struct Shape <: FrancyType
  s::Dict
end

mutable struct Link <: FrancyType
  l::Dict
end

function show(io::IO, t::FrancyMime, c::Canvas)
  C = Dict(:version => "1.0.4",
       :mime => FrancyMimeString,
       :canvas => c.c
       )
  print(io, JSON.json(C))
end

canvas_cache = Dict{String, WeakRef}()

function canvas(t::String; width = 800, height = 600)
  C = Canvas(Dict(:width => width,
         :id => create_id(),
         :height => height,
         :title => t,
         :zoomToFit => true,
         :texTypesetting => false,
         :menus => Dict(),
         :messages => Dict(),
         :graph => Dict()
    ))
  
  global canvas_cache
  canvas_cache[C.c[:id]] = WeakRef(C)
  return C
end

#= type can be
  :directed
  :tree
  :undirected
=#
function graph()
  return Graph(Dict(:type => :directed,
              :id => create_id(),
              :simulation => false,
              :collapsed => true,
              :links => Dict(),
              :nodes => Dict(),
              :messages => Dict(), 
              ))
end

function push!(C::Canvas, G::Graph)
  if length(C.c[:graph]) > 0
    error("Graph already present")
  end
  C.c[:graph] = G.g
end

#= type can be
 :triangle
 :diamond
 :circle
 :square
 :cross
 :star
 :wye
=#
function shape(n::String, type::Symbol = :circle)
  return Shape(Dict(:type => type,
              :id => create_id(),
              :size => 10,
              :x => 0,
              :y => 0,
              :title => n,
              :layer => 0,
              :color => "",
              :parent => "",
              :menus => Dict(),
              :messages => Dict(),
              :callbacks => Dict()
              ))
end

function link(s::Shape, t::Shape; title = "", length = 0, weight = 0)
  return Link(Dict(:id => create_id(),
              :source => s.s[:id],
              :target => t.s[:id],
              :length => length,
              :weight => weight,
              :color => "",
              :title => title,
              :invisible => false
              ))
end

function push!(G::Graph, S::Shape)
  G.g[:nodes][S.s[:id]] = S.s
end

function push!(G::Graph, L::Link)
  G.g[:links][L.l[:id]] = L.l
end

#= trigger can be
  :click  -> mouse event, left click in js
  :context -> mouse event, right click or context-menu
  :dblclick -> mouse event, double click
=#
function callback(f::String, a::String)
  return Callback(Dict(:id => create_id(),
              :func => f,
              :trigger => :click,
              :knownArgs => a,
              :requiredArgs => Dict()
              ))
end

function menu(t::String, C::Callback)
  return Menu(Dict(:id => create_id(),
              :title => t,
              :callback => C.c))
end

function add(k::Symbol, a::Dict, m::Dict)
  a[k][m[:id]] = m
end

push!(C::Canvas, M::Menu) = add(:menus, C.c, M.m)
push!(G::Graph, M::Menu) = add(:menus, G.g, M.m)
push!(S::Shape, M::Menu) = add(:menus, S.s, M.m)

push!(C::Canvas, M::Message) = add(:messages, C.c, M.m)
push!(G::Graph, M::Message) = add(:messages, G.g, M.m)
push!(S::Shape, M::Message) = add(:messages, S.s, M.m)

push!(S::Shape, C::Callback) = add(:callbacks, S.s, C.c)


#= type can be
  :info
  :error
  :success
  :warning
  :default
=#
function message(s::String, t::Symbol = :default)
  return Message(Dict(:id => create_id(),
              :type => t,
              :title => s,
              :value => "v:$s"
              ))
end

function id(C::Canvas)
  return C.c[:id]
end

function canvas(id::Symbol)
  global canvas_cache
  return canvas_cache[string(id)].value
end

#=
 THE MAGIC!
Trigger from java script when a call back is executed...
it gets a string in json which is composed of the info.
Experimentally, the above works, the interface needs more work...
=#


function Trigger(a::String)  #needs to be in global scope
  # incomplete: there can be more args.
  b = JSON.parse(a)
  c = b["func"] * "(" * b["knownArgs"] * ")"
  res = Core.eval(Main, Meta.parse(c))
end  

end

