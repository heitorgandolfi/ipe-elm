module Ipe exposing
    ( StorageType(..)
    , Error(..)
    , save
    , load
    , remove
    , storageTypeToString
    , decodeStorageResult
    )

{-| Elegant Storage for Elm

# Storage Types
@docs StorageType, storageTypeToString

# Error Types  
@docs Error

# Commands
@docs save, load, remove

# Decoders
@docs decodeStorageResult

-}

import Json.Decode as Decode
import Json.Encode as Encode


-- STORAGE TYPES


{-| Storage type - Local or Session storage
-}
type StorageType
    = Local
    | Session


{-| Convert storage type to string for JavaScript interop
-}
storageTypeToString : StorageType -> String
storageTypeToString st =
    case st of
        Local ->
            "local"

        Session ->
            "session"


-- ERRORS


{-| Storage operation errors
-}
type Error
    = DecodeError Decode.Error
    | NotFound


-- COMMAND BUILDERS


{-| Create a save command payload
-}
save : StorageType -> String -> Encode.Value -> Encode.Value
save storageType key value =
    Encode.object
        [ ( "storageType", Encode.string (storageTypeToString storageType) )
        , ( "key", Encode.string key )
        , ( "value", value )
        ]


{-| Create a load command payload
-}
load : StorageType -> String -> Encode.Value
load storageType key =
    Encode.object
        [ ( "storageType", Encode.string (storageTypeToString storageType) )
        , ( "key", Encode.string key )
        ]


{-| Create a remove command payload
-}
remove : StorageType -> String -> Encode.Value
remove storageType key =
    Encode.object
        [ ( "storageType", Encode.string (storageTypeToString storageType) )
        , ( "key", Encode.string key )
        ]


-- DECODERS


{-| Decode storage results from JavaScript
-}
decodeStorageResult : Decode.Decoder a -> Encode.Value -> Result Error a
decodeStorageResult decoder value =
    let
        decodeOuterPayload =
            Decode.field "data" (Decode.nullable Decode.value)
    in
    case Decode.decodeValue decodeOuterPayload value of
        Ok maybeJson ->
            case maybeJson of
                Nothing ->
                    Err NotFound

                Just json ->
                    case Decode.decodeValue decoder json of
                        Ok decodedValue ->
                            Ok decodedValue

                        Err decodeError ->
                            Err (DecodeError decodeError)

        Err _ ->
            Err NotFound