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
    ( Model key url Loading srcCode, compileSrcCommand srcCode )



-- UPDATE


type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url
    | GotCompilationResult (Result String String)
    | EditSrc String


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
            newModel |> reCompileSrc srcCode deps

        GotCompilationResult res ->
            case res of
                Ok code ->
                    ( { model | compilation = Success code }, Cmd.none )

                Err err ->
                    let
                        structuredError =
                            Json.decodeString Error.decoder err
                                |> Result.toMaybe
                    in
                    ( { model | compilation = Failure structuredError }, Cmd.none )

        EditSrc src ->
            model |> reCompileSrc src []


reCompileSrc : String -> List String -> Model -> ( Model, Cmd Msg )
reCompileSrc src extraDeps model =
    ( { model | compilation = Loading, srcCode = src }
    , addDepsAndCompileSrcCommand extraDeps src
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


view : Model -> Browser.Document Msg
view model =
    { title = "Ensō Elm Playground"
    , body =
        [ Html.main_ [ Attributes.class "min-h-screen flex flex-col bg-[#fff6f6]" ]
            [ viewHeader
            , viewWrappable
                [ viewExercices model.url.query
                , viewEditor model.srcCode
                , viewIFrame model.compilation
                ]
            ]
        ]
    }


viewHeader : Html Msg
viewHeader =
    Html.header [ Attributes.class "w-full flex flex-col items-center justify-center p-8 shrink-0 space-y-4" ]
        [ Html.h1 [ Attributes.class "text-2xl" ] [ Html.text "Learn Elm with Ensō" ]
        , viewParagraph
            [ Html.text """
        Try to make these simple exercises compile && work using nothing but the
        delightful and friendly compiler. The final two already work,
        but showcase some cool Elm stuff.
        """
            ]
        , viewParagraph
            [ Html.text "The exercies where originally made by "
            , viewLink "jgrenat" "https://github.com/jgrenat" False
            , Html.text " as a "
            , viewLink "workshop" "https://github.com/jgrenat/compiler-driven-development" False
            , Html.text ", and are used with his kind permission."
            ]
        , viewParagraph
            [ Html.text "A big shoutout to "
            , viewLink "Décio Ferreira" "https://github.com/decioferreira" False
            , Html.text ", for making "
            , viewLink "Guida-lang (1:1 compatible with Elm)" "https://guida-lang.org" False
            , Html.text ", and for being helpful with some nitty-gritty compiler details."
            ]
        ]


viewEditor : String -> Html Msg
viewEditor srcCode =
    Html.textarea
        [ Attributes.class "rounded-sm border-2 m-2 mr-1 p-2 focus:outline-none flex-1 font-mono resize-none"
        , Attributes.value srcCode
        , Events.onInput EditSrc
        ]
        []


viewIFrame : Compilation -> Html Msg
viewIFrame compilation =
    let
        ( content, loading ) =
            case compilation of
                Loading ->
                    ( viewStatus "Loading...", True )

                Failure Nothing ->
                    ( viewStatus "Something went wrong, and it's not your fault", False )

                Failure (Just err) ->
                    ( viewError err, False )

                Success res ->
                    ( Html.iframe [ Attributes.class "p-2 focus:outline-none flex-1 font-mono resize-none", Attributes.srcdoc res ] [], False )
    in
    Html.div
        [ Attributes.classList
            [ ( "flex h-full items-center justify-center rounded-sm border-2 m-2 mr-1 flex-1 transition transition-duration-1000", True )
            , ( "blur-[2px]", loading )
            ]
        ]
        [ content ]


viewStatus : String -> Html Msg
viewStatus string =
    Html.div [] [ Html.text string ]


viewWrappable : List (Html msg) -> Html msg
viewWrappable content =
    Html.div
        [ Attributes.class "flex flex-wrap flex-1"
        ]
        content


viewParagraph : List (Html msg) -> Html msg
viewParagraph content =
    Html.p [ Attributes.class "max-w-prose text-center" ] content


viewLink : String -> String -> Bool -> Html msg
viewLink text href active =
    Html.a
        [ Attributes.href href
        , Attributes.classList
            [ ( "hover:underline hover:font-bold text-blue-600", True )
            , ( "text-blue-600 font-bold", active )
            ]
        ]
        [ Html.text text ]


viewExercices : Maybe String -> Html msg
viewExercices activeExercise =
    Html.aside [ Attributes.class "w-64 p-4 border-r overflow-y-auto" ]
        [ Html.h2 [ Attributes.class "text-xl mb-4" ]
            [ Html.text "Exercises" ]
        , Html.ul
            []
            (exercises
                |> List.map
                    (\exercise ->
                        Html.li [] [ viewLink exercise.name ("?" ++ exercise.id) (activeExercise == Just exercise.id) ]
                    )
            )
        ]


wrapErr : String -> String
wrapErr err =
    """<pre style="color:red; padding:0rem; margin: 0;">""" ++ err ++ "</pre>"
