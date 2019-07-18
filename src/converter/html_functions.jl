"""
$(SIGNATURES)

Helper function to process an individual block when it's a `HFun` such as `{{ fill author }}`.
Dev Note: `fpath` is (currently) unused but is passed to all `convert_html_block` functions.
See [`convert_html`](@ref).
"""
function convert_html_block(β::HFun, allvars::PageVars, ::AbstractString="")::String
    # normalise function name and apply the function
    fn = lowercase(β.fname)
    haskey(HTML_FUNCTIONS, fn) && return HTML_FUNCTIONS[fn](β.params, allvars)
    # if we get here, then the function name is unknown, warn and ignore
    @warn "I found a function block '{{$fn ...}}' but don't recognise the function name. Ignoring."
    return ""
end


"""
$(SIGNATURES)

H-Function of the form `{{ fill vname }}` to plug in the content of a jd-var `vname` (assuming it
can be represented as a string).
"""
function hfun_fill(params::Vector{String}, allvars::PageVars)::String
    # check params
    if length(params) != 1
        throw(HTMLFunctionError("I found a {{fill ...}} with more than one parameter. Verify."))
    end
    # form the fill
    replacement = ""
    vname = params[1]
    if haskey(allvars, vname)
        # retrieve the value stored
        tmp_repl = allvars[vname].first
        isnothing(tmp_repl) || (replacement = string(tmp_repl))
    else
        @warn "I found a '{{fill $vname}}' but I do not know the variable '$vname'. Ignoring."
    end
    return replacement
end


"""
$(SIGNATURES)

H-Function of the form `{{ insert fpath }}` to plug in the content of a file at `fpath`. Note that
the base path is assumed to be `PATHS[:src_html]` so paths have to be expressed relative to that.
"""
function hfun_insert(params::Vector{String})::String
    # check params
    if length(params) != 1
        throw(HTMLFunctionError("I found a {{insert ...}} with more than one parameter. Verify."))
    end
    # apply
    replacement = ""
    fpath = joinpath(PATHS[:src_html], split(params[1], "/")...)
    if isfile(fpath)
        replacement = convert_html(read(fpath, String), merge(GLOBAL_PAGE_VARS, LOCAL_PAGE_VARS))
    else
        @warn "I found an {{insert ...}} block and tried to insert '$fpath' but I couldn't find the file. Ignoring."
    end
    return replacement
end


"""
$(SIGNATURES)

H-Function of the form `{{href ... }}`.
"""
function hfun_href(params::Vector{String})::String
    # check params
    if length(params) != 2
        throw(HTMLFunctionError("I found an {{href ...}} block and expected 2 parameters" *
                                "but got $(length(params)). Verify."))
    end
    # apply
    replacement = "<b>??</b>"
    dname, hkey = params[1], params[2]
    if params[1] == "EQR"
        haskey(PAGE_EQREFS, hkey) || return replacement
        replacement = html_ahref_key(hkey, PAGE_EQREFS[hkey])
    elseif params[1] == "BIBR"
        haskey(PAGE_BIBREFS, hkey) || return replacement
        replacement = html_ahref_key(hkey, PAGE_BIBREFS[hkey])
    else
        @warn "Unknown dictionary name $dname in {{href ...}}. Ignoring"
    end
    return replacement
end


"""
$(SIGNATURES)

H-Function of the form `{{toc}}` (table of contents).
"""
function hfun_toc()::String
    inner  = ""
    curlvl = 1
    for i ∈ 1:length(PAGE_HEADERS)
        h = PAGE_HEADERS[i]
        lvl = h[4]
        if lvl < curlvl
            # how many levels?
            δ = curlvl - lvl
            curlvl = lvl
            for i = 1:δ
                inner *= "</ol>"
            end
        elseif lvl > curlvl
            # how many levels?
            δ = lvl - curlvl
            curlvl = lvl
            for i = 1:δ
                inner *= "<ol>"
            end
        end
        inner *= "<li><a href=\"#$(h[2])\">$(h[1])</li>"
    end
    # close at whatever level we are
    for i = curlvl:-1:2
        inner *= "</ol>"
    end
    toc = "<div class=\"jd-toc\"><ol>" * inner * "</ol></div>"
end


"""
HTML_FUNCTIONS

Dictionary for special html functions. They can take two variables, the first one `π` refers to the
arguments passed to the function, the second one `ν` refers to the page variables (i.e. the
context) available to the function.
"""
const HTML_FUNCTIONS = Dict{String, Function}(
    "fill"   => ((π, ν) -> hfun_fill(π, ν)),
    "insert" => ((π, _) -> hfun_insert(π)),
    "href"   => ((π, _) -> hfun_href(π)),
    "toc"    => ((_, _) -> hfun_toc()),
    )
