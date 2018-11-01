module Component.User exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onInput)

-- MODEL

type alias Model =
  { name: String }

init: String -> Model
init name =
  Model name

-- UPDATE

type Msg
  = ChangeUserName String

update: Msg -> Model -> ( Model, Cmd Msg )
update msg model =
  case msg of
    ChangeUserName name ->
      ( { model | name = name }
      , Cmd.none
      )

-- VIEW

view: Model -> Html Msg
view model =
  div [ class "form-row" ]
    [ div [ class "col" ]
      [ input [ class "form-control", placeholder "Name", type_ "text", value model.name, onInput ChangeUserName ] []
      , small [ class "form-text text-danger", hidden (emptyName model == False) ] [ text "Please provide your name"]
      ]
    ]

emptyName model =
  if model.name == "" then True else False