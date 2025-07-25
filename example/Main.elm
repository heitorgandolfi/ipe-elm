port module Main exposing (..)

import Browser
import Html exposing (Html, button, div, h2, input, p, text)
import Html.Attributes exposing (class, placeholder, value)
import Html.Events exposing (onClick, onInput)
import Ipe exposing (Error(..), StorageType(..))
import Json.Decode as Decode
import Json.Encode as Encode
import Process
import Task


-- PORTS


port saveToStorage : Encode.Value -> Cmd msg
port loadFromStorage : Encode.Value -> Cmd msg
port removeFromStorage : Encode.Value -> Cmd msg
port receiveStorageResult : (Encode.Value -> msg) -> Sub msg


-- STORAGE HELPERS


saveToIpe : StorageType -> String -> Encode.Value -> Cmd msg
saveToIpe storageType key value =
    Ipe.save storageType key value |> saveToStorage

loadFromIpe : StorageType -> String -> Cmd msg  
loadFromIpe storageType key =
    Ipe.load storageType key |> loadFromStorage

removeFromIpe : StorageType -> String -> Cmd msg
removeFromIpe storageType key =
    Ipe.remove storageType key |> removeFromStorage


-- MODEL


type alias Model =
    { userProfile: Maybe UserProfile
    , userNameInput: String
    , userEmailInput: String
    , theme: Maybe String
    , statusMessage: String
    , lastError: Maybe String
    }


type alias UserProfile =
    { name: String
    , email: String
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( { userProfile = Nothing
      , userNameInput = ""
      , userEmailInput = ""
      , theme = Nothing
      , statusMessage = "Ready to start!"
      , lastError = Nothing
      }
    , Cmd.none
    )


-- MESSAGES


type Msg
    = UpdateUserName String
    | UpdateUserEmail String
    | SaveProfile
    | LoadProfile
    | RemoveProfile
    | SaveTheme String
    | LoadTheme
    | RemoveTheme
    | LoadNonExistentKey
    | TriggerDecodeError
    | StorageDataReceived Encode.Value
    | ResetStatus


-- JSON Encoders and Decoders


userProfileDecoder : Decode.Decoder UserProfile
userProfileDecoder =
    Decode.map2 UserProfile
        (Decode.field "name" Decode.string)
        (Decode.field "email" Decode.string)


encodeUserProfile : UserProfile -> Encode.Value
encodeUserProfile profile =
    Encode.object
        [ ( "name", Encode.string profile.name )
        , ( "email", Encode.string profile.email )
        ]


-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        UpdateUserName name ->
            ( { model | userNameInput = name }, Cmd.none )

        UpdateUserEmail email ->
            ( { model | userEmailInput = email }, Cmd.none )

        SaveProfile ->
            let
                profileToSave =
                    UserProfile model.userNameInput model.userEmailInput
            in
            ( { model | statusMessage = "Saving profile..." }
            , Cmd.batch
                [ saveToIpe Local "user-profile" (encodeUserProfile profileToSave)
                , Process.sleep 500 |> Task.perform (\_ -> ResetStatus)
                ]
            )

        LoadProfile ->
            ( { model | statusMessage = "Loading profile..." }
            , loadFromIpe Local "user-profile"
            )

        RemoveProfile ->
            ( { model | statusMessage = "Removing profile..." }
            , Cmd.batch
                [ removeFromIpe Local "user-profile"
                , Process.sleep 500 |> Task.perform (\_ -> ResetStatus)
                ]
            )

        SaveTheme themeName ->
            ( { model | statusMessage = "Saving theme..." }
            , Cmd.batch
                [ saveToIpe Session "session-theme" (Encode.string themeName)
                , Process.sleep 500 |> Task.perform (\_ -> ResetStatus)
                ]
            )

        LoadTheme ->
            ( { model | statusMessage = "Loading theme..." }
            , loadFromIpe Session "session-theme"
            )

        RemoveTheme ->
            ( { model | statusMessage = "Removing theme..." }
            , Cmd.batch
                [ removeFromIpe Session "session-theme"
                , Process.sleep 500 |> Task.perform (\_ -> ResetStatus)
                ]
            )

        LoadNonExistentKey ->
            ( { model | statusMessage = "Trying to load non-existent key..." }
            , loadFromIpe Local "key-that-does-not-exist"
            )

        TriggerDecodeError ->
            ( { model | statusMessage = "Triggering decode error by loading theme as profile..." }
            , Cmd.batch
                [ 
                  saveToIpe Session "test-theme-data" (Encode.string "Dark Theme")
                , 
                  loadFromIpe Session "test-theme-data"
                ]
            )

        StorageDataReceived value ->
            case Decode.decodeValue (Decode.field "key" Decode.string) value of
                Ok key ->
                    handleStorageData key value model
                
                Err _ ->
                    ( { model | statusMessage = "Failed to decode storage response.", lastError = Just "Invalid storage response format" }, Cmd.none )

        ResetStatus ->
            ( { model | statusMessage = "Operation completed successfully!" }, Cmd.none )


handleStorageData : String -> Encode.Value -> Model -> ( Model, Cmd Msg )
handleStorageData key value model =
    case key of
        "user-profile" ->
            case Ipe.decodeStorageResult userProfileDecoder value of
                Ok profile ->
                    ( { model | userProfile = Just profile, statusMessage = "Profile loaded successfully!", lastError = Nothing }, Cmd.none )
                
                Err (DecodeError decodeError) ->
                    ( { model | userProfile = Nothing, statusMessage = "Failed to load profile.", lastError = Just ("DecodeError: The found data does not match the expected format. (" ++ Decode.errorToString decodeError ++ ")") }, Cmd.none )
                
                Err NotFound ->
                    ( { model | userProfile = Nothing, statusMessage = "Profile not found.", lastError = Just "NotFound: The key was not found in storage." }, Cmd.none )

        "session-theme" ->
            case Ipe.decodeStorageResult Decode.string value of
                Ok themeData ->
                    ( { model | theme = Just themeData, statusMessage = "Theme loaded successfully!", lastError = Nothing }, Cmd.none )
                
                Err NotFound ->
                    ( { model | theme = Nothing, statusMessage = "Theme not found.", lastError = Just "NotFound: The key was not found in storage." }, Cmd.none )
                
                Err (DecodeError decodeError) ->
                    ( { model | theme = Nothing, statusMessage = "Failed to load theme.", lastError = Just ("DecodeError: " ++ Decode.errorToString decodeError) }, Cmd.none )

        "key-that-does-not-exist" ->
            case Ipe.decodeStorageResult Decode.string value of
                Ok foundValue ->
                    ( { model | statusMessage = "Key loaded: " ++ foundValue, lastError = Nothing }, Cmd.none )
                
                Err NotFound ->
                    ( { model | statusMessage = "Expected failure when loading key!", lastError = Just "NotFound: The key was not found in storage." }, Cmd.none )
                
                Err (DecodeError decodeError) ->
                    ( { model | statusMessage = "Expected failure when loading key!", lastError = Just ("DecodeError: " ++ Decode.errorToString decodeError) }, Cmd.none )

        "bad-data-key" ->
            case Ipe.decodeStorageResult userProfileDecoder value of
                Ok profile ->
                    ( { model | userProfile = Just profile, statusMessage = "Unexpected success!", lastError = Nothing }, Cmd.none )
                
                Err (DecodeError decodeError) ->
                    ( { model | statusMessage = "Expected decode error occurred.", lastError = Just ("DecodeError: The found data does not match the expected format. (" ++ Decode.errorToString decodeError ++ ")") }, Cmd.none )
                
                Err NotFound ->
                    ( { model | statusMessage = "Bad data key not found.", lastError = Just "NotFound" }, Cmd.none )

        "test-theme-data" ->
            -- Intentionally try to decode theme data as a profile to trigger error
            case Ipe.decodeStorageResult userProfileDecoder value of
                Ok profile ->
                    ( { model | userProfile = Just profile, statusMessage = "Unexpected success!", lastError = Nothing }, Cmd.none )
                
                Err (DecodeError decodeError) ->
                    ( { model | statusMessage = "Expected decode error occurred.", lastError = Just ("DecodeError: Tried to decode theme data as profile. " ++ Decode.errorToString decodeError) }, Cmd.none )
                
                Err NotFound ->
                    ( { model | statusMessage = "Test theme data not found.", lastError = Just "NotFound" }, Cmd.none )

        _ ->
            ( { model | statusMessage = "Unknown key received: " ++ key }, Cmd.none )


-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    receiveStorageResult StorageDataReceived


-- VIEW


view : Model -> Html Msg
view model =
    div []
        [ div [ class "card status-card" ]
            [ h2 [] [ text "📊 Status" ]
            , p [ class "status-message" ] [ text model.statusMessage ]
            , p [ class "error-message" ] [ text ("Last error: " ++ Maybe.withDefault "None" model.lastError) ]
            ]
        , div [ class "card" ]
            [ h2 [] [ text "⚙️ User Profile (LocalStorage)" ]
            , div [ class "profile-display" ] 
                [ text ("Saved profile: " ++ (Maybe.withDefault "None" (Maybe.map .name model.userProfile))) ]
            , div [ class "input-group" ]
                [ div [ class "input-row" ]
                    [ input [ class "input", placeholder "User name", value model.userNameInput, onInput UpdateUserName ] []
                    , input [ class "input", placeholder "Email", value model.userEmailInput, onInput UpdateUserEmail ] []
                    ]
                ]
            , div [ class "button-group" ]
                [ button [ class "btn-primary", onClick SaveProfile ] [ text "Save Profile" ]
                , button [ class "btn-secondary", onClick LoadProfile ] [ text "Load Profile" ]
                , button [ class "btn-danger", onClick RemoveProfile ] [ text "Remove Profile" ]
                ]
            ]
        , div [ class "card" ]
            [ h2 [] [ text "🎨 Session Theme (SessionStorage)" ]
            , div [ class "theme-display" ] 
                [ text ("Saved theme: " ++ Maybe.withDefault "None" model.theme) ]
            , div [ class "button-group" ]
                [ button [ class "btn-primary", onClick (SaveTheme "Light ☀️") ] [ text "Save Light Theme" ]
                , button [ class "btn-primary", onClick (SaveTheme "Dark 🌙") ] [ text "Save Dark Theme" ]
                , button [ class "btn-secondary", onClick LoadTheme ] [ text "Load Theme" ]
                , button [ class "btn-danger", onClick RemoveTheme ] [ text "Remove Theme" ]
                ]
            ]
        , div [ class "card" ]
            [ h2 [] [ text "🐞 Error Tests" ]
            , div [ class "button-group" ]
                [ button [ class "btn-danger", onClick LoadNonExistentKey ] [ text "Load Non-existent Key (NotFound)" ]
                , button [ class "btn-danger", onClick TriggerDecodeError ] [ text "Force Decode Error" ]
                ]
            ]
        ]


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }