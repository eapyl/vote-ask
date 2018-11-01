module Page.NewVoting exposing (..)

import Session
import Api
import Route
import Component.User as User

import Http
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput)
import Json.Encode as Encode
import Json.Decode as Decode

-- MODEL

type alias Variant =
  { id: Int
  , text: String
  }

type alias Model =
  { session: Session.Model
  , question: String
  , variants: List Variant
  , info: String
  }

init: Session.Model -> ( Model, Cmd Msg )
init session =
  ( Model session "" [ Variant 1 "", Variant 2 "" ] ""
  , Cmd.none)

-- UPDATE
type Msg
  = AddNewVariant
  | ChangeVariant Variant String
  | RemoveVariant Variant
  | ChangeQuestion String
  | SubmitVoting
  | VotingSubmitted (Maybe String)

update: Msg -> Model -> ( Model, Cmd Msg )
update msg model =
  case msg of
    AddNewVariant ->
      ( { model | variants = addNewVariant model }
      , Cmd.none
      )

    ChangeVariant v updatedText ->
      ( { model | variants = changeVariant v updatedText model }
      , Cmd.none
      )

    RemoveVariant v ->
      ( { model | variants = List.filter (\s -> v.id /= s.id) model.variants }
      , Cmd.none
      )

    ChangeQuestion questionText ->
      ( { model | question = questionText }
      , Cmd.none
      )

    SubmitVoting ->
      ( model
      , Api.toJs <| Encode.object
          [ ( "action", Encode.string "SubmitVoting" )
          , ( "question", Encode.string model.question )
          , ( "variants", Encode.list
              (\x -> Encode.object
                [ ( "id", Encode.int x.id)
                , ( "text", Encode.string x.text)
                ]
              ) model.variants
            )
          ]
      )

    VotingSubmitted result ->
      case result of
        Just newId ->
          ( { model | session = Session.toCreator model.session }
          , Route.goToUrl ( Session.navKey model.session ) ( Route.Voting newId )
          )
        Nothing ->
          ( { model | info = "Can't create voting." }
          , Cmd.none
          )

addNewVariant: Model -> List Variant
addNewVariant model =
  let
    existing = model.variants
    newId =
      case (List.maximum ( List.map ( \v -> v.id ) existing)) of
        Just max -> max + 1
        Nothing -> 1
    newVariant = Variant newId ""
  in
    existing ++ [ newVariant ]

changeVariant: Variant -> String -> Model -> List Variant
changeVariant v updatedText model =
   List.map (updateVariant v updatedText) model.variants

updateVariant changedVariant newText storedVariant =
  if changedVariant.id == storedVariant.id then
    { storedVariant | text = newText }
  else
    storedVariant

updateWith : (subModel -> Model) -> (subMsg -> Msg) -> Model -> ( subModel, Cmd subMsg ) -> ( Model, Cmd Msg )
updateWith toModel toMsg model ( subModel, subCmd ) =
    ( toModel subModel
    , Cmd.map toMsg subCmd
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

    result =
      Decode.decodeValue votingIdDecoder x
  in
    case result of
      Ok string ->
        VotingSubmitted <| Just string
      Err _ -> 
        VotingSubmitted Nothing

-- VIEW

view: Model -> List (Html Msg)
view model =
  let
    form = 
      [ div [ class "form-row"]
        [ div [ class "col" ]
          [ input [ class "form-control", type_ "text", placeholder "Question", value model.question, name "question", onInput ChangeQuestion ] []
          , small [] [ text ""]
          ]
        ]
      ]
      ++
      List.indexedMap (viewVariant model) model.variants
      ++
      [ input [ class "btn btn-primary mt-2", type_ "button", onClick AddNewVariant, value "Add new variant" ] [] ]
      ++
      showCreateVoteButton model
  in
    [ h2 [] [ text "New voting" ]
    , Html.form [] form
    ]

viewVariant: Model -> Int -> Variant -> Html Msg
viewVariant model ind v =
  let
    strIndex = String.fromInt (ind + 1)
  in
    div [ class "form-row mt-1" ]
      [ div [ class "col" ]
        [ input [ class "form-control", placeholder ("Variant " ++ strIndex), type_ "text", value v.text, onInput (ChangeVariant v) ] []
        ]
      , div [ class "col-auto" ]
        [ input [ class "btn btn-danger", type_ "button", value "Remove variant", onClick (RemoveVariant v) ] []
        ]
      ]

showCreateVoteButton: Model -> List (Html Msg)
showCreateVoteButton model =
  if model.question /= "" && List.length model.variants > 1 && List.all (\x -> x.text /= "") model.variants then
    [ input [ class "btn btn-success ml-1 mt-2", type_ "button", value "Create vote", onClick SubmitVoting ] []
    ]
  else
    []

toSession : Model -> Session.Model
toSession model =
    model.session