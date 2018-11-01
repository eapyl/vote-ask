port module Api exposing (..)

import Json.Encode as E
import Task

-- -- PORTS

port toJs : E.Value -> Cmd msg

port toElm : (E.Value -> msg) -> Sub msg

fakeRequest model msg =
  model |> Ok |> msg |> Task.succeed |> Task.perform identity

getExistingVoting model msg =
  fakeRequest model msg

getExistingVotingId model msg =
  fakeRequest model msg

getVotingResult model msg =
  fakeRequest model msg

closeVoting model msg =
  fakeRequest model msg

postVoting model msg =
  fakeRequest model msg

postVoteVariant model msg =
  fakeRequest model msg

getNewUserId model msg =
  --Http.send CreateNewVote (Http.get (Url.absolute ["new-id"] []) (Decode.field "newId" Decode.string))
  fakeRequest model msg

getNewVotingId model msg =
  --Http.send CreateNewVote (Http.get (Url.absolute ["new-id"] []) (Decode.field "newId" Decode.string))
  fakeRequest model msg

getAnswersOfVoting model msg =
  fakeRequest model msg

type Data = One Int | Two String
type alias Model =
  { value: Data
  }

subModelToModel: Model -> Data -> Model
subModelToModel model subModel =
  { model | value = subModel }

updateWith : (subModel -> Model) -> Model -> subModel -> Model
updateWith toModel model subModel =
    toModel subModel

mainModel =
  Model <| Two ""

mainFunc =
  One 1
    |> updateWith (subModelToModel mainModel) mainModel