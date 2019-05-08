"""
$(SIGNATURES)

Helper function for `convert_inter_html` that processes an extracted block given a latex context
`lxc` and returns the processed html that needs to be plugged in the final html.
"""
function convert_block(β::AbstractBlock, lxcontext::LxContext)::AbstractString
    # Return relevant interpolated string based on case
    βn = β.name
    βn == :CODE_INLINE  && return md2html(β.ss, true)
    βn == :CODE_BLOCK_L && return convert_code_block(β.ss)
    βn == :CODE_BLOCK   && return md2html(β.ss)
    βn == :ESCAPE       && return chop(β.ss, head=3, tail=3)

    # Math block --> needs to call further processing to resolve possible latex
    βn ∈ MD_MATH_NAMES  && return convert_mathblock(β, lxcontext.lxdefs)

    # Div block --> need to process the block as a sub-element
    if βn == :DIV
        ct, _ = convert_md(content(β) * EOS, lxcontext.lxdefs;
                           isrecursive=true, has_mddefs=false)
        name = chop(otok(β).ss, head=2, tail=0)
        return html_div(name, ct)
    end

    # default case, ignore block (should not happen)
    return ""
end
convert_block(β::LxCom, λ::LxContext) = resolve_lxcom(β, λ.lxdefs)


"""
JD_MBLOCKS_PM

Dictionary to keep track of how math blocks are fenced in standard LaTeX and how these fences need
to be adapted for compatibility with KaTeX. Each tuple contains the number of characters to chop
off the front and the back of the maths expression (fences) as well as the KaTeX-compatible
replacement.
For instance, `\$ ... \$` will become `\\( ... \\)` chopping off 1 character at the front and the
back (`\$` sign).
"""
const JD_MBLOCKS_PM = Dict{Symbol, Tuple{Int,Int,String,String}}(
    :MATH_A     => ( 1,  1, "\\(", "\\)"),
    :MATH_B     => ( 2,  2, "\\[", "\\]"),
    :MATH_C     => ( 2,  2, "\\[", "\\]"),
    :MATH_ALIGN => (13, 11, "\\[\\begin{aligned}", "\\end{aligned}\\]"),
    :MATH_EQA   => (16, 14, "\\[\\begin{array}{c}", "\\end{array}\\]"),
    :MATH_I     => ( 4,  4, "", "")
    )


"""
$(SIGNATURES)

Helper function for the math block case of `convert_block` taking the inside of a math block,
resolving any latex command in it and returning the correct syntax that KaTeX can render.
"""
function convert_mathblock(β::OCBlock, lxdefs::Vector{LxDef})::String
    # try to find the block out of `JD_MBLOCKS_PM`, if not found, error
    pm = get(JD_MBLOCKS_PM, β.name) do
        error("Unrecognised math block name.")
    end

    # convert the inside, decorate with KaTex and return, also act if
    # if the math block is a "display" one (with a number)
    inner = chop(β.ss, head=pm[1], tail=pm[2])
    htmls = IOBuffer()
    if β.name ∉ [:MATH_A, :MATH_I]
        # NOTE: in the future if allow equation tags, then will need an `if`
        # here and only increment if there's no tag. For now just use numbers.

        # increment equation counter
        JD_LOC_EQDICT[JD_LOC_EQDICT_COUNTER] += 1

        # check if there's a label, if there is, add that to the dictionary
        matched = match(r"\\label{(.*?)}", inner)
        
        if !isnothing(matched)
            name   = refstring(strip(matched.captures[1]))
            write(htmls, "<a id=\"$name\"></a>")
            inner  = replace(inner, r"\\label{.*?}" => "")
            # store the label name and associated number
            JD_LOC_EQDICT[name] = JD_LOC_EQDICT[JD_LOC_EQDICT_COUNTER]
        end
    end
    # assemble the katex decorators, the resolved content etc
    write(htmls, pm[3], convert_md_math(inner * EOS, lxdefs, from(β)), pm[4])
    return String(take!(htmls))
end


"""
$(SIGNATURES)

Helper function for the code block case of `convert_block`.
"""
function convert_code_block(ss::SubString)::String
    m = match(r"```([a-z-]*)\s*\n?((?:.|\n)*)```", ss)
    lang = m.captures[1]
    code = m.captures[2]
    return "<pre><code class=$lang>$code</code></pre>"
end
