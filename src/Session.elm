module Session exposing (..)

import Browser.Navigation as Nav
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onInput)

-- MODEL

type User
  = Guest
  | Creator
  | Voter

type alias Model =
  { key: Nav.Key
  , user: User
  }

init: Nav.Key -> Model
init key =
  Model key Guest

navKey : Model -> Nav.Key
navKey session =
  session.key

isCreator: Model -> Bool
isCreator session =
  if session.user == Creator then True else False

isVoter: Model -> Bool
isVoter session =
  if session.user == Voter then True else False

toCreator: Model -> Model
toCreator session =
  { session | user = Creator }

toVoter: Model -> Model
toVoter session =
  { session | user = Voter }

