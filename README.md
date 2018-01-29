# clojure-practise-chat
Practising clojure and swift by creating a simple chat server and iOs client

# Requirements
* [Leiningen](https://leiningen.org/) is required for running and getting libraries for server
* [Cocoapods](https://cocoapods.org/) is required for getting iOs client libraries

# Dependencies
## Server (clojure)
* [Aleph](http://aleph.io/) server library
* [Compojure](https://github.com/weavejester/compojure) http request routing library
* [clj-uuid](https://github.com/danlentz/clj-uuid) UUID library

## Client (swift)
* [Xcode and swift 4](https://developer.apple.com/xcode/)
* [Starscream](https://github.com/daltoniam/Starscream) Websocket library
* [SwiftyJSON](https://github.com/SwiftyJSON/SwiftyJSON) Sane JSON library

# Naming
Server is named chat-server, since that is what it does. Client is named Butembo Chat, since I was drinking coffee from Butembo at the time I created the Xcode project. Butembo is a city in Kongo.

![Screenshot](https://raw.githubusercontent.com/joonamo/clojure-practise-chat/master/preview.png)