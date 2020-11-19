module App.Board where

import Prelude
import Camera (Camera, Vec2, constrainPosition, screenPan, toViewBox, zoomOn)
import Data.Int (toNumber)
import Data.Maybe (Maybe(..))
import Data.MediaType (MediaType(..))
import Data.MouseButton (MouseButton(..), isPressed)
import Data.Symbol (SProxy(..))
import Data.Typelevel.Num (d0, d1)
import Data.Vec (vec2, (!!))
import Effect.Class (class MonadEffect, liftEffect)
import GameMap (BackgroundMap(..))
import Halogen (AttrName(..), get, gets, modify_)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import Halogen.Svg.Attributes as SA
import Halogen.Svg.Elements as SE
import Unsafe.Coerce (unsafeCoerce)
import Web.HTML as Web
import Web.HTML.Window as Window
import Web.UIEvent.MouseEvent as MouseEvent
import Web.UIEvent.WheelEvent (WheelEvent)
import Web.UIEvent.WheelEvent as WheelEent

type State
  = { backgroundMap :: BackgroundMap
    , lastMousePosition :: Vec2 Number
    , camera :: Camera
    , windowSize :: Vec2 Number
    }

data Action
  = Initialize
  | HandleMouseDown
  | HandleMouseUp
  | HandleMouseMove MouseEvent.MouseEvent
  | HandleScroll WheelEvent
  | HandleResize

type Input
  = State

_rawHtml :: SProxy "rawHtml"
_rawHtml = SProxy

gameMap :: H.RefLabel
gameMap = H.RefLabel "gameMap"

component :: forall q o m. MonadEffect m => H.Component HH.HTML q Input o m
component =
  H.mkComponent
    { initialState: identity
    , render
    , eval:
      H.mkEval
        $ H.defaultEval
            { handleAction = handleAction
            , initialize = Just Initialize
            }
    }

-- <object type="image/svg+xml" data="image.svg"></object>
render :: forall m cs. MonadEffect m => State -> H.ComponentHTML Action cs m
render state =
  SE.svg
    [ SA.height $ state.windowSize !! d0
    , SA.width $ state.windowSize !! d1
    , HP.id_ "board"
    , toViewBox state.windowSize state.camera
    , unsafeCoerce $ HE.onResize $ const $ Just HandleResize
    ]
    [ backgroundMap state.backgroundMap
    , SE.rect
        [ HE.onMouseMove $ HandleMouseMove >>> Just
        , HE.onMouseDown $ const $ Just HandleMouseDown
        , HE.onMouseUp $ const $ Just HandleMouseUp
        , HE.onWheel $ HandleScroll >>> Just
        , SA.height 1000.0 --SA.height 1000.0 --SA.width 1000.0 
        , SA.width 1000.0
        , HP.attr (AttrName "fill") "transparent"
        ]
    ]

backgroundMap :: forall m cs. BackgroundMap -> H.ComponentHTML Action cs m
backgroundMap (BackgroundMap { width, height, url }) =
  SE.foreignObject
    [ SA.width $ toNumber width
    , SA.height $ toNumber width
    ]
    [ HH.object
        [ HP.type_ (MediaType "image/svg+xml")
        , HP.attr (AttrName "data") ("assets/" <> url)
        , HP.width width
        , HP.height height
        ]
        []
    ]

handleAction :: forall cs o m. MonadEffect m => Action → H.HalogenM State Action cs o m Unit
handleAction = case _ of
  Initialize -> do
    pure unit
  HandleMouseDown -> pure unit
  HandleMouseUp -> pure unit
  HandleMouseMove event -> do
    { lastMousePosition, windowSize, backgroundMap: BackgroundMap background } <- get
    let
      mouseButtonState = MouseEvent.buttons event

      mousePosition = toNumber <$> vec2 (MouseEvent.clientX event) (MouseEvent.clientY event)

      updateCamera camera
        | isPressed LeftMouseButton mouseButtonState =
          constrainPosition zero (windowSize - vec2 (toNumber background.width) (toNumber background.height))
            $ screenPan (mousePosition - lastMousePosition) camera
        | otherwise = camera
    modify_ \state ->
      state
        { lastMousePosition = mousePosition
        , camera = updateCamera state.camera
        }
  HandleScroll event -> do
    mousePosition <- gets _.lastMousePosition
    let
      delta = WheelEent.deltaY event
    when (delta /= 0.0) do
      modify_ \state ->
        state
          { camera =
            zoomOn mousePosition
              ( if delta < 0.0 then 1.1 else 1.0 / 1.1
              )
              state.camera
          }
  HandleResize -> do
    window <- liftEffect Web.window
    width <- liftEffect $ Window.innerWidth window
    height <- liftEffect $ Window.innerHeight window
    modify_ _ { windowSize = toNumber <$> vec2 width height }
