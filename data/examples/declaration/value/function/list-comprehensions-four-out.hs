foo x = [a | a <- x]

bar x y = [(a, b) | a <- x, even a, b <- y, a != b]

barbaz x y z w =
    [ (a, b, c, d) -- Foo
    | a <-
        x -- Bar
    , b <- y -- Baz
    , any even [a, b]
    , c <-
        z
            * z ^ 2 -- Bar baz
    , d <-
        w
            + w -- Baz bar
    , all
        even
        [ a
        , b
        , c
        , d
        ]
    ]

a = do
    d <-
        [ x + 1
        | x <- b
        ]

    [ c
      | c <- d
      ]

trans =
    [ x
    | x <- xs
    , then
        reverse
    , then
        reverse
    ]
