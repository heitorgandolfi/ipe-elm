port module Ipe exposing
    ( StorageType(..)
    , Error(..)
    , save
    , load
    , remove
    , storageResults
    )

import Json.Decode as Decode
import Json.Encode as Encode


-- STORAGE TYPES


type StorageType
    = Local
    | Session


storageTypeToString : StorageType -> String
storageTypeToString st =
    case st of
        Local ->
            "local"

        Session ->
            "session"


-- ERRORS


type Error
    = DecodeError Decode.Error
    | NotFound


-- PORTS


port saveToStorage : Encode.Value -> Cmd msg
port loadFromStorage : Encode.Value -> Cmd msg
port removeFromStorage : Encode.Value -> Cmd msg
port receiveStorageResult : (Encode.Value -> msg) -> Sub msg


-- API


save : StorageType -> String -> Encode.Value -> Cmd msg
save storageType key value =
    Encode.object
        [ ( "storageType", Encode.string (storageTypeToString storageType) )
        , ( "key", Encode.string key )
        , ( "value", value )
        ]
        |> saveToStorage


load : StorageType -> String -> (Result Error Encode.Value -> msg) -> Cmd msg
load storageType key _ =
    let
        payload =
            Encode.object
                [ ( "storageType", Encode.string (storageTypeToString storageType) )
                , ( "key", Encode.string key )
                ]
    in
    loadFromStorage payload


remove : StorageType -> String -> Cmd msg
remove storageType key =
    Encode.object
        [ ( "storageType", Encode.string (storageTypeToString storageType) )
        , ( "key", Encode.string key )
        ]
        |> removeFromStorage


storageResults : Decode.Decoder a -> (Result Error a -> msg) -> Sub msg
storageResults decoder toMsg =
    let
        decodeOuterPayload =
            Decode.field "data" (Decode.nullable Decode.value)

        handleResult maybeJson =
            case maybeJson of
                Nothing ->
                    toMsg (Err NotFound)

                Just json ->
                    case Decode.decodeValue decoder json of
                        Ok value ->
                            toMsg (Ok value)

                        Err decodeError ->
                            toMsg (Err (DecodeError decodeError))
    in
    receiveStorageResult (Decode.decodeValue decodeOuterPayload >> Result.toMaybe >> Maybe.withDefault Nothing >> handleResult)