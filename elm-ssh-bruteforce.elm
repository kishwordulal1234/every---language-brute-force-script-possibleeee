module Main exposing (main)

import Browser
import Html exposing (Html, button, div, text, input, p, h1, h2)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput)
import Http
import Task
import Process
import Time

-- MAIN
main : Program () Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }

-- MODEL
type alias Model =
    { host : String
    , port_ : String
    , user : String
    , wordlist : String
    , threads : String
    , timeout : String
    , status : String
    , results : List String
    }

init : () -> ( Model, Cmd Msg )
init _ =
    ( Model "" "22" "" "" "4" "10" "Ready" []
    , Cmd.none
    )

-- UPDATE
type Msg
    = SetHost String
    | SetPort String
    | SetUser String
    | SetWordlist String
    | SetThreads String
    | SetTimeout String
    | StartBruteForce
    | CheckResult String
    | BruteForceComplete (Result Http.Error String)

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        SetHost host ->
            ( { model | host = host }, Cmd.none )
            
        SetPort port_ ->
            ( { model | port_ = port_ }, Cmd.none )
            
        SetUser user ->
            ( { model | user = user }, Cmd.none )
            
        SetWordlist wordlist ->
            ( { model | wordlist = wordlist }, Cmd.none )
            
        SetThreads threads ->
            ( { model | threads = threads }, Cmd.none )
            
        SetTimeout timeout ->
            ( { model | timeout = timeout }, Cmd.none )
            
        StartBruteForce ->
            ( { model | status = "Starting brute force...", results = [] }
            , simulateBruteForce model
            )
            
        CheckResult result ->
            ( { model | results = result :: model.results }
            , Cmd.none
            )
            
        BruteForceComplete result ->
            case result of
                Ok success ->
                    ( { model | status = success, results = success :: model.results }
                    , Cmd.none
                    )
                    
                Err _ ->
                    ( { model | status = "Brute force completed - no credentials found" }
                    , Cmd.none
                    )

-- SUBSCRIPTIONS
subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none

-- VIEW
view : Model -> Html Msg
view model =
    div [ class "container" ]
        [ h1 [] [ text "SSH Brute Force Tool (Elm)" ]
        , div [ class "input-group" ]
            [ input [ type_ "text", placeholder "Host", value model.host, onInput SetHost ] []
            , input [ type_ "text", placeholder "Port", value model.port_, onInput SetPort ] []
            , input [ type_ "text", placeholder "Username", value model.user, onInput SetUser ] []
            , input [ type_ "text", placeholder "Wordlist file", value model.wordlist, onInput SetWordlist ] []
            , input [ type_ "text", placeholder "Threads", value model.threads, onInput SetThreads ] []
            , input [ type_ "text", placeholder "Timeout", value model.timeout, onInput SetTimeout ] []
            , button [ onClick StartBruteForce ] [ text "Start Brute Force" ]
            ]
        , h2 [] [ text "Status" ]
        , p [] [ text model.status ]
        , h2 [] [ text "Results" ]
        , div [] (List.map (\result -> p [] [ text result ]) model.results)
        ]

-- HELPER FUNCTIONS
simulateBruteForce : Model -> Cmd Msg
simulateBruteForce model =
    Process.sleep 2000
        |> Task.andThen (\_ -> Task.succeed "[SUCCESS] admin:password123")
        |> Task.attempt BruteForceComplete

-- Note: This is a simulation since Elm runs in browser and can't directly make SSH connections
-- In a real implementation, you'd need to:
-- 1. Use ports to communicate with a backend service
-- 2. The backend would handle the actual SSH connections
-- 3. Elm would just handle the UI and display results
