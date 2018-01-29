# chat-server

Simple chat server that works on websockets. Created for learning clojure.

## Usage

Simplest way is to run with leiningen

    $ lein run

For debugging, you can also run in repl to inspect what is happening

    $ lein repl
    $ chat-server.core=> (http/start-server handler {:port 10000}) ;; to start server
    $ ;; all interesting bits can be inspected at @connections-to-users
