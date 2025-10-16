port module Main exposing (main)

import Browser
import Browser.Navigation as Nav
import Elm.Error as Error
import Errors exposing (viewError)
import Exercises exposing (exercises)
import Html exposing (..)
import Html.Attributes as Attributes exposing (..)
import Html.Events as Events
import Json.Decode as Json
import Url



-- MAIN


main : Program () Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlChange = UrlChanged
        , onUrlRequest = LinkClicked
        }



-- PORTS


port sendSrc : { deps : List String, code : String } -> Cmd msg


port compilationSuccess : (String -> msg) -> Sub msg


port compilationError : (String -> msg) -> Sub msg



-- MODEL


type alias Model =
    { key : Nav.Key
    , url : Url.Url
    , compilation : Compilation
    , srcCode : String
    , darkMode : Bool
    }


type Compilation
    = Loading
    | Failure (Maybe Error.Error)
    | Success String


init : () -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init _ url key =
    let
        ( srcCode, deps ) =
            Exercises.getExerciseSourceCodeOrDefault url.query
    in
    ( Model key url Loading srcCode False, addDepsAndCompileSrcCommand deps srcCode )



-- UPDATE


type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url
    | GotCompilationResult (Result String String)
    | EditSrc String
    | ToggleDarkMode
    | Noop


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LinkClicked urlRequest ->
            case urlRequest of
                Browser.Internal url ->
                    ( model, Nav.pushUrl model.key (Url.toString url) )

                Browser.External href ->
                    ( model, Nav.load href )

        UrlChanged url ->
            let
                newModel =
                    { model | url = url }

                ( srcCode, deps ) =
                    Exercises.getExerciseSourceCodeOrDefault url.query
            in
            newModel |> compileSrcWithDeps srcCode deps

        GotCompilationResult res ->
            case res of
                Ok code ->
                    ( { model | compilation = Success code }, Cmd.none )

                Err err ->
                    let
                        structuredError =
                            err
                                |> String.replace ".guida" ".elm"
                                |> Json.decodeString Error.decoder
                                |> Result.toMaybe
                    in
                    ( { model | compilation = Failure structuredError }, Cmd.none )

        EditSrc src ->
            model |> recompileSrc src

        ToggleDarkMode ->
            ( { model | darkMode = not model.darkMode }, Cmd.none )

        Noop ->
            ( model, Cmd.none )


compileSrcWithDeps : String -> List String -> Model -> ( Model, Cmd Msg )
compileSrcWithDeps src extraDeps model =
    ( { model | compilation = Loading, srcCode = src }
    , addDepsAndCompileSrcCommand extraDeps src
    )


recompileSrc : String -> Model -> ( Model, Cmd Msg )
recompileSrc srcCode model =
    ( { model | compilation = Loading, srcCode = srcCode }
    , compileSrcCommand srcCode
    )


addDepsAndCompileSrcCommand : List String -> String -> Cmd Msg
addDepsAndCompileSrcCommand deps srcCode =
    sendSrc { code = srcCode, deps = deps }


compileSrcCommand : String -> Cmd Msg
compileSrcCommand srcCode =
    sendSrc { code = srcCode, deps = [] }



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ compilationSuccess (\res -> GotCompilationResult (Ok res))
        , compilationError (\res -> GotCompilationResult (Err res))
        ]



-- VIEW


backgroundClass : Bool -> String
backgroundClass darkMode =
    if darkMode then
        "bg-[#1a1a1a]"

    else
        "bg-[#fff6f6]"


textColorClass : Bool -> String
textColorClass darkMode =
    if darkMode then
        "text-[#e0e0e0]"

    else
        "text-[#6d4646]"


textColorDarkClass : Bool -> String
textColorDarkClass darkMode =
    if darkMode then
        "text-[#ffffff]"

    else
        "text-[#0e0e0e]"


borderColorClass : Bool -> String
borderColorClass darkMode =
    if darkMode then
        "border-[#404040]"

    else
        "border-gray-300"


bgInputClass : Bool -> String
bgInputClass darkMode =
    if darkMode then
        "bg-[#2a2a2a]"

    else
        "bg-white"


linkColorClass : Bool -> String
linkColorClass darkMode =
    if darkMode then
        "text-[#9db4ff] hover:text-[#c5d4ff]"

    else
        "text-[#6d4646] hover:text-[#0e0e0e]"


view : Model -> Browser.Document Msg
view model =
    { title = "Ensō Elm Playground"
    , body =
        [ Html.main_ [ Attributes.class ("min-h-screen flex flex-col justify-between " ++ backgroundClass model.darkMode) ]
            [ logoSection model.darkMode
            , div [ class "" ]
                [ viewHeader model.darkMode
                , viewWrappable
                    [ viewExercices model.url.query model.darkMode
                    , viewEditor model.srcCode model.darkMode
                    , viewIFrame model.compilation model.darkMode
                    ]
                ]
            , footerSection model.darkMode
            ]
        ]
    }


logoSection : Bool -> Html Msg
logoSection darkMode =
    div [ class "p-2 pb-4 flex items-center justify-between" ]
        [ img [ src "Logo.svg", width 100 ] []
        , button
            [ class ("px-4 py-2 rounded-md " ++ bgInputClass darkMode ++ " " ++ textColorDarkClass darkMode ++ " border-2 " ++ borderColorClass darkMode ++ " hover:opacity-80 transition-opacity mr-4")
            , Events.onClick ToggleDarkMode
            ]
            [ text
                (if darkMode then
                    "☀️ Light"

                 else
                    "🌙 Dark"
                )
            ]
        ]


footerSection : Bool -> Html Msg
footerSection darkMode =
    div [ class ("text-center text-sm pt-4 " ++ textColorClass darkMode) ]
        [ a [ href "https://enso.no", target "_blank", class (linkColorClass darkMode ++ " underline") ] [ text "Made with ❤️ by Ensō" ] ]


viewHeader : Bool -> Html Msg
viewHeader darkMode =
    Html.header [ Attributes.class "w-full flex flex-col items-center justify-center p-8 shrink-0 space-y-4" ]
        [ Html.h1 [ Attributes.class ("text-4xl " ++ textColorClass darkMode) ] [ Html.text "Learn Elm with Ensō" ]
        , viewParagraph darkMode
            [ Html.text """
        Try to make these simple exercises compile && work using nothing but the
        delightful and friendly compiler. The exercies where originally made by """
            , viewLink "jgrenat" "https://github.com/jgrenat" False darkMode
            , Html.text " as a "
            , viewLink "workshop" "https://github.com/jgrenat/elm-compiler-driven-development" False darkMode
            , Html.text ", and are used with his kind permission."
            , Html.text "A big shoutout to "
            , viewLink "Décio Ferreira" "https://github.com/decioferreira" False darkMode
            , Html.text ", for making "
            , viewLink "Guida-lang (1:1 compatible with Elm)" "https://guida-lang.org" False darkMode
            , Html.text ", and for being helpful with some nitty-gritty compiler details."
            ]
        ]


viewEditor : String -> Bool -> Html Msg
viewEditor srcCode darkMode =
    Html.div
        [ Attributes.class "contents"
        ]
        [ Html.div
            [ Attributes.class ("m-2 mr-0 rounded-sm font-mono border-2 border-r-0 pt-2 text-right " ++ bgInputClass darkMode ++ " " ++ textColorDarkClass darkMode ++ " " ++ borderColorClass darkMode)
            ]
            (lineNumbers srcCode)
        , Html.textarea
            [ Attributes.class ("rounded-sm border-2 border-l-0 m-2 mr-1 ml-0 p-2 focus:outline-none flex-1 font-mono resize-none " ++ bgInputClass darkMode ++ " " ++ textColorDarkClass darkMode ++ " " ++ borderColorClass darkMode)
            , Attributes.value srcCode
            , onInputWithPreventDefault EditSrc
            ]
            []
        ]


onInputWithPreventDefault : (String -> msg) -> Attribute msg
onInputWithPreventDefault tagger =
    Events.preventDefaultOn "input" (Json.map alwaysPrevent (Json.map tagger targetValue))


alwaysPrevent : a -> ( a, Bool )
alwaysPrevent x =
    ( x, True )


targetValue : Json.Decoder String
targetValue =
    Json.at [ "target", "value" ] Json.string


lineNumbers : String -> List (Html msg)
lineNumbers srcCode =
    let
        lines =
            srcCode |> String.split "\n" |> List.length

        comp index =
            Html.div [] [ Html.text <| ((index + 1) |> String.fromInt) ++ "：" ]
    in
    List.repeat lines ()
        |> List.indexedMap (\index () -> comp index)


viewIFrame : Compilation -> Bool -> Html Msg
viewIFrame compilation darkMode =
    let
        ( content, loading ) =
            case compilation of
                Loading ->
                    ( viewStatus "Loading..." darkMode, True )

                Failure Nothing ->
                    ( viewStatus "Something went wrong, and it's not your fault" darkMode, False )

                Failure (Just err) ->
                    ( viewError err, False )

                Success res ->
                    ( Html.iframe [ Attributes.class ("p-2 focus:outline-none flex-1 font-mono resize-none " ++ bgInputClass darkMode), Attributes.srcdoc res ] [], False )
    in
    Html.div
        [ Attributes.classList
            [ ( "flex h-full items-center justify-center rounded-sm border-2 m-2 mr-1 flex-1 transition transition-duration-1000 " ++ bgInputClass darkMode ++ " " ++ borderColorClass darkMode, True )
            , ( "blur-[2px]", loading )
            ]
        ]
        [ content ]


viewStatus : String -> Bool -> Html Msg
viewStatus string darkMode =
    Html.div [ class (textColorDarkClass darkMode) ] [ Html.text string ]


viewWrappable : List (Html msg) -> Html msg
viewWrappable content =
    Html.div
        [ Attributes.class "flex flex-wrap flex-1"
        ]
        content


viewParagraph : Bool -> List (Html msg) -> Html msg
viewParagraph darkMode content =
    Html.p [ Attributes.class ("max-w-prose text-center " ++ textColorClass darkMode) ] content


viewLink : String -> String -> Bool -> Bool -> Html msg
viewLink text href active darkMode =
    Html.a
        [ Attributes.href href
        , Attributes.classList
            [ ( linkColorClass darkMode ++ " underline", True )
            , ( "font-bold", active )
            ]
        , Attributes.target "_blank"
        ]
        [ Html.text text ]


menuItem : String -> String -> Bool -> Bool -> Html msg
menuItem text href active darkMode =
    Html.a
        [ Attributes.href href
        , Attributes.classList
            [ ( "hover:underline uppercase mb-4 " ++ textColorClass darkMode, True )
            , ( "font-bold", active )
            ]
        ]
        [ Html.text text ]


viewExercices : Maybe String -> Bool -> Html msg
viewExercices activeExercise darkMode =
    Html.aside [ Attributes.class ("w-64 p-4 border-r overflow-y-auto " ++ bgInputClass darkMode ++ " " ++ borderColorClass darkMode) ]
        [ Html.h2 [ Attributes.class ("text-base " ++ textColorDarkClass darkMode) ]
            [ Html.text "Exercises:" ]
        , Html.ul
            []
            (exercises
                |> List.map
                    (\exercise ->
                        Html.li [ Attributes.class "mb-1" ] [ menuItem exercise.name ("?" ++ exercise.id) (activeExercise == Just exercise.id) darkMode ]
                    )
            )
        ]


wrapErr : String -> String
wrapErr err =
    """<pre style="color:red; padding:0rem; margin: 0;">""" ++ err ++ "</pre>"
