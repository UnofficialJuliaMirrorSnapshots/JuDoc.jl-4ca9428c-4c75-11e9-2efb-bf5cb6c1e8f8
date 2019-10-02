# Following multiple issues over time with ordering, this attempts to have
# bunch of test cases where it's clear in what order things are tokenized / found

@testset "Ordering-1" begin
    st = raw"""
        A
        <!--
        C
            indent
        D -->
        B
        """ * J.EOS
    steps = st |> explore_md_steps
    blocks, = steps[:ocblocks]
    @test length(blocks) == 1
    @test blocks[1].name == :COMMENT
    @test isapproxstr(st |> seval, """
            <p>A</p>
            <p>B</p>
            """)
end

@testset "Ordering-2" begin
    st = raw"""
        A
        \begin{eqnarray}
            1 + 1 &=& 2
        \end{eqnarray}
        B
        """ * J.EOS
    steps = st |> explore_md_steps
    blocks, = steps[:ocblocks]
    @test length(blocks) == 1
    @test blocks[1].name == :MATH_EQA

    @test isapproxstr(st |> seval, raw"""
            <p>A
            \[\begin{array}{c}
                1 + 1 &=& 2
            \end{array}\]
            B</p>""")
end

@testset "Ordering-3" begin
    st = raw"""
        A
        \begin{eqnarray}
            1 + 1 &=& 2
        \end{eqnarray}
        B
        <!--
            blah
            \begin{eqnarray}
                1 + 1 &=& 2
            \end{eqnarray}
        [blah](hello)
        -->
        C
        """ * J.EOS
    steps = st |> explore_md_steps
    blocks, = steps[:ocblocks]
    @test length(blocks) == 2
    @test blocks[1].name == :COMMENT
    @test blocks[2].name == :MATH_EQA

    @test isapproxstr(st |> seval, raw"""
            <p>A
            \[\begin{array}{c}
                1 + 1 &=& 2
            \end{array}\]
            B</p>
            <p>C</p>""")
end

@testset "Ordering-4" begin
    st = raw"""
        \newcommand{\eqa}[1]{\begin{eqnarray}#1\end{eqnarray}}
        A
        \eqa{
             B
        }
        C
        """ * J.EOS
    steps = st |> explore_md_steps
    blocks, = steps[:ocblocks]

    @test length(blocks) == 3
    @test all(getproperty.(blocks, :name) .== :LXB)

    @test isapproxstr(st |> seval, raw"""
            <p>A
            \[\begin{array}{c}
                B
            \end{array}\]
            C</p>""")
end

@testset "Ordering-5" begin
    st = raw"""
        A [❗️_ongoing_ ] C
        """ * J.EOS
    @test isapproxstr(st |> seval, raw"""
        <p>A &#91;❗️<em>ongoing</em> &#93; C</p>
        """)
    st = raw"""
        0
        * A
            * B [❗️_ongoing_ ]<!--(ongoing)
                ref:
                >> url
            -->
        C
        """ * J.EOS
    @test isapproxstr(st |> seval, raw"""
            <p>0</p>
            <ul>
              <li><p>A</p>
                <ul>
                  <li><p>B &#91;❗️<em>ongoing</em> &#93;</p></li>
                </ul>
              </li>
            </ul>
            <p>C</p>
            """)
end
