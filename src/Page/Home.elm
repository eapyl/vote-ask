module Page.Home exposing (..)

import Http
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput)
import Json.Encode as Encode
import Json.Decode as Decode

import Api
import Route
import Session

-- MODEL

type alias Model =
  { session: Session.Model
  , votingId: String
  , info: String
  }

init: Session.Model -> ( Model, Cmd Msg )
init session = 
  ( Model session "" "", Cmd.none)

-- UPDATE

type Msg
  = ChangeSeachVotingValue String
  | CheckVoting
  | VotingCheckResult (Maybe String)

update: Msg -> Model -> ( Model, Cmd Msg )
update msg model =
  case msg of
    ChangeSeachVotingValue value ->
      ( { model | votingId = value }
      , Cmd.none
      )
    
    CheckVoting -> 
      ( model
      , Api.toJs <| Encode.object
          [ ( "action", Encode.string "CheckVoting" )
          , ( "votingId", Encode.string model.votingId )
          ]
      )

    VotingCheckResult result ->
      case result of
        Just id ->
          ( { model | session = Session.toVoter model.session, info = "" }
          , Route.goToUrl (Session.navKey model.session) (Route.Voting id)
          )
        Nothing ->
          ( { model | info = "Can't find voting." }
          , Cmd.none
          )

-- SUBSCRIPTIONS

subscriptions : Model -> Sub Msg
subscriptions model =
  Api.toElm decodeVotingId

decodeVotingId : Encode.Value -> Msg
decodeVotingId x =
  let
    votingIdDecoder =
      Decode.field "votingId" Decode.string

    result = Decode.decodeValue votingIdDecoder x
  in
    case result of
      Ok string ->
        VotingCheckResult <| Just string
      Err _ -> 
        VotingCheckResult Nothing

-- VIEW

view: Model -> List (Html Msg)
view model =
  [ div [ class "jumbotron" ]
    [ h1 [ class "display-4" ] [ text "Please create or join voting!" ]
    , p [ class "lead" ] [ text "Quick, fast, realtime voting in just few clicks. Create voting and share link with colleagues. See results immediately!" ]
    , hr [ class "my-4"] []
    , div [ class "row"]
      [ div [ class "col-sm" ] [ a [ href "/create", class "btn btn-primary btn-lg" ] [ text "Create new voting" ] ]
      , div [ class "col-sm" ]
        [ Html.form []
          [ div [ class "form-group" ]
              [ label [] [ text "Insert identifier of existing voting:" ]
              , input [ class "form-control", value model.votingId, onInput ChangeSeachVotingValue ] []
              , small [ class "form-text text-muted" ] [ text model.info ]
              ]
          , input [ class "btn btn-primary", type_ "button", value "Find voting", onClick CheckVoting ] []
          ]
        ]
      ]
    ]
  ]

toSession : Model -> Session.Model
toSession model =
    model.session

