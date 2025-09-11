module Exercises exposing (Exercise, defaultExercise, exercises, getExerciseSourceCodeOrDefault)

{-| A collection of all Elm exercises with their content as strings.
-}

import Dict


type alias Exercise =
    { id : String
    , name : String
    , extraDependencies : List String
    , content : String
    }


exercises : List Exercise
exercises =
    [ { id = "010String"
      , name = "String Basics"
      , extraDependencies = []
      , content = """module Main exposing (main)

import Html

main = Html.text "A very simple first exercise..."""
      }
    , { id = "011StringConcat"
      , name = "String Concatenation"
      , extraDependencies = []
      , content = """module Main exposing (main)

import Html


hello =
    "Hello " + "world"


main =
    Html.text hello"""
      }
    , { id = "012IntToString"
      , name = "Integer to String Conversion"
      , extraDependencies = []
      , content = """module Main exposing (main)

import Html exposing (Html)


main =
    Html.text ("The multiplication of 19876 by 34678 results in " ++ result)


result =
    19876 * 34678"""
      }
    , { id = "013Functions"
      , name = "Basic Functions"
      , extraDependencies = []
      , content = """module Main exposing (main)

import Html exposing (div, text)


add a b =
    a + b


main =
    div []
        [ div [] [ text ("5 plus 6 equals " ++ String.fromInt (add 5 6)) ]
        , div [] [ text ("5 times 6 equals " ++ String.fromInt (multiply 5 6)) ]
        ]"""
      }
    , { id = "014Signatures"
      , name = "Function Signatures"
      , extraDependencies = []
      , content = """module Main exposing (main)

import Html exposing (div, text)


add : Int -> Int -> Int
add a b =
    a + b


multiply : Int
multiply a b =
    a * b


main =
    div []
        [ div [] [ text ("5 plus 6 equals " ++ String.fromInt (add 5 6)) ]
        , div [] [ text ("5 times 6 equals " ++ String.fromInt (multiply 5 6)) ]
        ]"""
      }
    , { id = "015ModuleName"
      , name = "Module Names"
      , extraDependencies = []
      , content = """module main exposing (..)

import Html


main =
    Html.text "Hello World!\""""
      }
    , { id = "016HTML"
      , name = "HTML Basics"
      , extraDependencies = []
      , content = """module Main exposing (main)


main =
    "Hello World!\""""
      }
    , { id = "017StyledHTML"
      , name = "Styled HTML"
      , extraDependencies = []
      , content = """module Main exposing (main)

import Html exposing (li, text, ul)
import Html.Attributes exposing (id, style)


main =
    ul []
        [ li [ style "color" "red" ] [ text "This text is red" ]
        , li [ id "greenText", style "color-green" ] [ text "This text is green (hopefully)" ]
        ]"""
      }
    , { id = "018CustomTypes"
      , name = "Custom Types"
      , extraDependencies = []
      , content = """module Main exposing (main)

import Html exposing (li, text, ul)
import Html.Attributes exposing (id, style)


type Color
    = Red
    | Green


main =
    ul []
        [ li [ style "color" (colorToString Red) ] [ text "This text is red" ]
        , li [ style "color" (colorToString Green) ] [ text "This text is green (hopefully)" ]
        ]


colorToString : Color -> String
colorToString color =
    case color of
        Red ->
            "red\""""
      }
    , { id = "019CustomTypesWithArguments"
      , name = "Custom Types with Arguments"
      , extraDependencies = []
      , content = """module Main exposing (main)

import Html exposing (li, text, ul)
import Html.Attributes exposing (id, style)


type Shape
    = Point
    | Square Float
    | Rectangle Float Float


main =
    Html.text
        ("A rectangle with sides 5 cm and 3 cm has an area of "
            ++ String.fromFloat (calculateArea (Rectangle 5 3))
            ++ " cm2"
        )


calculateArea : Shape -> Float
calculateArea shape =
    case shape of
        Point ->
            0

        Square side ->
            side * side

        Rectangle width ->
            width"""
      }
    , { id = "020TEA"
      , name = "The Elm Architecture (TEA)"
      , extraDependencies = []
      , content = """module Main exposing (main)

import Browser
import Html exposing (Html, button, div, span, text)
import Html.Attributes exposing (style)
import Html.Events exposing (onClick)


type alias Model =
    { count : Int }


initialModel : Model
initialModel =
    {}


type Msg
    = Increment


update : Msg -> Model -> Model
update msg model =
    case msg of
        Increment ->
            { model | count = model.count + 1 }


view : Model -> Html Msg
view model =
    div [ style "padding" "1rem" ]
        [ span [] [ text (String.fromInt model.count) ]
        , text " "
        , button [ onClick Increment ] [ text "+1" ]
        ]


main : Program () Model Msg
main =
    Browser.sandbox
        { init = initialModel
        , view = view
        , update = update
        }"""
      }
    , { id = "021CounterReset"
      , name = "Counter with Reset"
      , extraDependencies = []
      , content = """module Main exposing (main)

import Browser
import Html exposing (Html, button, div, span, text)
import Html.Attributes exposing (style)
import Html.Events exposing (onClick)


type alias Model =
    { count : Int }


initialModel : Model
initialModel =
    { count = 0 }


type Msg
    = Increment


update : Msg -> Model -> Model
update msg model =
    case msg of
        Increment ->
            { model | count = model.count + 1 }


view : Model -> Html Msg
view model =
    div [ style "padding" "1rem" ]
        [ span [] [ text (String.fromInt model.count) ]
        , text " "
        , button [ onClick Increment ] [ text "+1" ]
        , button [ onClick Reset ] [ text "Reset to 0" ]
        ]


main : Program () Model Msg
main =
    Browser.sandbox
        { init = initialModel
        , view = view
        , update = update
        }"""
      }
    , { id = "022ListRepeat"
      , name = "List Repeat"
      , extraDependencies = []
      , content = """module Main exposing (main)

import Browser
import Html exposing (Html, button, div, img, span, text)
import Html.Attributes exposing (src, style)
import Html.Events exposing (onClick)


type alias Model =
    { count : Int }


initialModel : Model
initialModel =
    { count = 1 }


type Msg
    = Increment


update : Msg -> Model -> Model
update msg model =
    case msg of
        Increment ->
            { model | count = model.count + 1 }


view : Model -> Html Msg
view model =
    -- There are two compilation errors here...
    -- Something tells me the second mistake might be the most useful one...
    div [ style "padding" "1rem" ]
        [ button [ onClick Increment, style "margin-bottom" "1em" ] [ text "Add a match" ]
        , div [] (List.repeat image model.count)
        ]


image =
    img [ src "https://freesvg.org/img/1577808279match.png", style "width" "30px" ] []


main : Program () Model Msg
main =
    Browser.sandbox
        { init = initialModel
        , view = view
        , update = update
        }"""
      }
    , { id = "023ListMap"
      , name = "List Map"
      , extraDependencies = []
      , content = """module Main exposing (main)

import Browser
import Html exposing (Html, button, div, img, text)
import Html.Attributes exposing (src, style)
import Html.Events exposing (onClick)


type alias Model =
    { shapes : List Shape }


type Shape
    = Square Float
    | Circle Float


initialModel : Model
initialModel =
    { shapes = [ Square 50 ] }


type Msg
    = AddShape Shape


update : Msg -> Model -> Model
update msg model =
    case msg of
        AddShape shape ->
            { model | shapes = shape ++ model.shapes }


view : Model -> Html Msg
view model =
    div []
        [ div []
            [ button [ onClick (AddShape (Square 50)), style "margin-right" "1em" ] [ text "Add a square" ]
            , button [ onClick (AddShape (Circle 50)) ] [ text "Add a circle" ]
            ]
        , div [ style "padding" "1rem", style "display" "flex" ]
            (List.map viewShape)
        ]


viewShape : Shape -> Html Msg
viewShape shape =
    case shape of
        Square side ->
            div
                [ style "width" (floatToPixels side)
                , style "height" (floatToPixels side)
                , style "background-color" "blue"
                , style "margin-right" "1em"
                ]
                []

        Circle radius ->
            div
                [ style "width" (floatToPixels radius)
                , style "height" (floatToPixels radius)
                , style "background-color" "green"
                , style "border-radius" "50%"
                , style "margin-right" "1em"
                ]
                []


floatToPixels : Float -> String
floatToPixels float =
    String.fromFloat float ++ "px"


main : Program () Model Msg
main =
    Browser.sandbox
        { init = initialModel
        , view = view
        , update = update
        }"""
      }
    , { id = "024ListPatternMatching"
      , name = "List Pattern Matching"
      , extraDependencies = []
      , content = """module Main exposing (main)

import Browser
import Html exposing (Html, button, div, img, text)
import Html.Attributes exposing (src, style)
import Html.Events exposing (onClick)


type alias Model =
    { shapes : List Shape }


type Shape
    = Square Float
    | Circle Float


initialModel : Model
initialModel =
    { shapes = [ Square 50 ] }


type Msg
    = AddShape Shape
    | RemoveShape


update : Msg -> Model -> Model
update msg model =
    case msg of
        AddShape shape ->
            { model | shapes = shape :: model.shapes }

        RemoveShape ->
            case model.shapes of
                firstShape :: otherShapes ->
                    { model | shapes = otherShapes }


view : Model -> Html Msg
view model =
    div []
        [ div []
            [ button [ onClick (AddShape (Square 50)), style "margin-right" "1em" ] [ text "Add a square" ]
            , button [ onClick (AddShape (Circle 50)), style "margin-right" "1em" ] [ text "Add a circle" ]
            , button [ onClick RemoveShape ] [ text "Remove last added shape" ]
            ]
        , div [ style "padding" "1rem", style "display" "flex" ]
            (List.map viewShape model.shapes)
        ]


viewShape : Shape -> Html Msg
viewShape shape =
    case shape of
        Square side ->
            div
                [ style "width" (floatToPixels side)
                , style "height" (floatToPixels side)
                , style "background-color" "blue"
                , style "margin-right" "1em"
                ]
                []

        Circle radius ->
            div
                [ style "width" (floatToPixels radius)
                , style "height" (floatToPixels radius)
                , style "background-color" "green"
                , style "border-radius" "50%"
                , style "margin-right" "1em"
                ]
                []


floatToPixels : Float -> String
floatToPixels float =
    String.fromFloat float ++ "px"


main : Program () Model Msg
main =
    Browser.sandbox
        { init = initialModel
        , view = view
        , update = update
        }"""
      }
    , { id = "025Http"
      , name = "HTTP Requests"
      , extraDependencies = [ "elm/http" ]
      , content = """module Main exposing (main)

import Browser
import Html exposing (Html, button, div, img, pre, text)
import Html.Attributes exposing (src, style)
import Html.Events exposing (onClick)
import Http



-- Until now, our programs have been fairly simple and didn't depend on the outside world.
--
-- In Elm, the outside world is considered "dangerous": what happens when a network request
-- fails? Or returns an unexpected format?
--
-- So we delegate this task to the _runtime_, which protects us and forces us to handle such errors
-- (in Elm, protective measures are always on 😷).
--
-- To perform an HTTP request, we use the concept of a "command": our update function now returns
-- the new model AND a command to execute (in our case, an HTTP request).
--
-- The runtime performs the request, then returns the result to us in a message (in our case, `QuoteFetched`).


type alias Model =
    { quote : String }


initialModel : Model
initialModel =
    { quote = "Click on any button to load a quote 😉" }


type Msg
    = QuoteButtonClicked String
      -- The HTTP request can fail, which is why we receive a `Result` that contains either an error (`Http.Error`) or a quote (`String`).
    | QuoteFetched (Result Http.Error String)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        QuoteButtonClicked url ->
            ( { model | quote = "Loading..." }, Http.get { expect = Http.expectString QuoteFetched } )

        QuoteFetched result ->
            case result of
                Err error ->
                    ( { model | quote = "Error! 😱" }, Cmd.none )


view : Model -> Html Msg
view model =
    div []
        [ div []
            [ button [ onClick (QuoteButtonClicked "/resources/quote-1.txt"), style "margin-right" "1em" ] [ text "Get quote 1" ]
            , button [ onClick (QuoteButtonClicked "/resources/quote-2.txt"), style "margin-right" "1em" ] [ text "Get quote 2" ]
            , button [ onClick (QuoteButtonClicked "/resources/quote-3.txt") ] [ text "Get quote 3" ]
            ]
        , pre
            [ style "padding" "10px"
            , style "border" "1px solid gray"
            , style "max-width" "500px"
            , style "white-space" "pre-wrap"
            , style "margin" "10px"
            ]
            [ text model.quote ]
        ]


main : Program () Model Msg
main =
    Browser.element
        { init = \\_ -> ( initialModel, Cmd.none )
        , view = view
        , update = update
        , subscriptions = \\_ -> Sub.none
        }"""
      }
    , { id = "026HttpDecoder"
      , name = "HTTP with JSON Decoder"
      , extraDependencies = [ "elm/json", "elm/http" ]
      , content = """module Main exposing (main)

import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http
import Json.Decode exposing (Decoder)


type Model
    = Failure String
    | Loading
    | Success Cat


type alias Cat =
    { title : String
    , url : String
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( Loading, getRandomCatGif )


type Msg
    = CatButtonClicked
    | GifReceived (Result Http.Error Cat)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        CatButtonClicked ->
            ( Loading, getRandomCatGif )

        GifReceived result ->
            case result of
                Ok cat ->
                    ( Success cat, Cmd.none )

                Err error ->
                    case error of
                        Http.BadBody errorMsg ->
                            ( Failure errorMsg, Cmd.none )

                        _ ->
                            ( Failure "Http error!", Cmd.none )



-- VIEW


view : Model -> Html Msg
view model =
    div []
        [ h2 [] [ text "Random Cats" ]
        , viewGif model
        ]


viewGif : Model -> Html Msg
viewGif model =
    case model of
        Failure errorMsg ->
            div []
                [ text ("An error occurred: " ++ errorMsg)
                , button [ onClick CatButtonClicked ] [ text "Try again!" ]
                ]

        Loading ->
            text "Loading..."

        Success cat ->
            div []
                [ h1 [] [ text cat.title ]
                , button [ onClick CatButtonClicked, style "display" "block" ] [ text "Another one!" ]
                , img [ src cat.url ] []
                ]


getRandomCatGif : Cmd Msg
getRandomCatGif =
    Http.get
        { url = "https://api.giphy.com/v1/gifs/random?api_key=kOZdCy0KDR2n8Y83kawP0zdqUMqpHYRj&tag=cat"
        , expect = Http.expectJson GifReceived gifDecoder
        }


gifDecoder : Decoder Cat
gifDecoder =
    -- Elm can't guess the shape of the JSON we receive, so we need to tell it which fields
    -- we're interested in using this decoder.
    --
    -- The JSON looks like this:
    -- {
    --   "data": {
    --     "title": "Tired cat",
    --     "images" : { "original": { "url" : "http://...", ...}, ...},
    --     ...,
    --   },
    --   ...,
    -- }
    --
    -- You can see the full structure at the following link:
    -- https://api.giphy.com/v1/gifs/random?api_key=kOZdCy0KDR2n8Y83kawP0zdqUMqpHYRj&tag=cat
    Json.Decode.map2 Cat
        (Json.Decode.at [ "data", "title" ] Json.Decode.int)
        (Json.Decode.at [ "data", "images", "original", "url" ] Json.Decode.string)


main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = \\_ -> Sub.none
        , view = view
        }



-- Inspired by:
-- https://elm-lang.org/examples/cat-gifs"""
      }
    , { id = "027Time"
      , name = "Time and Subscriptions"
      , extraDependencies = [ "elm/time" ]
      , content = """module Main exposing (main)

import Browser
import Html exposing (..)
import Task
import Time



-- We want to display the current time. To do this, we need to "subscribe" to the current time:
-- the runtime will regularly send messages containing the current time (in the form of a
-- timestamp/Posix).
--
-- Once again, this protects us from the outside world 😷.


type alias Model =
    { zone : Time.Zone
    , time : Time.Posix
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( { zone = Time.utc, time = Time.millisToPosix 0 }
    , -- Elm forces us to handle the time zone separately from the time itself, which helps us avoid
      -- many common pitfalls related to time handling (see https://gist.github.com/timvisee/fcda9bbdff88d45cc9061606b4b923ca).
      --
      -- This command retrieves the user's time zone:
      Task.perform TimeZoneReceived Time.here
    )


type Msg
    = Tick Time.Posix
    | TimeZoneReceived Time.Zone


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Tick newTime ->
            ( { model | time = newTime }
            , Cmd.none
            )

        TimeZoneReceived newZone ->
            ( { model | zone = newZone }
            , Cmd.none
            )


subscriptions : Model -> Sub Msg
subscriptions model =
    -- But how do we specify that we want to generate a `Tick` message every 1000 milliseconds?
    Time.every 1000


view : Model -> Html Msg
view model =
    let
        hour =
            String.fromInt (Time.toHour model.zone model.time)

        second =
            String.fromInt (Time.toSecond model.zone model.time)
    in
    h1 [] [ text (hour ++ ":" ++ minute ++ ":" ++ second) ]


main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }"""
      }
    , { id = "030Draw"
      , name = "Drawing with SVG"
      , extraDependencies = [ "elm-community/html-extra", "elm/json", "elm/svg" ]
      , content = """module Main exposing (main)

import Browser
import Html exposing (Html, button, div, h1, img, p, pre, text)
import Html.Attributes exposing (height, src, style, width)
import Html.Events exposing (on)
import Html.Events.Extra.Mouse as Mouse
import Json.Decode exposing (Decoder)
import Svg exposing (Svg, circle, line, svg)
import Svg.Attributes exposing (cx, cy, r, x1, x2, y1, y2)


type alias Point =
    { x : Float, y : Float }


type alias Line =
    { from : Point, to : Point }


type alias Model =
    { lines : List Line
    , firstPointForNextLine : Maybe Point
    }


initialModel : Model
initialModel =
    { lines = []
    , firstPointForNextLine = Nothing
    }


type Msg
    = CanvasClickedAt Point


update : Msg -> Model -> Model
update msg model =
    case msg of
        CanvasClickedAt pointClicked ->
            case model.firstPointForNextLine of
                Just firstPoint ->
                    { model
                        | firstPointForNextLine = Nothing
                        , lines = { from = firstPoint, to = pointClicked } :: model.lines
                    }

                Nothing ->
                    { model | firstPointForNextLine = Just pointClicked }


view : Model -> Html Msg
view model =
    div [ style "padding" "1rem" ]
        [ h1 [] [ text "Draw lines!" ]
        , p [] [ text "Click at different spots in the frame below to draw lines." ]
        , svg
            [ style "border" "1px black solid"
            , width 800
            , height 400
            , Mouse.onClick
                (\\event ->
                    CanvasClickedAt
                        { x = Tuple.first event.offsetPos
                        , y = Tuple.second event.offsetPos
                        }
                )
            ]
            (drawFirstPoint model.firstPointForNextLine :: List.map drawLine model.lines)
        ]


drawLine : Line -> Svg Msg
drawLine { from, to } =
    line
        [ x1 (String.fromFloat from.x)
        , y1 (String.fromFloat from.y)
        , x2 (String.fromFloat to.x)
        , y2 (String.fromFloat to.y)
        , Svg.Attributes.style "stroke:rgb(255,0,0);stroke-width:2"
        ]
        []


drawFirstPoint : Maybe Point -> Svg Msg
drawFirstPoint maybePoint =
    case maybePoint of
        Just point ->
            circle
                [ cx (String.fromFloat point.x)
                , cy (String.fromFloat point.y)
                , r "2"
                , Svg.Attributes.style "fill:rgb(255,0,0)"
                ]
                []

        Nothing ->
            circle [] []


main : Program () Model Msg
main =
    Browser.sandbox
        { init = initialModel
        , view = view
        , update = update
        }"""
      }
    , { id = "040MemoryGame"
      , name = "Memory Game"
      , extraDependencies = []
      , content = """module Main exposing (main)

import Browser
import Html exposing (Html)
import Html.Attributes exposing (disabled, style)
import Html.Events exposing (onClick)
import Random
import Random.List as Random
import Time


type alias Model =
    { state : State
    , cards : Maybe (List Card)
    , matched : List Card
    }


type State
    = Hidden
    | OneRevealed Card
    | TwoRevealed Card Card
    | Solved


type Card
    = Card Emoji Instance


type Instance
    = A
    | B


type Msg
    = Click Card
    | TimeOut
    | NewGame (List Card)


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }


init : () -> ( Model, Cmd Msg )
init () =
    ( initialModel, newGame numPairsInit )


numPairsInit : Int
numPairsInit =
    3


initialModel : Model
initialModel =
    { state = Hidden
    , cards = Nothing
    , matched = []
    }


newGame : Int -> Cmd Msg
newGame numPairs =
    Random.generate
        NewGame
        (Random.shuffle emojisList
            |> Random.andThen
                (\\code ->
                    createCards code numPairs
                        |> Random.shuffle
                )
        )


createCards : List Emoji -> Int -> List Card
createCards emojis numPairs =
    List.take numPairs emojis
        |> List.concatMap (\\emoji -> [ Card emoji A, Card emoji B ])


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        TimeOut ->
            ( case model.state of
                TwoRevealed _ _ ->
                    { model | state = Hidden }

                _ ->
                    model
            , Cmd.none
            )

        Click card ->
            ( if List.member card model.matched then
                model

              else
                case model.state of
                    Hidden ->
                        { model | state = OneRevealed card }

                    OneRevealed card1 ->
                        revealAnother model card1 card

                    _ ->
                        model
            , Cmd.none
            )

        NewGame cards ->
            ( { model | cards = Just cards }
            , Cmd.none
            )


revealAnother : Model -> Card -> Card -> Model
revealAnother model alreadyRevealed toReveal =
    if toReveal == alreadyRevealed then
        model

    else
        let
            matched : List Card
            matched =
                if matching numPairsInit alreadyRevealed toReveal then
                    alreadyRevealed :: toReveal :: model.matched

                else
                    model.matched
        in
        { model
            | state =
                if List.length matched == numPairsInit * 2 then
                    Solved

                else
                    TwoRevealed alreadyRevealed toReveal
            , matched = matched
        }


matching : Int -> Card -> Card -> Bool
matching numPairs card1 card2 =
    case ( card1, card2 ) of
        ( Card index1 _, Card index2 _ ) ->
            index1 == index2


subscriptions : Model -> Sub Msg
subscriptions model =
    case model.state of
        TwoRevealed _ _ ->
            Time.every 1000 (always TimeOut)

        _ ->
            Sub.none


view : Model -> Html Msg
view model =
    case model.cards of
        Just cards ->
            let
                numCards : Int
                numCards =
                    List.length cards

                columns : Int
                columns =
                    numColumns numCards

                rows : Int
                rows =
                    numCards // columns
            in
            Html.div []
                [ header model
                , Html.div
                    (grid rows columns)
                    (List.map
                        (cardView model.matched model.state)
                        cards
                    )
                ]

        Nothing ->
            Html.span messageStyle [ Html.text "Shuffling …" ]


{-| Try for equal number of rows and columns,
favoring more columns if numCards is not a perfect square
-}
numColumns : Int -> Int
numColumns numCards =
    Maybe.withDefault numCards
        (List.filter
            (\\n -> modBy n numCards == 0)
            (List.range
                (numCards
                    |> toFloat
                    |> sqrt
                    |> ceiling
                )
                numCards
            )
            |> List.head
        )


header : Model -> Html Msg
header model =
    Html.div [ style "padding" "10px" ]
        (case model.state of
            Solved ->
                [ Html.span messageStyle [ Html.text "Congrats!" ]
                , Html.div []
                    [ Html.span messageStyle
                        [ Html.text "Play again?" ]
                    ]
                ]

            TwoRevealed card1 card2 ->
                [ Html.span messageStyle
                    [ Html.text
                        (if matching numPairsInit card1 card2 then
                            "Pair revealed!"

                         else
                            "It's not a pair, try again."
                        )
                    ]
                ]

            _ ->
                [ Html.span messageStyle [ Html.text "Click on cards to reveal them" ] ]
        )


cardView : List Card -> State -> Card -> Html Msg
cardView matched state card =
    if List.member card matched then
        cardRevealedView card

    else
        case state of
            OneRevealed card1 ->
                if card == card1 then
                    cardRevealedView card

                else
                    cardHiddenView matched state card

            TwoRevealed card1 card2 ->
                if List.member card [ card1, card2 ] then
                    cardRevealedView card

                else
                    cardHiddenView matched state card

            _ ->
                cardHiddenView matched state card


cardRevealedView : Card -> Html Msg
cardRevealedView card =
    Html.span cardStyle
        [ case card of
            Card emoji _ ->
                emojiToString emoji
                    |> Html.text
        ]


cardHiddenView : List Card -> State -> Card -> Html Msg
cardHiddenView matched state card =
    let
        isDisabled =
            List.member card matched
                || (case state of
                        TwoRevealed _ _ ->
                            True

                        _ ->
                            False
                   )
    in
    Html.button
        (onClick (Click card)
            :: disabled isDisabled
            :: cardStyle
        )
        [ Html.text "❓" ]


grid : Int -> Int -> List (Html.Attribute Msg)
grid rows columns =
    [ style "display" "grid"
    , style "grid-template-columns" (String.join " " (List.repeat columns "60pt"))
    , style "grid-template-rows" (String.join " " (List.repeat rows "60pt"))
    ]


cardStyle : List (Html.Attribute Msg)
cardStyle =
    [ style "font-size" "40pt"
    , style "margin" "5px"
    , style "padding" "2px"
    , style "border-radius" "1px"
    ]


messageStyle : List (Html.Attribute Msg)
messageStyle =
    [ style "font-size" "20pt"
    , style "margin" "5px"
    , style "padding" "2px"
    ]



-- HANDLING EMOJIS


type Emoji
    = Emoji Int


emojiToString : Emoji -> String
emojiToString (Emoji code) =
    code
        |> Char.fromCode
        |> String.fromChar


emojisList : List Emoji
emojisList =
    List.map Emoji
        [ 0x0001F400
        , 0x0001F403
        , 0x0001F404
        , 0x0001F405
        , 0x0001F406
        , 0x0001F407
        , 0x0001F408
        , 0x0001F409
        , 0x0001F40A
        ]



-- Inspired by https://github.com/O-O-Balance/pairs/"""
      }
    ]
        |> List.map (\{ id, name, content, extraDependencies } -> { id = id, name = name, extraDependencies = extraDependencies, content = content |> String.trim })


defaultExercise : String
defaultExercise =
    """
module Main exposing (main)

import Browser
import Html exposing (text)

main =
    Browser.sandbox
        { init = ()
        , view = \\_ -> text "Hello, Elm!"
        , update = \\_ model -> model
        }
        """
        |> String.trim


exerciseMap : Dict.Dict String ( String, List String )
exerciseMap =
    exercises |> List.map (\el -> ( el.id, ( el.content, el.extraDependencies ) )) |> Dict.fromList


getExerciseSourceCodeOrDefault : Maybe String -> ( String, List String )
getExerciseSourceCodeOrDefault maybeId =
    maybeId
        |> Maybe.andThen
            (\id ->
                exerciseMap |> Dict.get id
            )
        |> Maybe.withDefault ( defaultExercise, [] )
