import Browser
import Html exposing (..)
import Browser.Navigation as Nav
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput)
import Url
import Http

import Url.Builder as Url
import Json.Decode as Decode
import Json.Encode as Encode
import Task

import Route exposing (Route)
import Session
import Api
import Page.Home as Home
import Page.Voting as Voting
import Page.NewVoting as NewVoting

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

init : () -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
  changeRouteTo (Route.fromUrl url) (Redirect <| Session.init key)

-- MODEL
type Model
  = Redirect Session.Model
  | NotFound Session.Model
  | Home Home.Model
  | Voting Voting.Model
  | NewVoting NewVoting.Model

toSession : Model -> Session.Model
toSession page =
  case page of
    Redirect session ->
      session
    NotFound session ->
      session
    Home home ->
      Home.toSession home
    Voting voting ->
      Voting.toSession voting
    NewVoting newVoting ->
      NewVoting.toSession newVoting

-- UPDATE

changeRouteTo : Maybe Route -> Model -> ( Model, Cmd Msg )
changeRouteTo maybeRoute model =
  let
    session = toSession model
  in
    case maybeRoute of
      Nothing ->
        ( NotFound (toSession model), Cmd.none )
      Just Route.Home ->
        Home.init session
          |> updateWith Home GotHomeMsg model
      Just (Route.Voting id) ->
        Voting.init session id
          |> updateWith Voting GotVotingMsg model
      Just Route.NewVoting ->
        NewVoting.init session
          |> updateWith NewVoting GotNewVotingMsg model

type Msg
  = LinkClicked Browser.UrlRequest
  | UrlChanged Url.Url
  | GotHomeMsg Home.Msg
  | GotVotingMsg Voting.Msg
  | GotNewVotingMsg NewVoting.Msg
  | UpdateStr String

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
  case ( msg, model ) of
    ( LinkClicked urlRequest, _ ) ->
      case urlRequest of
        Browser.Internal url ->
          ( model
          , Nav.pushUrl (Session.navKey <| toSession model) (Url.toString url)
          )
        Browser.External href ->
          ( model, Nav.load href )

    ( UrlChanged url, _ ) ->
      changeRouteTo (Route.fromUrl url) model

    ( GotHomeMsg subMsg, Home home ) ->
      Home.update subMsg home
        |> updateWith Home GotHomeMsg model

    ( GotVotingMsg subMsg, Voting voting ) ->
      Voting.update subMsg voting
        |> updateWith Voting GotVotingMsg model

    ( GotNewVotingMsg subMsg, NewVoting newVoting ) ->
      NewVoting.update subMsg newVoting
        |> updateWith NewVoting GotNewVotingMsg model

    ( UpdateStr str, _) ->
        ( model, Cmd.none )

    ( _, _ ) ->
      ( model, Cmd.none )

updateWith : (subModel -> Model) -> (subMsg -> Msg) -> Model -> ( subModel, Cmd subMsg ) -> ( Model, Cmd Msg )
updateWith toModel toMsg model ( subModel, subCmd ) =
    ( toModel subModel
    , Cmd.map toMsg subCmd
    )

-- SUBSCRIPTIONS

subscriptions : Model -> Sub Msg
subscriptions model =
  case model of
    Home homeModel ->
      Home.subscriptions homeModel
        |> Sub.map GotHomeMsg

    NewVoting newVotingModel ->
      NewVoting.subscriptions newVotingModel
        |> Sub.map GotNewVotingMsg

    Voting votingModel ->
      Voting.subscriptions votingModel
        |> Sub.map GotVotingMsg

    _ -> Sub.none

-- VIEW

view : Model -> Browser.Document Msg
view model =
  let
     realTitle = getTitle model
  in
    { title = realTitle
    , body = getBody model
    }

getTitle: Model -> String
getTitle model =
  case model of
    Home _ -> "Ask to Vote!"
    Voting m -> "Voting #" ++ m.id
    NewVoting m -> "Create voting"
    NotFound _ -> "Not found"
    _ -> ""

getBody: Model -> List (Html Msg)
getBody model =
  let
    nonStaticBody =
      case model of
        Home subModel ->
          List.map (Html.map GotHomeMsg) (Home.view subModel)
        Voting subModel -> 
          List.map (Html.map GotVotingMsg) (Voting.view subModel)
        NewVoting subModel ->
          List.map (Html.map GotNewVotingMsg) (NewVoting.view subModel)
        NotFound _ ->
          [ div [ class "jumbotron"]
            [ h1 [ class "display-4" ] [ text "Not found" ]
            ]
          ]
        _ -> []
  in
    [ div [ class "container" ] <|
      mainMenu model
      ++ 
      nonStaticBody
      ++
      footerElement
    ]

mainMenu model =
  let
    mainPageClass =
      case model of
        Home _ -> " active"
        _ -> ""
  in
  [ ul [ class "nav" ]
    [ li [ class "nav-item" ]
        [ a [ href "/", class ("nav-link" ++ mainPageClass) ] [ text "Main page" ]
        ]
    ]
  ]

footerElement =
  [ div [ class "alert alert-warning"] [ text "Server is not saving votings and doesn't have persistant storage. All results can be lost in any time. Save results by yourself!"]
  , footer [ class "float-right" ]
    [ p [] [ text "Copyright Yauhen Pyl"]
    , a [ class "float-right", href "https://github.com/eapyl/vote-ask" ] [ small [] [ text "v.0.0.1" ] ]
    ]
  ]
