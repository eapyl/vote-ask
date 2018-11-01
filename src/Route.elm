module Route exposing (Route(..), fromUrl, routeToString, goToUrl)

import Url.Parser as Parser exposing (Parser, (</>), int, map, oneOf, s, string)
import Browser.Navigation as Nav

type Route = 
  Home
  | Voting String
  | NewVoting

routeParser =
  oneOf
  [ Parser.map Home Parser.top
  , Parser.map Voting (s "vote" </> string)
  , Parser.map NewVoting (s "create")
  ]

fromUrl url =
  Parser.parse routeParser url

routeToString : Route -> String
routeToString page =
  let
    pieces =
      case page of
        Home -> [ "/" ]
        Voting id -> [ "vote", id ]
        NewVoting -> [ "create" ]
  in
    String.join "/" pieces

goToUrl: Nav.Key -> Route -> Cmd msg
goToUrl key route =
  Nav.pushUrl key (routeToString route)

