(ns chat-server.core
  (:require
    [compojure.core :as compojure :refer [GET]]
    [ring.middleware.params :as params]
    [compojure.route :as route]
    [aleph.http :as http]
    [byte-streams :as bs]
    [manifold.stream :as s]
    [manifold.deferred :as d]
    [manifold.bus :as bus]
    [clojure.core.async :as a]))

(def connections-to-users (atom {}))

(defn add-user 
  [users new-connection]
  (assoc users new-connection {:name "new-user"}))
(defn add-user! 
  [new-connection]
  (swap! connections-to-users add-user new-connection))
(defn rename-user
  [users target-user new-name]
  (if (contains? users target-user)
    (update-in users [target-user :name] (fn [& _] new-name))
    users)
    )
(defn rename-user!
  [target-user new-name]
  (swap! connections-to-users rename-user target-user new-name))
(defn remove-user!
  [target-user]
  (swap! connections-to-users dissoc target-user))


(def non-websocket-request
  {:status 400
   :headers {"content-type" "application/text"}
   :body "Expected a websocket request."})

(defn echo-handler
  [req]
  (->
    (d/let-flow [socket (http/websocket-connection req)
                  _ (s/on-closed socket #(println "socket closed"))]
      
      (s/connect socket socket))
    (d/catch
      (fn [_]
        non-websocket-request))))

(def chatrooms (bus/event-bus))

(defn handle-incoming-data
  [room & args]
  (println (str room " " (first args)))
  (bus/publish! chatrooms room args))

(defn chat-handler
  [req]
  (d/let-flow [conn (d/catch
                      (http/websocket-connection req)
                      (fn [_] nil))]
    (if-not conn
      ;; if it wasn't a valid websocket handshake, return an error
      non-websocket-request
      ;; otherwise, take the first two messages, which give us the chatroom and name
      (d/let-flow [room (s/take! conn)
                   name (s/take! conn)]
        (println (str "user " name " joined channel " room))
        ;; take all messages from the chatroom, and feed them to the client
        (s/connect
          (bus/subscribe chatrooms room)
          conn)
        ;; take all messages from the client, prepend the name, and publish it to the room
        (s/consume
          #(handle-incoming-data room %)
          (->> conn
            (s/map #(str name ": " %))
            (s/buffer 100)))))))
(def handler
  (params/wrap-params
    (compojure/routes
      (GET "/chat" [] chat-handler)
      (GET "/echo" [] echo-handler)
      (route/not-found "No such page."))))


(defn -main
  "I don't do a whole lot ... yet."
  [& args]
  (println "Starting server!")
  (http/start-server handler {:port 10000})
  (println "Server running?")
  )
