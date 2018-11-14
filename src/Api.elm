port module Api exposing (..)

import Json.Encode as E
import Task

-- PORTS

port toJs : E.Value -> Cmd msg

port toElm : (E.Value -> msg) -> Sub msg
