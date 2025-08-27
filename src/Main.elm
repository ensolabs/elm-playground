module Main exposing (main)

import Browser
import Browser.Navigation as Nav
import Exercises exposing (exercises)
import Html exposing (..)
import Html.Attributes as Attributes exposing (..)
import Html.Events as Events
import Http
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



-- MODEL


type alias Model =
    { key : Nav.Key
    , url : Url.Url
    , compilation : Compilation
    , srcCode : String
    }


type Compilation
    = Loading
    | Failure String
    | Success String


init : () -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init _ url key =
    let
        srcCode =
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
            in
            newModel |> reCompileSrc (Exercises.getExerciseSourceCodeOrDefault url.query)

        GotCompilationResult res ->
            case res of
                Ok code ->
                    ( { model | compilation = Success code }, Cmd.none )

                Err err ->
                    ( { model | compilation = Failure err }, Cmd.none )

        EditSrc src ->
            model |> reCompileSrc src


reCompileSrc : String -> Model -> ( Model, Cmd Msg )
reCompileSrc src model =
    ( { model | compilation = Loading, srcCode = src }
    , compileSrcCommand src
    )


compileSrcCommand : String -> Cmd Msg
compileSrcCommand src =
    Http.post
        { url = "/compile"
        , body = Http.stringBody "text/plain;charset=utf-8" src
        , expect =
            Http.expectStringResponse GotCompilationResult
                (\res ->
                    case res of
                        Http.GoodStatus_ _ body ->
                            Result.Ok body

                        Http.BadStatus_ _ body ->
                            Result.Err body

                        _ ->
                            Result.Err "Unknown error!"
                )
        }



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



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
        ( srcDoc, loading ) =
            case compilation of
                Loading ->
                    ( "Loading...", True )

                Failure err ->
                    ( err |> wrapErr, False )

                Success res ->
                    ( res, False )
    in
    Html.iframe
        [ Attributes.classList
            [ ( "rounded-sm border-2 m-2 mr-1 p-2 focus:outline-none flex-1 font-mono resize-none transition transition-duration-1000", True )
            , ( "blur-[2px]", loading )
            ]
        , Attributes.srcdoc srcDoc
        ]
        []


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
            [ ( "hover:underline hover:font-bold", True )
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
