@testset "Partial MD" begin
    st = raw"""
        \newcommand{\com}{HH}
        \newcommand{\comb}[1]{HH#1HH}
        A list
        * \com and \comb{blah}
        * $f$ is a function
        * a last element
        """ * J.EOS

    steps = explore_md_steps(st)
    lxdefs, tokens, braces, blocks, lxcoms = steps[:latex]

    @test length(braces) == 1
    @test J.content(braces[1]) == "blah"

    @test length(blocks) == 1
    @test blocks[1].name == :MATH_A
    @test J.content(blocks[1]) == "f"

    blocks2insert, = steps[:blocks2insert]

    inter_md, mblocks = J.form_inter_md(st, blocks2insert, lxdefs)
    @test inter_md == "\n\nA list\n*  ##JDINSERT##  and  ##JDINSERT## \n*  ##JDINSERT##  is a function\n* a last element\n"
    inter_html = J.md2html(inter_md)
    @test inter_html == "<p>A list</p>\n<ul>\n<li><p>##JDINSERT##  and  ##JDINSERT## </p>\n</li>\n<li><p>##JDINSERT##  is a function</p>\n</li>\n<li><p>a last element</p>\n</li>\n</ul>\n"
end


# index arithmetic over a string is a bit trickier when using all symbols
# we can use `prevind` and `nextind` to make sure it works properly
@testset "Inter Md 2" begin
    st = raw"""
        ~~~
        this⊙ then ⊙ ⊙ and
        ~~~
        finally ⊙⊙𝛴⊙ and
        ~~~
        escape ∀⊙∀
        ~~~
        done
        """

    inter_md, = explore_md_steps(st)[:inter_md]
    @test inter_md == " ##JDINSERT## \nfinally ⊙⊙𝛴⊙ and\n ##JDINSERT## \ndone"
end


@testset "Latex eqa" begin
    st = raw"""
        a\newcommand{\eqa}[1]{\begin{eqnarray}#1\end{eqnarray}}b@@d .@@
        \eqa{\sin^2(x)+\cos^2(x) &=& 1}
        """ * J.EOS

    steps = explore_md_steps(st)
    lxdefs, tokens, braces, blocks, lxcoms = steps[:latex]
    blocks2insert, = steps[:blocks2insert]
    inter_md, mblocks = steps[:inter_md]
    @test inter_md == "ab ##JDINSERT## \n ##JDINSERT## \n"

    inter_html, = steps[:inter_html]
    lxcontext = J.LxContext(lxcoms, lxdefs, braces)

    @test J.convert_block(blocks2insert[1], lxcontext) == "<div class=\"d\">.</div>"
    @test J.convert_block(blocks2insert[2], lxcontext) == "\\[\\begin{array}{c} \\sin^2(x)+\\cos^2(x) &=& 1\\end{array}\\]"

    hstring = J.convert_inter_html(inter_html, blocks2insert, lxcontext)
    @test hstring == "<p>ab<div class=\"d\">.</div> \\[\\begin{array}{c} \\sin^2(x)+\\cos^2(x) &=& 1\\end{array}\\]</p>\n"
end


@testset "MD>HTML" begin
    st = raw"""
        text A1 \newcommand{\com}{blah}text A2 \com and
        ~~~
        escape B1
        ~~~
        \newcommand{\comb}[ 1]{\mathrm{#1}} text C1 $\comb{b}$ text C2
        \newcommand{\comc}[ 2]{part1:#1 and part2:#2} then \comc{AA}{BB}.
        """ * J.EOS

    steps = explore_md_steps(st)
    lxdefs, tokens, braces, blocks, lxcoms = steps[:latex]
    blocks2insert, = steps[:blocks2insert]
    inter_md, mblocks = steps[:inter_md]
    inter_html, = steps[:inter_html]

    @test inter_md == "text A1 text A2  ##JDINSERT##  and\n ##JDINSERT## \n text C1  ##JDINSERT##  text C2\n then  ##JDINSERT## .\n"

    @test inter_html == "<p>text A1 text A2  ##JDINSERT##  and  ##JDINSERT##   text C1  ##JDINSERT##  text C2  then  ##JDINSERT## .</p>\n"

    lxcontext = J.LxContext(lxcoms, lxdefs, braces)
    hstring = J.convert_inter_html(inter_html, blocks2insert, lxcontext)
    @test hstring == "<p>text A1 text A2 blah and \nescape B1\n  text C1 \\(\\mathrm{ b}\\) text C2  then part1: AA and part2: BB.</p>\n"
end


@testset "headers" begin
    J.CUR_PATH[] = "index.md"
    h = """
        # Title
        and then
        ## Subtitle cool!
        done
        """ |> seval
    @test isapproxstr(h, """
                        <h1 id="title"><a href="/index.html#title">Title</a></h1>
                        and then
                        <h2 id="subtitle_cool"><a href="/index.html#subtitle_cool">Subtitle cool&#33;</a></h2>
                        done
                        """)
end
