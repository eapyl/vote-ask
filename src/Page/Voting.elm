module Page.Voting exposing (..)

import Http
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput)
import Json.Encode as Encode
import Json.Decode as Decode

import Session
import Api
import Component.User as User
import Route

-- MODEL

type alias Variant =
  { id: Int
  , text: String
  }

type alias UserAnswer =
  { variantId: Int
  , user: String
  }

type alias Model =
  { session: Session.Model
  , id: String
  , question: String
  , variants: List Variant
  , answers: List UserAnswer
  , user: User.Model
  , isClosed: Bool
  }

init: Session.Model -> String -> ( Model, Cmd Msg )
init session votingId = 
  let
    user = User.init ""
  in
    ( Model session "" "" [] [] user False
    , Api.toJs <| Encode.object
          [ ( "action", Encode.string "GetExistingVoting" )
          , ( "votingId", Encode.string votingId )
          ]
    )

fakeModel: Session.Model -> String -> User.Model -> Model
fakeModel session id user =
  Model session id "Question" [ Variant 0 "Variant-1", Variant 1 "Variant-2"] [UserAnswer 0 "Four", UserAnswer 1 "Three", UserAnswer 1 "Two"] user False

-- UPDATE

type Msg
  = GotToUserMsg User.Msg
  | VotingLoaded (Maybe Model)
  | SubmitVoteVariant Variant
  | CloseVoting

update: Msg -> Model -> ( Model, Cmd Msg )
update msg model =
  case msg of
    GotToUserMsg subMsg ->
      User.update subMsg model.user
        |> updateWith (\subMod -> { model | user = subMod }) GotToUserMsg model

    VotingLoaded result ->
      case result of
        Just voting ->
          ( voting
          , Cmd.none
          )
        Nothing ->
          ( model
          , Route.goToUrl (Session.navKey model.session) Route.Home
          )

    SubmitVoteVariant variant ->
      ( model
      , Api.toJs <| Encode.object
          [ ( "action", Encode.string "SubmitVoteVariant" )
          , ( "votingId", Encode.string model.id )
          , ( "variantId", Encode.int variant.id )
          , ( "user", Encode.string model.user.name )
          ]
      )

    CloseVoting ->
      ( model
      , Api.toJs <| Encode.object
          [ ( "action", Encode.string "CloseVoting" )
          , ( "votingId", Encode.string model.id )
          ]
      )

updateWith : (subModel -> Model) -> (subMsg -> Msg) -> Model -> ( subModel, Cmd subMsg ) -> ( Model, Cmd Msg )
updateWith toModel toMsg model ( subModel, subCmd ) =
    ( toModel subModel
    , Cmd.map toMsg subCmd
    )

-- SUBSCRIPTIONS

subscriptions : Model -> Sub Msg
subscriptions model =
  Api.toElm (decodeVoting model)

decodeVoting : Model -> Encode.Value -> Msg
decodeVoting model x =
  let
    variantDecoder =
      Decode.map2 Variant
        (Decode.field "Id" Decode.int)
        (Decode.field "Text" Decode.string)

    answersDecoder =
      Decode.map2 UserAnswer
        (Decode.field "VariantId" Decode.int)
        (Decode.field "User" Decode.string)

    votingDecoder =
      Decode.map7 Model
        (Decode.succeed model.session)
        (Decode.field "Id" Decode.string)
        (Decode.field "Question" Decode.string)
        (Decode.field "Variants" <| Decode.list variantDecoder)
        (Decode.field "Answers" <| Decode.list answersDecoder)
        (Decode.succeed model.user)
        (Decode.field "IsClosed" Decode.bool)

    result = Decode.decodeValue votingDecoder x
  in
    case result of
      Ok voting ->
        VotingLoaded <| Just voting
      Err err ->
        VotingLoaded Nothing

-- VIEW

view: Model -> List (Html Msg)
view model =
  let

    form =
      showUserWidget model
      ++
      [ div [ class "form-row" ]
        [ div [ class "col" ] [ input [ readonly True, class "form-control-plaintext", value model.question ] [] ]
        ]
      ]
      ++
      ( List.concat <| List.map (showVariant model) model.variants )
      ++
      showClose model
  in
    [ h1 [] [ text ("Vote # " ++ model.id) ] ]
    ++
    showRole model
    ++
    [ Html.form [] form ]

showUserWidget: Model -> List ( Html Msg )
showUserWidget model =
  if model.isClosed then
    []
  else
    [ User.view model.user |> Html.map GotToUserMsg ]

showClose: Model -> List (Html Msg)
showClose model =
  if Session.isCreator model.session && model.isClosed == False then
    [ input [ class "btn btn-danger mt-2", type_ "button", value "Close voting", onClick CloseVoting ] []
    ]
  else
    []

showRole: Model -> List ( Html msg )
showRole model =
  if model.isClosed then
    [ div [ class "alert alert-info" ] [ text "Voting is closed. Only view mode." ]]
  else
    if Session.isCreator model.session then
      [ div [ class "alert alert-danger" ] [ text "You are creator. Don't reload the page. Otherwise the voting will be closed and read-only." ] ]
    else
      [ div [ class "alert alert-dark"] [ text "You are voter."]] 

showVariant: Model -> Variant -> List ( Html Msg )
showVariant model variant =
  let
    percent = (votesCount model variant.id) * 100 // (List.length model.answers)  |> String.fromInt
  in
    [ div [ class "form-row mt-2" ] <|
      [ div [ class "col" ] 
        [ input [ readonly True, value variant.text, class "form-control-plaintext" ] []
        ]
      , div [ class "col-auto" ] <| showVoteButton model variant
      ]
    , div [ class "form-row mt-1" ]
      [ div [ class "col"]
        [ div [ class "progress" ]
          [ div [ class "progress-bar", style "width" (percent ++ "%") ] [ text (percent ++ "%") ]
          ]
        ]
      ]
    ]

showVoteButton: Model -> Variant -> List ( Html Msg )
showVoteButton model variant =
  if model.isClosed || User.emptyName model.user then
    []
  else
    [ input [ class "btn btn-success", type_ "button", value "Vote!", onClick (SubmitVoteVariant variant) ] [] ]

votesCount: Model -> Int -> Int
votesCount model variantId =
  model.answers |> List.filter (\x -> x.variantId == variantId) |> List.length

toSession : Model -> Session.Model
toSession model =
    model.session

