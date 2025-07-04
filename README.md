# Ipê - Elegant Storage for Elm 🌸

[![Elm Package](https://img.shields.io/badge/elm-package-red.svg)](https://package.elm-lang.org/)
[![Version](https://img.shields.io/badge/version-1.0.0-yellow.svg)](https://github.com/heitorgandolfi/ipe-elm/releases)

> A beautiful, type-safe storage library for Elm applications. Simple, elegant, and powerful.

## About Ipê

Just like the Ipê tree that blooms magnificently, this library aims to make your Elm applications flourish with elegant and reliable storage capabilities.

## Features

- **Type-safe** - Full Elm type safety for your storage operations
- **Universal** - Works with both LocalStorage and SessionStorage
- **Simple API** - Clean, intuitive interface
- **Zero dependencies** - Lightweight and focused
- **Modern** - Built for Elm 0.19.1+
- **Reactive** - Subscription-based data updates
- **Error handling** - Comprehensive error management

## Installation

```bash
elm install heitorgandolfi/ipe-elm
```

## Quick Start

### 1. Add the required ports to your Elm module

```elm
port module Main exposing (..)

import Ipe exposing (StorageType(..), Error(..))
import Json.Encode as Encode
import Json.Decode as Decode

-- Required ports
port saveToStorage : Encode.Value -> Cmd msg
port loadFromStorage : Encode.Value -> Cmd msg
port removeFromStorage : Encode.Value -> Cmd msg
port receiveStorageResult : (Encode.Value -> msg) -> Sub msg

-- Helper functions to connect Ipê with your ports
saveToIpe : StorageType -> String -> Encode.Value -> Cmd msg
saveToIpe storageType key value =
    Ipe.save storageType key value |> saveToStorage

loadFromIpe : StorageType -> String -> Cmd msg
loadFromIpe storageType key =
    Ipe.load storageType key |> loadFromStorage

removeFromIpe : StorageType -> String -> Cmd msg
removeFromIpe storageType key =
    Ipe.remove storageType key |> removeFromStorage
```

### 2. Set up the JavaScript bridge

Copy this code to your JavaScript file and call `setupIpePorts(app)` after initializing your Elm app:

```javascript
function setupIpePorts(app) {
  app.ports.saveToStorage.subscribe((payload) => {
    try {
      const { storageType, key, value } = payload;
      const data = JSON.stringify(value);

      if (storageType === "local") {
        localStorage.setItem(key, data);
      } else {
        sessionStorage.setItem(key, data);
      }
    } catch (e) {
      console.error("Ipê (save): Failed to save to storage.", e);
    }
  });

  app.ports.loadFromStorage.subscribe((payload) => {
    try {
      const { storageType, key } = payload;

      let data = null;
      if (storageType === "local") {
        data = localStorage.getItem(key);
      } else {
        data = sessionStorage.getItem(key);
      }

      let parsed = null;
      if (data !== null) {
        try {
          parsed = JSON.parse(data);
        } catch (parseError) {
          parsed = data;
        }
      }

      app.ports.receiveStorageResult.send({ key, data: parsed });
    } catch (e) {
      console.error("Ipê (load): Failed to load from storage.", e);
    }
  });

  app.ports.removeFromStorage.subscribe((payload) => {
    try {
      const { storageType, key } = payload;

      if (storageType === "local") {
        localStorage.removeItem(key);
      } else {
        sessionStorage.removeItem(key);
      }
    } catch (e) {
      console.error("Ipê (remove): Failed to remove from storage.", e);
    }
  });
}

// Initialize your Elm app and connect the ports
var app = Elm.Main.init({ node: document.getElementById('app') });
setupIpePorts(app);
```

### 3. Use Ipê in your Elm code

```elm
type Msg
    = SaveUser
    | LoadUser
    | StorageReceived Encode.Value

type alias User = { name : String, email : String }

-- Save data
saveUser : User -> Cmd Msg
saveUser user =
    saveToIpe Local "current-user" (encodeUser user)

-- Load data  
loadUser : Cmd Msg
loadUser =
    loadFromIpe Local "current-user"

-- Remove data
removeUser : Cmd Msg
removeUser =
    removeFromIpe Local "current-user"

-- Subscribe to storage events
subscriptions : Model -> Sub Msg
subscriptions _ =
    receiveStorageResult StorageReceived

-- Handle storage responses
update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
    case msg of
        StorageReceived value ->
            case Decode.decodeValue (Decode.field "key" Decode.string) value of
                Ok "current-user" ->
                    handleUserData value model
                _ ->
                    (model, Cmd.none)
        
        -- ... other cases

-- Handle user data with Ipê's decoder
handleUserData : Encode.Value -> Model -> (Model, Cmd Msg)
handleUserData value model =
    case Ipe.decodeStorageResult userDecoder value of
        Ok user ->
            ({ model | user = Just user }, Cmd.none)
        
        Err (Ipe.DecodeError error) ->
            ({ model | error = Just ("Decode error: " ++ Decode.errorToString error) }, Cmd.none)
        
        Err Ipe.NotFound ->
            ({ model | user = Nothing }, Cmd.none)
```

## API Reference

### Storage Types

```elm
type StorageType
    = Local      -- localStorage
    | Session    -- sessionStorage
```

### Error Types

```elm
type Error
    = DecodeError Decode.Error  -- JSON decoding failed
    | NotFound                  -- Key not found in storage
```

### Core Functions

#### `save : StorageType -> String -> Encode.Value -> Encode.Value`

Create a save command payload.

```elm
-- Create save payload
savePayload = Ipe.save Local "username" (Encode.string "john")

-- Use with your port
savePayload |> saveToStorage
```

#### `load : StorageType -> String -> Encode.Value`

Create a load command payload.

```elm
-- Create load payload
loadPayload = Ipe.load Local "username"

-- Use with your port
loadPayload |> loadFromStorage
```

#### `remove : StorageType -> String -> Encode.Value`

Create a remove command payload.

```elm
-- Create remove payload
removePayload = Ipe.remove Local "username"

-- Use with your port
removePayload |> removeFromStorage
```

#### `decodeStorageResult : Decode.Decoder a -> Encode.Value -> Result Error a`

Decode storage results from JavaScript.

```elm
-- Handle storage response
case Ipe.decodeStorageResult userDecoder storageValue of
    Ok user ->
        -- Successfully decoded user
        
    Err (DecodeError error) ->
        -- Failed to decode
        
    Err NotFound ->
        -- Key not found in storage
```

#### `storageTypeToString : StorageType -> String`

Convert storage type to string (for advanced usage).

```elm
Ipe.storageTypeToString Local    -- "local"
Ipe.storageTypeToString Session  -- "session"
```

## Example Application

Check out the `/example` directory for a complete, beautiful example application that demonstrates:

- Saving and loading user profiles
- Session theme management  
- Error handling scenarios
- Modern, responsive UI
- Real-world usage patterns

### Running the Example

```bash
cd example
elm make Main.elm --output=main.js
# Open index.html in your browser
```

## JavaScript Bridge (`storage.js`)

The JavaScript bridge is essential for Ipê to work. It handles the actual browser storage operations and communicates with your Elm application through ports.

### Key Features:
- **Automatic JSON handling** - Serializes/deserializes data automatically
- **Error resilience** - Graceful error handling and logging
- **Storage abstraction** - Works with both localStorage and sessionStorage
- **Type preservation** - Maintains data types when possible

### Integration:
1. Copy the `setupIpePorts` function to your project
2. Call it after initializing your Elm app
3. That's it! Ipê handles the rest

## Project Structure

```
ipe-elm/
├── src/
│   └── Ipe.elm              # Main library module
├── example/
│   ├── Main.elm              # Example application
│   ├── index.html            # Example HTML with styling
│   └── main.js               # Compiled example (generated)
├── js/
│   └── storage.js            # JavaScript bridge
├── elm.json                  # Package configuration
└── README.md                 # This file
```

## Contributing

Contributions are welcome! Please feel free to submit issues, feature requests, or pull requests.

### Development Setup

```bash
git clone https://github.com/heitorgandolfi/ipe-elm.git
cd ipe-elm
elm make src/Ipe.elm
```

## Requirements

- Elm 0.19.1+
- Browser with localStorage/sessionStorage support
- JavaScript enabled

## Changelog

### v1.0.0 (Initial Release)
- ✨ Core storage operations (save, load, remove)
- ✨ Support for localStorage and sessionStorage
- ✨ Type-safe error handling
- ✨ Subscription-based updates
- ✨ Complete example application
- ✨ Modern, beautiful UI example

## License

BSD 3-Clause - see [LICENSE](LICENSE) for details.

## Acknowledgments

- Built with ❤️ for the Elm community
- Inspired by the beauty of Brazilian Ipê trees
- Special thanks to all contributors and users

---

Made with 🌸 by the Elm community
Bringing the beauty of Ipê flowers to your Elm applications
