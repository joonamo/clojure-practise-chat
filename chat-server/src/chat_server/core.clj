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
    [clojure.core.async :as a]
    [clojure.data.json :as json]))

;; user handling
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

(defn get-name-for-user
  [target-user]
  (if (contains? @connections-to-users target-user)
    ((@connections-to-users target-user) :name)
    nil))

(def non-websocket-request
  {:status 400
   :headers {"content-type" "application/text"}
   :body "Expected a websocket request."})

(def quit-response
  {:status 200
   :headers {"content-type" "application/text"}
   :body "Thank you for chatting!"})

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
  [room conn data]
  (println (str "data: " data))
  (bus/publish! chatrooms room (str (get-name-for-user conn) " said " data)))

(defn chat-handler
  [req]
    (d/let-flow [conn (d/catch
                      (http/websocket-connection req)
                      (fn [_] nil))]
    (if-not conn
      ;; if it wasn't a valid websocket handshake, return an error
      non-websocket-request
      ;; otherwise, create new user
      (d/let-flow [room "default"
                    _ (add-user! conn)
                    _ (s/on-closed conn #(remove-user! conn))]
        ;; take all messages from the chatroom, and feed them to the client
        (s/connect
          (bus/subscribe chatrooms room)
          conn)
        (s/consume
          #(handle-incoming-data room conn %)
          (->> conn
              (s/map #(str %))
              (s/buffer 100))))))

    quit-response)


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
