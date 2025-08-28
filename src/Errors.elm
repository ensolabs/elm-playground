module Errors exposing (viewError)

{-| Ref.: <https://github.com/elm/compiler/blob/master/reactor/src/Errors.elm>
-}

import Elm.Error as Error
import Html exposing (Html)
import Html.Attributes as Attr
import String



{- Borrowed from https://raw.githubusercontent.com/guida-lang/guida-lang.org/refs/heads/master/src/Errors.elm -}
-- VIEW


viewError : Error.Error -> Html msg
viewError error =
    Html.div [ Attr.class "w-full min-h-full flex flex-col items-center text-black font-mono" ]
        [ Html.div [ Attr.class "block whitespace-pre-wrap bg-white p-8" ]
            (viewErrorHelp error)
        ]


viewErrorHelp : Error.Error -> List (Html msg)
viewErrorHelp error =
    case error of
        Error.GeneralProblem { path, title, message } ->
            viewHeader title path :: viewMessage message

        Error.ModuleProblems badModules ->
            viewBadModules badModules



-- VIEW HEADER


viewHeader : String -> Maybe String -> Html msg
viewHeader title maybeFilePath =
    let
        left : String
        left =
            "-- " ++ title ++ " "

        right : String
        right =
            case maybeFilePath of
                Nothing ->
                    ""

                Just filePath ->
                    " " ++ filePath
    in
    Html.span [ Attr.style "color" "#238fca" ] [ Html.text (fill left right ++ "\n\n") ]


fill : String -> String -> String
fill left right =
    left ++ String.repeat (80 - String.length left - String.length right) "-" ++ right



-- VIEW BAD MODULES


viewBadModules : List Error.BadModule -> List (Html msg)
viewBadModules badModules =
    case badModules of
        [] ->
            []

        [ badModule ] ->
            [ viewBadModule badModule ]

        a :: b :: cs ->
            viewBadModule a :: viewSeparator a.name b.name :: viewBadModules (b :: cs)


viewBadModule : Error.BadModule -> Html msg
viewBadModule { path, problems } =
    Html.span [] (List.map (viewProblem path) problems)


viewProblem : String -> Error.Problem -> Html msg
viewProblem filePath problem =
    Html.span [] (viewHeader problem.title (Just filePath) :: viewMessage problem.message)


viewSeparator : String -> String -> Html msg
viewSeparator before after =
    Html.span [ Attr.style "color" "rgb(211,56,211)" ]
        [ Html.text <|
            String.padLeft 80 ' ' (before ++ "  ↑    ")
                ++ "\n"
                ++ "====o======================================================================o====\n"
                ++ "    ↓  "
                ++ after
                ++ "\n\n\n"
        ]



-- VIEW MESSAGE


viewMessage : List Error.Chunk -> List (Html msg)
viewMessage chunks =
    case chunks of
        [] ->
            [ Html.text "\n\n\n" ]

        chunk :: others ->
            let
                htmlChunk : Html msg
                htmlChunk =
                    case chunk of
                        Error.Unstyled string ->
                            Html.text string

                        Error.Styled style string ->
                            Html.span (styleToAttrs style) [ Html.text string ]
            in
            htmlChunk :: viewMessage others


styleToAttrs : Error.Style -> List (Html.Attribute msg)
styleToAttrs { bold, underline, color } =
    addBold bold <| addUnderline underline <| addColor color []


addBold : Bool -> List (Html.Attribute msg) -> List (Html.Attribute msg)
addBold bool attrs =
    if bool then
        Attr.style "font-weight" "bold" :: attrs

    else
        attrs


addUnderline : Bool -> List (Html.Attribute msg) -> List (Html.Attribute msg)
addUnderline bool attrs =
    if bool then
        Attr.style "text-decoration" "underline" :: attrs

    else
        attrs


addColor : Maybe Error.Color -> List (Html.Attribute msg) -> List (Html.Attribute msg)
addColor maybeColor attrs =
    case maybeColor of
        Nothing ->
            attrs

        Just color ->
            Attr.style "color" (colorToCss color) :: attrs


colorToCss : Error.Color -> String
colorToCss color =
    case color of
        Error.Red ->
            "rgb(194,54,33)"

        Error.RED ->
            "rgb(252,57,31)"

        Error.Magenta ->
            "rgb(211,56,211)"

        Error.MAGENTA ->
            "rgb(249,53,248)"

        Error.Yellow ->
            "rgb(173,173,39)"

        Error.YELLOW ->
            "rgb(234,236,35)"

        Error.Green ->
            "rgb(37,188,36)"

        Error.GREEN ->
            "rgb(49,231,34)"

        Error.Cyan ->
            "rgb(51,187,200)"

        Error.CYAN ->
            "rgb(13,130,128)"

        Error.Blue ->
            "rgb(73,46,225)"

        Error.BLUE ->
            "rgb(88,51,255)"

        Error.White ->
            "rgb(203,204,205)"

        Error.WHITE ->
            "rgb(233,235,235)"

        Error.Black ->
            "rgb(0,0,0)"

        Error.BLACK ->
            "rgb(129,131,131)"
